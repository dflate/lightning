from concurrent import futures
from fixtures import *  # noqa: F401,F403
from time import time
from tqdm import tqdm


import logging
import pytest
import random
import utils
import time


num_workers = 10
num_payments = 100


@pytest.fixture
def executor():
    ex = futures.ThreadPoolExecutor(max_workers=num_workers)
    yield ex
    ex.shutdown(wait=False)


@pytest.fixture(scope="module")
def bitcoind():
    bitcoind = utils.BitcoinD(rpcport=21441)
    bitcoind.start()
    info = bitcoind.rpc.getblockchaininfo()
    # Make sure we have segwit
    # Make sure we have some spendable funds
    bitcoind.generate_block(123)
    start_time = time.time()
    # 120 sec timeout
    local_timeout = 120
    while (bitcoind.rpc.getblockchaininfo()['blocks'] < 122) and time.time() < start_time + local_timeout:
        bitcoind.generate_block(1)

    assert not (bitcoind.rpc.getblockchaininfo()['blocks'] < 122)

    if bitcoind.rpc.getwalletinfo()['balance'] < 1:
        logging.debug("Insufficient balance")
        raise ValueError("groestlcoind error no funds from generate blocks")

    yield bitcoind

    try:
        bitcoind.rpc.stop()
    except Exception:
        bitcoind.proc.kill()
    bitcoind.proc.wait()


def test_single_hop(node_factory, executor):
    #FIXME if VALGRIND=1
    l1 = node_factory.get_node()
    l2 = node_factory.get_node()

    l1.rpc.connect(l2.info['id'], 'localhost', port = l2.port)
    l1.daemon.wait_for_log('openingd-.*: Handed peer, entering loop')
    l1.openchannel(l2, 10000000)
    l1.bitcoin.generate_block(1)
    route = l1.rpc.getroute(l2.info['id'], 123000, 1 , 9 , l1.info['id'], 10)['route']


    print("Collecting invoices")
    fs = []
    invoices = []
    for i in tqdm(range(num_payments)):
        invoices.append(l2.rpc.invoice(123000, 'invoice-%d' % (i), 'desc')['payment_hash'])


    print("Sending payments")
    start_time = time.time()

    def do_pay(i):
        p = l1.rpc.sendpay(route, i)
        filler_time = time.time()
        r = l1.rpc.waitsendpay(p['payment_hash'])
        return r

    for i in invoices:
        fs.append(executor.submit(do_pay, i))

    for f in tqdm(futures.as_completed(fs), total=len(fs)):
        f.result()

    diff = time.time() - start_time
    print("Done. %d payments performed in %f seconds (%f payments per second)" % (num_payments, diff, num_payments / diff))


def test_single_payment(node_factory, benchmark):
    l1 = node_factory.get_node()
    l2 = node_factory.get_node()
    l1.rpc.connect(l2.info['id'], 'localhost' , port=l2.port)
    l1.openchannel(l2, 4000000)

    def do_pay(l1, l2):
        invoice = l2.rpc.invoice(1000, 'invoice-{}'.format(random.random()), 'desc')['bolt11']
        l1.rpc.pay(invoice)

    benchmark(do_pay, l1, l2)


def test_invoice(node_factory, benchmark):
    l1 = node_factory.get_node()

    def bench_invoice():
        l1.rpc.invoice(1000, 'invoice-{}'.format(time.time()), 'desc')['bolt11']

    benchmark(bench_invoice)



def test_start(node_factory, benchmark):
    benchmark(node_factory.get_node)

from concurrent import futures
from fixtures import *  # noqa: F401,F403
from time import time
from tqdm import tqdm


import pytest
import random
import time 


num_workers = 10
num_payments = 100


@pytest.fixture
def executor():
    ex = futures.ThreadPoolExecutor(max_workers=num_workers)
    yield ex
    ex.shutdown(wait=False)


def test_single_hop(node_factory, executor):
    l1, l2 = node_factory.line_graph(2, fundchannel=True)
    route = l1.rpc.getroute(l2.info['id'], 1000, 1 , 9 , l1.info['id'], 10)['route']

    print("Collecting invoices")
    fs = []
    invoices = []
    for i in tqdm(range(num_payments)):
        invoices.append(l2.rpc.invoice(1000, 'invoice-%d' % (i), 'desc')['payment_hash'])

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
    l1, l2 = node_factory.line_graph(2)

    def do_pay(l1, l2):
        invoice = l2.rpc.invoice(1000, 'invoice-{}'.format(random.random()), 'desc')['bolt11']
        l1.rpc.pay(invoice)

    benchmark(do_pay, l1, l2)


def test_invoice(node_factory, benchmark):
    l1 = node_factory.get_node()

    def bench_invoice():
        l1.rpc.invoice(1000, 'invoice-{}'.format(time.time()), 'desc')['bolt11']

    benchmark(bench_invoice)


def test_pay(node_factory, benchmark):
    l1, l2 = node_factory.line_graph(2)

    invoices = []
    for _ in range(1, num_payments):
        invoice = l2.rpc.invoice(1000, 'invoice-{}'.format(random.random()), 'desc')['bolt11']
        invoices.append(invoice)

    def do_pay(l1, l2):
        l1.rpc.pay(invoices.pop())

    benchmark(do_pay, l1, l2)



def test_start(node_factory, benchmark):
    benchmark(node_factory.get_node)

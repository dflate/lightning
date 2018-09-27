#include <assert.h>
#include <bitcoin/address.h>
#include <bitcoin/base58.h>
#include <bitcoin/privkey.h>
#include <bitcoin/pubkey.h>
#include <ccan/str/hex/hex.h>
#include <common/type_to_string.h>
#include <common/utils.h>
#include <inttypes.h>
#include <stdio.h>
#define SUPERVERBOSE printf
  #include "../../common/funding_tx.c"
#undef SUPERVERBOSE
  #include "../../common/key_derive.c"

#if 0
static struct sha256 sha256_from_hex(const char *hex)
{
	struct sha256 sha256;
	if (strstarts(hex, "0x"))
		hex += 2;
	if (!hex_decode(hex, strlen(hex), &sha256, sizeof(sha256)))
		abort();
	return sha256;
}

static struct privkey privkey_from_hex(const char *hex)
{
	struct privkey pk;
	size_t len;
	if (strstarts(hex, "0x"))
		hex += 2;
	len = strlen(hex);
	if (len == 66 && strends(hex, "01"))
		len -= 2;
	if (!hex_decode(hex, len, &pk, sizeof(pk)))
		abort();
	return pk;
}
#endif

int main(void)
{
	setup_locale();

	struct bitcoin_tx *input, *funding;
	u64 fee;
	struct pubkey local_funding_pubkey, remote_funding_pubkey;
	struct privkey input_privkey;
	struct pubkey inputkey;
	bool testnet;
	struct utxo utxo;
	const struct utxo **utxomap;
	u64 funding_satoshis;
	u16 funding_outnum;
	u8 *subscript;
	secp256k1_ecdsa_signature sig;
	struct bitcoin_address addr;

	secp256k1_ctx = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY
						 | SECP256K1_CONTEXT_SIGN);
	setup_tmpctx();

	/* BOLT #3:
	 *
	 * Block 1 coinbase transaction: 01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff03510101ffffffff0100002cd6e2150000232102a74321b69723e7574510f2a96d3becea672dd465c747bc6b23b9771a4d02e48aac00000000
	 */

	input = bitcoin_tx_from_hex(tmpctx,
				 "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff03510101ffffffff0100002cd6e2150000232102a74321b69723e7574510f2a96d3becea672dd465c747bc6b23b9771a4d02e48aac00000000",
				 strlen("01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff03510101ffffffff0100002cd6e2150000232102a74321b69723e7574510f2a96d3becea672dd465c747bc6b23b9771a4d02e48aac00000000"));
	assert(input);

	/* BOLT #3:
	 *    Block 1 coinbase privkey: 8344ce325246cce131a4785b3878daef212643c2d62aa23e170f05f38258807901
	 *    # privkey in base58: cRysUDzUoa5BqfvaQnLwQ5aXGXsKD4Hh8Ai3sK6UYSx1CNyLBA2q
	 */
	if (!key_from_base58("cRysUDzUoa5BqfvaQnLwQ5aXGXsKD4Hh8Ai3sK6UYSx1CNyLBA2q",strlen("cRysUDzUoa5BqfvaQnLwQ5aXGXsKD4Hh8Ai3sK6UYSx1CNyLBA2q"),
			     &testnet, &input_privkey, &inputkey))
		abort();
	/* testnet coinbase */
	assert(testnet);
	printf("* Block 1 coinbase privkey: %s\n",
	       type_to_string(tmpctx, struct privkey, &input_privkey));

	/* BOLT #3:
	 *
	 * The funding transaction is paid to the following pubkeys:
	 *
	 *     local_funding_pubkey: 023da092f6980e58d2c037173180e9a465476026ee50f96695963e8efe436f54eb
	 *     remote_funding_pubkey: 030e9f7b623d2ccc7c9bd44d66d5ce21ce504c0acf6385a132cec6d3c39fa711c1
	 */
	if (!pubkey_from_hexstr("0282600e6ffb205676f45b19bd4ff3bd7b0980dcb8d7979fe988516d7e7e95db27",
				strlen("0282600e6ffb205676f45b19bd4ff3bd7b0980dcb8d7979fe988516d7e7e95db27"),
				&local_funding_pubkey))
		abort();
	if (!pubkey_from_hexstr("0282600e6ffb205676f45b19bd4ff3bd7b0980dcb8d7979fe988516d7e7e95db27",
				strlen("030e9f7b623d2ccc7c9bd44d66d5ce21ce504c0acf6385a132cec6d3c39fa711c1"),
				&remote_funding_pubkey))
		abort();

	bitcoin_txid(input, &utxo.txid);
	utxo.outnum = 0;
	utxo.amount = 24064000000000;
	utxo.is_p2sh = false;
	utxo.close_info = NULL;
	funding_satoshis = 10000000;
	fee = 13920;

	printf("input[0] txid: %s\n",
	       tal_hexstr(tmpctx, &utxo.txid, sizeof(utxo.txid)));
	printf("input[0] input: %u\n", utxo.outnum);
	printf("input[0] satoshis: %"PRIu64"\n", utxo.amount);
	printf("funding satoshis: %"PRIu64"\n", funding_satoshis);

	utxomap = tal_arr(tmpctx, const struct utxo *, 1);
	utxomap[0] = &utxo;
	funding = funding_tx(tmpctx, &funding_outnum, utxomap,
			     funding_satoshis,
			     &local_funding_pubkey,
			     &remote_funding_pubkey,
			     utxo.amount - fee - funding_satoshis,
			     &inputkey, NULL);
	printf("# fee: %"PRIu64"\n", fee);
	printf("change satoshis: %"PRIu64"\n",
	       funding->output[!funding_outnum].amount);

	printf("funding output: %u\n", funding_outnum);

	pubkey_to_hash160(&inputkey, &addr.addr);
	subscript = scriptpubkey_p2pkh(funding, &addr);
	sign_tx_input(funding, 0, subscript, NULL, &input_privkey, &inputkey,
		      &sig);

	funding->input[0].script = bitcoin_redeem_p2pkh(funding, &inputkey,
							&sig);
	printf("funding tx: %s\n",
	       tal_hex(tmpctx, linearize_tx(tmpctx, funding)));

	/* No memory leaks please */
	secp256k1_context_destroy(secp256k1_ctx);
	tal_free(tmpctx);

	return 0;
}

#include "shadouble.h"
#include <bitcoin/groestl.h>
#include <ccan/mem/mem.h>
#include <common/type_to_string.h>
#include <common/utils.h>

void sha256_double(struct sha256_double *shadouble, const void *p, size_t len)
{
	sha256(&shadouble->sha, memcheck(p, len), len);
	groestlhash((void *)&shadouble->sha, (void *)p, len);
}

void sha256_double_done(struct sha256_ctx *shactx, struct sha256_double *res)
{
	sha256_done(shactx, &res->sha);
#ifdef COMPILE_FOR_BITCOIN
	/* FIXME */
	 sha256(&res->sha, &res->sha, sizeof(res->sha));
#endif
}
REGISTER_TYPE_TO_HEXSTR(sha256_double);

#include <bitcoin/groestl.h>
#include <bitcoin/sph_groestl.h>
#include <bitcoin/sph_types.h>
#include <ccan/build_assert/build_assert.h>
#include <ccan/tal/str/str.h>
#include <common/utils.h>
#include <stdio.h>

void groestlhash(void *output, const void *input , size_t len)
{
	uint32_t hash[16];
	sph_groestl512_context ctx_1,ctx_2;

	/*int ii;
	printf("result input: ");
	for (ii=0; ii < len; ii++)
	{
		printf ("%.2x",((uint8_t*)input)[ii]);
	};
	printf ("\n");
	*/
	sph_groestl512_init(&ctx_1);
	sph_groestl512(&ctx_1, input, len);
	sph_groestl512_close(&ctx_1, hash);

	sph_groestl512_init(&ctx_2);
	sph_groestl512(&ctx_2, hash, 64);
	sph_groestl512_close(&ctx_2, hash);

	memcpy(output, hash, 32);

	/*
	printf("result output: ");
	for (ii=0; ii < 32; ii++)
	{
	printf ("%.2x",((uint8_t*)output)[ii]);
	};
	printf ("---\n");
	for (ii=0; ii < 32; ii++)
	{
		printf ("%.2x",((uint8_t*)hash)[ii]);
	};
	printf ("\n");
	*/
}





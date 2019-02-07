/* 
 * SHA-1 hash in C and x86 assembly
 * 
 * Copyright (c) 2017 Project Nayuki. (MIT License)
 * https://www.nayuki.io/page/fast-sha1-hash-implementation-in-x86-assembly
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * - The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 * - The Software is provided "as is", without warranty of any kind, express or
 *   implied, including but not limited to the warranties of merchantability,
 *   fitness for a particular purpose and noninfringement. In no event shall the
 *   authors or copyright holders be liable for any claim, damages or other
 *   liability, whether in an action of contract, tort or otherwise, arising from,
 *   out of or in connection with the Software or the use or other dealings in the
 *   Software.
 */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>


/* Function prototypes */

#define BLOCK_LEN 64  // In bytes
#define STATE_LEN 5  // In words

static bool self_check(void);
void sha1_hash(const uint8_t message[], size_t len, uint32_t hash[static STATE_LEN]);

// Link this program with an external C or x86 compression function
extern void sha1_compress(uint32_t state[static STATE_LEN], const uint8_t block[static BLOCK_LEN]);


/* Main program */

int main(void) {
	// Self-check
	if (!self_check()) {
		printf("Self-check failed\n");
		return EXIT_FAILURE;
	}
	printf("Self-check passed\n");
	
	// Benchmark speed
	uint32_t state[STATE_LEN] = {0};
	uint8_t block[BLOCK_LEN] = {0};
	const long ITERS = 10000000;
	clock_t start_time = clock();
	for (long i = 0; i < ITERS; i++)
		sha1_compress(state, block);
	printf("Speed: %.1f MB/s\n", (double)ITERS * (sizeof(block) / sizeof(block[0]))
		/ (clock() - start_time) * CLOCKS_PER_SEC / 1000000);
	
	return EXIT_SUCCESS;
}


/* Test vectors and checker */

static bool self_check(void) {
	struct TestCase {
		uint32_t answer[STATE_LEN];
		const char *message;
	};
	
	static const struct TestCase cases[] = {
		#define TESTCASE(a,b,c,d,e,msg) {{UINT32_C(a),UINT32_C(b),UINT32_C(c),UINT32_C(d),UINT32_C(e)}, msg}
		TESTCASE(0xDA39A3EE,0x5E6B4B0D,0x3255BFEF,0x95601890,0xAFD80709, ""),
		TESTCASE(0x86F7E437,0xFAA5A7FC,0xE15D1DDC,0xB9EAEAEA,0x377667B8, "a"),
		TESTCASE(0xA9993E36,0x4706816A,0xBA3E2571,0x7850C26C,0x9CD0D89D, "abc"),
		TESTCASE(0xC12252CE,0xDA8BE899,0x4D5FA029,0x0A47231C,0x1D16AAE3, "message digest"),
		TESTCASE(0x32D10C7B,0x8CF96570,0xCA04CE37,0xF2A19D84,0x240D3A89, "abcdefghijklmnopqrstuvwxyz"),
		TESTCASE(0x84983E44,0x1C3BD26E,0xBAAE4AA1,0xF95129E5,0xE54670F1, "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
		#undef TESTCASE
	};
	
	size_t numCases = sizeof(cases) / sizeof(cases[0]);
	for (size_t i = 0; i < numCases; i++) {
		const struct TestCase *tc = &cases[i];
		size_t len = strlen(tc->message);
		uint8_t *msg = calloc(len, sizeof(uint8_t));
		if (msg == NULL) {
			perror("calloc");
			exit(1);
		}
		for (size_t j = 0; j < len; j++)
			msg[j] = (uint8_t)tc->message[j];
		
		uint32_t hash[STATE_LEN];
		sha1_hash(msg, len, hash);
		if (memcmp(hash, tc->answer, sizeof(tc->answer)) != 0)
			return false;
		free(msg);
	}
	return true;
}


/* Full message hasher */

void sha1_hash(const uint8_t message[], size_t len, uint32_t hash[static STATE_LEN]) {
	hash[0] = UINT32_C(0x67452301);
	hash[1] = UINT32_C(0xEFCDAB89);
	hash[2] = UINT32_C(0x98BADCFE);
	hash[3] = UINT32_C(0x10325476);
	hash[4] = UINT32_C(0xC3D2E1F0);
	
	#define LENGTH_SIZE 8  // In bytes
	
	size_t off;
	for (off = 0; len - off >= BLOCK_LEN; off += BLOCK_LEN)
		sha1_compress(hash, &message[off]);
	
	uint8_t block[BLOCK_LEN] = {0};
	size_t rem = len - off;
	memcpy(block, &message[off], rem);
	
	block[rem] = 0x80;
	rem++;
	if (BLOCK_LEN - rem < LENGTH_SIZE) {
		sha1_compress(hash, block);
		memset(block, 0, sizeof(block));
	}
	
	block[BLOCK_LEN - 1] = (uint8_t)((len & 0x1FU) << 3);
	len >>= 5;
	for (int i = 1; i < LENGTH_SIZE; i++, len >>= 8)
		block[BLOCK_LEN - 1 - i] = (uint8_t)(len & 0xFFU);
	sha1_compress(hash, block);
}

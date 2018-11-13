/* 
 * SHA-1 hash in C
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

#include <stdint.h>


void sha1_compress(uint32_t state[5], const uint8_t block[64]) {
#define ROTL32(x, n)  (((0U + (x)) << (n)) | ((x) >> (32 - (n))))  // Assumes that x is uint32_t and 0 < n < 32
        
#define LOADSCHEDULE(i)					\
  schedule[i] = (uint32_t)block[i * 4 + 0] << 24	\
    | (uint32_t)block[i * 4 + 1] << 16			\
    | (uint32_t)block[i * 4 + 2] <<  8			\
    | (uint32_t)block[i * 4 + 3] <<  0;
        
#define SCHEDULE(i)							\
  temp = schedule[(i - 3) & 0xF] ^ schedule[(i - 8) & 0xF] ^ schedule[(i - 14) & 0xF] ^ schedule[(i - 16) & 0xF]; \
  schedule[i & 0xF] = ROTL32(temp, 1);
        
#define ROUND0a(a, b, c, d, e, i)  LOADSCHEDULE(i)  ROUNDTAIL(a, b, e, ((b & c) | (~b & d))         , i, 0x5A827999)
#define ROUND0b(a, b, c, d, e, i)  SCHEDULE(i)      ROUNDTAIL(a, b, e, ((b & c) | (~b & d))         , i, 0x5A827999)
#define ROUND1(a, b, c, d, e, i)   SCHEDULE(i)      ROUNDTAIL(a, b, e, (b ^ c ^ d)                  , i, 0x6ED9EBA1)
#define ROUND2(a, b, c, d, e, i)   SCHEDULE(i)      ROUNDTAIL(a, b, e, ((b & c) ^ (b & d) ^ (c & d)), i, 0x8F1BBCDC)
#define ROUND3(a, b, c, d, e, i)   SCHEDULE(i)      ROUNDTAIL(a, b, e, (b ^ c ^ d)                  , i, 0xCA62C1D6)
        
#ifndef UINT32_C
#define UINT32_C(c)c ## U
#endif

#define ROUNDTAIL(a, b, e, f, i, k)					\
  e = 0U + e + ROTL32(a, 5) + f + UINT32_C(k) + schedule[i & 0xF];	\
  b = ROTL32(b, 30);
        
  uint32_t a = state[0];
  uint32_t b = state[1];
  uint32_t c = state[2];
  uint32_t d = state[3];
  uint32_t e = state[4];
        
  uint32_t schedule[16];
  uint32_t temp;
  ROUND0a(a, b, c, d, e,  0)
    ROUND0a(e, a, b, c, d,  1)
    ROUND0a(d, e, a, b, c,  2)
    ROUND0a(c, d, e, a, b,  3)
    ROUND0a(b, c, d, e, a,  4)
    ROUND0a(a, b, c, d, e,  5)
    ROUND0a(e, a, b, c, d,  6)
    ROUND0a(d, e, a, b, c,  7)
    ROUND0a(c, d, e, a, b,  8)
    ROUND0a(b, c, d, e, a,  9)
    ROUND0a(a, b, c, d, e, 10)
    ROUND0a(e, a, b, c, d, 11)
    ROUND0a(d, e, a, b, c, 12)
    ROUND0a(c, d, e, a, b, 13)
    ROUND0a(b, c, d, e, a, 14)
    ROUND0a(a, b, c, d, e, 15)
    ROUND0b(e, a, b, c, d, 16)
    ROUND0b(d, e, a, b, c, 17)
    ROUND0b(c, d, e, a, b, 18)
    ROUND0b(b, c, d, e, a, 19)
    ROUND1(a, b, c, d, e, 20)
    ROUND1(e, a, b, c, d, 21)
    ROUND1(d, e, a, b, c, 22)
    ROUND1(c, d, e, a, b, 23)
    ROUND1(b, c, d, e, a, 24)
    ROUND1(a, b, c, d, e, 25)
    ROUND1(e, a, b, c, d, 26)
    ROUND1(d, e, a, b, c, 27)
    ROUND1(c, d, e, a, b, 28)
    ROUND1(b, c, d, e, a, 29)
    ROUND1(a, b, c, d, e, 30)
    ROUND1(e, a, b, c, d, 31)
    ROUND1(d, e, a, b, c, 32)
    ROUND1(c, d, e, a, b, 33)
    ROUND1(b, c, d, e, a, 34)
    ROUND1(a, b, c, d, e, 35)
    ROUND1(e, a, b, c, d, 36)
    ROUND1(d, e, a, b, c, 37)
    ROUND1(c, d, e, a, b, 38)
    ROUND1(b, c, d, e, a, 39)
    ROUND2(a, b, c, d, e, 40)
    ROUND2(e, a, b, c, d, 41)
    ROUND2(d, e, a, b, c, 42)
    ROUND2(c, d, e, a, b, 43)
    ROUND2(b, c, d, e, a, 44)
    ROUND2(a, b, c, d, e, 45)
    ROUND2(e, a, b, c, d, 46)
    ROUND2(d, e, a, b, c, 47)
    ROUND2(c, d, e, a, b, 48)
    ROUND2(b, c, d, e, a, 49)
    ROUND2(a, b, c, d, e, 50)
    ROUND2(e, a, b, c, d, 51)
    ROUND2(d, e, a, b, c, 52)
    ROUND2(c, d, e, a, b, 53)
    ROUND2(b, c, d, e, a, 54)
    ROUND2(a, b, c, d, e, 55)
    ROUND2(e, a, b, c, d, 56)
    ROUND2(d, e, a, b, c, 57)
    ROUND2(c, d, e, a, b, 58)
    ROUND2(b, c, d, e, a, 59)
    ROUND3(a, b, c, d, e, 60)
    ROUND3(e, a, b, c, d, 61)
    ROUND3(d, e, a, b, c, 62)
    ROUND3(c, d, e, a, b, 63)
    ROUND3(b, c, d, e, a, 64)
    ROUND3(a, b, c, d, e, 65)
    ROUND3(e, a, b, c, d, 66)
    ROUND3(d, e, a, b, c, 67)
    ROUND3(c, d, e, a, b, 68)
    ROUND3(b, c, d, e, a, 69)
    ROUND3(a, b, c, d, e, 70)
    ROUND3(e, a, b, c, d, 71)
    ROUND3(d, e, a, b, c, 72)
    ROUND3(c, d, e, a, b, 73)
    ROUND3(b, c, d, e, a, 74)
    ROUND3(a, b, c, d, e, 75)
    ROUND3(e, a, b, c, d, 76)
    ROUND3(d, e, a, b, c, 77)
    ROUND3(c, d, e, a, b, 78)
    ROUND3(b, c, d, e, a, 79)
        
    state[0] = 0U + state[0] + a;
  state[1] = 0U + state[1] + b;
  state[2] = 0U + state[2] + c;
  state[3] = 0U + state[3] + d;
  state[4] = 0U + state[4] + e;
}

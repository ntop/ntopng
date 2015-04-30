/**
 * This code is released under the
 * Apache License Version 2.0 http://www.apache.org/licenses/.
 *
 * (c) Daniel Lemire, http://lemire.me/en/
 *
 * Some code from the public domain tuklib.
 */

#ifndef EWAHUTIL_H
#define EWAHUTIL_H

#include <string.h>
#include <stdlib.h>
#include <iso646.h> // mostly for Microsoft compilers
#include <limits.h>
#include <stdint.h> // part of Visual Studio 2010 and better

#include <cassert>
#include <iostream>
#include <vector>
#include <string>
#include <stdexcept>
#include <cstddef>
#include <algorithm>
#include <sstream>

// taken from stackoverflow
#ifndef NDEBUG
#   define ASSERT(condition, message) \
    do { \
        if (! (condition)) { \
            std::cerr << "Assertion `" #condition "` failed in " << __FILE__ \
                      << " line " << __LINE__ << ": " << message << std::endl; \
            std::exit(EXIT_FAILURE); \
        } \
    } while (false)
#else
#   define ASSERT(condition, message) do { } while (false)
#endif







static inline uint32_t ctz32(uint32_t n) {
#if defined(__INTEL_COMPILER)
	return _bit_scan_forward(n);

#elif defined(__GNUC__) && UINT_MAX >= UINT32_MAX
	return static_cast<uint32_t>(__builtin_ctz(n));

#elif defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))
	uint32_t i;
	__asm__("bsfl %1, %0" : "=r" (i) : "rm" (n));
	return i;

#elif defined(_MSC_VER) && _MSC_VER >= 1400
	uint32_t i;
	_BitScanForward((unsigned long *) &i, n);
	return i;

#else
	uint32_t i = 0;

	if ((n & UINT32_C(0x0000FFFF)) == 0) {
		n >>= 16;
		i = 16;
	}

	if ((n & UINT32_C(0x000000FF)) == 0) {
		n >>= 8;
		i += 8;
	}

	if ((n & UINT32_C(0x0000000F)) == 0) {
		n >>= 4;
		i += 4;
	}

	if ((n & UINT32_C(0x00000003)) == 0) {
		n >>= 2;
		i += 2;
	}

	if ((n & UINT32_C(0x00000001)) == 0)
		++i;

	return i;
#endif
}


static inline uint32_t ctz16(uint16_t n) {
#if defined(__INTEL_COMPILER)
	return _bit_scan_forward(n);

#elif defined(__GNUC__) && UINT_MAX >= UINT32_MAX
	return static_cast<uint32_t>(__builtin_ctz(n));

#elif defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))
	uint32_t i;
	__asm__("bsfl %1, %0" : "=r" (i) : "rm" (n));
	return i;

#elif defined(_MSC_VER) && _MSC_VER >= 1400
	uint32_t i;
	_BitScanForward((unsigned long *) &i, n);
	return i;

#else
	uint32_t i = 0;

	if ((n & UINT16_C(0x0000FFFF)) == 0) {
		n >>= 16;
		i = 16;
	}

	if ((n & UINT16_C(0x000000FF)) == 0) {
		n >>= 8;
		i += 8;
	}

	if ((n & UINT16_C(0x0000000F)) == 0) {
		n >>= 4;
		i += 4;
	}

	if ((n & UINT16_C(0x00000003)) == 0) {
		n >>= 2;
		i += 2;
	}

	if ((n & UINT16_C(0x00000001)) == 0)
		++i;

	return i;
#endif
}




#ifdef __GNUC__
/**
 * count the number of bits set to one (32 bit version)
 */
inline uint32_t countOnes(uint32_t x) {
    return static_cast<uint32_t>(__builtin_popcount(x));
}
#else
inline uint32_t countOnes(uint32_t x) {
  uint32_t c; // c accumulates the total bits set in v
  for (c = 0; x; c++) {
     x &= x - 1; // clear the least significant bit set
  }
  return c;
}
#endif


/**
 * count the number of bits set to one (64 bit version)
 */
inline uint32_t countOnes(uint64_t v) {
    return countOnes(static_cast<uint32_t> (v)) + countOnes(
            static_cast<uint32_t> (v >> 32));
}

inline uint32_t countOnes(uint16_t v) {
    return countOnes(static_cast<uint32_t>(v));
}


inline uint32_t numberOfTrailingZeros(uint32_t x) {
    if (x == 0) return 32;
    return ctz32(x);
}


inline uint32_t numberOfTrailingZeros(uint64_t x) {
    if(static_cast<uint32_t> (x)!= 0) {
        return numberOfTrailingZeros(static_cast<uint32_t> (x));
    }
    else return 32+numberOfTrailingZeros(static_cast<uint32_t> (x >> 32));
}

inline uint32_t numberOfTrailingZeros(uint16_t x) {
    if (x == 0) return 16;
    return ctz16(x);
}


/**
 * Returns the binary representation of a binary word.
 */
template<class uword>
std::string toBinaryString(const uword w) {
    std::ostringstream convert;
    for (uint32_t k = 0; k < sizeof(uword) * 8; ++k) {
        if (w & (static_cast<uword> (1) << k))
            convert << "1";
        else
            convert << "0";
    }
    return convert.str();
}

#endif

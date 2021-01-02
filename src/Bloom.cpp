/*
 *
 * (C) 2013-21 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* ******************************************************* */

/**
 * Constructor: initializes the bloom.
 * @param _num_bloom_bits The bitmap size.
 */
Bloom::Bloom(u_int32_t _num_bloom_bits) {
  num_bloom_bits = Utils::pow2(_num_bloom_bits);
  bitmask = new (std::nothrow) Bitmask(_num_bloom_bits);
  mask = num_bloom_bits - 1;
}

/* ******************************************************* */

/**
 * Destructor.
 */
Bloom::~Bloom() {
  delete bitmask;
}

/* ******************************************************* */

/**
 * Computes a simple and fast hash on the provided string.
 * @param str The string to hash.
 * @return The hash.
 */
u_int32_t Bloom::ntophash(char *str) {
  u_int32_t hash = 0;

  for(u_int32_t i = 0; str[i] != 0; i++)
    hash += tolower(str[i])*(i+1);

  return(hash & mask);
}


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

#ifndef _BLOOM_H_
#define _BLOOM_H_

/**
 * @file Bloom.h
 *
 * @brief      Bloom class implementation.
 * @details    A Bloom instance represents a bitmask that can be used as bloom filter for strings.
 */

#include "ntop_includes.h"

class Bloom {
 private:
  Bitmask *bitmask; /**< The bitmask */
  u_int32_t num_bloom_bits; /**< The bitmask size */
  u_int32_t mask; /**< The mask to be used for the hash */

  u_int32_t ntophash(char *str);

 public:
  Bloom(u_int32_t _num_bloom_bits);
  ~Bloom();

  /**
   * Adds a new value to the bloom setting the relative bit in the bitmask.
   * @param str The value to set.
   */
  inline void setBit(char *str) { bitmask->set_bit(ntophash(str)); }

  /**
   * Removes a value to the bloom unsetting the relative bit in the bitmask.
   * This is not the best thing that we could do with a bloom even though
   * if the user is aware of the limitation it can be used safely
   * @param str The value to set.
   */
  inline void unsetBit(char *str) { bitmask->clear_bit(ntophash(str)); }

  /**
   * Checks if a value is set in the bloom filter.
   * @param str The value to check.
   * @return True is the hash for the provided value is set, false otherwise.
   */
  inline bool issetBit(char *str) { return(bitmask->is_set_bit(ntophash(str))); }
};

#endif /* _BLOOM_H_ */

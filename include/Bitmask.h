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

/**
 * @file Bitmask.h
 *
 * @brief      Bitmask class implementation.
 * @details    A Bitmask instance represents a simple bitmask, where bits can be set, cleared and read.
 */

#ifndef _BITMASK_H_
#define _BITMASK_H_

#include "ntop_includes.h"

/*
  NOTE

  Bitmask is not thread safe and locking is not a bad idea
  however we believe that (on most architectures) writing a
  bimask byte while reading it won't be a problem.
 */

class Bitmask {
 private:
  u_int32_t tot_elems; /**< The bitmask size in bits */
  u_int32_t num_elems; /**< The bitmask size in bytes */
  u_int32_t *bits; /**< The bitmask */

  void bitmask_set(u_int32_t n);
  void bitmask_clr(u_int32_t n);
  bool bitmask_isset(u_int32_t n);

 public:
  Bitmask(u_int32_t num_tot_elems);
  ~Bitmask();

  /**
   * Sets a bit in the bitmask.
   * @param bit The bit position.
   */
  inline void set_bit(u_int32_t bit) { bitmask_set(bit); }

  /**
   * Clears a bit in the bitmask.
   * @param bit The bit position.
   */
  inline void clear_bit(u_int32_t bit) { bitmask_clr(bit); }

  /**
   * Checks if a bit is set.
   * @param bit The bit position.
   * @return True if the bit is set, false otherwise.
   */
  inline bool is_set_bit(u_int32_t bit) { return(bitmask_isset(bit) ? true : false); }

  void print();
};

#endif /* _BITMASK_H_ */

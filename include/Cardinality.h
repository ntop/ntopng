/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _CARDINALITY_H_
#define _CARDINALITY_H_

#include "ntop_includes.h"

/* ******************************* */

class Cardinality {
 private:
  struct ndpi_hll hll;

public:
  Cardinality() {
    memset(&hll, 0, sizeof(hll));
  }
  
  ~Cardinality() {
    ndpi_hll_destroy(&hll);
  }

  void init(u_int8_t bits) {
    if(ndpi_hll_init(&hll, bits))
      throw "init error";
  }
  
  void addElement(const char *value, size_t value_len) {
    ndpi_hll_add(&hll, value, value_len);
  }
  
  void addElement(u_int32_t value) {
    ndpi_hll_add_number(&hll, value);
  }

  u_int32_t getEstimate() {
    return((u_int32_t)ndpi_hll_count(&hll));
  }

  void reset() {
    memset(hll.registers, 0, hll.size); /* A lock might help here... */
  }
};

#endif /* _CARDINALITY_H_ */

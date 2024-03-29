/*
 *
 * (C) 2017-22 - ntop.org
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

#ifndef _FREQUENT_NUMERIC_ITEMS_H_
#define _FREQUENT_NUMERIC_ITEMS_H_

#include "ntop_includes.h"

/* https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf */

typedef struct {
  u_int32_t key;
  u_int32_t value;
  UT_hash_handle hh;         /* makes this structure hashable */
} FrequentNumericKey_t;

/* *************************************** */

class FrequentNumericItems {
 private:
  u_int32_t max_items, max_items_threshold;
  FrequentNumericKey_t *q;
  Mutex m;
  bool thread_safe;
  
  void cleanup();
  void prune();
  
 public:
  FrequentNumericItems(u_int32_t _max_items, bool _thread_safe = true) { max_items =_max_items, max_items_threshold = 2*_max_items, q = NULL, thread_safe = _thread_safe; }
  ~FrequentNumericItems();
  
  void add(u_int32_t key, u_int32_t value);
  void print();
  char* json();
};

#endif /* _FREQUENT_NUMERIC_ITEMS_H_ */

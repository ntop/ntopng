/*
 *
 * (C) 2017 - ntop.org
 *
 *
 * This code is proprietary code subject to the terms and conditions
 * defined in LICENSE file which is part of this source code package.
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

  void prune();
  
 public:
  FrequentNumericItems(u_int32_t _max_items) { max_items =_max_items, max_items_threshold = 2*_max_items, q = NULL; }
  ~FrequentNumericItems();
  
  void add(u_int32_t key, u_int32_t value);
  void print();
  char* json();
};

#endif /* _FREQUENT_NUMERIC_ITEMS_H_ */

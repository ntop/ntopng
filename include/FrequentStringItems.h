/*
 *
 * (C) 2017 - ntop.org
 *
 *
 * This code is proprietary code subject to the terms and conditions
 * defined in LICENSE file which is part of this source code package.
 *
 */

#ifndef _FREQUENT_STRING_ITEMS_H_
#define _FREQUENT_STRING_ITEMS_H_

#include "ntop_includes.h"

/* https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf */

typedef struct {
  char *key;
  u_int32_t value;
  UT_hash_handle hh;         /* makes this structure hashable */
} FrequentStringKey_t;

/* *************************************** */

class FrequentStringItems {
 private:
  u_int32_t max_items, max_items_threshold;
  FrequentStringKey_t *q;

  void prune();
  
 public:
  FrequentStringItems(u_int32_t _max_items) { max_items =_max_items, max_items_threshold = 2*_max_items, q = NULL; }
  ~FrequentStringItems();
  
  void add(char *key, u_int32_t value);
  void print();
  char* json();
};

#endif /* _FREQUENT_STRING_ITEMS_H_ */

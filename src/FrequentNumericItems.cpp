/*
 *
 * (C) 2017 - ntop.org
 *
 *
 * This code is proprietary code subject to the terms and conditions
 * defined in LICENSE file which is part of this source code package.
 *
 */

#include "ntop_includes.h"

/* ******************************************************** */

FrequentNumericItems::~FrequentNumericItems() {
  FrequentNumericKey_t *current, *tmp;

  HASH_ITER(hh, q, current, tmp) {
    HASH_DEL(q, current);  /* delete it */
    free(current);         /* free it */
  }
}

/* ******************************************************** */

void FrequentNumericItems::add(u_int32_t key, u_int32_t value) {
  FrequentNumericKey_t *s = NULL;

  HASH_FIND_INT(q, &key, s);

  if(s)
    s->value += value;
  else {
    if(HASH_COUNT(q) > max_items_threshold)
      prune();

    if((s = (FrequentNumericKey_t*)malloc(sizeof(FrequentNumericKey_t))) != NULL) {
      s->key = key, s->value = value;

      HASH_ADD_INT(q, key, s);
    }
  }
}

/* ******************************************************** */

static int value_sort(FrequentNumericKey_t *a, FrequentNumericKey_t *b) {
  return(b->value - a->value); /* desc sort */
}

/* ******************************************************** */

void FrequentNumericItems::prune() {
  FrequentNumericKey_t *curr;
  u_int32_t num = 0;
  /*
    Sort the hash items by value and remove those who exceeded
    the threshold of max_items_threshold
  */
  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentNumericKey_t*)curr->hh.next) {
    // ntop->getTrace()->traceEvent(TRACE_INFO, "%u = %u\n", curr->key, curr->value);

    if(++num > max_items) {
      HASH_DEL(q, curr);  /* delete it */
      free(curr);         /* free it */
    }
  }
}

/* ******************************************************** */

void FrequentNumericItems::print() {
  FrequentNumericKey_t *curr;

  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentNumericKey_t*)curr->hh.next) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u = %u\n", curr->key, curr->value);
  }
}

/* ******************************************************** */

char* FrequentNumericItems::json() {
  FrequentNumericKey_t *curr;
  json_object *j;
  char *rsp;

  if((j = json_object_new_object()) == NULL) return(NULL);

  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentNumericKey_t*)curr->hh.next) {
    char key[16];

    snprintf(key, sizeof(key), "%u", curr->key);
    json_object_object_add(j, key, json_object_new_int64(curr->value));
  }
  
  rsp = strdup(json_object_to_json_string(j));
  json_object_put(j);

  return(rsp);
}

/* ******************************************* */

#ifdef TESTME

void testme() {
  FrequentNumericItems *f = new FrequentNumericItems(8);

  for(int i = 0; i<256; i++) {
    f->add(i % 24, rand());
  }

  f->print();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", f->json());
  
  exit(0);
}

#endif

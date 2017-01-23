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

FrequentStringItems::~FrequentStringItems() {
  FrequentStringKey_t *current, *tmp;

  HASH_ITER(hh, q, current, tmp) {
    HASH_DEL(q, current);  /* delete it */
    free(current->key);
    free(current);         /* free it */
  }
}

/* ******************************************************** */

void FrequentStringItems::add(char *key, u_int32_t value) {
  FrequentStringKey_t *s = NULL;

  HASH_FIND_STR(q, key, s);

  if(s)
    s->value += value;
  else {
    if(HASH_COUNT(q) > max_items_threshold)
      prune();

    if((s = (FrequentStringKey_t*)malloc(sizeof(FrequentStringKey_t))) != NULL) {
      s->key = strdup(key), s->value = value;

      HASH_ADD_STR(q, key, s);
    }
  }
}

/* ******************************************************** */

static int value_sort(FrequentStringKey_t *a, FrequentStringKey_t *b) {
  return(b->value - a->value); /* desc sort */
}

/* ******************************************************** */

void FrequentStringItems::prune() {
  FrequentStringKey_t *curr;
  u_int32_t num = 0;
  /*
    Sort the hash items by value and remove those who exceeded
    the threshold of max_items_threshold
  */
  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentStringKey_t*)curr->hh.next) {
    // ntop->getTrace()->traceEvent(TRACE_INFO, "%s = %d\n", curr->key, curr->value);

    if(++num > max_items) {
      HASH_DEL(q, curr);  /* delete it */
      free(curr->key);
      free(curr);         /* free it */
    }
  }
}

/* ******************************************************** */

void FrequentStringItems::print() {
  FrequentStringKey_t *curr;

  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentStringKey_t*)curr->hh.next) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s = %u\n", curr->key, curr->value);
  }
}

/* ******************************************************** */

char* FrequentStringItems::json() {
  FrequentStringKey_t *curr;
  json_object *j;
  char *rsp;

  if((j = json_object_new_object()) == NULL) return(NULL);

  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentStringKey_t*)curr->hh.next)
    json_object_object_add(j, curr->key, json_object_new_int64(curr->value));

  rsp = strdup(json_object_to_json_string(j));
  json_object_put(j);

  return(rsp);
}

/* ******************************************* */

#ifdef TESTME

void testme() {
  FrequentStringItems *f = new FrequentStringItems(8);

  for(int i = 0; i<256; i++) {
    char buf[32];

    snprintf(buf, sizeof(buf), "%u", i % 24);
    f->add(buf, rand());
  }

  f->print();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", f->json());
  
  exit(0);
}

#endif

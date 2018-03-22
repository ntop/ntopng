/*
 *
 * (C) 2017-18 - ntop.org
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

/* ******************************************************** */

FrequentStringItems::~FrequentStringItems() {
  cleanup();
}

/* ******************************************************** */

void FrequentStringItems::cleanup() {
  FrequentStringKey_t *current, *tmp;

  m.lock(__FILE__, __LINE__);
  
  HASH_ITER(hh, q, current, tmp) {
    HASH_DEL(q, current);  /* delete it */
    free(current->key);
    free(current);         /* free it */
  }

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

void FrequentStringItems::add(char *key, u_int32_t value) {
  FrequentStringKey_t *s = NULL;

  m.lock(__FILE__, __LINE__);
  
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

  m.unlock(__FILE__, __LINE__);  
}

/* ******************************************************** */

static int value_sort(FrequentStringKey_t *a, FrequentStringKey_t *b) {
  return(b->value - a->value); /* desc sort */
}

/* ******************************************************** */

void FrequentStringItems::prune() {
  FrequentStringKey_t *curr, *tmp;
  u_int32_t num = 0;

  /* No lock here */
  
  /*
    Sort the hash items by value and remove those who exceeded
    the threshold of max_items_threshold
  */
  HASH_SORT(q, value_sort);

  HASH_ITER(hh, q, curr, tmp) {
    if(++num > max_items) {
      HASH_DEL(q, curr);
      free(curr->key);
      free(curr);
    }
  }
}

/* ******************************************************** */

void FrequentStringItems::print() {
  FrequentStringKey_t *curr;

  m.lock(__FILE__, __LINE__);
  
  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentStringKey_t*)curr->hh.next) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s = %u\n", curr->key, curr->value);
  }

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

char* FrequentStringItems::json() {
  FrequentStringKey_t *curr;
  json_object *j;
  char *rsp;

  if((j = json_object_new_object()) == NULL) return(NULL);

  m.lock(__FILE__, __LINE__);
  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentStringKey_t*)curr->hh.next)
    json_object_object_add(j, curr->key, json_object_new_int64(curr->value));

  rsp = strdup(json_object_to_json_string(j));
  json_object_put(j);
  m.unlock(__FILE__, __LINE__);
  
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

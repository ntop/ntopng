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

FrequentNumericItems::~FrequentNumericItems() {
  cleanup();
}


/* ******************************************************** */

void FrequentNumericItems::cleanup() {
  FrequentNumericKey_t *current, *tmp;

  m.lock(__FILE__, __LINE__);

  HASH_ITER(hh, q, current, tmp) {
    HASH_DEL(q, current);  /* delete it */
    free(current);         /* free it */
  }

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

void FrequentNumericItems::add(u_int32_t key, u_int32_t value) {
  FrequentNumericKey_t *s = NULL;

  m.lock(__FILE__, __LINE__);
  
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

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

static int value_sort(FrequentNumericKey_t *a, FrequentNumericKey_t *b) {
  return(b->value - a->value); /* desc sort */
}

/* ******************************************************** */

void FrequentNumericItems::prune() {
  FrequentNumericKey_t *curr, *tmp;
  u_int32_t num = 0;

  /* No lock here */
  /*
    Sort the hash items by value and remove those who exceeded
    the threshold of max_items_threshold
  */
  HASH_SORT(q, value_sort);

  HASH_ITER(hh, q, curr, tmp) {
    if(++num > max_items) {
      HASH_DEL(q, curr);  /* delete it */
      free(curr);         /* free it */
    }
  }
}

/* ******************************************************** */

void FrequentNumericItems::print() {
  FrequentNumericKey_t *curr;

  m.lock(__FILE__, __LINE__);
  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentNumericKey_t*)curr->hh.next) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u = %u\n", curr->key, curr->value);
  }

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

char* FrequentNumericItems::json() {
  FrequentNumericKey_t *curr;
  json_object *j;
  char *rsp;

  if((j = json_object_new_object()) == NULL) return(NULL);

  m.lock(__FILE__, __LINE__);
  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentNumericKey_t*)curr->hh.next) {
    char key[16];

    snprintf(key, sizeof(key), "%u", curr->key);
    json_object_object_add(j, key, json_object_new_int64(curr->value));
  }

  m.unlock(__FILE__, __LINE__);
  
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

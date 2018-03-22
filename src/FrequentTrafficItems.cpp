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

FrequentTrafficItems::FrequentTrafficItems(u_int32_t _max_items) {
  max_items =_max_items, max_items_threshold = 2 * _max_items;
  q = q_committed = NULL;
  values_sum = last_values_sum = 0;
}

/* ******************************************************** */

FrequentTrafficItems::~FrequentTrafficItems() {
  cleanup(q);
  cleanup(q_committed);
}

/* ******************************************************** */

void FrequentTrafficItems::cleanup(FrequentTrafficNode_t *head) {
  FrequentTrafficNode_t *current, *tmp;

  HASH_ITER(hh, head, current, tmp) {
    HASH_DEL(head, current);  /* delete it */
    free(current);         /* free it */
  }
}

/* ******************************************************** */

FrequentTrafficNode_t* FrequentTrafficItems::addGeneric(FrequentTrafficKey_t *key, size_t keysize, u_int32_t value) {
  FrequentTrafficNode_t *s = NULL;

  /* hh_name, head, key_ptr, key_len, item_ptr */
  HASH_FIND(hh, q, key, keysize, s);

  if(! s) {
    if(HASH_COUNT(q) > max_items_threshold)
      prune();

    if((s = (FrequentTrafficNode_t*)calloc(1, sizeof(FrequentTrafficNode_t))) != NULL) {
      memcpy(&s->key, key, keysize);

      HASH_ADD(hh, q, key, keysize, s);
    }
  }

  return s;
}

/* ******************************************************** */

void FrequentTrafficItems::addPoolProtocol(u_int16_t pool_id, u_int16_t proto_id, u_int32_t value) {
  FrequentTrafficKey_t key;

  memset(&key, 0, sizeof(key));
  key.pool_proto.pool_id = pool_id;
  key.pool_proto.proto_id = proto_id;

  FrequentTrafficNode_t *s = addGeneric(&key, sizeof(key.pool_proto), value);
  s->value += value;
  values_sum += value;
}

/* ******************************************************** */

static int value_sort(FrequentTrafficNode_t *a, FrequentTrafficNode_t *b) {
  return(b->value - a->value); /* desc sort */
}

/* ******************************************************** */

void FrequentTrafficItems::luaTopPoolsProtocols(lua_State *vm) {
  FrequentTrafficNode_t *curr;
  u_int32_t i = 0;

  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  HASH_SORT(q_committed, value_sort);

  for(curr=q_committed; curr != NULL; curr = (FrequentTrafficNode_t*)curr->hh.next) {
    lua_newtable(vm);
    lua_push_int_table_entry(vm, "pool", curr->key.pool_proto.pool_id);
    lua_push_int_table_entry(vm, "proto", curr->key.pool_proto.proto_id);
    lua_push_float_table_entry(vm, "Bps", curr->value * 1000 / last_diff);
    lua_push_float_table_entry(vm, "ratio", curr->value * 100.f / last_values_sum);
    lua_rawseti(vm, -2, ++i);
  }

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

void FrequentTrafficItems::addMacProtocol(u_int8_t mac[6], u_int16_t proto_id, u_int32_t value) {
  FrequentTrafficKey_t key;

  memset(&key, 0, sizeof(key));
  memcpy(key.mac_proto.mac, mac, 6);
  key.mac_proto.proto_id = proto_id;

  FrequentTrafficNode_t *s = addGeneric(&key, sizeof(key.mac_proto), value);
  s->value += value;
  values_sum += value;
}

/* ******************************************************** */

void FrequentTrafficItems::luaTopMacsProtocols(lua_State *vm) {
  FrequentTrafficNode_t *curr;
  u_int32_t i = 0;
  char buf[32];

  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  HASH_SORT(q_committed, value_sort);

  for(curr=q_committed; curr != NULL; curr = (FrequentTrafficNode_t*)curr->hh.next) {
    lua_newtable(vm);
    lua_push_str_table_entry(vm, "mac", Utils::formatMac(curr->key.mac_proto.mac, buf, sizeof(buf)));
    lua_push_int_table_entry(vm, "proto", curr->key.mac_proto.proto_id);
    lua_push_float_table_entry(vm, "Bps", curr->value * 1000 / last_diff);
    lua_push_float_table_entry(vm, "ratio", curr->value * 100.f / last_values_sum);
    lua_rawseti(vm, -2, ++i);
  }

  m.unlock(__FILE__, __LINE__);
}

/* ******************************************************** */

void FrequentTrafficItems::prune() {
  FrequentTrafficNode_t *curr, *tmp;
  u_int32_t num = 0;

  /*
    Sort the hash items by value and remove those who exceeded
    the threshold of max_items_threshold
  */
  HASH_SORT(q, value_sort);

  HASH_ITER(hh, q, curr, tmp) {
    if(++num > max_items) {
      HASH_DEL(q, curr);
      free(curr);
    }
  }
}

/* ******************************************************** */

void FrequentTrafficItems::reset(float tdiff_msec) {
  /* The mutex is only needed to guard q_committed */
  m.lock(__FILE__, __LINE__);
  cleanup(q_committed);
  q_committed = q;
  m.unlock(__FILE__, __LINE__);

  q = NULL;
  last_diff = tdiff_msec;
  last_values_sum = values_sum;
  values_sum = 0;
}

// #define TEST_ME
#ifdef TEST_ME

/* ******************************************************** */

void FrequentTrafficItems::print() {
  FrequentTrafficNode_t *curr;
  
  HASH_SORT(q, value_sort);

  for(curr=q; curr != NULL; curr = (FrequentTrafficNode_t*)curr->hh.next) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "<%u, %u> = %u\n",
      curr->key.pool_proto.pool_id, curr->key.pool_proto.proto_id, curr->value);
  }
}

/* ******************************************* */

void FrequentTrafficItems::testme() {
  reset(0);

  for(int i = 0; i<256; i++)
    addPoolProtocol(rand() % 5, rand() % 20, rand());

  print();

  reset(5000);

  print();

  exit(0);
}

#endif // #ifdef TEST_ME

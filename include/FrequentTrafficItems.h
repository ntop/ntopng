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

#ifndef _FREQUENT_TRAFFIC_ITEMS_H_
#define _FREQUENT_TRAFFIC_ITEMS_H_

#include "ntop_includes.h"

/* https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf */

typedef union {
  struct {
    u_int16_t pool_id;
    u_int16_t proto_id;
  } pool_proto;
  struct {
    u_int8_t mac[6];
    u_int16_t proto_id;
  } mac_proto;
} FrequentTrafficKey_t;

typedef struct {
  FrequentTrafficKey_t key;
  u_int32_t value;
  UT_hash_handle hh;         /* makes this structure hashable */
} FrequentTrafficNode_t;

/*
 * NOTE: The assumption to provide concurrent access is that:
 *  - only one thread, at a given moment, can call the add* / reset functions
 *  - one or more threads, concurrently, can call the lua* methods (data query)
 */

/* *************************************** */

class FrequentTrafficItems {
 private:
  u_int32_t max_items, max_items_threshold;
  u_int32_t values_sum, last_values_sum;
  float last_diff;
  FrequentTrafficNode_t *q, *q_committed;
  Mutex m;

  void cleanup(FrequentTrafficNode_t *root);
  void prune();
  FrequentTrafficNode_t* addGeneric(FrequentTrafficKey_t *key, size_t keysize, u_int32_t value);

 public:
  FrequentTrafficItems(u_int32_t _max_items);
  ~FrequentTrafficItems();

  void print();
  void testme();

  void reset(float tdiff_msec);

  void addPoolProtocol(u_int16_t pool_id, u_int16_t proto_id, u_int32_t value);
  void luaTopPoolsProtocols(lua_State *vm);

  void addMacProtocol(u_int8_t mac[6], u_int16_t proto_id, u_int32_t value);
  void luaTopMacsProtocols(lua_State *vm);
};

#endif /* _FREQUENT_TRAFFIC_ITEMS_H_ */

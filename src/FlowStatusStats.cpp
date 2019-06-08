/*
 *
 * (C) 2019 - ntop.org
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

#include "ntop_includes.h"

/* *************************************** */

FlowStatusStats::FlowStatusStats() {
  resetStats();
}

/* *************************************** */

FlowStatusStats::~FlowStatusStats() {
}

/* *************************************** */

void FlowStatusStats::incStats(FlowStatus status) {
  counters[status]++;
}

/* *************************************** */

void FlowStatusStats::lua(lua_State* vm) {
  lua_newtable(vm);

  for(int i = 0; i < num_flow_status; i++) {
    if(unlikely(counters[i] > 0)) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "count", counters[i]);

      lua_pushinteger(vm, i);
      lua_insert(vm, -2);
      lua_rawset(vm, -3);
    }
  }

  lua_pushstring(vm, "status");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void FlowStatusStats::resetStats() {
  memset(counters, 0, sizeof(counters));
}

/* *************************************** */



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

FlowStats::FlowStats() {
  resetStats();
}

/* *************************************** */

FlowStats::~FlowStats() {
}

/* *************************************** */

void FlowStats::incStats(Bitmap status_bitmap, u_int8_t l4_protocol, AlertLevel alert_level) {
  int i;

  for(i = 0; i < BITMAP_NUM_BITS; i++) {
    if(status_bitmap.issetBit(i))
      counters[i]++;
  }

  protocols[l4_protocol]++;
  alert_levels[alert_level]++;
}

/* *************************************** */

void FlowStats::lua(lua_State* vm) {
  lua_newtable(vm);

  for(int i = 0; i < BITMAP_NUM_BITS; i++) {
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

  lua_newtable(vm);

  for(int i = 0; i < 0x100; i++) {
    if(unlikely(protocols[i] > 0)) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "count", protocols[i]);

      lua_pushinteger(vm, i);
      lua_insert(vm, -2);
      lua_rawset(vm, -3);
    }
  }

  lua_pushstring(vm, "l4_protocols");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Alert levels */
  u_int32_t alert_level_notice_and_lower = 0, alert_level_warning = 0, alert_level_error_and_higher = 0;

  for(int i = 0; i < ALERT_LEVEL_MAX_LEVEL; i++) {
    AlertLevel alert_level = (AlertLevel)i;

    if(alert_level <= alert_level_notice)
      alert_level_notice_and_lower += alert_levels[alert_level];
    else if(alert_level == alert_level_warning)
      alert_level_warning += alert_levels[alert_level];
    else if(alert_level >= alert_level_error)
      alert_level_error_and_higher += alert_levels[alert_level];
  }

  lua_newtable(vm);

  if(alert_level_notice_and_lower > 0) lua_push_uint64_table_entry(vm, "notice_and_lower", alert_level_notice_and_lower);
  if(alert_level_warning > 0)          lua_push_uint64_table_entry(vm, "warning",          alert_level_warning);
  if(alert_level_error_and_higher > 0) lua_push_uint64_table_entry(vm, "error_and_higher", alert_level_error_and_higher);

  lua_pushstring(vm, "alert_levels");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void FlowStats::resetStats() {
  memset(counters, 0, sizeof(counters));
  memset(protocols, 0, sizeof(protocols));
  memset(alert_levels, 0, sizeof(alert_levels));
}

/* *************************************** */



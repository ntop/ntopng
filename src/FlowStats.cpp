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
  u_int32_t count_notice_or_lower = 0, count_warning = 0, count_error_or_higher = 0;

  for(int i = 0; i < ALERT_LEVEL_MAX_LEVEL; i++) {
    AlertLevel alert_level = (AlertLevel)i;

    switch(alert_level) {
    case alert_level_debug:
    case alert_level_info:
    case alert_level_notice:
      count_notice_or_lower += alert_levels[alert_level];
      break;
    case alert_level_warning:
      count_warning += alert_levels[alert_level];
      break;
    case alert_level_error:
    case alert_level_critical:
    case alert_level_alert:
    case alert_level_emergency:
      count_error_or_higher += alert_levels[alert_level];
    default:
      break;
    }
  }

  lua_newtable(vm);

  if(count_notice_or_lower > 0) lua_push_uint64_table_entry(vm, "notice_or_lower", count_notice_or_lower);
  if(count_warning > 0)         lua_push_uint64_table_entry(vm, "warning",         count_warning);
  if(count_error_or_higher > 0) lua_push_uint64_table_entry(vm, "error_or_higher", count_error_or_higher);

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



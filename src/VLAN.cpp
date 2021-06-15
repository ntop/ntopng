/*
 *
 * (C) 2013-21 - ntop.org
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

VLAN::VLAN(NetworkInterface *_iface, VLANid _vlan_id) : GenericHashEntry(_iface), GenericTrafficElement(), Score(_iface) {
  vlan_id = _vlan_id;

#ifdef VLAN_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created VLAN %u", vlan_id);
#endif

  deserializeFromRedis();
}

/* *************************************** */

void VLAN::set_hash_entry_state_idle() {
if(ntop->getPrefs()->is_idle_local_host_cache_enabled())
  serializeToRedis();
}

/* *************************************** */

VLAN::~VLAN() {
  /* NOTE: ndpiStats is alredy freed by GenericTrafficElement */
}

/* *************************************** */

void VLAN::lua(lua_State* vm, DetailsLevel details_level, bool asListElement) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "vlan", vlan_id);

  if(details_level >= details_high) {
    ((GenericTrafficElement*)this)->lua(vm, true);

    if(details_level >= details_higher)
      if(ndpiStats) ndpiStats->lua(iface, vm);
  }

  lua_push_uint64_table_entry(vm, "vlan_id", vlan_id);

  lua_push_uint64_table_entry(vm, "seen.first", first_seen);
  lua_push_uint64_table_entry(vm, "seen.last", last_seen);
  lua_push_uint64_table_entry(vm, "duration", get_duration());

  lua_push_uint64_table_entry(vm,   "num_hosts", getNumHosts());

  Score::lua_get_score(vm);
  Score::lua_get_score_breakdown(vm);

  if(asListElement) {
    lua_pushinteger(vm, vlan_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool VLAN::equal(VLANid _vlan_id) {
  return(vlan_id == _vlan_id);
}

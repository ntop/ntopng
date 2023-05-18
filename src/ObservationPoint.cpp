/*
 *
 * (C) 2013-23 - ntop.org
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

ObservationPoint::ObservationPoint(NetworkInterface* _iface,
                                   u_int16_t _obs_point)
    : GenericHashEntry(_iface),
      GenericTrafficElement(),
      Score(_iface),
      dirstats(_iface, 0) {
  obs_point = _obs_point;
  num_flows = 0;
  delete_requested = false;
  remove_entry = false;
  exporter_list = ndpi_bitmap_alloc();

#ifdef OBS_POINT_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created Observation Point %s",
                               obs_point);
#endif
}

/* *************************************** */

void ObservationPoint::set_hash_entry_state_idle() { ; /* Nothing to do */ }

/* *************************************** */

bool ObservationPoint::is_hash_entry_state_idle_transition_ready() {
  /* Observation points always stay in memory if no delete is requested */
  if (!remove_entry) return false;

  /* Delete requested, purge stats*/
  return true;
}

/* *************************************** */

ObservationPoint::~ObservationPoint() {
  ndpi_bitmap_free(exporter_list);
#ifdef OBS_POINT_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted Observation Point");
#endif
}

/* *************************************** */

void ObservationPoint::updateStats(const struct timeval* tv) {
  if (!remove_entry) GenericTrafficElement::updateStats(tv);
}

/* *************************************** */

void ObservationPoint::lua(lua_State* vm, DetailsLevel details_level,
                           bool asListElement) {
  /* Security check done to prevent race conditions */
  if (remove_entry) {
    lua_pushnil(vm);
    return;
  }

  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "obs_point", obs_point);
  lua_push_uint64_table_entry(vm, "bytes", getNumBytes());
  lua_push_bool_table_entry(vm, "to_remove", delete_requested);
  lua_push_uint64_table_entry(vm, "flows", getNumFlows());

  lua_push_uint64_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  if (details_level >= details_high) {
    dirstats.lua(vm);
    GenericTrafficElement::lua(vm, true); /* Must stay after dirstats */
    lua_push_uint64_table_entry(vm, "seen.first", first_seen);
    lua_push_uint64_table_entry(vm, "seen.last", last_seen);
    lua_push_uint64_table_entry(vm, "duration", get_duration());

    lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());

    if (ndpiStats) ndpiStats->lua(iface, vm);
  }

  Score::lua_get_score(vm);
  Score::lua_get_score_breakdown(vm);

  u_int32_t exporter_ip = 0;

  lua_newtable(vm);
  ndpi_bitmap_iterator* iterator = ndpi_bitmap_iterator_alloc(exporter_list);
  while (ndpi_bitmap_iterator_next(iterator, &exporter_ip)) {
    char buf[32];
    lua_push_uint32_table_entry(
        vm, Utils::intoaV4(exporter_ip, buf, sizeof(buf)), 1);
  }
  lua_pushstring(vm, "exporter_list");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if (asListElement) {
    lua_pushinteger(vm, obs_point);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

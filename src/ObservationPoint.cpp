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

ObservationPoint::ObservationPoint(NetworkInterface *_iface, u_int16_t _obs_point) : GenericHashEntry(_iface), GenericTrafficElement(), Score(_iface), dirstats(_iface, 0) {
  obs_point = _obs_point;

#ifdef OBS_POINT_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created Observation Point %s", obs_point);
#endif

  if(ntop->getPrefs()->is_idle_local_host_cache_enabled())
    deserializeFromRedis();
}
/* *************************************** */

void ObservationPoint::set_hash_entry_state_idle() {
  if(ntop->getPrefs()->is_idle_local_host_cache_enabled())
    serializeToRedis();
}

/* *************************************** */

ObservationPoint::~ObservationPoint() {
#ifdef OBS_POINT_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted Observation Point %s", obs_point);
#endif
}

/* *************************************** */

void ObservationPoint::updateStats(const struct timeval *tv)  {
  GenericTrafficElement::updateStats(tv);
}

/* *************************************** */

void ObservationPoint::lua(lua_State* vm, DetailsLevel details_level, bool asListElement) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "obs_point", obs_point);
  lua_push_uint64_table_entry(vm, "bytes", getNumBytes());

  lua_push_uint64_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  if(details_level >= details_high) {
    dirstats.lua(vm);
    GenericTrafficElement::lua(vm, true); /* Must stay after dirstats */
    lua_push_uint64_table_entry(vm, "seen.first", first_seen);
    lua_push_uint64_table_entry(vm, "seen.last", last_seen);
    lua_push_uint64_table_entry(vm, "duration", get_duration());

    lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());

    if(ndpiStats) ndpiStats->lua(iface, vm);
    tcp_packet_stats_sent.lua(vm, "tcpPacketStats.sent");
    tcp_packet_stats_rcvd.lua(vm, "tcpPacketStats.rcvd");
  }

  Score::lua_get_score(vm);
  Score::lua_get_score_breakdown(vm);

  if(asListElement) {
    lua_pushinteger(vm, obs_point);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */
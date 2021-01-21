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

// #define AS_RTT_DEBUG 1

/* *************************************** */

OperatingSystem::OperatingSystem(NetworkInterface *_iface, OSType _os_type) 
                : GenericHashEntry(_iface), GenericTrafficElement() {
  round_trip_time = 0;
  os_type = _os_type;

#ifdef AS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created Operating System %u", os_type);
#endif

  if(ntop->getPrefs()->is_idle_local_host_cache_enabled())
    deserializeFromRedis();
}

/* *************************************** */

void OperatingSystem::set_hash_entry_state_idle() {
  if(ntop->getPrefs()->is_idle_local_host_cache_enabled())
    serializeToRedis();
}

/* *************************************** */

OperatingSystem::~OperatingSystem() {
  /* TODO: decide if it is useful to dump AS stats to redis */
#ifdef AS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted Autonomous System %u", os_type);
#endif
}

/* *************************************** */

void OperatingSystem::updateRoundTripTime(u_int32_t rtt_msecs) {
  /* EWMA formula is EWMA(n) = (alpha_percent * sample + (100 - alpha_percent) * EWMA(n-1)) / 100

     We read the EWMA alpha_percent from the preferences
  */
  u_int8_t ewma_alpha_percent = ntop->getPrefs()->get_ewma_alpha_percent();

#ifdef AS_RTT_DEBUG
  u_int32_t old_rtt = round_trip_time;
#endif
  if(round_trip_time)
    Utils::update_ewma(rtt_msecs, &round_trip_time, ewma_alpha_percent);
  else
    round_trip_time = rtt_msecs;
#ifdef AS_RTT_DEBUG
  printf("Updating rtt EWMA: [os: %u][sample msecs: %u][old rtt: %u][new rtt: %u][alpha percent: %u]\n",
	 os_type, rtt_msecs, old_rtt, round_trip_time, ewma_alpha_percent);
#endif
}

/* *************************************** */

void OperatingSystem::lua(lua_State* vm, DetailsLevel details_level, bool asListElement) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "os", os_type);

  lua_push_uint64_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  if(details_level >= details_high) {
    ((GenericTrafficElement*)this)->lua(vm, true);

    lua_push_uint64_table_entry(vm, "seen.first", first_seen);
    lua_push_uint64_table_entry(vm, "seen.last", last_seen);
    lua_push_uint64_table_entry(vm, "duration", get_duration());

    lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());
    lua_push_uint64_table_entry(vm, "round_trip_time", round_trip_time);

    if(details_level >= details_higher) {
      if(ndpiStats) ndpiStats->lua(iface, vm);
        tcp_packet_stats_sent.lua(vm, "tcpPacketStats.sent");
	      tcp_packet_stats_rcvd.lua(vm, "tcpPacketStats.rcvd");
    }
  }

  if(asListElement) {
    lua_pushinteger(vm, os_type);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool OperatingSystem::equal(OSType _os) {
  return(os_type == _os);
}

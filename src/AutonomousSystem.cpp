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

AutonomousSystem::AutonomousSystem(NetworkInterface *_iface, IpAddress *ipa) : GenericHashEntry(_iface), GenericTrafficElement(), Score(_iface) {
  asname = NULL;
  round_trip_time = 0;
#ifdef NTOPNG_PRO
  nextMinPeriodicUpdate = 0;
#endif
  ntop->getGeolocation()->getAS(ipa, &asn, &asname);

#ifdef AS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created Autonomous System %u", asn);
#endif

  if(ntop->getPrefs()->is_idle_local_host_cache_enabled())
    deserializeFromRedis();
}

/* *************************************** */

void AutonomousSystem::set_hash_entry_state_idle() {
  if(ntop->getPrefs()->is_idle_local_host_cache_enabled())
    serializeToRedis();
}

/* *************************************** */

AutonomousSystem::~AutonomousSystem() {
  if(asname) free(asname);
  /* TODO: decide if it is useful to dump AS stats to redis */

#ifdef AS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted Autonomous System %u", asn);
#endif
}

/* *************************************** */

void AutonomousSystem::updateRoundTripTime(u_int32_t rtt_msecs) {
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
  printf("Updating rtt EWMA: [asn: %u][sample msecs: %u][old rtt: %u][new rtt: %u][alpha percent: %u]\n",
	 asn, rtt_msecs, old_rtt, round_trip_time, ewma_alpha_percent);
#endif
}

/* *************************************** */

void AutonomousSystem::lua(lua_State* vm, DetailsLevel details_level, bool asListElement) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "asn", asn);
  lua_push_str_table_entry(vm, "asname", asname ? asname : (char*)"");

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

#ifdef NTOPNG_PRO
  luaTrafficBehavior(vm);
  luaScoreBehavior(vm);
#endif

  Score::lua_get_score(vm);
  Score::lua_get_score_breakdown(vm);

  if(asListElement) {
    lua_pushinteger(vm, asn);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool AutonomousSystem::equal(u_int32_t _asn) {
  return(asn == _asn);
}

/* *************************************** */

#ifdef NTOPNG_PRO

/* ***************************************** */

void AutonomousSystem::updateStats(const struct timeval *tv)  {
  GenericTrafficElement::updateStats(tv);
  
  updateBehaviorStats(tv);
}

/* ***************************************** */

void AutonomousSystem::updateBehaviorStats(const struct timeval *tv) {
  /* 5 Min Update */
  if(tv->tv_sec >= nextMinPeriodicUpdate) {
    /* hll visited sites update */
    updateTrafficIfaceBehavior();
    updateScoreIfaceBehavior();

    nextMinPeriodicUpdate = tv->tv_sec + ASES_BEHAVIOR_REFRESH;
  }
}

/* *************************************** */

void AutonomousSystem::updateScoreIfaceBehavior() {
  if(score_behavior.addObservation(getScore())) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[ANOMALY] %s [ASN: %s | score] [value: %u]",
          iface->get_name(),
          get_asname(),
          getScore());
  }
}

/* *************************************** */

void AutonomousSystem::updateTrafficIfaceBehavior() {
  if(traffic_rx_behavior.addObservation(getNumBytesSent())) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[ANOMALY] %s [ASN: %s | traffic rx] [value: %lu]",
          iface->get_name(),
          get_asname(),
          getNumBytesSent());
  }

  if(traffic_tx_behavior.addObservation(getNumBytesRcvd())) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[ANOMALY] %s [ASN: %s | traffic tx] [value: %lu]",
          iface->get_name(),
          get_asname(),
          getNumBytesRcvd());
  }
}

/* *************************************** */

void AutonomousSystem::luaTrafficBehavior(lua_State* vm) {
  lua_newtable(vm);
  /* ASN score behaviour */
  lua_push_bool_table_entry(vm,  "anomaly",     traffic_rx_behavior.anomalyFound());
  lua_push_int32_table_entry(vm, "value",       traffic_rx_behavior.getLastValue());
  lua_push_int32_table_entry(vm, "lower_bound", traffic_rx_behavior.getLastLowerBound());
  lua_push_int32_table_entry(vm, "upper_bound", traffic_rx_behavior.getLastUpperBound());

  lua_pushstring(vm, "traffic_rx_behavior");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  /* ASN score behaviour */
  lua_push_bool_table_entry(vm,  "anomaly",     traffic_tx_behavior.anomalyFound());
  lua_push_int32_table_entry(vm, "value",       traffic_tx_behavior.getLastValue());
  lua_push_int32_table_entry(vm, "lower_bound", traffic_tx_behavior.getLastLowerBound());
  lua_push_int32_table_entry(vm, "upper_bound", traffic_tx_behavior.getLastUpperBound());

  lua_pushstring(vm, "traffic_tx_behavior");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void AutonomousSystem::luaScoreBehavior(lua_State* vm) {
  lua_newtable(vm);
  /* ASN score behaviour */
  lua_push_bool_table_entry(vm,  "anomaly",     score_behavior.anomalyFound());
  lua_push_int32_table_entry(vm, "value",       score_behavior.getLastValue());
  lua_push_int32_table_entry(vm, "lower_bound", score_behavior.getLastLowerBound());
  lua_push_int32_table_entry(vm, "upper_bound", score_behavior.getLastUpperBound());

  lua_pushstring(vm, "score_behavior");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

#endif

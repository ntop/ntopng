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

  score_behavior = NULL;
  traffic_tx_behavior = NULL;
  traffic_rx_behavior = NULL; 

  if(ntop->getPrefs()->isASNBehavourAnalysisEnabled()) {
    score_behavior = new AnalysisBehavior();
    traffic_tx_behavior = new AnalysisBehavior(0.5 /* Alpha parameter */, 0.1 /* Beta parameter */, 0.05 /* Significance */, true /* Counter */);
    traffic_rx_behavior = new AnalysisBehavior(0.5 /* Alpha parameter */, 0.1 /* Beta parameter */, 0.05 /* Significance */, true /* Counter */);
  }
  
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

#ifdef NTOPNG_PRO
  if(score_behavior) delete(score_behavior);
  if(traffic_tx_behavior) delete(traffic_tx_behavior);
  if(traffic_rx_behavior) delete(traffic_rx_behavior);
#endif

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

void AutonomousSystem::lua(lua_State* vm, DetailsLevel details_level, bool asListElement, bool diff) {
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
  if(traffic_rx_behavior)
    traffic_rx_behavior->luaBehavior(vm, "traffic_rx_behavior", diff ? ASES_BEHAVIOR_REFRESH : 0);
  if(traffic_tx_behavior)
    traffic_tx_behavior->luaBehavior(vm, "traffic_tx_behavior", diff ? ASES_BEHAVIOR_REFRESH : 0);
  if(score_behavior)
    score_behavior->luaBehavior(vm, "score_behavior");
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

void AutonomousSystem::updateStats(const struct timeval *tv)  {
  GenericTrafficElement::updateStats(tv);

#ifdef NTOPNG_PRO
  updateBehaviorStats(tv);
#endif
}

/* ***************************************** */

#ifdef NTOPNG_PRO

void AutonomousSystem::updateBehaviorStats(const struct timeval *tv) {
  /* 5 Min Update */
  if(tv->tv_sec >= nextMinPeriodicUpdate) {
    char score_buf[256], tx_buf[128], rx_buf[128];

    /* Traffic behavior stats update, currently score, traffic rx and tx */
    if(score_behavior) {
      snprintf(score_buf, sizeof(score_buf), "AS %d | score", asn);
      score_behavior->updateBehavior(iface, getScore(), score_buf, (asn ? true : false));
    }

    if(traffic_tx_behavior) {
      snprintf(tx_buf, sizeof(tx_buf), "AS %d | traffic tx", asn);
      traffic_tx_behavior->updateBehavior(iface, getNumBytesSent(), tx_buf, (asn ? true : false));
    }

    if(traffic_rx_behavior) {
      snprintf(rx_buf, sizeof(rx_buf), "AS %d | traffic rx", asn);
      traffic_rx_behavior->updateBehavior(iface, getNumBytesRcvd(), rx_buf, (asn ? true : false));
    }

    nextMinPeriodicUpdate = tv->tv_sec + ASES_BEHAVIOR_REFRESH;
  }
}

#endif

/*
 *
 * (C) 2013-26 - ntop.org
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

AutonomousSystem::AutonomousSystem(NetworkInterface* _iface, IpAddress* ipa)
    : GenericHashEntry(_iface), GenericTrafficElement(), Score(_iface) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  asname = NULL;
  save_exporters_stats = false;
  round_trip_time = 0;
  alerted_flows_as_client = alerted_flows_as_server = 0;
#ifdef NTOPNG_PRO
  nextMinPeriodicUpdate = 0;

#endif
  ntop->getGeolocation()->getAS(ipa, &asn, &asname);

#ifdef AS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created Autonomous System %u",
                               asn);
#endif

  if (ntop->getPrefs()->isCustomerASN(get_asn()) ||
      ntop->getPrefs()->isSubCustomerASN(get_asn()) ||
      ntop->getPrefs()->isRemoteASN(get_asn())) {
    saveExporterStatsPrefs(true);
#ifdef AS_DEBUG
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "Autonomous System [asn: %u] [exporter stats: true]",
        get_asn());
#endif
  } else {
    saveExporterStatsPrefs(false);
#ifdef AS_DEBUG
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "Autonomous System [asn: %u] [exporter stats: false]",
        get_asn());
#endif
  }
}

/* *************************************** */

void AutonomousSystem::set_hash_entry_state_idle() { ; /* Nothing to do */ }

/* *************************************** */

AutonomousSystem::~AutonomousSystem() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
  if (asname) free(asname);
  /* TODO: decide if it is useful to dump AS stats to redis */

#ifdef AS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted Autonomous System %u",
                               asn);
#endif
}

/* *************************************** */

void AutonomousSystem::updateRoundTripTime(u_int32_t rtt_msecs) {
  /* EWMA formula is EWMA(n) = (alpha_percent * sample + (100 - alpha_percent) *
     EWMA(n-1)) / 100

     We read the EWMA alpha_percent from the preferences
  */
  u_int8_t ewma_alpha_percent = ntop->getPrefs()->get_ewma_alpha_percent();

#ifdef AS_RTT_DEBUG
  u_int32_t old_rtt = round_trip_time;
#endif
  if (round_trip_time)
    Utils::update_ewma(rtt_msecs, &round_trip_time, ewma_alpha_percent);
  else
    round_trip_time = rtt_msecs;
#ifdef AS_RTT_DEBUG
  printf(
      "Updating rtt EWMA: [asn: %u][sample msecs: %u][old rtt: %u][new rtt: "
      "%u][alpha percent: %u]\n",
      asn, rtt_msecs, old_rtt, round_trip_time, ewma_alpha_percent);
#endif
}

/* *************************************** */

void AutonomousSystem::lua(lua_State* vm, DetailsLevel details_level,
                           bool asListElement, bool diff) {
  lua_newtable(vm);
  ((GenericTrafficElement*)this)->lua(vm, true);

  lua_push_uint64_table_entry(vm, "asn", asn);
  lua_push_str_table_entry(vm, "asname", asname ? asname : (char*)"");

  lua_push_uint64_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  lua_push_uint64_table_entry(vm, "seen.first", first_seen);
  lua_push_uint64_table_entry(vm, "seen.last", last_seen);

  if (details_level >= details_high) {
    lua_push_uint64_table_entry(vm, "duration", get_duration());

    lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());
    lua_push_uint64_table_entry(vm, "round_trip_time", round_trip_time);

    if (details_level >= details_higher) {
      if (ndpiStats) ndpiStats->lua(iface, vm);
      tcp_packet_stats_sent.lua(vm, "tcpPacketStats.sent");
      tcp_packet_stats_rcvd.lua(vm, "tcpPacketStats.rcvd");
    }
#ifdef NTOPNG_PRO
    qoe_stats.lua_qoe_stats(vm);
#endif
    if (!exporters_map.empty()) {
      lua_newtable(vm);
      for (std::map<std::pair<struct ndpi_in6_addr, u_int16_t>, TrafficCounter>::iterator it = exporters_map.begin(); it != exporters_map.end(); ++it) {
        lua_newtable(vm);
        char buf[32], buf2[64];
        IpAddress exporter;
        TrafficCounter& stats = it->second;

        exporter.set((struct ndpi_in6_addr*)&it->first.first);

        lua_push_uint64_table_entry(vm, "bytes_sent", stats.getSent());
        lua_push_uint64_table_entry(vm, "bytes_rcvd", stats.getRcvd());
        snprintf(buf2, sizeof(buf2), "%s_%d", exporter.print(buf, sizeof(buf)),
                 it->first.second);
        lua_pushstring(vm, buf2);
        lua_insert(vm, -2);
        lua_settable(vm, -3);
      }

      lua_pushstring(vm, "exporters");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "as_client",
                              getTotalAlertedNumFlowsAsClient());
  lua_push_uint64_table_entry(vm, "as_server",
                              getTotalAlertedNumFlowsAsServer());
  lua_push_uint64_table_entry(
      vm, "total",
      getTotalAlertedNumFlowsAsClient() + getTotalAlertedNumFlowsAsServer());
  lua_pushstring(vm, "alerted_flows");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  Score::lua_get_score(vm);
  Score::lua_get_score_breakdown(vm);

  if (asListElement) {
    lua_pushinteger(vm, asn);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool AutonomousSystem::equal(u_int32_t _asn) { return (asn == _asn); }

/* *************************************** */

void AutonomousSystem::updateStats(const struct timeval* tv) {
  GenericTrafficElement::updateStats(tv);

#ifdef NTOPNG_PRO
  updateBehaviorStats(tv);
#endif
}

/* ***************************************** */

#ifdef NTOPNG_PRO

void AutonomousSystem::updateBehaviorStats(const struct timeval* tv) {}

#endif

/* ***************************************** */

void AutonomousSystem::findExportersStats(u_int64_t bytes_sent, u_int64_t bytes_rcvd,
					  std::pair<struct ndpi_in6_addr, u_int16_t>* key) {
  std::map<std::pair<struct ndpi_in6_addr, u_int16_t>, TrafficCounter>::iterator it;
  std::pair<struct ndpi_in6_addr, u_int16_t> a;
  
  // it = exporters_map.find(*key);
  it = exporters_map.find(a);

  if (it != exporters_map.end()) {
    it->second.incStats(bytes_sent, bytes_rcvd);  // Update if exists already
  } else {
    exporters_map[*key] = TrafficCounter();
    exporters_map[*key].incStats(bytes_sent, bytes_rcvd);
  }
}

/* ***************************************** */

void AutonomousSystem::incExportersStats(u_int64_t bytes_sent,
                                         u_int64_t bytes_rcvd,
                                         struct ndpi_in6_addr *exporter_ip,
                                         u_int32_t in_index,
                                         u_int32_t out_index) {
  if (save_exporters_stats && exporter_ip) {
    std::pair<struct ndpi_in6_addr, u_int16_t> key;

    /* Increase the stats just one time, same interface */
    /* Out interface, so Sent Bytes and Rcvd Bytes are okay this way */
    key = std::make_pair(*exporter_ip, out_index);

    findExportersStats(bytes_sent, bytes_rcvd, &key);

    if (in_index != out_index) {
      key = std::make_pair(*exporter_ip, in_index);
      /* In interface, so Sent Bytes and Rcvd Bytes are inverted (Sent Bytes is
       * Rcvd Bytes and viceversa) */

      findExportersStats(bytes_rcvd, bytes_sent, &key);
    }
  }
}

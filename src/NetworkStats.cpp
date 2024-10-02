/*
 *
 * (C) 2015-24 - ntop.org
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

NetworkStats::NetworkStats(NetworkInterface *iface, u_int16_t _network_id)
    : InterfaceMemberAlertableEntity(iface, alert_entity_network),
      GenericTrafficElement(),
      Score(iface) {
  const char *netname;

  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
  network_id = _network_id;
  numHosts = 0, alerted_flows_as_client = alerted_flows_as_server = 0;
  syn_recvd_last_min = synack_sent_last_min = 0;
  round_trip_time = 0;

#ifdef NTOPNG_PRO
  network_matrix =
      (InOutTraffic *)calloc(ntop->getNumLocalNetworks(), sizeof(InOutTraffic));
  nextMinPeriodicUpdate = 0;  
#endif

  netname = ntop->getLocalNetworkName(network_id);
  setEntityValue(netname ? netname : "");
}

/* *************************************** */

bool NetworkStats::match(AddressTree *tree) {
  IpAddress *network_address = NULL;
  u_int8_t network_prefix;
  bool res = true;

  if (!tree) return res;

  ntop->getLocalNetworkIp(network_id, &network_address, &network_prefix);

  if (network_address) {
#if 0
    char buf[64];
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Attempting to match %s", network_address->print(buf, sizeof(buf)));
#endif

    res = tree->match(network_address, network_prefix);
    delete network_address;
  }

  return res;
}

NetworkStats::~NetworkStats() {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
  
#ifdef NTOPNG_PRO
  if (network_matrix) free(network_matrix);
#endif
}

/* *************************************** */

void NetworkStats::lua(lua_State *vm, bool diff) {
  int hits;

  lua_push_str_table_entry(vm, "network_key",
                           ntop->getLocalNetworkName(network_id));
  lua_push_uint64_table_entry(vm, "network_id", network_id);
  lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());
  lua_push_uint64_table_entry(vm, "engaged_alerts", getNumEngagedAlerts());
  lua_push_uint64_table_entry(vm, "round_trip_time", round_trip_time);

  lua_push_uint64_table_entry(vm, "ingress", ingress.getNumBytes());
  lua_push_uint64_table_entry(vm, "egress", egress.getNumBytes());
  lua_push_uint64_table_entry(vm, "inner", inner.getNumBytes());

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "ingress", ingress_broadcast.getNumBytes());
  lua_push_uint64_table_entry(vm, "egress", egress_broadcast.getNumBytes());
  lua_push_uint64_table_entry(vm, "inner", inner_broadcast.getNumBytes());
  lua_pushstring(vm, "broadcast");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

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

#ifdef NTOPNG_PRO
  lua_newtable(vm);

  for (u_int16_t i = 0; i < ntop->getNumLocalNetworks(); i++) {
    /* Safety check in case a local network is NULL */
    if(!ntop->getLocalNetworkName(i))
      continue;

    lua_newtable(vm);
    lua_push_uint64_table_entry(vm, "bytes_sent", network_matrix[i].bytes_sent);
    lua_push_uint64_table_entry(vm, "bytes_rcvd", network_matrix[i].bytes_rcvd);
    lua_pushstring(vm, ntop->getLocalNetworkName(i));
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
  lua_pushstring(vm, "intranet_traffic");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
#endif

  tcp_packet_stats_ingress.lua(vm, "tcpPacketStats.ingress");
  tcp_packet_stats_egress.lua(vm, "tcpPacketStats.egress");
  tcp_packet_stats_inner.lua(vm, "tcpPacketStats.inner");

  if ((hits = syn_flood_victim_alert.hits()))
    lua_push_uint64_table_entry(vm, "hits.syn_flood_victim", hits);
  if ((hits = flow_flood_victim_alert.hits()))
    lua_push_uint64_table_entry(vm, "hits.flow_flood_victim", hits);

  hits = 0;
  if (syn_recvd_last_min > synack_sent_last_min)
    hits = syn_recvd_last_min - synack_sent_last_min;
  if (hits) lua_push_uint64_table_entry(vm, "hits.syn_scan_victim", hits);

  GenericTrafficElement::lua(vm, true);
  Score::lua_get_score(vm);
  Score::lua_get_score_breakdown(vm);
}

/* *************************************** */

bool NetworkStats::serialize(json_object *my_object) {
  json_object_object_add(my_object, "ingress",
                         json_object_new_int64(ingress.getNumBytes()));
  json_object_object_add(my_object, "egress",
                         json_object_new_int64(egress.getNumBytes()));
  json_object_object_add(my_object, "inner",
                         json_object_new_int64(inner.getNumBytes()));

  return true;
}

/* *************************************** */

void NetworkStats::updateRoundTripTime(u_int32_t rtt_msecs) {
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

void NetworkStats::housekeepAlerts(ScriptPeriodicity p) {
  switch (p) {
    case minute_script:
      flow_flood_victim_alert.reset_hits(); /*,syn_flood_victim_alert.reset_hits()*/
      syn_recvd_last_min = synack_sent_last_min = 0;
      break;
    default:
      break;
  }
}

/* *************************************** */

void NetworkStats::updateSynAlertsCounter(time_t when, bool syn_sent) {
  if (!syn_sent) {
    syn_recvd_last_min++;
  }
}
/* *************************************** */

void NetworkStats::updateSynFloodAlertsCounter( bool connection_opened) {
  if (connection_opened) {
    syn_flood_victim_alert.inc_no_time_window();
  }
  else{
    syn_flood_victim_alert.dec();
  }
}

/* *************************************** */

void NetworkStats::updateSynAckAlertsCounter(time_t when, bool synack_sent) {
  if (synack_sent) synack_sent_last_min++;
}

/* *************************************** */

void NetworkStats::incNumFlows(time_t t, bool as_client) {
  if (!as_client) flow_flood_victim_alert.inc(t, this);
}

/* ***************************************** */

void NetworkStats::updateStats(const struct timeval *tv) {
  GenericTrafficElement::updateStats(tv);

#ifdef NTOPNG_PRO
  updateBehaviorStats(tv);
#endif
}

#ifdef NTOPNG_PRO

/* ***************************************** */

void NetworkStats::incTrafficBetweenNets(u_int16_t net_id, u_int32_t bytes_sent,
                                         u_int32_t bytes_rcvd) {
#ifdef NTOPNG_PRO
  if (net_id < ntop->getNumLocalNetworks() && net_id != (u_int16_t)-1) {
    network_matrix[net_id].bytes_sent += bytes_sent;
    network_matrix[net_id].bytes_rcvd += bytes_rcvd;
  }
#endif
}

/* ***************************************** */

void NetworkStats::resetTrafficBetweenNets() {
#ifdef NTOPNG_PRO
  for (u_int16_t i = 0; i < ntop->getNumLocalNetworks(); i++) {
    network_matrix[i].bytes_sent = 0;
    network_matrix[i].bytes_rcvd = 0;
  }
#endif
}

/* ***************************************** */

void NetworkStats::updateBehaviorStats(const struct timeval *tv) {}

#endif

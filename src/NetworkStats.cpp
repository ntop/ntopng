/*
 *
 * (C) 2015-20 - ntop.org
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

NetworkStats::NetworkStats(NetworkInterface *iface, u_int8_t _network_id) : AlertableEntity(iface, alert_entity_network), GenericTrafficElement() {
  const char *netname;
  network_id = _network_id;
  numHosts = 0;
  syn_recvd_last_min = synack_sent_last_min = 0;

  netname = ntop->getLocalNetworkName(network_id);
  setEntityValue(netname ? netname : "");
}

/* *************************************** */

bool NetworkStats::match(const AddressTree * const tree) const {
  IpAddress *network_address = NULL;
  u_int8_t network_prefix;
  bool res = true;

  if(!tree)
    return res;

  ntop->getLocalNetworkIp(network_id, &network_address, &network_prefix);

  if(network_address) {
#if 0
    char buf[64];
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Attempting to match %s", network_address->print(buf, sizeof(buf)));
#endif

    res = tree->match(network_address, network_prefix);
    delete network_address;
  }

  return res;
}

/* *************************************** */

void NetworkStats::lua(lua_State* vm) {
  int hits;

  lua_push_str_table_entry(vm, "network_key", ntop->getLocalNetworkName(network_id));
  lua_push_uint64_table_entry(vm, "network_id", network_id);
  lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());
  lua_push_uint64_table_entry(vm, "engaged_alerts", getNumTriggeredAlerts());

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

  tcp_packet_stats_ingress.lua(vm, "tcpPacketStats.ingress");
  tcp_packet_stats_egress.lua(vm, "tcpPacketStats.egress");
  tcp_packet_stats_inner.lua(vm, "tcpPacketStats.inner");

  if((hits = syn_flood_victim_alert.hits()))
    lua_push_uint64_table_entry(vm, "hits.syn_flood_victim", hits);
  if((hits = flow_flood_victim_alert.hits()))
    lua_push_uint64_table_entry(vm, "hits.flow_flood_victim", hits);

  hits = 0;
  if (syn_recvd_last_min > synack_sent_last_min)
    hits = syn_recvd_last_min - synack_sent_last_min;
  if(hits)
    lua_push_uint64_table_entry(vm, "hits.syn_scan_victim", hits);
  
  GenericTrafficElement::lua(vm, true);
}

/* *************************************** */

bool NetworkStats::serialize(json_object *my_object) {
  json_object_object_add(my_object, "ingress", json_object_new_int64(ingress.getNumBytes()));
  json_object_object_add(my_object, "egress", json_object_new_int64(egress.getNumBytes()));
  json_object_object_add(my_object, "inner", json_object_new_int64(inner.getNumBytes()));

  return true;
}

/* *************************************** */

void NetworkStats::deserialize(json_object *o) {
  json_object *obj;
  time_t now = time(NULL);

  if(json_object_object_get_ex(o, "ingress", &obj)) ingress.incStats(now, 0, json_object_get_int(obj));
  if(json_object_object_get_ex(o, "egress", &obj)) egress.incStats(now, 0, json_object_get_int(obj));
  if(json_object_object_get_ex(o, "inner", &obj)) inner.incStats(now, 0, json_object_get_int(obj));
}

/* *************************************** */

void NetworkStats::housekeepAlerts(ScriptPeriodicity p) {
  switch(p) {
  case minute_script:
      flow_flood_victim_alert.reset_hits(),
      syn_flood_victim_alert.reset_hits();
      syn_recvd_last_min = synack_sent_last_min = 0;
    break;
  default:
    break;
  }
}

/* *************************************** */

void NetworkStats::updateSynAlertsCounter(time_t when, bool syn_sent) {
  if(!syn_sent) {
    syn_flood_victim_alert.inc(when, this);
    syn_recvd_last_min++;
  }
}

/* *************************************** */

void NetworkStats::updateSynAckAlertsCounter(time_t when, bool synack_sent) {
  if(synack_sent)
    synack_sent_last_min++;
}

/* *************************************** */

void NetworkStats::incNumFlows(time_t t, bool as_client) {
  if(!as_client)
    flow_flood_victim_alert.inc(t, this);
}

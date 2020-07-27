/*
 *
 * (C) 2013-20 - ntop.org
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

GenericTrafficElement::GenericTrafficElement() {
  /* NOTE NOTE NOTE: keep in sync with copy constructor below */
  ndpiStats = NULL;

  /* Stats */
  resetStats();

#ifdef NTOPNG_PRO
  custom_app_stats = NULL;
#endif

  dscpStats = NULL;
}

/* *************************************** */

void GenericTrafficElement::resetStats() {
  /* NOTE NOTE NOTE: keep in sync with copy constructor below */
  total_num_dropped_flows = 0;
  sent = TrafficStats();
  rcvd = TrafficStats();
  bytes_thpt.resetStats();
  pkts_thpt.resetStats();
  tcp_packet_stats_sent = TcpPacketStats();
  tcp_packet_stats_rcvd = TcpPacketStats();
}

/* *************************************** */

GenericTrafficElement::GenericTrafficElement(const GenericTrafficElement &gte) {
  ndpiStats = (gte.ndpiStats) ? new nDPIStats(*gte.ndpiStats) : NULL;

  bytes_thpt = ThroughputStats(gte.bytes_thpt);
  pkts_thpt  = ThroughputStats(gte.pkts_thpt);

  /* Stats */
  total_num_dropped_flows = gte.total_num_dropped_flows;

  sent = gte.sent;
  rcvd = gte.rcvd;
  tcp_packet_stats_sent = gte.tcp_packet_stats_sent;
  tcp_packet_stats_rcvd = gte.tcp_packet_stats_rcvd;

#ifdef NTOPNG_PRO
  custom_app_stats = (gte.custom_app_stats) ? new CustomAppStats(*gte.custom_app_stats) : NULL;
#endif

  dscpStats = (gte.dscpStats) ? new DSCPStats(*gte.dscpStats) : NULL;
}

/* *************************************** */

void GenericTrafficElement::updateStats(const struct timeval *tv) {
  bytes_thpt.updateStats(tv, sent.getNumBytes() + rcvd.getNumBytes());
  pkts_thpt.updateStats(tv, sent.getNumPkts() + rcvd.getNumPkts());
}

/* *************************************** */

void GenericTrafficElement::lua(lua_State* vm, bool host_details) {
  lua_push_float_table_entry(vm, "throughput_bps", bytes_thpt.getThpt());
  lua_push_uint64_table_entry(vm, "throughput_trend_bps", bytes_thpt.getTrend());

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[bytes_thpt: %.2f] [bytes_thpt_trend: %d]", bytes_thpt,bytes_thpt_trend);
  lua_push_float_table_entry(vm, "throughput_pps", pkts_thpt.getThpt());
  lua_push_uint64_table_entry(vm, "throughput_trend_pps", pkts_thpt.getTrend());

  if(total_num_dropped_flows)
    lua_push_uint64_table_entry(vm, "flows.dropped", total_num_dropped_flows);

  if(host_details) {
    lua_push_uint64_table_entry(vm, "bytes.sent", sent.getNumBytes());
    lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());
    lua_push_uint64_table_entry(vm, "packets.sent", sent.getNumPkts());
    lua_push_uint64_table_entry(vm, "packets.rcvd", rcvd.getNumPkts());
    lua_push_uint64_table_entry(vm, "bytes.ndpi.unknown", ndpiStats ? ndpiStats->getProtoBytes(NDPI_PROTOCOL_UNKNOWN) : 0);

    lua_push_uint64_table_entry(vm, "bytes.sent.anomaly_index", sent.getBytesAnomaly());
    lua_push_uint64_table_entry(vm, "bytes.rcvd.anomaly_index", rcvd.getBytesAnomaly());
    lua_push_uint64_table_entry(vm, "packets.sent.anomaly_index", sent.getPktsAnomaly());
    lua_push_uint64_table_entry(vm, "packets.rcvd.anomaly_index", rcvd.getPktsAnomaly());
  }
}

/* *************************************** */

void GenericTrafficElement::getJSONObject(json_object *my_object, NetworkInterface *iface) {
  if(total_num_dropped_flows)
      json_object_object_add(my_object, "flows.dropped", json_object_new_int(total_num_dropped_flows));

  json_object_object_add(my_object, "sent", sent.getJSONObject());
  json_object_object_add(my_object, "rcvd", rcvd.getJSONObject());

  if(ndpiStats)
    json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObject(iface));
}

/* *************************************** */

void GenericTrafficElement::deserialize(json_object *o, NetworkInterface *iface) {
  json_object *obj;

  if(json_object_object_get_ex(o, "flows.dropped", &obj)) total_num_dropped_flows = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "sent", &obj))  sent.deserialize(obj);
  if(json_object_object_get_ex(o, "rcvd", &obj))  rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "ndpiStats", &obj)) {
    if(ndpiStats) delete ndpiStats;
    ndpiStats = new nDPIStats();
    ndpiStats->deserialize(iface, obj);
  }
}

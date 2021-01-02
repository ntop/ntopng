/*
 *
 * (C) 2013-21 - ntop.org
 *
 *o
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

/* **************************************************** */

void L4Stats::luaStats(lua_State* vm) {
  lua_push_uint64_table_entry(vm, "tcp.packets.sent",  tcp_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "tcp.packets.rcvd",  tcp_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "tcp.bytes.sent", tcp_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "tcp.bytes.rcvd", tcp_rcvd.getNumBytes());

  lua_push_uint64_table_entry(vm, "udp.packets.sent",  udp_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "udp.bytes.sent", udp_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "udp.packets.rcvd",  udp_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "udp.bytes.rcvd", udp_rcvd.getNumBytes());

  lua_push_uint64_table_entry(vm, "icmp.packets.sent",  icmp_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "icmp.bytes.sent", icmp_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "icmp.packets.rcvd",  icmp_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "icmp.bytes.rcvd", icmp_rcvd.getNumBytes());

  lua_push_uint64_table_entry(vm, "other_ip.packets.sent",  other_ip_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.sent", other_ip_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "other_ip.packets.rcvd",  other_ip_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.rcvd", other_ip_rcvd.getNumBytes());
}

/* **************************************************** */

void L4Stats::luaAnomalies(lua_State* vm) {
  lua_push_uint64_table_entry(vm, "tcp.bytes.sent.anomaly_index", tcp_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "tcp.bytes.rcvd.anomaly_index", tcp_rcvd.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "udp.bytes.sent.anomaly_index", udp_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "udp.bytes.rcvd.anomaly_index", udp_rcvd.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "icmp.bytes.sent.anomaly_index", icmp_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "icmp.bytes.rcvd.anomaly_index", icmp_rcvd.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.sent.anomaly_index", other_ip_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.rcvd.anomaly_index", other_ip_rcvd.getBytesAnomaly());
}

/* **************************************************** */

void L4Stats::serialize(json_object *obj) {
  json_object_object_add(obj, "tcp_sent", tcp_sent.getJSONObject());
  json_object_object_add(obj, "tcp_rcvd", tcp_rcvd.getJSONObject());
  json_object_object_add(obj, "udp_sent", udp_sent.getJSONObject());
  json_object_object_add(obj, "udp_rcvd", udp_rcvd.getJSONObject());
  json_object_object_add(obj, "icmp_sent", icmp_sent.getJSONObject());
  json_object_object_add(obj, "icmp_rcvd", icmp_rcvd.getJSONObject());
  json_object_object_add(obj, "other_ip_sent", other_ip_sent.getJSONObject());
  json_object_object_add(obj, "other_ip_rcvd", other_ip_rcvd.getJSONObject());
}

/* **************************************************** */

void L4Stats::deserialize(json_object *o) {
  json_object *obj;

  if(json_object_object_get_ex(o, "tcp_sent", &obj))  tcp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "tcp_rcvd", &obj))  tcp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "udp_sent", &obj))  udp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "udp_rcvd", &obj))  udp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "icmp_sent", &obj))  icmp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "icmp_rcvd", &obj))  icmp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "other_ip_sent", &obj))  other_ip_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "other_ip_rcvd", &obj))  other_ip_rcvd.deserialize(obj);
}

/* **************************************************** */

void L4Stats::incStats(time_t when, u_int8_t l4_proto,
          u_int64_t rcvd_packets, u_int64_t rcvd_bytes,
          u_int64_t sent_packets, u_int64_t sent_bytes) {
  switch(l4_proto) {
  case 0:
    /* Unknown protocol */
    break;
  case IPPROTO_UDP:
    udp_rcvd.incStats(when, rcvd_packets, rcvd_bytes),
      udp_sent.incStats(when, sent_packets, sent_bytes);
    break;
  case IPPROTO_TCP:
    tcp_rcvd.incStats(when, rcvd_packets, rcvd_bytes),
      tcp_sent.incStats(when, sent_packets, sent_bytes);
    break;
  case IPPROTO_ICMP:
    icmp_rcvd.incStats(when, rcvd_packets, rcvd_bytes),
      icmp_sent.incStats(when, sent_packets, sent_bytes);
    break;
  default:
    other_ip_rcvd.incStats(when, rcvd_packets, rcvd_bytes),
      other_ip_sent.incStats(when, sent_packets, sent_bytes);
    break;
  }
}

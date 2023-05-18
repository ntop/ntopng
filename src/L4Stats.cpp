/*
 *
 * (C) 2013-23 - ntop.org
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

void L4Stats::luaStats(lua_State *vm) {
  lua_push_uint64_table_entry(vm, "tcp.packets.sent", tcp_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "tcp.packets.rcvd", tcp_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "tcp.bytes.sent", tcp_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "tcp.bytes.rcvd", tcp_rcvd.getNumBytes());

  lua_push_uint64_table_entry(vm, "udp.packets.sent", udp_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "udp.bytes.sent", udp_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "udp.packets.rcvd", udp_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "udp.bytes.rcvd", udp_rcvd.getNumBytes());

  lua_push_uint64_table_entry(vm, "icmp.packets.sent", icmp_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "icmp.bytes.sent", icmp_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "icmp.packets.rcvd", icmp_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "icmp.bytes.rcvd", icmp_rcvd.getNumBytes());

  lua_push_uint64_table_entry(vm, "other_ip.packets.sent",
                              other_ip_sent.getNumPkts());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.sent",
                              other_ip_sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "other_ip.packets.rcvd",
                              other_ip_rcvd.getNumPkts());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.rcvd",
                              other_ip_rcvd.getNumBytes());
}

/* **************************************************** */

void L4Stats::luaAnomalies(lua_State *vm) {
  lua_push_uint64_table_entry(vm, "tcp.bytes.sent.anomaly_index",
                              tcp_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "tcp.bytes.rcvd.anomaly_index",
                              tcp_rcvd.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "udp.bytes.sent.anomaly_index",
                              udp_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "udp.bytes.rcvd.anomaly_index",
                              udp_rcvd.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "icmp.bytes.sent.anomaly_index",
                              icmp_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "icmp.bytes.rcvd.anomaly_index",
                              icmp_rcvd.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.sent.anomaly_index",
                              other_ip_sent.getBytesAnomaly());
  lua_push_uint64_table_entry(vm, "other_ip.bytes.rcvd.anomaly_index",
                              other_ip_rcvd.getBytesAnomaly());
}

/* **************************************************** */

void L4Stats::incStats(time_t when, u_int8_t l4_proto, u_int64_t rcvd_packets,
                       u_int64_t rcvd_bytes, u_int64_t sent_packets,
                       u_int64_t sent_bytes) {
  switch (l4_proto) {
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

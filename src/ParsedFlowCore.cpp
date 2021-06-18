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

ParsedFlowCore::ParsedFlowCore() {
  src_ip.reset(), dst_ip.reset();
  memset(&src_mac, 0, sizeof(src_mac));
  memset(&dst_mac, 0, sizeof(dst_mac));
  memset(&device_ipv6, 0, sizeof(device_ipv6));
  src_tos = dst_tos = 0;
  version = 0;
  device_ip = 0;
  src_port = dst_port = 0;
  inIndex = outIndex = 0;
  observationPointId = 0;
  l7_proto = Flow::get_ndpi_unknown_protocol();
  vlan_id = 0;
  pkt_sampling_rate = 1; /* 1:1 (no sampling) */
  l4_proto = 0;
  in_pkts = in_bytes = out_pkts = out_bytes = vrfId = 0;
  in_fragments = out_fragments = 0;
  absolute_packet_octet_counters = 0;
  memset(&tcp, 0, sizeof(tcp));
  first_switched = last_switched = 0;
  direction = source_id = 0;
  src_as = dst_as = prev_adjacent_as = next_adjacent_as = 0;
}

/* *************************************** */

ParsedFlowCore::ParsedFlowCore(const ParsedFlowCore &pfc) {
  src_ip.set(&pfc.src_ip), dst_ip.set(&pfc.dst_ip);
  memcpy(&src_mac, &pfc.src_mac, sizeof(src_mac));
  memcpy(&dst_mac, &pfc.dst_mac, sizeof(dst_mac));
  memcpy(&device_ipv6, &pfc.device_ipv6, sizeof(device_ipv6));
  version = pfc.version;
  device_ip = pfc.device_ip;
  src_port = pfc.src_port, dst_port = pfc.dst_port;
  inIndex = pfc.inIndex, outIndex = pfc.outIndex;
  observationPointId = pfc.observationPointId;
  l7_proto = pfc.l7_proto;
  vlan_id = pfc.vlan_id;
  pkt_sampling_rate = pfc.pkt_sampling_rate;
  l4_proto = pfc.l4_proto;
  in_pkts = pfc.in_pkts, in_bytes = pfc.in_bytes;
  out_pkts = pfc.out_pkts, out_bytes = pfc.out_bytes;
  vrfId = pfc.vrfId;
  absolute_packet_octet_counters = pfc.absolute_packet_octet_counters;
  memcpy(&tcp, &pfc.tcp, sizeof(tcp));
  first_switched = pfc.first_switched, last_switched = pfc.last_switched;
  direction = pfc.direction;
  source_id = pfc.source_id;
  src_as = pfc.src_as, dst_as = pfc.dst_as;
  prev_adjacent_as = pfc.prev_adjacent_as, next_adjacent_as = pfc.next_adjacent_as;
}

/* *************************************** */

ParsedFlowCore::~ParsedFlowCore() {
}

/* *************************************** */

void ParsedFlowCore::swap() {
  u_int8_t tmp_mac[6];
  IpAddress tmp_ip;
  u_int16_t tmp_port, tmp_index;
  u_int32_t tmp_bytes, tmp_pkts;
  u_int32_t tmp_fragments;
  u_int8_t tmp_tcp_flags;
  u_int32_t tmp_ooo_pkts, tmp_retr_pkts, tmp_lost_pkts;
  struct timeval tmp_nw_latency;
  u_int32_t tmp_src_as, tmp_prev_adjacent_as;
  u_int16_t tmp_window;
  
  memcpy(&tmp_mac, &src_mac, sizeof(tmp_mac));
  tmp_ip.set(&src_ip);
  tmp_port = src_port, tmp_index = inIndex;
  tmp_bytes = in_bytes, tmp_pkts = in_pkts;
  tmp_fragments = in_fragments;
  tmp_tcp_flags = tcp.client_tcp_flags;
  tmp_ooo_pkts = tcp.ooo_in_pkts, tmp_retr_pkts = tcp.retr_in_pkts, tmp_lost_pkts = tcp.lost_in_pkts;
  memcpy(&tmp_nw_latency, &tcp.clientNwLatency, sizeof(tcp.clientNwLatency));
  tmp_window = tcp.in_window;
  tmp_src_as = src_as, tmp_prev_adjacent_as = prev_adjacent_as;

  memcpy(&src_mac, &dst_mac, sizeof(src_mac));
  src_ip.set(&dst_ip);
  src_port = dst_port, inIndex = outIndex;
  in_bytes = out_bytes, in_pkts = out_pkts;
  in_fragments = out_fragments;
  tcp.client_tcp_flags = tcp.server_tcp_flags;
  tcp.ooo_in_pkts = tcp.ooo_out_pkts, tcp.retr_in_pkts = tcp.retr_out_pkts, tcp.lost_in_pkts = tcp.lost_out_pkts;
  memcpy(&tcp.clientNwLatency, &tcp.serverNwLatency, sizeof(tcp.clientNwLatency));
  tcp.in_window = tcp.out_window;
  src_as = dst_as, prev_adjacent_as = next_adjacent_as;

  memcpy(&dst_mac, &tmp_mac, sizeof(dst_mac));
  dst_ip.set(&tmp_ip);
  dst_port = tmp_port, outIndex = tmp_index;
  out_bytes = tmp_bytes, out_pkts = tmp_pkts;
  out_fragments = tmp_fragments;
  tcp.server_tcp_flags = tmp_tcp_flags;
  tcp.ooo_out_pkts = tmp_ooo_pkts, tcp.retr_out_pkts = tmp_retr_pkts, tcp.lost_out_pkts = tmp_lost_pkts;
  memcpy(&tcp.serverNwLatency, &tmp_nw_latency, sizeof(tcp.serverNwLatency));
  tcp.out_window = tmp_window;
  dst_as = tmp_src_as, next_adjacent_as = tmp_prev_adjacent_as;
}

/* *************************************** */

void ParsedFlowCore::print() {
  char buf1[32], buf2[32];

  src_ip.print(buf1, sizeof(buf1));
  dst_ip.print(buf2, sizeof(buf2));

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[src: %s][dst: %s][src_port: %u][dst_port: %u]",
  			       src_ip.print(buf1, sizeof(buf1)),
  			       dst_ip.print(buf2, sizeof(buf2)),
  			       ntohs(src_port), ntohs(dst_port));
 }

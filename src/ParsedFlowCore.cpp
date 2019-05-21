/*
 *
 * (C) 2013-19 - ntop.org
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

  version = 0;
  deviceIP = 0;
  src_port = dst_port = inIndex = outIndex = 0;
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
}

/* *************************************** */

ParsedFlowCore::ParsedFlowCore(const ParsedFlowCore &pfc) {
  src_ip.set(&pfc.src_ip), dst_ip.set(&pfc.dst_ip);
  memcpy(&src_mac, &pfc.src_mac, sizeof(src_mac));
  memcpy(&dst_mac, &pfc.dst_mac, sizeof(dst_mac));

  version = pfc.version;
  deviceIP = pfc.deviceIP;
  src_port = pfc.src_port, dst_port = pfc.dst_port;
  inIndex = pfc.inIndex, outIndex = pfc.outIndex;
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
}

/* *************************************** */

ParsedFlowCore::~ParsedFlowCore() {
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

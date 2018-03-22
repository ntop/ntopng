/*
 *
 * (C) 2013-18 - ntop.org
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

EthStats::EthStats() {
  cleanup();
}

/* *************************************** */

void EthStats::incStats(bool ingressPacket,
			u_int16_t proto, u_int32_t num_pkts,
			u_int32_t num_bytes, u_int pkt_overhead) {
  if(ingressPacket)
    rawIngress.inc(num_pkts, num_bytes+pkt_overhead*num_pkts);
  else
    rawEgress.inc(num_pkts, num_bytes+pkt_overhead*num_pkts);

  switch(proto) {
  case ETHERTYPE_ARP:
    eth_ARP.inc(num_pkts, num_bytes);
    break;
  case ETHERTYPE_IP:
    eth_IPv4.inc(num_pkts, num_bytes);
    break;
  case ETHERTYPE_IPV6:
    eth_IPv6.inc(num_pkts, num_bytes);
    break;
  case ETHERTYPE_MPLS:
  case ETHERTYPE_MPLS_MULTI:
    eth_MPLS.inc(num_pkts, num_bytes);
    break;
  default:
    eth_other.inc(num_pkts, num_bytes);
    break;
  }
};

/* *************************************** */

void EthStats::lua(lua_State *vm) {
  lua_newtable(vm);

  eth_IPv4.lua(vm,  "IPv4_");
  eth_IPv6.lua(vm,  "IPv6_");
  eth_ARP.lua(vm,   "ARP_");
  eth_MPLS.lua(vm,  "MPLS_");
  eth_other.lua(vm, "other_");
  lua_push_int_table_entry(vm, "bytes",   getNumBytes());
  lua_push_int_table_entry(vm, "packets", getNumPackets());

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "bytes",   getNumIngressBytes());
  lua_push_int_table_entry(vm, "packets", getNumIngressPackets());
  lua_pushstring(vm, "ingress"); lua_insert(vm, -2); lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "bytes",   getNumEgressBytes());
  lua_push_int_table_entry(vm, "packets", getNumEgressPackets());
  lua_pushstring(vm, "egress"); lua_insert(vm, -2); lua_settable(vm, -3);

  lua_pushstring(vm, "eth"); lua_insert(vm, -2); lua_settable(vm, -3);
}

/* *************************************** */

void EthStats::print() {
  eth_IPv4.print ("[IPv4] ");
  eth_IPv6.print ("[IPv6] ");
  eth_ARP.print  ("[ARP]  ");
  eth_MPLS.print ("[MPLS] ");
  eth_other.print("[Other]");
}

/* *************************************** */

void EthStats::cleanup() {
  rawIngress.reset(), rawEgress.reset(); 
  eth_IPv4.reset();
  eth_IPv6.reset();
  eth_ARP.reset();
  eth_MPLS.reset();
  eth_other.reset();
}

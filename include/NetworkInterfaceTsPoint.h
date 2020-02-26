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

#ifndef _NETWORK_INTERFACE_TS_POINT_H_
#define _NETWORK_INTERFACE_TS_POINT_H_

#include "ntop_includes.h"

/* This is manually populated by NetworkInterface::makeTsPoint */
class NetworkInterfaceTsPoint: public TimeseriesPoint {
 public:
  nDPIStats ndpi;
  LocalTrafficStats local_stats;
  u_int hosts, local_hosts;
  u_int devices, flows, http_hosts;
  u_int engaged_alerts, dropped_alerts;
  u_int num_alerted_flows, num_misbehaving_flows;
  TcpPacketStats tcpPacketStats;
  PacketStats packetStats;
  L4Stats l4Stats;

  virtual void lua(lua_State* vm, NetworkInterface *iface);
};

#endif /* _NETWORK_INTERFACE_TS_POINT_H_ */

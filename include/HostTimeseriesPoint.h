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

#ifndef _HOST_TIMESERIES_POINT_H_
#define _HOST_TIMESERIES_POINT_H_

#include "ntop_includes.h"

class TimeseriesStats;

class DnsStats;
class ICMPstats;
class LocalHostStats;

class HostTimeseriesPoint: public TimeseriesPoint {
 private:
  TimeseriesStats *host_stats;

 public:
  /* Keep these public in order to allow LocalHostStats::makeTsPoint to set them. */
  u_int32_t active_flows_as_client, active_flows_as_server;
  u_int32_t contacts_as_client, contacts_as_server;
  u_int32_t engaged_alerts;
  TcpPacketStats tcp_packet_stats_sent, tcp_packet_stats_rcvd;
  DnsStats *dns;
  ts_icmp_stats *icmp;

  HostTimeseriesPoint(const LocalHostStats * const hs);
  virtual ~HostTimeseriesPoint();
  virtual void lua(lua_State* vm, NetworkInterface *iface);
};

#endif /* _HOST_TIMESERIES_POINT_H_ */

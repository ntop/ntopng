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

#ifndef _HOST_TIMESERIES_POINT_H_
#define _HOST_TIMESERIES_POINT_H_

#include "ntop_includes.h"

class HostTimeseriesPoint: public TimeseriesPoint {
 public:
  nDPIStats *ndpi;
  u_int64_t sent, rcvd;
  u_int32_t num_flows_as_client, num_flows_as_server;
  u_int64_t total_num_anomalous_flows_as_client, total_num_anomalous_flows_as_server;
  TrafficCounter l4_stats[4]; // tcp, udp, icmp, other
  u_int32_t num_contacts_as_cli, num_contacts_as_srv;

  HostTimeseriesPoint();
  virtual ~HostTimeseriesPoint();
  virtual void lua(lua_State* vm, NetworkInterface *iface);
};

#endif /* _HOST_TIMESERIES_POINT_H_ */

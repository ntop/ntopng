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

TimeseriesStats::TimeseriesStats(Host * _host) : GenericTrafficElement() {
  host = _host;
  misbehaving_flows_as_client = misbehaving_flows_as_server = 0;
  unreachable_flows_as_client = unreachable_flows_as_server = 0;
  host_unreachable_flows_as_client = host_unreachable_flows_as_server = 0;
  udp_sent_unicast = udp_sent_non_unicast = 0;
  total_num_flows_as_client = total_num_flows_as_server = 0;
  num_flow_alerts = 0;
}

/* *************************************** */

/* NOTE: this method is also called by Host::lua
 * Return only the minimal information needed by the timeseries
 * to avoid slowing down the periodic scripts too much! */
void TimeseriesStats::luaStats(lua_State* vm, NetworkInterface *iface, bool host_details, bool verbose, bool tsLua) {
  /* NOTE: this class represents a (previously saved) timeseries point. Do not access Host data and push it directly here! */
  lua_push_uint64_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());
  lua_push_uint64_table_entry(vm, "total_flows.as_client", total_num_flows_as_client);
  lua_push_uint64_table_entry(vm, "total_flows.as_server", total_num_flows_as_server);

  if(verbose) {
    if(ndpiStats) ndpiStats->lua(iface, vm, true, tsLua);
  }

  if(host_details) {
    lua_push_uint64_table_entry(vm, "misbehaving_flows.as_client", getTotalMisbehavingNumFlowsAsClient());
    lua_push_uint64_table_entry(vm, "misbehaving_flows.as_server", getTotalMisbehavingNumFlowsAsServer());
    lua_push_uint64_table_entry(vm, "unreachable_flows.as_client", unreachable_flows_as_client);
    lua_push_uint64_table_entry(vm, "unreachable_flows.as_server", unreachable_flows_as_server);
    lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_client", host_unreachable_flows_as_client);
    lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_server", host_unreachable_flows_as_server);
    lua_push_uint64_table_entry(vm, "total_alerts", getTotalAlerts());
    lua_push_uint64_table_entry(vm, "num_flow_alerts", num_flow_alerts);

    l4stats.luaStats(vm);
    lua_push_uint64_table_entry(vm, "udpBytesSent.unicast", udp_sent_unicast);
    lua_push_uint64_table_entry(vm, "udpBytesSent.non_unicast", udp_sent_non_unicast);
  }
}

/* *************************************** */

u_int32_t TimeseriesStats::getTotalAlerts() const {
  std::map<AlertType, u_int32_t>::const_iterator it;
  u_int32_t num_alerts = 0;

  for(it = total_alerts.begin(); it != total_alerts.end(); ++it)
    num_alerts += it->second;

  return(num_alerts);
}

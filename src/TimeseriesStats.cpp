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

TimeseriesStats::TimeseriesStats(Host * _host) : GenericTrafficElement() {
  host = _host;
  anomalous_flows_as_client = anomalous_flows_as_server = 0;
  unreachable_flows_as_client = unreachable_flows_as_server = 0;
  host_unreachable_flows_as_client = host_unreachable_flows_as_server = 0;
  udp_sent_unicast = udp_sent_non_unicast = 0;
}

/* *************************************** */

TimeseriesStats::~TimeseriesStats() {
  // TODO
}

/* *************************************** */

void TimeseriesStats::luaStats(lua_State* vm, NetworkInterface *iface, bool host_details, bool verbose, bool tsLua) {
  lua_push_uint64_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());
  lua_push_uint64_table_entry(vm, "active_flows.as_client", host->getNumOutgoingFlows());
  lua_push_uint64_table_entry(vm, "active_flows.as_server", host->getNumIncomingFlows());
  lua_push_uint64_table_entry(vm, "total_flows.as_client", host->getTotalNumFlowsAsClient());
  lua_push_uint64_table_entry(vm, "total_flows.as_server", host->getTotalNumFlowsAsServer());

  if(verbose) {
    if(ndpiStats) ndpiStats->lua(iface, vm, true, tsLua);
  }

  if(host_details) {
    lua_push_uint64_table_entry(vm, "anomalous_flows.as_client", getTotalAnomalousNumFlowsAsClient());
    lua_push_uint64_table_entry(vm, "anomalous_flows.as_server", getTotalAnomalousNumFlowsAsServer());
    lua_push_uint64_table_entry(vm, "unreachable_flows.as_client", unreachable_flows_as_client);
    lua_push_uint64_table_entry(vm, "unreachable_flows.as_server", unreachable_flows_as_server);
    lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_client", host_unreachable_flows_as_client);
    lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_server", host_unreachable_flows_as_server);
    lua_push_uint64_table_entry(vm, "contacts.as_client", host->getNumActiveContactsAsClient());
    lua_push_uint64_table_entry(vm, "contacts.as_server", host->getNumActiveContactsAsServer());
    lua_push_uint64_table_entry(vm, "total_alerts", getTotalAlerts());

    l4stats.luaStats(vm);
    lua_push_uint64_table_entry(vm, "udpBytesSent.unicast", udp_sent_unicast);
    lua_push_uint64_table_entry(vm, "udpBytesSent.non_unicast", udp_sent_non_unicast);

    host->luaDNS(vm);
    host->luaTCP(vm);
    host->luaICMP(vm, host->get_ip()->isIPv4(),false);
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

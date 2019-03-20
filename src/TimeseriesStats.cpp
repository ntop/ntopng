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
  port_unreachable_flows_as_client = port_unreachable_flows_as_server = 0;

  total_alerts = 0;
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

  if(verbose) {
    if(ndpiStats) ndpiStats->lua(iface, vm, true, tsLua);
  }

  if(host_details) {
    lua_push_uint64_table_entry(vm, "anomalous_flows.as_client", getTotalAnomalousNumFlowsAsClient());
    lua_push_uint64_table_entry(vm, "anomalous_flows.as_server", getTotalAnomalousNumFlowsAsServer());
    lua_push_uint64_table_entry(vm, "unreachable_flows.as_client", unreachable_flows_as_client);
    lua_push_uint64_table_entry(vm, "unreachable_flows.as_server", unreachable_flows_as_server);
    lua_push_uint64_table_entry(vm, "port_unreachable_flows.as_client", port_unreachable_flows_as_client);
    lua_push_uint64_table_entry(vm, "port_unreachable_flows.as_server", port_unreachable_flows_as_server);
    lua_push_uint64_table_entry(vm, "contacts.as_client", getNumActiveContactsAsClient());
    lua_push_uint64_table_entry(vm, "contacts.as_server", getNumActiveContactsAsServer());
    lua_push_uint64_table_entry(vm, "total_alerts", total_alerts);

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
}

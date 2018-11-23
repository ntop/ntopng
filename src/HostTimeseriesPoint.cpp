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

HostTimeseriesPoint::HostTimeseriesPoint() {
  ndpi = NULL;
}

HostTimeseriesPoint::~HostTimeseriesPoint() {
  if(ndpi) delete ndpi;
}

/* *************************************** */

void HostTimeseriesPoint::lua(lua_State* vm, NetworkInterface *iface) {
  if(ndpi)
    ndpi->lua(iface, vm, true /* with categories */, true /* tsLua */);

  lua_push_uint64_table_entry(vm, "bytes.sent", sent);
  lua_push_uint64_table_entry(vm, "bytes.rcvd", rcvd);
  lua_push_uint64_table_entry(vm, "active_flows.as_client", num_flows_as_client);
  lua_push_uint64_table_entry(vm, "active_flows.as_server", num_flows_as_server);
  lua_push_uint64_table_entry(vm, "contacts.as_client", num_contacts_as_cli);
  lua_push_uint64_table_entry(vm, "contacts.as_server", num_contacts_as_srv);

  /* L4 */
  lua_push_uint64_table_entry(vm, "tcp.bytes.sent", l4_stats[0].sent);
  lua_push_uint64_table_entry(vm, "tcp.bytes.rcvd", l4_stats[0].rcvd);
  lua_push_uint64_table_entry(vm, "udp.bytes.sent",  l4_stats[1].sent);
  lua_push_uint64_table_entry(vm, "udp.bytes.rcvd", l4_stats[1].rcvd);
  lua_push_uint64_table_entry(vm, "icmp.bytes.sent",  l4_stats[2].sent);
  lua_push_uint64_table_entry(vm, "icmp.bytes.rcvd", l4_stats[2].rcvd);
  lua_push_uint64_table_entry(vm, "other_ip.bytes.sent", l4_stats[3].sent);
  lua_push_uint64_table_entry(vm, "other_ip.bytes.rcvd", l4_stats[3].rcvd);
}

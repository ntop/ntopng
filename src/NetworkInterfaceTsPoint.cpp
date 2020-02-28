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

void NetworkInterfaceTsPoint::lua(lua_State* vm, NetworkInterface *iface) {
  ndpi.lua(iface, vm, true /* with categories */);
  local_stats.lua(vm);
  tcpPacketStats.lua(vm, "tcpPacketStats");
  packetStats.lua(vm, "pktSizeDistribution");

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "hosts", hosts);
  lua_push_uint64_table_entry(vm, "local_hosts", local_hosts);
  lua_push_uint64_table_entry(vm, "devices", devices);
  lua_push_uint64_table_entry(vm, "flows", flows);
  lua_push_uint64_table_entry(vm, "http_hosts", http_hosts);
  lua_push_uint64_table_entry(vm, "engaged_alerts", engaged_alerts);
  lua_push_uint64_table_entry(vm, "dropped_alerts", dropped_alerts);
  lua_push_uint64_table_entry(vm, "num_alerted_flows", num_alerted_flows);
  lua_push_uint64_table_entry(vm, "num_new_flows", num_new_flows);
  lua_push_uint64_table_entry(vm, "num_misbehaving_flows", num_misbehaving_flows);
  l4Stats.luaStats(vm);
  lua_pushstring(vm, "stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

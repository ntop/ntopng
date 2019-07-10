/*
 *
 * (C) 2015-19 - ntop.org
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

NetworkStats::NetworkStats() : AlertableEntity() {
  network_id = 0;
}

/* *************************************** */

void NetworkStats::lua(lua_State* vm) {
  lua_push_str_table_entry(vm, "network_key", ntop->getLocalNetworkName(network_id));
  lua_push_uint64_table_entry(vm, "network_id", network_id);

  lua_push_uint64_table_entry(vm, "ingress", ingress.getNumBytes());
  lua_push_uint64_table_entry(vm, "egress", egress.getNumBytes());
  lua_push_uint64_table_entry(vm, "inner", inner.getNumBytes());

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "ingress", ingress_broadcast.getNumBytes());
  lua_push_uint64_table_entry(vm, "egress", egress_broadcast.getNumBytes());
  lua_push_uint64_table_entry(vm, "inner", inner_broadcast.getNumBytes());
  lua_pushstring(vm, "broadcast");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  tcp_packet_stats_ingress.lua(vm, "tcpPacketStats.ingress");
  tcp_packet_stats_egress.lua(vm, "tcpPacketStats.egress");
  tcp_packet_stats_inner.lua(vm, "tcpPacketStats.inner");
}

/* *************************************** */

bool NetworkStats::serialize(json_object *my_object) {
  json_object_object_add(my_object, "ingress", json_object_new_int64(ingress.getNumBytes()));
  json_object_object_add(my_object, "egress", json_object_new_int64(egress.getNumBytes()));
  json_object_object_add(my_object, "inner", json_object_new_int64(inner.getNumBytes()));

  return true;
}

/* *************************************** */

void NetworkStats::deserialize(json_object *o) {
  json_object *obj;
  time_t now = time(NULL);

  if(json_object_object_get_ex(o, "ingress", &obj)) ingress.incStats(now, 0, json_object_get_int(obj));
  if(json_object_object_get_ex(o, "egress", &obj)) egress.incStats(now, 0, json_object_get_int(obj));
  if(json_object_object_get_ex(o, "inner", &obj)) inner.incStats(now, 0, json_object_get_int(obj));
}

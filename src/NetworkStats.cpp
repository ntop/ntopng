/*
 *
 * (C) 2015-18 - ntop.org
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

NetworkStats::NetworkStats() {
}

/* *************************************** */

void NetworkStats::lua(lua_State* vm) {
  lua_push_int_table_entry(vm, "ingress", ingress.getNumBytes());
  lua_push_int_table_entry(vm, "egress", egress.getNumBytes());
  lua_push_int_table_entry(vm, "inner", inner.getNumBytes());

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "ingress", ingress_broadcast.getNumBytes());
  lua_push_int_table_entry(vm, "egress", egress_broadcast.getNumBytes());
  lua_push_int_table_entry(vm, "inner", inner_broadcast.getNumBytes());
  lua_pushstring(vm, "broadcast");
  lua_insert(vm, -2);
  lua_settable(vm, -3);  
}

/* *************************************** */

bool NetworkStats::serializeCheckpoint(json_object *my_object, DetailsLevel details_level) {
  json_object_object_add(my_object, "ingress", json_object_new_int64(ingress.getNumBytes()));
  json_object_object_add(my_object, "egress", json_object_new_int64(egress.getNumBytes()));
  json_object_object_add(my_object, "inner", json_object_new_int64(inner.getNumBytes()));

  return true;
}

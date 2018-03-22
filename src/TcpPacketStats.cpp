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

TcpPacketStats::TcpPacketStats() {
  pktRetr = pktOOO = pktLost = 0;
}

/* *************************************** */

char* TcpPacketStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void TcpPacketStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  if(json_object_object_get_ex(o, "retransmissions", &obj)) pktRetr = json_object_get_int(obj); else pktRetr = 0;
  if(json_object_object_get_ex(o, "out_of_order", &obj))    pktOOO = json_object_get_int(obj);  else pktOOO = 0;
  if(json_object_object_get_ex(o, "lost", &obj))            pktLost = json_object_get_int(obj); else pktLost = 0;
}

/* ******************************************* */

json_object* TcpPacketStats::getJSONObject() {
  json_object *my_object;

  my_object = json_object_new_object();

  if(pktRetr > 0) json_object_object_add(my_object, "retransmissions", json_object_new_int(pktRetr));
  if(pktOOO > 0) json_object_object_add(my_object, "out_of_order", json_object_new_int(pktOOO));
  if(pktLost > 0) json_object_object_add(my_object, "lost", json_object_new_int(pktLost));
  
  return(my_object);
}

/* ******************************************* */

void TcpPacketStats::lua(lua_State* vm, const char *label) {
  lua_newtable(vm);
  
  lua_push_int_table_entry(vm, "retransmissions", pktRetr);
  lua_push_int_table_entry(vm, "out_of_order", pktOOO);
  lua_push_int_table_entry(vm, "lost", pktLost);
  
  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

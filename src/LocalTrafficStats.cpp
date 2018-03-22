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

LocalTrafficStats::LocalTrafficStats() {
  memset(&packets, 0, sizeof(packets));
  memset(&bytes, 0, sizeof(bytes));
}

/* *************************************** */

void LocalTrafficStats::incStats(u_int num_pkts, u_int pkt_len, 
				 bool localsender, bool localreceiver) { 
  if(localsender) {
    if(localreceiver)
      packets.local2local += num_pkts, bytes.local2local += pkt_len;
    else
      packets.local2remote += num_pkts, bytes.local2remote += pkt_len;    
  } else {
    if(localreceiver)
      packets.remote2local += num_pkts, bytes.remote2local += pkt_len;
    else
      packets.remote2remote += num_pkts, bytes.remote2remote += pkt_len;
  }
};  

/* *************************************** */

char* LocalTrafficStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void LocalTrafficStats::deserialize(json_object *o) {
  json_object *obj, *s;

  if(!o) return;

  if(json_object_object_get_ex(o, "bytes", &s)) {
    if(json_object_object_get_ex(s, "local2local", &obj)) bytes.local2local = json_object_get_int64(obj);
    if(json_object_object_get_ex(s, "local2remote", &obj)) bytes.local2remote = json_object_get_int64(obj);
    if(json_object_object_get_ex(s, "remote2local", &obj)) bytes.remote2local = json_object_get_int64(obj);
    if(json_object_object_get_ex(s, "remote2remote", &obj)) bytes.remote2remote = json_object_get_int64(obj);
  }

  if(json_object_object_get_ex(o, "packets", &s)) {
    if(json_object_object_get_ex(s, "local2local", &obj)) packets.local2local = json_object_get_int64(obj);
    if(json_object_object_get_ex(s, "local2remote", &obj)) packets.local2remote = json_object_get_int64(obj);
    if(json_object_object_get_ex(s, "remote2local", &obj)) packets.remote2local = json_object_get_int64(obj);
    if(json_object_object_get_ex(s, "remote2remote", &obj)) packets.remote2remote = json_object_get_int64(obj);
  }
}

/* ******************************************* */

json_object* LocalTrafficStats::getJSONObject() {
  json_object *my_object;
  json_object *my_stats;

  my_object = json_object_new_object();

  my_stats = json_object_new_object();
  if(packets.local2local > 0) json_object_object_add(my_object, "local2local", json_object_new_int64(packets.local2local));
  if(packets.local2remote > 0) json_object_object_add(my_object, "local2remote", json_object_new_int64(packets.local2remote));
  if(packets.remote2local > 0) json_object_object_add(my_object, "remote2local", json_object_new_int64(packets.remote2local));
  if(packets.remote2remote > 0) json_object_object_add(my_object, "remote2remote", json_object_new_int64(packets.remote2remote));
  json_object_object_add(my_object, "packets", my_stats);
  
  my_stats = json_object_new_object();
  if(bytes.local2local > 0) json_object_object_add(my_object, "local2local", json_object_new_int64(bytes.local2local));
  if(bytes.local2remote > 0) json_object_object_add(my_object, "local2remote", json_object_new_int64(bytes.local2remote));
  if(bytes.remote2local > 0) json_object_object_add(my_object, "remote2local", json_object_new_int64(bytes.remote2local));
  if(bytes.remote2remote > 0) json_object_object_add(my_object, "remote2remote", json_object_new_int64(bytes.remote2remote));
  json_object_object_add(my_object, "bytes", my_stats);
  
  return(my_object);
}

/* ******************************************* */

void LocalTrafficStats::lua(lua_State* vm) {
  lua_newtable(vm);
  
  lua_newtable(vm);
  lua_push_int_table_entry(vm, "local2local", packets.local2local);
  lua_push_int_table_entry(vm, "local2remote", packets.local2remote);
  lua_push_int_table_entry(vm, "remote2local", packets.remote2local);
  lua_push_int_table_entry(vm, "remote2remote", packets.remote2remote);  
  lua_pushstring(vm, "packets");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "local2local", bytes.local2local);
  lua_push_int_table_entry(vm, "local2remote", bytes.local2remote);
  lua_push_int_table_entry(vm, "remote2local", bytes.remote2local);
  lua_push_int_table_entry(vm, "remote2remote", bytes.remote2remote);  
  lua_pushstring(vm, "bytes");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_pushstring(vm, "localstats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

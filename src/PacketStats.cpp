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

PacketStats::PacketStats() {
  upTo64 = 0, upTo128 = 0, upTo256 = 0,
    upTo512 = 0, upTo1024 = 0, upTo1518 = 0,
    upTo2500 = 0, upTo6500 = 0, upTo9000 = 0,
    above9000 = 0, syn = 0, synack = 0,
    finack = 0, rst = 0;
}

/* *************************************** */

void PacketStats::incStats(u_int pkt_len) { 
  if(pkt_len <= 64)        upTo64 += 1;
  else if(pkt_len <= 128)  upTo128 += 1;
  else if(pkt_len <= 256)  upTo256 += 1;
  else if(pkt_len <= 512)  upTo512 += 1;
  else if(pkt_len <= 1024) upTo1024 += 1;
  else if(pkt_len <= 1518) upTo1518 += 1;
  else if(pkt_len <= 2500) upTo2500 += 1;
  else if(pkt_len <= 6500) upTo6500 += 1;
  else if(pkt_len <= 9000) upTo9000 += 1;
  else above9000 += 1;
};  

/* *************************************** */

void PacketStats::incFlagStats(u_int8_t flags) { 
  if(flags == TH_SYN)                 syn++;
  else if(flags == (TH_SYN|TH_ACK))   synack++;
  else if(flags == (TH_FIN|TH_ACK))   finack++;
  else if((flags & TH_RST) == TH_RST) rst++;
}

/* *************************************** */

char* PacketStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void PacketStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  if(json_object_object_get_ex(o, "upTo64", &obj))    upTo64  = json_object_get_int64(obj);   else upTo64 = 0;
  if(json_object_object_get_ex(o, "upTo128", &obj))   upTo128 = json_object_get_int64(obj);   else upTo128 = 0;
  if(json_object_object_get_ex(o, "upTo256", &obj))   upTo256 = json_object_get_int64(obj);   else upTo256 = 0;
  if(json_object_object_get_ex(o, "upTo512", &obj))   upTo512  = json_object_get_int64(obj);  else upTo512 = 0;
  if(json_object_object_get_ex(o, "upTo1024", &obj))  upTo1024 = json_object_get_int64(obj);  else upTo1024 = 0;
  if(json_object_object_get_ex(o, "upTo1518", &obj))  upTo1518  = json_object_get_int64(obj); else upTo1518 = 0;
  if(json_object_object_get_ex(o, "upTo2500", &obj))  upTo2500  = json_object_get_int64(obj); else upTo2500 = 0;
  if(json_object_object_get_ex(o, "upTo6500", &obj))  upTo6500 = json_object_get_int64(obj);  else upTo6500 = 0;
  if(json_object_object_get_ex(o, "upTo9000", &obj))  upTo9000 = json_object_get_int64(obj);  else upTo9000 = 0;
  if(json_object_object_get_ex(o, "above9000", &obj)) above9000 = json_object_get_int64(obj); else above9000 = 0;
  if(json_object_object_get_ex(o, "syn", &obj)) syn = json_object_get_int64(obj); else syn = 0;
  if(json_object_object_get_ex(o, "synack", &obj)) synack = json_object_get_int64(obj); else synack = 0;
  if(json_object_object_get_ex(o, "finack", &obj)) finack = json_object_get_int64(obj); else finack = 0;
  if(json_object_object_get_ex(o, "rst", &obj)) rst = json_object_get_int64(obj); else rst = 0;
}

/* ******************************************* */

json_object* PacketStats::getJSONObject() {
  json_object *my_object;

  my_object = json_object_new_object();

  if(upTo64 > 0) json_object_object_add(my_object, "upTo64", json_object_new_int64(upTo64));
  if(upTo128 > 0) json_object_object_add(my_object, "upTo128", json_object_new_int64(upTo128));
  if(upTo256 > 0) json_object_object_add(my_object, "upTo256", json_object_new_int64(upTo256));
  if(upTo512 > 0) json_object_object_add(my_object, "upTo512", json_object_new_int64(upTo512));
  if(upTo1024 > 0) json_object_object_add(my_object, "upTo1024", json_object_new_int64(upTo1024));
  if(upTo1518 > 0) json_object_object_add(my_object, "upTo1518", json_object_new_int64(upTo1518));
  if(upTo2500 > 0) json_object_object_add(my_object, "upTo2500", json_object_new_int64(upTo2500));
  if(upTo6500 > 0) json_object_object_add(my_object, "upTo6500", json_object_new_int64(upTo6500));
  if(upTo9000 > 0) json_object_object_add(my_object, "upTo9000", json_object_new_int64(upTo9000));
  if(above9000 > 0) json_object_object_add(my_object, "above9000", json_object_new_int64(above9000));
  if(syn > 0)    json_object_object_add(my_object, "syn", json_object_new_int64(syn));
  if(synack > 0) json_object_object_add(my_object, "synack", json_object_new_int64(synack));
  if(finack > 0) json_object_object_add(my_object, "finack", json_object_new_int64(finack));
  if(rst > 0)    json_object_object_add(my_object, "rst", json_object_new_int64(rst));
  
  return(my_object);
}

/* ******************************************* */

void PacketStats::lua(lua_State* vm, const char *label) {
  lua_newtable(vm);
  
  lua_push_int_table_entry(vm, "upTo64", upTo64);
  lua_push_int_table_entry(vm, "upTo128", upTo128);
  lua_push_int_table_entry(vm, "upTo256", upTo256);
  lua_push_int_table_entry(vm, "upTo512", upTo512);
  lua_push_int_table_entry(vm, "upTo1024", upTo1024);
  lua_push_int_table_entry(vm, "upTo1518", upTo1518);
  lua_push_int_table_entry(vm, "upTo2500", upTo2500);
  lua_push_int_table_entry(vm, "upTo6500", upTo6500);
  lua_push_int_table_entry(vm, "upTo9000", upTo9000);
  lua_push_int_table_entry(vm, "above9000", above9000);

  lua_push_int_table_entry(vm, "syn", syn);
  lua_push_int_table_entry(vm, "synack", synack);
  lua_push_int_table_entry(vm, "finack", finack);
  lua_push_int_table_entry(vm, "rst", rst);
  
  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

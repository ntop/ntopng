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

TcpFlowStats::TcpFlowStats() {
  numSynFlows = numEstablishedFlows = numResetFlows = numFinFlows = 0;
}

/* *************************************** */

char* TcpFlowStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void TcpFlowStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  if(json_object_object_get_ex(o, "numSynFlows", &obj))    numSynFlows = json_object_get_int(obj);   else numSynFlows = 0;
  if(json_object_object_get_ex(o, "numEstablishedFlows", &obj))    numEstablishedFlows = json_object_get_int(obj);   else numEstablishedFlows = 0;
  if(json_object_object_get_ex(o, "numResetFlows", &obj))    numResetFlows = json_object_get_int(obj);   else numResetFlows = 0;
  if(json_object_object_get_ex(o, "numFinFlows", &obj))    numFinFlows = json_object_get_int(obj);   else numFinFlows = 0;
}

/* ******************************************* */

json_object* TcpFlowStats::getJSONObject() {
  json_object *my_object;

  my_object = json_object_new_object();

  if(numSynFlows > 0) json_object_object_add(my_object, "numSynFlows", json_object_new_int(numSynFlows));
  if(numEstablishedFlows > 0) json_object_object_add(my_object, "numEstablishedFlows", json_object_new_int(numEstablishedFlows));
  if(numResetFlows > 0) json_object_object_add(my_object, "numResetFlows", json_object_new_int(numResetFlows));
  if(numFinFlows > 0) json_object_object_add(my_object, "numFinFlows", json_object_new_int(numFinFlows));
  
  return(my_object);
}

/* ******************************************* */

void TcpFlowStats::lua(lua_State* vm, const char *label) {
  lua_newtable(vm);
  
  lua_push_int_table_entry(vm, "numSynFlows", numSynFlows);
  lua_push_int_table_entry(vm, "numEstablishedFlows", numEstablishedFlows);
  lua_push_int_table_entry(vm, "numResetFlows", numResetFlows);
  lua_push_int_table_entry(vm, "numFinFlows", numFinFlows);
  
  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

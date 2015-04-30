/*
 *
 * (C) 2013-15 - ntop.org
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

EppStats::EppStats() {
  memset(&sent, 0, sizeof(struct epp_stats));
  memset(&rcvd, 0, sizeof(struct epp_stats));
}

/* *************************************** */

void EppStats::luaStats(lua_State *vm, struct epp_stats *stats, const char *label) {
  lua_newtable(vm);

  lua_push_int_table_entry(vm, "num_queries", stats->num_queries);
  lua_push_int_table_entry(vm, "num_replies_ok", stats->num_replies_ok);
  lua_push_int_table_entry(vm, "num_replies_error", stats->num_replies_error);

  for(int i=1; i < CONST_EPP_MAX_CMD_NUM; i++) {
    if(stats->breakdown[i] > 0) {
      char buf[32];

      snprintf(buf, sizeof(buf), "num_cmd_%u", i);
      lua_push_int_table_entry(vm, buf, stats->breakdown[i]);
    }
  }

  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void EppStats::lua(lua_State *vm) {
  lua_newtable(vm);

  luaStats(vm, &sent, "sent");
  luaStats(vm, &rcvd, "rcvd");

  lua_pushstring(vm, "epp");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

}

/* *************************************** */

char* EppStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void EppStats::deserializeStats(json_object *o, struct epp_stats *stats) {
  json_object *obj;
  
  memset(stats, 0, sizeof(struct epp_stats));
  for(int i=1; i < CONST_EPP_MAX_CMD_NUM; i++) {
    char buf[32];
    
    snprintf(buf, sizeof(buf), "num_cmd_%u", i);
    
    if(json_object_object_get_ex(o, buf, &obj)) 
      stats->breakdown[i] = json_object_get_int64(obj);
  }
}

/* ******************************************* */

void EppStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  if(json_object_object_get_ex(o, "sent", &obj))
    deserializeStats(obj, &sent);  

  if(json_object_object_get_ex(o, "rcvd", &obj))
    deserializeStats(obj, &sent);  
}

/* ******************************************* */

json_object* EppStats::getStatsJSONObject(struct epp_stats *stats) {
  json_object *my_object = json_object_new_object();

  if(stats->num_queries > 0) json_object_object_add(my_object, "num_queries", json_object_new_int64(stats->num_queries));
  if(stats->num_replies_ok > 0) json_object_object_add(my_object, "num_replies_ok", json_object_new_int64(stats->num_replies_ok));
  if(stats->num_replies_error > 0) json_object_object_add(my_object, "num_replies_error", json_object_new_int64(stats->num_replies_error));

  for(int i=1; i < CONST_EPP_MAX_CMD_NUM; i++) {
    if(stats->breakdown[i] > 0) {
      char buf[32];

      snprintf(buf, sizeof(buf), "num_cmd_%u", i);
      json_object_object_add(my_object, buf, json_object_new_int64(stats->breakdown[i]));
    }
  }

  return(my_object);
}

/* ******************************************* */

json_object* EppStats::getJSONObject() {
  json_object *my_object = json_object_new_object();

  json_object_object_add(my_object, "sent", getStatsJSONObject(&sent));
  json_object_object_add(my_object, "rcvd", getStatsJSONObject(&rcvd));
  
  return(my_object);
}

/* ******************************************* */

void EppStats::incNumEPPQueries(u_int16_t query_type, struct epp_stats *what) {
  what->num_queries++; 

  if((query_type < 1) || (query_type > CONST_EPP_MAX_CMD_NUM))
    query_type = epp_cmd_unknown_command;

  what->breakdown[query_type] += 1;
};

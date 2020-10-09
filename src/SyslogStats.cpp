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

SyslogStats::SyslogStats() {
  resetStats();
}

/* *************************************** */

void SyslogStats::resetStats() {
  num_total_events = 0;
  num_malformed = 0;
  num_dispatched = 0;
  num_unhandled = 0;
  num_alerts = 0;
  num_host_correlations = 0;
  num_collected_flows = 0;
}

/* *************************************** */

void SyslogStats::incStats(u_int32_t _num_total_events, u_int32_t _num_malformed,
    u_int32_t _num_dispatched, u_int32_t _num_unhandled, u_int32_t _num_alerts, 
    u_int32_t _num_host_correlations, u_int32_t _num_collected_flows) {
  num_total_events += _num_total_events;
  num_malformed += _num_malformed;
  num_dispatched += _num_dispatched;
  num_unhandled += _num_unhandled;
  num_alerts += _num_alerts;
  num_host_correlations += _num_host_correlations;
  num_collected_flows += _num_collected_flows;
};  

/* *************************************** */

char* SyslogStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void SyslogStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  if(json_object_object_get_ex(o, "tot_events", &obj))
    num_total_events = json_object_get_int64(obj); 
  else
    num_total_events = 0;

  if(json_object_object_get_ex(o, "malformed", &obj))
    num_malformed = json_object_get_int64(obj); 
  else
    num_malformed = 0;

  if(json_object_object_get_ex(o, "dispatched", &obj))
    num_dispatched = json_object_get_int64(obj); 
  else
    num_dispatched = 0;

  if(json_object_object_get_ex(o, "unhandled", &obj)) 
    num_unhandled = json_object_get_int64(obj);
  else
    num_unhandled = 0;

  if(json_object_object_get_ex(o, "alerts", &obj)) 
    num_alerts = json_object_get_int64(obj); 
  else
    num_alerts = 0;

  if(json_object_object_get_ex(o, "host_correlations", &obj))
    num_host_correlations = json_object_get_int64(obj); 
  else 
    num_host_correlations = 0;

  if(json_object_object_get_ex(o, "flows", &obj))
    num_collected_flows = json_object_get_int64(obj);
  else
    num_collected_flows = 0;
}

/* ******************************************* */

json_object* SyslogStats::getJSONObject() {
  json_object *my_object;

  my_object = json_object_new_object();

  if(num_total_events > 0)
    json_object_object_add(my_object, "tot_events", json_object_new_int64(num_total_events));

  if(num_malformed > 0)
    json_object_object_add(my_object, "malformed", json_object_new_int64(num_malformed));

  if(num_dispatched > 0)
    json_object_object_add(my_object, "dispatched", json_object_new_int64(num_dispatched));

  if(num_unhandled > 0)
    json_object_object_add(my_object, "unhandled", json_object_new_int64(num_unhandled));

  if(num_alerts > 0)
    json_object_object_add(my_object, "alerts", json_object_new_int64(num_alerts));

  if(num_host_correlations > 0)
    json_object_object_add(my_object, "host_correlations", json_object_new_int64(num_host_correlations));

  if(num_collected_flows > 0)
    json_object_object_add(my_object, "flows", json_object_new_int64(num_collected_flows));
  
  return(my_object);
}

/* ******************************************* */

void SyslogStats::lua(lua_State* vm) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "tot_events", num_total_events);
  lua_push_uint64_table_entry(vm, "malformed", num_malformed);
  lua_push_uint64_table_entry(vm, "dispatched", num_dispatched);
  lua_push_uint64_table_entry(vm, "unhandled", num_unhandled);
  lua_push_uint64_table_entry(vm, "alerts", num_alerts);
  lua_push_uint64_table_entry(vm, "host_correlations", num_host_correlations);
  lua_push_uint64_table_entry(vm, "flows", num_collected_flows);
  
  lua_pushstring(vm, "syslog");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ******************************************* */

void SyslogStats::sum(SyslogStats *s) const {
  s->num_total_events += num_total_events;
  s->num_malformed += num_malformed;
  s->num_dispatched += num_dispatched;
  s->num_unhandled += num_unhandled;
  s->num_alerts += num_alerts;
  s->num_host_correlations += num_host_correlations;
  s->num_collected_flows += num_collected_flows;
}


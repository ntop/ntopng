/*
 *
 * (C) 2019 - ntop.org
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

/* ****************************************** */

/* Relase the expired alerts and push them into the Lua table */
void AlertableEntity::getExpiredAlerts(ScriptPeriodicity p, lua_State* vm, time_t now) {
  std::map<std::string, Alert>::iterator it;
  int seconds = Utils::periodicityToSeconds(p);

  for(it = triggered_alerts[(u_int)p].begin(); it != triggered_alerts[(u_int)p].end(); ++it) {
    if((now - it->second.last_update) > seconds)
      lua_push_uint64_table_entry(vm, it->first.c_str(), it->second.last_update);
  }
}

/* ****************************************** */

void AlertableEntity::luaAlert(lua_State* vm, Alert *alert, ScriptPeriodicity p) {
  /* NOTE: must conform to the AlertsManager format */
  lua_push_int32_table_entry(vm, "alert_type", alert->alert_type);
  lua_push_str_table_entry(vm, "alert_subtype", alert->alert_subtype.c_str());
  lua_push_int32_table_entry(vm, "alert_severity", alert->alert_severity);
  lua_push_int32_table_entry(vm, "alert_entity", entity_type);
  lua_push_str_table_entry(vm, "alert_entity_val", entity_val.c_str());
  lua_push_uint64_table_entry(vm, "alert_tstamp", alert->alert_tstamp_start);
  lua_push_uint64_table_entry(vm, "alert_tstamp_end", alert->alert_tstamp_start);
  lua_push_int32_table_entry(vm, "alert_granularity", Utils::periodicityToSeconds((ScriptPeriodicity)p));
  lua_push_str_table_entry(vm, "alert_json", alert->alert_json.c_str());
}

/* ****************************************** */

/* Return true if the element was inserted, false if already present */
bool AlertableEntity::triggerAlert(std::string key, ScriptPeriodicity p, time_t now,
    AlertLevel alert_severity, AlertType alert_type,
    const char *alert_subtype,
    const char *alert_json) {
  std::map<std::string, Alert>::iterator it = triggered_alerts[(u_int)p].find(key);

  if(entity_val.empty()) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "setEntityValue() not called or empty entity_val");
    return(false);
  }

  if(it != triggered_alerts[(u_int)p].end()) {
    it->second.last_update = now;
    return(false); /* already present */
  } else {
    Alert alert;

    alert.alert_tstamp_start = alert.last_update = now;
    alert.alert_severity = alert_severity;
    alert.alert_type = alert_type;
    alert.alert_subtype = alert_subtype;
    alert.alert_json = alert_json;

    triggered_alerts[(u_int)p][key] = alert;
    return(true); /* inserted */
  }
}

/* ****************************************** */

bool AlertableEntity::releaseAlert(lua_State* vm, std::string key, ScriptPeriodicity p) {
  std::map<std::string, Alert>::iterator it = triggered_alerts[(u_int)p].find(key);

  if(it == triggered_alerts[(u_int)p].end()) {
    lua_pushnil(vm);
    return(false);
  }

  /* Found, push the alert */
  lua_newtable(vm);
  luaAlert(vm, &it->second, p);

  triggered_alerts[(u_int)p].erase(it);
  return(true);
}

/* ****************************************** */

u_int AlertableEntity::getNumTriggeredAlerts() {
  int i;
  u_int num_alerts = 0;

  for(i = 0; i<MAX_NUM_PERIODIC_SCRIPTS; i++)
    num_alerts += getNumTriggeredAlerts((ScriptPeriodicity) i);

  return(num_alerts);
}

/* ****************************************** */

void AlertableEntity::countAlerts(grouped_alerts_counters *counters) {
  int p;
  std::map<std::string, Alert>::iterator it;

  for(p = 0; p<MAX_NUM_PERIODIC_SCRIPTS; p++) {
    for(it = triggered_alerts[p].begin(); it != triggered_alerts[p].end(); ++it) {
      Alert *alert = &it->second;

      counters->severities[alert->alert_severity]++;
      counters->types[alert->alert_type]++;
    }
  }
}

/* ****************************************** */

void AlertableEntity::getAlerts(lua_State* vm, AlertType type_filter, AlertLevel severity_filter, u_int *idx) {
  int p;
  std::map<std::string, Alert>::iterator it;

  for(p = 0; p<MAX_NUM_PERIODIC_SCRIPTS; p++) {
    for(it = triggered_alerts[p].begin(); it != triggered_alerts[p].end(); ++it) {
      Alert *alert = &it->second;

      if(((type_filter == alert_none) || (type_filter == alert->alert_type))
          && ((severity_filter == alert_level_none) || (severity_filter == alert->alert_severity))) {
        lua_newtable(vm);
        luaAlert(vm, alert, (ScriptPeriodicity)p);

        lua_pushinteger(vm, ++(*idx));
        lua_insert(vm, -2);
        lua_settable(vm, -3);
      }
    }
  }
}

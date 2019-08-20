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

AlertableEntity::AlertableEntity(NetworkInterface *iface, AlertEntity entity) {
  alert_iface = iface;
  entity_type = entity, num_triggered_alerts = 0, force_shadow_refresh = false;

  for(u_int i=0; i<MAX_NUM_PERIODIC_SCRIPTS; i++)
    rx_triggered_alerts[i] = NULL, shadow_rx_triggered_alerts[i] = NULL;

  suppressed_alerts = false;
  refreshSuppressedAlert();
}

/* ****************************************** */

AlertableEntity::~AlertableEntity() {
  for(u_int i=0; i<MAX_NUM_PERIODIC_SCRIPTS; i++) {
    if(rx_triggered_alerts[i])
      delete rx_triggered_alerts[i];

    if(shadow_rx_triggered_alerts[i])
      delete shadow_rx_triggered_alerts[i];
  }
}

/* ****************************************** */

/* Relase the expired alerts and push them into the Lua table */
void AlertableEntity::getExpiredAlerts(ScriptPeriodicity p, lua_State* vm, time_t now) {
  std::map<std::string, Alert>::iterator it;
  int seconds = Utils::periodicityToSeconds(p);
  u_int idx = 0;

  for(it = triggered_alerts[(u_int)p].begin(); it != triggered_alerts[(u_int)p].end();) {
    Alert *alert = &it->second;

    if((now - alert->last_update) > seconds) {
      if(alert->is_disabled) {
        /* The alert is disabled, remove it now.
         * NOTE: do not increment again iterator after this assignment. */
        triggered_alerts[(u_int)p].erase(it++), force_shadow_refresh = true;	
      } else {
        lua_newtable(vm);

        luaAlert(vm, alert, p);

        lua_pushinteger(vm, ++idx);
        lua_insert(vm, -2);
        lua_settable(vm, -3);
        ++it;
      }
    } else
      ++it;
  }
}

/* ****************************************** */

void AlertableEntity::luaAlert(lua_State* vm, Alert *alert, ScriptPeriodicity p) {
  /* NOTE: must conform to the AlertsManager format */
  lua_push_int32_table_entry(vm,  "alert_type", alert->alert_type);
  lua_push_str_table_entry(vm,    "alert_subtype", alert->alert_subtype.c_str());
  lua_push_int32_table_entry(vm,  "alert_severity", alert->alert_severity);
  lua_push_int32_table_entry(vm,  "alert_entity", entity_type);
  lua_push_str_table_entry(vm,    "alert_entity_val", entity_val.c_str());
  lua_push_uint64_table_entry(vm, "alert_tstamp", alert->alert_tstamp_start);
  lua_push_uint64_table_entry(vm, "alert_tstamp_end", alert->last_update);
  lua_push_int32_table_entry(vm,  "alert_granularity", Utils::periodicityToSeconds((ScriptPeriodicity)p));
  lua_push_str_table_entry(vm,    "alert_json", alert->alert_json.c_str());
}

/* ****************************************** */

/* Return true if the element was inserted, false if already present */
bool AlertableEntity::triggerAlert(lua_State* vm, std::string key,
				   ScriptPeriodicity p, time_t now,
				   AlertLevel alert_severity, AlertType alert_type,
				   const char *alert_subtype,
				   const char *alert_json,
				   bool alert_disabled) {
  bool rv = false;
  std::map<std::string, Alert>::iterator it = triggered_alerts[(u_int)p].find(key);
  
  if(entity_val.empty()) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "setEntityValue() not called or empty entity_val");
  } else if(it != triggered_alerts[(u_int)p].end()) {
    it->second.last_update = now;

    if(it->second.is_disabled && !alert_disabled) {
      /* Alert was not accounted but now enabled, so increase count */
      it->second.is_disabled = false;
      alert_iface->incNumAlertsEngaged(p);
      force_shadow_refresh = true;
    } else if(!it->second.is_disabled && alert_disabled) {
      /* Alert was accounted but is now disabled, so decresase count */
      it->second.is_disabled = true;
      alert_iface->decNumAlertsEngaged(p);
      force_shadow_refresh = true;
    }

    /* already present */
  } else {
    Alert alert;

    alert.alert_tstamp_start = alert.last_update = now;
    alert.alert_severity = alert_severity;
    alert.alert_type = alert_type;
    alert.alert_subtype = alert_subtype;
    alert.alert_json = alert_json;

    /* NOTE: keeping track of disabled alerts state is necessary to
     * correctly increment disabled alerts counters */
    alert.is_disabled = alert_disabled;

    if(!alert_disabled)
      alert_iface->incNumAlertsEngaged(p);

    triggered_alerts[(u_int)p][key] = alert;
    force_shadow_refresh = true, rv = true; /* inserted */

    lua_newtable(vm);
    luaAlert(vm, &alert, p);
  }

  if(!rv)
    lua_pushnil(vm);
  
  return(rv);
}

/* ****************************************** */

bool AlertableEntity::releaseAlert(lua_State* vm,
				   std::string key, ScriptPeriodicity p, time_t now) {
  std::map<std::string, Alert>::iterator it = triggered_alerts[(u_int)p].find(key);
  bool rv = false;
  
  if(it == triggered_alerts[(u_int)p].end()) {
    lua_pushnil(vm);
    return(rv);
  }

  if(!it->second.is_disabled) {
    /* Set the release time */
    it->second.last_update = now;

    /* Found, push the alert */
    lua_newtable(vm);
    luaAlert(vm, &it->second, p);

    alert_iface->decNumAlertsEngaged(p);
    rv = true;
  } else
    lua_pushnil(vm);

  triggered_alerts[(u_int)p].erase(it);
  force_shadow_refresh = true;
  
  return(rv);
}

/* ****************************************** */

void AlertableEntity::updateNumTriggeredAlerts() {
  int i;
  u_int num_alerts = 0;

  for(i = 0; i<MAX_NUM_PERIODIC_SCRIPTS; i++)
    num_alerts += getNumTriggeredAlerts((ScriptPeriodicity) i);

  num_triggered_alerts = num_alerts;
}

/* ****************************************** */

void AlertableEntity::countAlerts(grouped_alerts_counters *counters) {
  int p;
  std::map<std::string, Alert>::iterator it;

  for(p = 0; p<MAX_NUM_PERIODIC_SCRIPTS; p++) {
    if(rx_triggered_alerts[p] != NULL) {
      for(it = rx_triggered_alerts[p]->begin(); it != rx_triggered_alerts[p]->end(); ++it) {
	Alert *alert = &it->second;
	
	if(!alert->is_disabled) {
	  counters->severities[alert->alert_severity]++;
	  counters->types[alert->alert_type]++;
	}
      }
    }
  }
}

/* ****************************************** */

void AlertableEntity::getPeriodicityAlerts(lua_State* vm, ScriptPeriodicity p,
				AlertType type_filter, AlertLevel severity_filter, u_int *idx) {
  std::map<std::string, Alert>::iterator it;
  std::map<std::string, Alert> *rx_copy = rx_triggered_alerts[p];

  /* NOTE
     Use rx_copy and not rx_triggered_alerts[p] as it might change overtime
     due to syncReadonlyTriggeredAlerts()
  */

  if(rx_copy != NULL) {
    for(it = rx_copy->begin(); it != rx_copy->end(); ++it) {
      Alert *alert = &it->second;

      if(!alert->is_disabled) {
        if(((type_filter == alert_none)
            || (type_filter == alert->alert_type))
           && ((severity_filter == alert_level_none)
         || (severity_filter == alert->alert_severity))) {
          lua_newtable(vm);
          luaAlert(vm, alert, (ScriptPeriodicity)p);

          lua_pushinteger(vm, ++(*idx));
          lua_insert(vm, -2);
          lua_settable(vm, -3);
        }
      }
    }
  }
}

/* ****************************************** */

/*
  IMPORTANT
   as this method is called by the GUI/periodic scripts while triggered_alerts[] might be manipulated
   by periodic scrits, it uses rx_triggered_alerts instead of triggered_alerts
*/
void AlertableEntity::getAlerts(lua_State* vm, ScriptPeriodicity periodicity_filter,
				AlertType type_filter, AlertLevel severity_filter, u_int *idx) {
  if(periodicity_filter != no_periodicity) {
    /* Get alerts about a specific periodicity */
    getPeriodicityAlerts(vm, periodicity_filter, type_filter, severity_filter, idx);
  } else {
    int p;

    for(p = 0; p<MAX_NUM_PERIODIC_SCRIPTS; p++)
      getPeriodicityAlerts(vm, (ScriptPeriodicity)p, type_filter, severity_filter, idx);
  }
}

/* ****************************************** */

/*
  IMPORTANT
   as this method is called by the GUI while triggered_alerts[] might be manipulated
   by periodic scrits, it uses rx_triggered_alerts instead of triggered_alerts
*/
u_int AlertableEntity::getNumTriggeredAlerts(ScriptPeriodicity p) {
  std::map<std::string, Alert>::iterator it;
  u_int ctr = 0;
  std::map<std::string, Alert> *rx_copy = rx_triggered_alerts[p];
  
  /* NOTE
     Use rx_copy and not rx_triggered_alerts[p] as it might change overtime
     due to syncReadonlyTriggeredAlerts()
  */
  if(rx_copy != NULL) {    
    for(it = rx_copy->begin(); it != rx_copy->end(); ++it) {
      if(!it->second.is_disabled)
	ctr++;
    }
  }
  
  return(ctr);
}

/* ****************************************** */

void AlertableEntity::syncReadonlyTriggeredAlerts() {
  for(u_int i=0; i<MAX_NUM_PERIODIC_SCRIPTS; i++) {
    std::map<std::string, Alert> *cpy;
    std::map<std::string, Alert>::iterator it;
    
    try {
      cpy = new std::map<std::string, Alert>();
      
      if(shadow_rx_triggered_alerts[i] != NULL)
	delete shadow_rx_triggered_alerts[i];
      
      shadow_rx_triggered_alerts[i] = rx_triggered_alerts[i];
      
      for(it = triggered_alerts[i].begin(); it != triggered_alerts[i].end(); ++it)
	(*cpy)[it->first] = Alert(it->second);
      
      rx_triggered_alerts[i] = cpy;
    } catch(std::bad_alloc& ba) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Memory allocation error");  
    }
  }

  updateNumTriggeredAlerts();
}

/* ****************************************** */

void AlertableEntity::refreshSuppressedAlert() {
  if(!entity_val.empty()) {
    char rsp[64], rkey[128];

    snprintf(rkey, sizeof(rkey), CONST_SUPPRESSED_ALERT_PREFS, alert_iface->get_id());

    if(ntop->getRedis()->hashGet(rkey, entity_val.c_str(), rsp, sizeof(rsp)) == 0)
      suppressed_alerts = ((strcmp(rsp, "false") == 0) ? 1 : 0);
    else
      suppressed_alerts = false;
  }
}

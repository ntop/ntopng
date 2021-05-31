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

OtherAlertableEntity::OtherAlertableEntity(NetworkInterface *iface, AlertEntity entity) : AlertableEntity(iface, entity) {
}

/* ****************************************** */

OtherAlertableEntity::~OtherAlertableEntity() {
}

/* ****************************************** */

void OtherAlertableEntity::luaAlert(lua_State* vm, const Alert *alert, ScriptPeriodicity p) const {
  lua_push_int32_table_entry(vm,  "alert_id", alert->alert_id);
  lua_push_str_table_entry(vm,    "subtype", alert->subtype.c_str());
  lua_push_int32_table_entry(vm,  "entity_id", getEntityType());
  lua_push_str_table_entry(vm,    "entity_val", getEntityValue().c_str());
  lua_push_int32_table_entry(vm,  "score", alert->score);
  lua_push_int32_table_entry(vm,  "severity", Utils::mapScoreToSeverity(alert->score));
  lua_push_str_table_entry(vm,    "name", getEntityValue().c_str());
  lua_push_uint64_table_entry(vm, "tstamp", alert->tstamp);
  lua_push_uint64_table_entry(vm, "tstamp_end", time(NULL));
  lua_push_int32_table_entry(vm,  "granularity", Utils::periodicityToSeconds((ScriptPeriodicity)p));
  lua_push_str_table_entry(vm,    "json", alert->json.c_str());
}

/* ****************************************** */

/* Return true if the element was inserted, false if already present.
   NOTE: given a ScriptPeriodicity p, only one thread at time can perform
   a triggerAlert. */
bool OtherAlertableEntity::triggerAlert(lua_State* vm, std::string key,
				   ScriptPeriodicity p, time_t now,
				   u_int32_t score, AlertType alert_id,
				   const char *subtype,
				   const char *json) {
  bool rv = false;
  std::map<std::string, Alert>::iterator it;

  if(getEntityValue().empty()) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "setEntityValue() not called or empty entity_val");
  } else {
    engaged_alerts_lock.wrlock(__FILE__, __LINE__);

    it = engaged_alerts[(u_int)p].find(key);

    if(it == engaged_alerts[(u_int)p].end()) {
      Alert alert;

      alert.tstamp = alert.last_update = now;
      alert.score = score;
      alert.alert_id = alert_id;
      alert.subtype = subtype;
      alert.json = json;

      incNumAlertsEngaged();

      engaged_alerts[(u_int)p][key] = alert;

      lua_newtable(vm);
      luaAlert(vm, &alert, p);

      rv = true; /* Actually inserted */
    }

    engaged_alerts_lock.unlock(__FILE__, __LINE__);
  }

  if(!rv)
    lua_pushnil(vm);
  
  return(rv);
}

/* ****************************************** */

bool OtherAlertableEntity::releaseAlert(lua_State* vm,
				   std::string key, ScriptPeriodicity p, time_t now) {
  std::map<std::string, Alert>::iterator it;
  bool rv = false;

  if(!engaged_alerts[(u_int)p].empty()) {
    engaged_alerts_lock.wrlock(__FILE__, __LINE__);

    it = engaged_alerts[(u_int)p].find(key);

    if(it != engaged_alerts[(u_int)p].end()) {
      /* Set the release time */
      it->second.last_update = now;

      /* Found, push the alert */
      lua_newtable(vm);
      luaAlert(vm, &it->second, p);

      /*
	Decrease instance and instance number of engaged alerts
       */
      decNumAlertsEngaged();

      engaged_alerts[(u_int)p].erase(it);

      rv = true; /* Actually released */
    }

    engaged_alerts_lock.unlock(__FILE__, __LINE__);
  }

  if(!rv)
    lua_pushnil(vm);

  return(rv);
}

/* ****************************************** */

void OtherAlertableEntity::countAlerts(grouped_alerts_counters *counters) {
  std::map<std::string, Alert>::const_iterator it;

  for(int i = 0; i < MAX_NUM_PERIODIC_SCRIPTS; i++) {
    ScriptPeriodicity p = (ScriptPeriodicity)i;

    if(!engaged_alerts[p].empty()) {
      engaged_alerts_lock.rdlock(__FILE__, __LINE__);

      for(it = engaged_alerts[p].begin(); it != engaged_alerts[p].end(); ++it) {
	const Alert *alert = &it->second;
	
	counters->severities[std::make_pair(getEntityType(), Utils::mapScoreToSeverity(alert->score))]++;
	counters->types[std::make_pair(getEntityType(), alert->alert_id)]++;
      }

      engaged_alerts_lock.unlock(__FILE__, __LINE__);
    }
  }
}

/* ****************************************** */

void OtherAlertableEntity::getPeriodicityAlerts(lua_State* vm, ScriptPeriodicity p,
						AlertType type_filter, AlertLevel severity_filter,
						AlertRole role_filter, u_int *idx) {
  std::map<std::string, Alert>::const_iterator it;

  if(!engaged_alerts[p].empty()) {
    engaged_alerts_lock.rdlock(__FILE__, __LINE__);

    for(it = engaged_alerts[p].begin(); it != engaged_alerts[p].end(); ++it) {
      const Alert *alert = &it->second;

      if(((type_filter == alert_none)
	  || (type_filter == alert->alert_id))
	 && ((severity_filter == alert_level_none)
	     || (severity_filter == Utils::mapScoreToSeverity(alert->score)))) {
	lua_newtable(vm);
	luaAlert(vm, alert, (ScriptPeriodicity)p);

	lua_pushinteger(vm, ++(*idx));
	lua_insert(vm, -2);
	lua_settable(vm, -3);
      }
    }

    engaged_alerts_lock.unlock(__FILE__, __LINE__);
  }
}

/* ****************************************** */

void OtherAlertableEntity::getAlerts(lua_State* vm, ScriptPeriodicity periodicity_filter,
				     AlertType type_filter, AlertLevel severity_filter, AlertRole role_filter,
				     u_int *idx) {
  if(periodicity_filter != no_periodicity) {
    /* Get alerts about a specific periodicity */
    getPeriodicityAlerts(vm, periodicity_filter, type_filter, severity_filter, role_filter, idx);
  } else {
    int p;

    for(p = 0; p < MAX_NUM_PERIODIC_SCRIPTS; p++)
      getPeriodicityAlerts(vm, (ScriptPeriodicity)p, type_filter, severity_filter, role_filter, idx);
  }
}

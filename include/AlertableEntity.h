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

#ifndef _ALERTABLE_ENTITY_H_
#define _ALERTABLE_ENTITY_H_

#include "ntop_includes.h"

class AlertableEntity {
 protected:
  AlertEntity entity_type;
  std::string entity_val;

  std::map<std::string, std::string> alert_cache[MAX_NUM_PERIODIC_SCRIPTS];
  std::map<std::string, Alert> triggered_alerts[MAX_NUM_PERIODIC_SCRIPTS];

 public:
  AlertableEntity(AlertEntity entity) {
    entity_type = entity;
  }

  virtual ~AlertableEntity() {};

  inline std::string getAlertCachedValue(std::string key, ScriptPeriodicity p) {
    std::map<std::string, std::string>::iterator it = alert_cache[(u_int)p].find(key);

    return((it != alert_cache[(u_int)p].end()) ? it->second : std::string(""));
  }

  inline void setAlertCacheValue(std::string key, std::string value, ScriptPeriodicity p) {
    alert_cache[(u_int)p][key] = value;
  }

  u_int getNumTriggeredAlerts(ScriptPeriodicity p);
  inline void setEntityValue(const char *ent_val) { entity_val = ent_val; }

  bool triggerAlert(std::string key, NetworkInterface *iface, ScriptPeriodicity p, time_t now,
    AlertLevel alert_severity, AlertType alert_type,
    const char *alert_subtype,
    const char *alert_json,
    bool alert_disabled);
  bool releaseAlert(lua_State* vm, NetworkInterface *iface, std::string key, ScriptPeriodicity p, time_t now);

  void luaAlert(lua_State* vm, Alert *alert, ScriptPeriodicity p);
  void getExpiredAlerts(ScriptPeriodicity p, lua_State* vm, time_t now);
  u_int getNumTriggeredAlerts();
  void countAlerts(grouped_alerts_counters *counters);
  void getAlerts(lua_State* vm, AlertType type_filter, AlertLevel severity_filter, u_int *idx);
};

#endif

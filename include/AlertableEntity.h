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

class NetworkInterface;

class AlertableEntity {
 private:
  void incNumAlertsEngaged();
  void decNumAlertsEngaged();

 protected:
  AlertEntity entity_type;
  std::string entity_val;
  NetworkInterface *alert_iface;

  /*
    Creating multiple maps guarantees that periodic scripts at different granularities
    do not interfere each other and thus that they can run concurrently without locking.

    However while alert_cache is accessed only by the alert engine and thus it is "thread-safe"
    as concurrent scripts (i.e. at different granularities) cannot call it, engaged_alerts
    needs to be protected as
    - it can be called by the Lua GUI
    - it can be called by the alert engine
  */
  std::map<std::string, std::string> alert_cache[MAX_NUM_PERIODIC_SCRIPTS];
  std::map<std::string, Alert> engaged_alerts[MAX_NUM_PERIODIC_SCRIPTS];
  RwLock *locks[MAX_NUM_PERIODIC_SCRIPTS];
  std::atomic<u_int> num_engaged_alerts;

  RwLock* getLock(ScriptPeriodicity p);
  void rdLock(ScriptPeriodicity p, const char *filename, int line);
  void wrLock(ScriptPeriodicity p, const char *filename, int line);
  void unlock(ScriptPeriodicity p, const char *filename, int line);
  void getPeriodicityAlerts(lua_State* vm, ScriptPeriodicity p,
				AlertType type_filter, AlertLevel severity_filter, u_int *idx);

public:
  AlertableEntity(NetworkInterface *alert_iface, AlertEntity entity);
  virtual ~AlertableEntity();

  /*
    getAlertCachedValue and setAlertCacheValue as thread safe as they are invoked only by
    periodic scripts and are not accessed by the GUI lua methods
  */
  inline std::string getAlertCachedValue(std::string key, ScriptPeriodicity p) {
    std::map<std::string, std::string>::iterator it = alert_cache[(u_int)p].find(key);

    return((it != alert_cache[(u_int)p].end()) ? it->second : std::string(""));
  }

  inline void setAlertCacheValue(std::string key, std::string value,
				 ScriptPeriodicity p) {
    alert_cache[(u_int)p][key] = value;
  }

  u_int getNumEngagedAlerts(ScriptPeriodicity p) const;
  inline u_int getNumEngagedAlerts() const { return(num_engaged_alerts); }
  
  inline void setEntityValue(const char *ent_val) { entity_val = ent_val; }
  inline std::string getEntityValue()       const { return(entity_val); }
  inline AlertEntity getEntityType()        const { return(entity_type); }

  bool triggerAlert(lua_State* vm, std::string key,
		    ScriptPeriodicity p, time_t now,
		    AlertLevel alert_severity, AlertType alert_type,
		    const char *alert_subtype,
		    const char *alert_json);
  bool releaseAlert(lua_State* vm, std::string key,
		    ScriptPeriodicity p, time_t now);

  void luaAlert(lua_State* vm, const Alert *alert, ScriptPeriodicity p) const;
  void countAlerts(grouped_alerts_counters *counters);
  void getAlerts(lua_State* vm, ScriptPeriodicity p, AlertType type_filter,
		 AlertLevel severity_filter, u_int *idx);
  bool matchesAllowedNetworks(AddressTree *allowed_nets);
};

#endif

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

#ifndef _ALERTS_MANAGER_H_
#define _ALERTS_MANAGER_H_

#include "ntop_includes.h"

class Flow;

class AlertsManager : protected StoreManager {
 private:
  char queue_name[CONST_MAX_LEN_REDIS_KEY];
  bool store_opened, store_initialized;
  u_int32_t num_alerts_engaged;
  bool alerts_stored;
  int openStore();
  
  /* methods used for alerts that have a timespan */
  bool isAlertEngaged(AlertEngine alert_engine, AlertEntity alert_entity, const char *alert_entity_value, const char *engaged_alert_id,
		  AlertType *alert_type, AlertLevel *alert_severity, char **alert_json, char **alert_source, char **alert_target, time_t *alert_tstamp);
  void markForMakeRoom(bool on_flows);
  int engageAlert(AlertEngine alert_engine, AlertEntity alert_entity, const char *alert_entity_value,
		  const char *engaged_alert_id,
		  AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
		  const char *alert_origin, const char *alert_target, bool ignore_disabled);
  int releaseAlert(AlertEngine alert_engine, AlertEntity alert_entity, const char *alert_entity_value,
		   const char *engaged_alert_id, bool ignore_disabled);
  int storeAlert(AlertEntity alert_entity, const char *alert_entity_value,
		 AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
		 const char *alert_origin, const char *alert_target,
		 bool check_maximum, time_t when);

  bool notifyAlert(AlertEntity alert_entity, const char *alert_entity_value,
		   const char *engaged_alert_id,
		   AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
		   const char *alert_origin, const char *alert_target,
		   bool engage, time_t now, Flow *flow);
  
  int engageReleaseHostAlert(const char *host_ip, u_int16_t host_vlan,
			     AlertEngine alert_engine,
			     const char *engaged_alert_id,
			     AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
			     const char *alert_origin, const char *alert_target,
			     bool engage, bool ignore_disabled=false);

  /* methods used to retrieve alerts and counters with possible sql clause to filter */
  int queryAlertsRaw(lua_State *vm, const char *selection, const char *clauses, const char *table_name, bool ignore_disabled);
  int getNumAlerts(bool engaged, const char *sql_where_clause, bool ignore_disabled=false);
  int getNumFlowAlerts(const char *sql_where_clause);

  /* private methods to check the goodness of submitted inputs and possible return the input database string */
  bool isValidHost(Host *h, char *host_string, size_t host_string_len);
  bool isValidFlow(Flow *f);
  bool isValidNetwork(const char *cidr);
  bool isValidInterface(NetworkInterface *n);

  inline void refreshCachedNumAlerts() {
    num_alerts_engaged = getNumAlerts(true,  static_cast<char*>(NULL), true);
    alerts_stored = (getNumAlerts(false,  static_cast<char*>(NULL), true) + getNumFlowAlerts()) > 0;
  }

 public:
  AlertsManager(int interface_id, const char *db_filename);
  ~AlertsManager() {};

  /*
    ========== HOST alerts API =========
   */
  inline int engageHostAlert(const char *host_ip, u_int16_t host_vlan,
			     AlertEngine alert_engine,
			     const char *engaged_alert_id,
			     AlertType alert_type, AlertLevel alert_severity,
			     const char *alert_json, bool ignore_disabled=false) {
    return engageReleaseHostAlert(host_ip, host_vlan, alert_engine, engaged_alert_id,
				  alert_type, alert_severity, alert_json, NULL, NULL, true /* engage */, ignore_disabled);
  };
  inline int releaseHostAlert(const char *host_ip, u_int16_t host_vlan,
			      AlertEngine alert_engine,
			      const char *engaged_alert_id,
			      AlertType alert_type, AlertLevel alert_severity,
			      const char *alert_json, bool ignore_disabled=false) {
    return engageReleaseHostAlert(host_ip, host_vlan, alert_engine, engaged_alert_id,
				  alert_type, alert_severity, alert_json, NULL, NULL,
				  false /* release */, ignore_disabled);
  };
  
  int storeHostAlert(Host *h, AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
		     Host *alert_origin, Host *alert_target);
  inline int storeHostAlert(Host *h, AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return storeHostAlert(h, alert_type, alert_severity, alert_json, NULL, NULL);
  }
  
  int getNumHostAlerts(Host *h, bool engaged);

  /*
    ========== FLOW alerts API =========
   */
  int storeFlowAlert(Flow *f);
  inline int getNumFlowAlerts() {
    return getNumFlowAlerts(NULL);
  };

  /*
    ========== Generic alerts API =========
   */
  inline int engageGenericAlert(AlertEntity alert_entity, const char *alert_entity_value,
				AlertEngine alert_engine,
				const char *engaged_alert_id,
				AlertType alert_type, AlertLevel alert_severity,
				const char *alert_json, bool ignore_disabled=false) {
    return engageAlert(alert_engine, alert_entity, alert_entity_value, engaged_alert_id,
		       alert_type, alert_severity, alert_json, NULL, NULL, ignore_disabled);
  };

  inline int releaseGenericAlert(AlertEntity alert_entity, const char *alert_entity_value,
				 AlertEngine alert_engine,
				 const char *engaged_alert_id,
				 AlertType alert_type, AlertLevel alert_severity,
				 const char *alert_json, bool ignore_disabled=false) {
    return releaseAlert(alert_engine, alert_entity, alert_entity_value, engaged_alert_id, ignore_disabled);
  };

  inline int storeGenericAlert(AlertEntity alert_entity, const char *alert_entity_value,
			       AlertType alert_type, AlertLevel alert_severity,
			       const char *alert_json, time_t when) {
    return storeAlert(alert_entity, alert_entity_value, alert_type,
		      alert_severity, alert_json, NULL, NULL, true, when);
  }

  /*
    ========== counters API ======
  */
  int getCachedNumAlerts(lua_State *vm);
  inline int getNumAlerts(bool engaged) {
    /* must force the cast or the compiler will go crazy with ambiguous calls */
    return getNumAlerts(engaged, "alert_severity=2" /* errors only */);
  }

  /*
    ========== raw API ======
  */
  inline int queryAlertsRaw(lua_State *vm, bool engaged, const char *selection, const char *clauses, bool ignore_disabled) {
    return queryAlertsRaw(vm, selection, clauses,
			  engaged ? ALERTS_MANAGER_ENGAGED_TABLE_NAME : ALERTS_MANAGER_TABLE_NAME, ignore_disabled);
  };
  inline int queryFlowAlertsRaw(lua_State *vm, const char *selection, const char *clauses, bool ignore_disabled) {
    return queryAlertsRaw(vm, selection, clauses, ALERTS_MANAGER_FLOWS_TABLE_NAME, ignore_disabled);
  };
};

#endif /* _ALERTS_MANAGER_H_ */

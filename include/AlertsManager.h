/*
 *
 * (C) 2013-17 - ntop.org
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
 friend class AlertsWriter;

 private:
  AlertsWriter *writer;
  char queue_name[CONST_MAX_LEN_REDIS_KEY];
  bool store_opened, store_initialized;
  u_int32_t num_alerts_engaged;
  bool alerts_stored;
  bool make_room;
  int openStore();
  
  /* methods used for alerts that have a timespan */
  bool isAlertEngaged(AlertEntity alert_entity, const char *alert_entity_value, const char *engaged_alert_id, char **output_json);
  void markForMakeRoom(AlertEntity alert_entity, const char *alert_entity_value, const char *table_name);
  int deleteOldestAlert(AlertEntity alert_entity, const char *alert_entity_value, const char *table_name, u_int32_t max_num_rows);
  int engageAlert(AlertEntity alert_entity, const char *alert_entity_value,
		  const char *engaged_alert_id, time_t when,
		  AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
		  const char *alert_origin, const char *alert_target);
  int releaseAlert(AlertEntity alert_entity, const char *alert_entity_value,
		   const char *engaged_alert_id, char **alert_json);
  int storeAlert(time_t when, AlertEntity alert_entity, const char *alert_entity_value,
		 AlertType alert_type, AlertLevel alert_severity,
		 const char *alert_origin, const char *alert_target,
		 const char *alert_json, bool check_maximum);

  const char* getAlertEntity(AlertEntity alert_entity);
  const char* getAlertLevel(AlertLevel alert_severity);
  const char* getAlertType(AlertType alert_type);
  SlackNotificationChoice getSlackNotificationChoice(char* choice);
  
  void notifySlack (AlertEntity alert_entity, const char *alert_entity_value,
		    const char *engaged_alert_id,
		    AlertType alert_type, AlertLevel alert_severity,
		    const char *alert_json,
		    const char *alert_origin, const char *alert_target);
  void notifyAlert(AlertEntity alert_entity, const char *alert_entity_value,
		   const char *engaged_alert_id,
		   AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
		   const char *alert_origin, const char *alert_target);
  
  int engageReleaseHostAlert(Host *h,
			     const char *engaged_alert_id,
			     time_t when,
			     AlertType alert_type, AlertLevel alert_severity,
			     Host *alert_origin, Host *alert_target,
			     bool engage, const char *alert_json, char **output_json);

  int engageReleaseNetworkAlert(const char *cidr,
				const char *engaged_alert_id,
				time_t when,
				AlertType alert_type, AlertLevel alert_severity,
				bool engage, const char *alert_json, char **output_json);

  int engageReleaseInterfaceAlert(NetworkInterface *n,
				  const char *engaged_alert_id,
				  time_t when,
				  AlertType alert_type, AlertLevel alert_severity,
				  bool engage, const char *alert_json, char **output_json);

  /* methods used to retrieve alerts and counters with possible sql clause to filter */
  int queryAlertsRaw(lua_State *vm, const char *selection, const char *clauses, const char *table_name);

  int getAlerts(lua_State* vm, AddressTree *allowed_hosts,
		u_int32_t start_offset, u_int32_t end_offset,
		bool engaged, const char *sql_where_clause);
  int getFlowAlerts(lua_State* vm, AddressTree *allowed_hosts,
		    u_int32_t start_offset, u_int32_t end_offset,
		    const char *sql_where_clause);
  int getNumAlerts(bool engaged, const char *sql_where_clause);
  int getNumFlowAlerts(const char *sql_where_clause);

  /* private methods to check the goodness of submitted inputs and possible return the input database string */
  bool isValidHost(Host *h, char *host_string, size_t host_string_len);
  bool isValidFlow(Flow *f);
  bool isValidNetwork(const char *cidr);
  bool isValidInterface(NetworkInterface *n);

 protected:

  /* Writer API */

  /*
    ========== HOST alerts API =========
   */
  inline int engageHostAlert(Host *h,
			     const char *engaged_alert_id,
			     time_t when,
			     AlertType alert_type, AlertLevel alert_severity,
			     Host *alert_origin, Host *alert_target,
			     const char *alert_json) {
    return engageReleaseHostAlert(h, engaged_alert_id, when, alert_type, alert_severity, alert_origin, alert_target, true /* engage */, alert_json, 0);
  };
  inline int releaseHostAlert(Host *h,
			      const char *engaged_alert_id,
			      AlertType alert_type,
			      char **output_json) {
    return engageReleaseHostAlert(h, engaged_alert_id, 0, alert_type, (AlertLevel)0, NULL, NULL, false /* release */, NULL, output_json);
  };
  int storeHostAlert(Host *h, time_t when, AlertType alert_type, AlertLevel alert_severity,
		     Host *alert_origin, Host *alert_target, const char *alert_json);

  /*
    ========== FLOW alerts API =========
   */
  int storeFlowAlert(Flow *f, time_t when, AlertType alert_type, AlertLevel alert_severity, const char *alert_json);

  /*
    ========== NETWORK alerts API ======
   */
  inline int engageNetworkAlert(const char *cidr,
			     const char *engaged_alert_id,
			     time_t when,
			     AlertType alert_type, AlertLevel alert_severity,
			     const char *alert_json) {
    return engageReleaseNetworkAlert(cidr, engaged_alert_id, when, alert_type, alert_severity, true /* engage */, alert_json, 0);
  };
  inline int releaseNetworkAlert(const char *cidr,
			      const char *engaged_alert_id,
			      AlertType alert_type,
			      char **output_json) {
    return engageReleaseNetworkAlert(cidr, engaged_alert_id, 0, alert_type, (AlertLevel)0, false /* release */, NULL, output_json);
  };
  inline int storeNetworkAlert(const char *cidr, time_t when, AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return storeAlert(when, alert_entity_network, cidr, alert_type, alert_severity, NULL, NULL, alert_json, true);
  }

  /*
    ========== INTERFACE alerts API ======
   */
  inline int engageInterfaceAlert(NetworkInterface *n,
				  const char *engaged_alert_id,
				  time_t when,
				  AlertType alert_type, AlertLevel alert_severity,
				  const char *alert_json) {
    return engageReleaseInterfaceAlert(n, engaged_alert_id, when, alert_type, alert_severity, true /* engage */, alert_json, 0);
  };
  inline int releaseInterfaceAlert(NetworkInterface *n,
				   const char *engaged_alert_id,
				   AlertType alert_type,
				   char **output_json) {
    return engageReleaseInterfaceAlert(n, engaged_alert_id, 0, alert_type, (AlertLevel)0, false /* release */, NULL, output_json);
  };
  inline int storeInterfaceAlert(NetworkInterface *n, time_t when, AlertType alert_type, AlertLevel alert_severity, const char *alert_json, bool check_max) {
    /* TODO interface alert entity value */
    return storeAlert(when, alert_entity_interface, "TODO", alert_type, alert_severity, NULL, NULL, alert_json, check_max);
  }

 public:
  AlertsManager(int interface_id, const char *db_filename);
  ~AlertsManager();

  inline AlertsWriter* getAlertsWriter() { return writer; }
  inline NetworkInterface* getNetworkInterface() { return StoreManager::getNetworkInterface(); }

#ifdef NOTUSED
  int storeAlert(AlertType alert_type, AlertLevel alert_severity, const char *alert_json);
  int storeAlert(lua_State *L, int index);
#endif

  inline bool makeRoomRequested() { return(make_room); };
  void makeRoom(AlertEntity alert_entity, const char *alert_entity_value, const char *table_name);

  /*
    ========== HOST alerts API =========
   */

  int getHostAlerts(Host *h,
		    lua_State* vm, AddressTree *allowed_hosts,
		    u_int32_t start_offset, u_int32_t end_offset,
		    bool engaged);
  
  int getHostAlerts(const char *host_ip, u_int16_t vlan_id,
		    lua_State* vm, AddressTree *allowed_hosts,
		    u_int32_t start_offset, u_int32_t end_offset,
		    bool engaged);

  int getNumHostAlerts(const char *host_ip, u_int16_t vlan_id, bool engaged);
  int getNumHostAlerts(Host *h, bool engaged);
  int getNumHostFlowAlerts(const char *host_ip, u_int16_t vlan_id);
  int getNumHostFlowAlerts(Host *h);

  /*
    ========== FLOW alerts API =========
   */
  inline int getFlowAlerts(lua_State* vm, AddressTree *allowed_hosts,
			   u_int32_t start_offset, u_int32_t end_offset) {
    return getFlowAlerts(vm, allowed_hosts, start_offset, end_offset, NULL);
  };
  inline int getNumFlowAlerts() {
    return getNumFlowAlerts(NULL);
  };
  
  inline int getAlerts(lua_State* vm, AddressTree *allowed_hosts,
		       u_int32_t start_offset, u_int32_t end_offset,
		       bool engaged){
    return getAlerts(vm, allowed_hosts, start_offset, end_offset, engaged, NULL /* all alerts by default */);
  }

  /*
    ========== counters API ======
  */
  int getCachedNumAlerts(lua_State *vm);
  inline void refreshCachedNumAlerts() {
    num_alerts_engaged = getNumAlerts(true,  static_cast<char*>(NULL));
    alerts_stored = (getNumAlerts(false,  static_cast<char*>(NULL)) + getNumFlowAlerts()) > 0;
  }
  inline int getNumAlerts(bool engaged) {
    /* must force the cast or the compiler will go crazy with ambiguous calls */
    return getNumAlerts(engaged, "alert_severity=2" /* errors only */);
  }
  int getNumAlerts(bool engaged, u_int64_t start_time);
  int getNumAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value);
  int getNumAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value, AlertType alert_type);

  /*
    ========== delete API ======
   */
  int deleteAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value, AlertType alert_type, time_t older_than);

  /*
    ========== raw API ======
  */
  inline int queryAlertsRaw(lua_State *vm, bool engaged, const char *selection, const char *clauses) {
    return queryAlertsRaw(vm, selection, clauses,
			  engaged ? ALERTS_MANAGER_ENGAGED_TABLE_NAME : ALERTS_MANAGER_TABLE_NAME);
  };
  inline int queryFlowAlertsRaw(lua_State *vm, const char *selection, const char *clauses) {
    return queryAlertsRaw(vm, selection, clauses, ALERTS_MANAGER_FLOWS_TABLE_NAME);
  };

  /* Following are the legacy methods that were formally global to the whole ntopng */
#ifdef NOTUSED
  /**
   * @brief Queue an alert in redis
   *
   * @param level The alert level
   * @param s     The alert status (alert on/off)
   * @param t     The alert type
   * @param msg   The alert message
   */
  int queueAlert(AlertLevel level, AlertStatus s, AlertType t, char *msg);
  /**
   * @brief Returns up to the specified number of alerts, and removes them from redis. The first parameter must be long enough to hold the returned results
   * @param allowed_hosts The list of hosts allowed to be returned by this function
   * @param alerts The returned alerts
   * @param start_idx The initial queue index from which extract messages. Zero (0) is the first (i.e. most recent) queue element.
   * @param num The maximum number of alerts to return.
   * @return The number of elements read.
   *
   */
  int getQueuedAlerts(lua_State* vm, AddressTree *allowed_hosts, int start_offset, int end_offset);
  /**
   * @brief Returns the number of queued alerts in redis generated by ntopng
   *
   */
  int getNumQueuedAlerts();
  /**
   * @brief Delete the alert identified by the specified index.
   * @param idx The queued alert index to delete. Zero (0) is the first (i.e. most recent) queue element.
   * @return The number of elements read.
   *
   */
  int deleteQueuedAlert(u_int32_t idx_to_delete);
  /**
   * @brief Flush all queued alerts
   *
   */
  int flushAllQueuedAlerts();
#endif
};

#endif /* _ALERTS_MANAGER_H_ */

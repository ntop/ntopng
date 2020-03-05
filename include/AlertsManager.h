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

#ifndef _ALERTS_MANAGER_H_
#define _ALERTS_MANAGER_H_

#include "ntop_includes.h"

class Flow;

class AlertsManager : public StoreManager {
 private:
  char queue_name[CONST_MAX_LEN_REDIS_KEY];
  bool store_opened, store_initialized;
  int openStore();

  /* methods used for alerts that have a timespan */
  void markForMakeRoom(bool on_flows);

  /* methods used to retrieve alerts and counters with possible sql clause to filter */
  int queryAlertsRaw(lua_State *vm, const char *selection, const char *filter,
            const char *allowed_nets_filter, const char *group_by,
            const char *table_name, bool ignore_disabled);

  /* private methods to check the goodness of submitted inputs and possible return the input database string */
  bool isValidHost(Host *h, char *host_string, size_t host_string_len);
  bool isValidFlow(Flow *f);
  bool isValidNetwork(const char *cidr);
  bool isValidInterface(NetworkInterface *n);

  /* Methods to handle caching for alerts (to avoid putting high pressure on sqlite) */
  static char *getAlertCacheKey(int ifid, AlertType alert_type, const char *subtype, int granularity,
				AlertEntity alert_entity, const char *alert_entity_value, AlertLevel alert_severity);
  static bool isCached(int ifid, AlertType alert_type, const char *subtype, int granularity,
		       AlertEntity alert_entity, const char *alert_entity_value, AlertLevel alert_severity,
		       u_int64_t *cached_rowid);
  static void cache(int ifid, AlertType alert_type, const char *subtype, int granularity,
		    AlertEntity alert_entity, const char *alert_entity_value, AlertLevel alert_severity,
		    u_int64_t rowid);

 public:
  AlertsManager(int interface_id, const char *db_filename);
  ~AlertsManager();

  int storeAlert(time_t tstart, time_t tend, int granularity, 
      AlertType alert_type, const char *subtype,
      AlertLevel alert_severity, AlertEntity alert_entity, 
      const char *alert_entity_value,
      const char *alert_json, bool *new_alert, u_int64_t *rowid,
      bool ignore_disabled = false, bool check_maximum = true);

  int storeFlowAlert(lua_State *L, int index, u_int64_t *rowid);

  static void buildSqliteAllowedNetworksFilters(lua_State *vm);
  static int parseEntityValueIp(const char *alert_entity_value, struct in6_addr *ip_raw);

  bool hasAlerts();

  inline int queryAlertsRaw(lua_State *vm, const char *selection, const char *filter,
            const char *allowed_nets_filter, const char *group_by, bool ignore_disabled) {
    return queryAlertsRaw(vm, selection, filter, allowed_nets_filter, group_by, ALERTS_MANAGER_TABLE_NAME, ignore_disabled);
  };
  inline int queryFlowAlertsRaw(lua_State *vm, const char *selection, const char *filter,
            const char *allowed_nets_filter, const char *group_by, bool ignore_disabled) {
    return queryAlertsRaw(vm, selection, filter, allowed_nets_filter, group_by, ALERTS_MANAGER_FLOWS_TABLE_NAME, ignore_disabled);
  };
};

#endif /* _ALERTS_MANAGER_H_ */

/*
 *
 * (C) 2021 - ntop.org
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
  AlertEntity entity_type;
  std::string entity_val;
  NetworkInterface *alert_iface;
  u_int num_engaged_alerts;

 protected:  
  RwLock engaged_alerts_lock; /* Lock to handle concurrent access from the GUI */

  void incNumAlertsEngaged();
  void decNumAlertsEngaged();

 public:
  AlertableEntity(NetworkInterface *alert_iface, AlertEntity entity);
  virtual ~AlertableEntity();

  inline NetworkInterface *getAlertInterface() { return alert_iface; }

  inline void setEntityValue(const char *ent_val) { entity_val = ent_val; }
  inline std::string getEntityValue() const { return(entity_val); }

  inline AlertEntity getEntityType()  const { return(entity_type); }

  inline u_int getNumEngagedAlerts()  const { return(num_engaged_alerts); }

  virtual void countAlerts(grouped_alerts_counters *counters) {};
  virtual void getAlerts(lua_State* vm, ScriptPeriodicity p, 
			 AlertType type_filter, AlertLevel severity_filter, AlertRole role_filter,
			 u_int *idx) {};

  bool matchesAllowedNetworks(AddressTree *allowed_nets);

  static int parseEntityValueIp(const char *alert_entity_value, struct in6_addr *ip_raw);
};

#endif

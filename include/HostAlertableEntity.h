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

#ifndef _HOST_ALERTABLE_ENTITY_H_
#define _HOST_ALERTABLE_ENTITY_H_

#include "ntop_includes.h"

class NetworkInterface;
class HostAlert;

class HostAlertableEntity : public AlertableEntity {
 private:
  Bitmap16 engaged_alerts_map;
  
  HostAlert *engaged_alerts[NUM_DEFINED_HOST_CALLBACKS]; /* List of engaged alerts for each callback */

  RwLock engaged_alerts_lock; /* Lock to handle concurrent access from the GUI */

  void clearEngagedAlerts();
  void luaAlert(lua_State* vm, HostAlert *alert);

 public:
  HostAlertableEntity(NetworkInterface *alert_iface, AlertEntity entity);
  virtual ~HostAlertableEntity();

  bool addEngagedAlert(HostAlert *a);
  bool removeEngagedAlert(HostAlert *a);
  inline bool isEngagedAlert(HostAlertType alert_id) { return engaged_alerts_map.isSetBit(alert_id.id); }
  bool hasCallbackEngagedAlert(HostCallbackID callback_id);
  inline HostAlert *getCallbackEngagedAlert(HostCallbackID t) { return engaged_alerts[t]; }
  HostAlert *findEngagedAlert(HostAlertType alert_id, HostCallbackID callback_id);

  void countAlerts(grouped_alerts_counters *counters);
  void getAlerts(lua_State* vm, ScriptPeriodicity p,
    AlertType type_filter, AlertLevel severity_filter, u_int *idx);
};

#endif

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

#include "ntop_includes.h"

/* ****************************************** */

AlertableEntity::AlertableEntity(NetworkInterface *iface, AlertEntity entity) {
  alert_iface = iface;
  entity_type = entity;
  num_engaged_alerts = 0;
}

/* ****************************************** */

AlertableEntity::~AlertableEntity() {
  /*
    Decrease (possibly) engaged alerts to keep counters consisten.
  */
  while(getNumEngagedAlerts() > 0)
    decNumAlertsEngaged();
}

/* ****************************************** */

/* Increase interface and instance number of engaged alerts */
void AlertableEntity::incNumAlertsEngaged() {
  alert_iface->incNumAlertsEngaged();
  num_engaged_alerts++;
};

/* ****************************************** */

/* Decrease interface and instance number of engaged alerts */
void AlertableEntity::decNumAlertsEngaged() {
  alert_iface->decNumAlertsEngaged();
  num_engaged_alerts--;
};

/* ****************************************** */

bool AlertableEntity::matchesAllowedNetworks(AddressTree *allowed_nets) {
  struct in6_addr ip_raw;
  IpAddress addr;
  int netbits;
  std::string entity_value = getEntityValue();
  const char *alert_entity_value = entity_value.c_str();

  if(!allowed_nets)
    return(true);

  AlertsManager::parseEntityValueIp(alert_entity_value, &ip_raw);

  if(strchr(alert_entity_value, ':')) {
    // IPv6
    addr.set(&ip_raw);
    netbits = 128;
  } else {
    // IPv4
    addr.set(*((u_int32_t*)&ip_raw.s6_addr[12]));
    netbits = 32;
  }

  return(allowed_nets->match(&addr, netbits));
}

/* ****************************************** */

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
    Cannot destroy an alertable entity with currently engaged alerts
  */
  if(getNumEngagedAlerts() > 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error. Destroying an alertable with engaged alerts.");
}

/* ****************************************** */

/* Increase interface and instance number of engaged alerts */
void AlertableEntity::incNumAlertsEngaged(AlertLevel alert_severity) {
  alert_iface->incNumAlertsEngaged(getEntityType(), alert_severity);
  num_engaged_alerts++;
};

/* ****************************************** */

/* Decrease interface and instance number of engaged alerts */
void AlertableEntity::decNumAlertsEngaged(AlertLevel alert_severity) {
  alert_iface->decNumAlertsEngaged(getEntityType(), alert_severity);
  num_engaged_alerts--;
};

/* ****************************************** */

int AlertableEntity::parseEntityValueIp(const char *alert_entity_value, struct in6_addr *ip_raw) {
  char tmp_entity[128];
  char *sep;
  int rv;

  memset(ip_raw, 0, sizeof(*ip_raw));

  if(!alert_entity_value)
    return(-1);

  snprintf(tmp_entity, sizeof(tmp_entity)-1, "%s", alert_entity_value);

  /* Ignore VLAN */
  if((sep = strchr(tmp_entity, '@')))
    *sep = '\0';

  /* Ignore subnet. Save the networks as a single IP. */
  if((sep = strchr(tmp_entity, '/')))
    *sep = '\0';

  /* Try to parse as IP address */
  if(strchr(tmp_entity, ':'))
    rv = inet_pton(AF_INET6, tmp_entity, ip_raw);
  else
    rv = inet_pton(AF_INET, tmp_entity, ((char*)ip_raw)+12);

  return(rv);
}

/* ****************************************** */

bool AlertableEntity::matchesAllowedNetworks(AddressTree *allowed_nets) {
  struct in6_addr ip_raw;
  IpAddress addr;
  int netbits;
  std::string entity_value = getEntityValue();
  const char *alert_entity_value = entity_value.c_str();

  if(!allowed_nets)
    return(true);

  parseEntityValueIp(alert_entity_value, &ip_raw);

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

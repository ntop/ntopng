/*
 *
 * (C) 2013-21 - ntop.org
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
#include "host_checks_includes.h"

/* ***************************************************** */

ServerContacts::ServerContacts() : HostCheck(ntopng_edition_community, false /* All interfaces */, false /* Don't exclude for nEdge */, false /* NOT only for nEdge */) {
  contacts_threshold = (u_int64_t)5;
};

/* ***************************************************** */

void ServerContacts::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  u_int32_t contacted_servers = 0;

  if((contacted_servers = getContactedServers(h)) >= contacts_threshold) {
    if (!alert) alert = allocAlert(this, h, CLIENT_FULL_RISK_PERCENTAGE, contacted_servers, contacts_threshold);
    if (alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool ServerContacts::loadConfiguration(json_object *config) {
  json_object *json_threshold;
  
  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", json_object_to_json_string(config));

  if(json_object_object_get_ex(config, "threshold", &json_threshold))
    contacts_threshold = json_object_get_int64(json_threshold);

  return(true);
}

/* ***************************************************** */


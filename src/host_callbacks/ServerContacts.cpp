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
#include "host_callbacks_includes.h"

/* ***************************************************** */

ServerContacts::ServerContacts() : HostCallback(ntopng_edition_community) {
};

/* ***************************************************** */

void ServerContacts::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  u_int32_t contacted_servers = 0;

  if((contacted_servers = getContactedServers(h)) >= contacts_threshold) {
    /* New alert */
    if (!alert)
       alert = allocAlert(this, h, contacted_servers, contacts_threshold);

    if (alert) {
      /* Set alert info */
      alert->setSeverity(alert_level_error);
      alert->setCliScore(50);

      /* Trigger if new */
      if (!engaged_alert) h->triggerAlert(alert);
    }
  }
}

/* ***************************************************** */

bool ServerContacts::loadConfiguration(json_object *config) {
  HostCallback::loadConfiguration(config); /* Parse parameters in common */

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", json_object_to_json_string(config));

  return(true);
}

/* ***************************************************** */


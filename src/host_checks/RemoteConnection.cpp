/*
 *
 * (C) 2013-23 - ntop.org
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

RemoteConnection::RemoteConnection()
    : HostCheck(ntopng_edition_community, false /* All interfaces */,
                false /* Don't exclude for nEdge */,
                false /* NOT only for nEdge */){};

/* ***************************************************** */

void RemoteConnection::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  u_int8_t num_remote_access = 0;

  num_remote_access = h->getRemoteAccess();

  if (num_remote_access > 0) {
    if (!alert)
      alert =
          allocAlert(this, h, CLIENT_FAIR_RISK_PERCENTAGE, num_remote_access);
    if (alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool RemoteConnection::loadConfiguration(json_object *config) {
  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  return (true);
}

/* ***************************************************** */

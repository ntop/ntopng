/*
 *
 * (C) 2013-24 - ntop.org
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
//#define DEBUG_GATEWAY 1

/* ***************************************************** */

UnexpectedGateway::UnexpectedGateway()
    : HostCheck(ntopng_edition_community, false /* All interfaces */,
                false /* Don't exclude for nEdge */,
                false /* NOT only for nEdge */) {};

/* ***************************************************** */

void UnexpectedGateway::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  IpAddress *p = h->get_ip();

  if (h->isLocalHost() && p && !p->isBroadcastAddress()) {
#ifdef DEBUG_GATEWAY
    char buf[64];
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL,
        "Checking Unexpected Gateway [IP %s] [Is Gateway: %s] [Is Configured "
        "Gateway: "
        "%s]",
        p->print(buf, sizeof(buf)), p->isGateway() ? "Yes" : "No",
        ntop->getPrefs()->isGateway(p, h->get_vlan_id()) ? "Yes" : "No");
#endif
    if (p->isGateway() && !ntop->getPrefs()->isGateway(p, h->get_vlan_id())) {
      if (!alert)
        alert = allocAlert(this, h, CLIENT_FULL_RISK_PERCENTAGE);
      if (alert) h->triggerAlert(alert);
    }
  }
}

/* ***************************************************** */

bool UnexpectedGateway::loadConfiguration(json_object *config) {
  HostCheck::loadConfiguration(config); /* Parse parameters in common */
  return (true);
}

/* ***************************************************** */
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
#include "flow_checks_includes.h"
// #define DEBUG_DNS_SERVER

/* ***************************************************** */

bool UnexpectedDNSServer::isAllowedHost(Flow* f) {
  if (ntop->getPrefs()->isEmptyServersConfiguration(HOST_SERVICE_DNS))
    return (true);
  else {
    IpAddress* ip = (IpAddress*)getServerIP(f);

    if (ip != NULL) {
#ifdef DEBUG_DNS_SERVER
      char buf[64];

      ntop->getTrace()->traceEvent(
          TRACE_NORMAL,
          "Checking Unexpected DNS Server [IP %s] [Is DNS: %s] [Is Configured "
          "DNS: %s]",
          ip->print(buf, sizeof(buf)),
          ip->providesService(HOST_SERVICE_DNS) ? "Yes" : "No",
          ntop->getPrefs()->isServer(HOST_SERVICE_DNS, ip, f->get_vlan_id()) ? "Yes" : "No");
#endif

      return (ntop->getPrefs()->isServer(HOST_SERVICE_DNS, ip, f->get_vlan_id()) ||
              ntop->getPrefs()->isServer(HOST_SERVICE_DNS, ip, 0 /* Check for the VLAN 0 (no vlan) too */));
    } else
      return (true);
  }
}

/* ***************************************************** */

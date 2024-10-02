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
//#define DEBUG_GATEWAY 1

/* ***************************************************** */

bool UnexpectedGateway::isAllowedHost(Flow *f) {
  IpAddress *p = (IpAddress *)getServerIP(f);

  if (p == NULL || p->isBroadcastAddress()) return true;

#ifdef DEBUG_GATEWAY
  char buf[64];
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Checking Unexpected Gateway [IP %s] [Is Gateway: %s] [Is Configured Gateway: "
      "%s]",
      p->print(buf, sizeof(buf)), p->isGateway() ? "Yes" : "No",
      ntop->getPrefs()->isGateway(p, f->get_vlan_id()) ? "Yes" : "No");
#endif
  if (p->isGateway() && !ntop->getPrefs()->isGateway(p, f->get_vlan_id())) {
    return false;
  }

  return (true);
}

/* ***************************************************** */
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
#define DEBUG_SYN_FLOOD 0

/* ***************************************************** */

void SYNFlood::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  u_int16_t hits = 0;

#ifdef DEBUG_SYN_FLOOD
  char buf[64];
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Checking SYN Flood [IP: %s] [Attacker Hits: %d] [Victim Hits: %d]",
      h->get_string_key(buf, sizeof(buf)), h->syn_flood_attacker_hits(),
      h->syn_flood_victim_hits());
#endif

  if ((hits = h->syn_flood_attacker_hits()) > threshold)
    triggerFlowHitsAlert(h, engaged_alert, true, hits, threshold,
                         CLIENT_FULL_RISK_PERCENTAGE);
  else if ((hits = h->syn_flood_victim_hits()) > threshold)
    triggerFlowHitsAlert(h, engaged_alert, false, hits, threshold,
                         CLIENT_NO_RISK_PERCENTAGE);
}

/* ***************************************************** */

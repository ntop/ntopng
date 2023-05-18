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

void FlowFlood::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  u_int16_t flows = 0;

  if ((flows = h->flow_flood_attacker_hits()) > threshold)
    triggerFlowHitsAlert(h, engaged_alert, true, flows, threshold,
                         CLIENT_FULL_RISK_PERCENTAGE);
  else if ((flows = h->flow_flood_victim_hits()) > threshold)
    triggerFlowHitsAlert(h, engaged_alert, false, flows, threshold,
                         CLIENT_NO_RISK_PERCENTAGE);

  /* Reset counters once done */
  h->reset_flow_flood_hits();
}

/* ***************************************************** */

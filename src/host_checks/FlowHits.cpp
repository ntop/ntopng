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

FlowHits::FlowHits() : HostCheck(ntopng_edition_community, false /* All interfaces */, false /* Don't exclude for nEdge */, false /* NOT only for nEdge */) {
  threshold = (u_int64_t)-1;
};

/* ***************************************************** */

void FlowHits::triggerFlowHitsAlert(Host *h, HostAlert *engaged, bool attacker,
    u_int16_t hits, u_int64_t threshold, risk_percentage cli_pctg) {
  FlowHitsAlert *alert = static_cast<FlowHitsAlert*>(engaged);

  if (!alert) {
    alert = allocAlert(h, cli_pctg, hits, threshold, attacker);
    if(attacker)
      alert->setAttacker();
    else
      alert->setVictim();
  } else {
    /*
      Perform an update only if:
      - The existing alert is attacker an the function is called as attacker
      - The existing alert is victim and the function is called as victim 
    */
    if(alert->isAttacker() == attacker) { 
      /* Update engaged alert */
      alert->setHits(hits);
    }
  }

  if(alert)
    h->triggerAlert(alert);
}

/* ***************************************************** */

bool FlowHits::loadConfiguration(json_object *config) {
  json_object *json_threshold;

  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  if(json_object_object_get_ex(config, "threshold", &json_threshold))
    threshold = json_object_get_int64(json_threshold);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", json_object_to_json_string(config));

  return(true);
}

/* ***************************************************** */


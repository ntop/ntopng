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

PktThreshold::PktThreshold() : HostCheck(ntopng_edition_community, false /* All interfaces */, false /* Don't exclude for nEdge */, false /* NOT only for nEdge */) {
  pkt_threshold = (u_int64_t)-1;
};

/* ***************************************************** */

void PktThreshold::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  u_int64_t  pkt_sent= h->getNumPktsSent();
  u_int64_t  pkt_rcvd= h->getNumPktsRcvd();
  u_int64_t pkt_total = pkt_sent + pkt_rcvd;
  u_int64_t delta;
  u_int64_t value = 0;
  if((delta = h->cb_status_delta_pkt_counter (pkt_total)) > pkt_threshold)  value = delta;
  if(value) {
    if(!alert) alert = allocAlert(this, h, CLIENT_FULL_RISK_PERCENTAGE, value/60, pkt_threshold/60);
    if (alert) h->triggerAlert(alert);
    }
  
  }

/* ***************************************************** */

bool PktThreshold::loadConfiguration(json_object *config) {
  json_object *json_threshold;

  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  if(json_object_object_get_ex(config, "threshold", &json_threshold))
    pkt_threshold = json_object_get_int64(json_threshold)*60;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s %u", json_object_to_json_string(config), dns_bytes_threshold);

  return(true);
}

/* ***************************************************** */


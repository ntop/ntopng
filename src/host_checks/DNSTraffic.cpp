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

DNSTraffic::DNSTraffic() : HostCheck(ntopng_edition_community, false /* All interfaces */, false /* Don't exclude for nEdge */, false /* NOT only for nEdge */) {
  dns_bytes_threshold = (u_int64_t)-1;
};

/* ***************************************************** */

void DNSTraffic::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  u_int64_t delta;

  if((delta = h->cb_status_delta_dns_bytes(h->get_ndpi_stats()->getProtoBytes(NDPI_PROTOCOL_DNS))) > dns_bytes_threshold) {
    if (!alert) alert = allocAlert(this, h, CLIENT_FULL_RISK_PERCENTAGE, delta, dns_bytes_threshold);
    if (alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool DNSTraffic::loadConfiguration(json_object *config) {
  json_object *json_threshold;

  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  if(json_object_object_get_ex(config, "threshold", &json_threshold))
    dns_bytes_threshold = json_object_get_int64(json_threshold);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s %u", json_object_to_json_string(config), dns_bytes_threshold);

  return(true);
}

/* ***************************************************** */


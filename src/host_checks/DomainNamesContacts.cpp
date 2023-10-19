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

DomainNamesContacts::DomainNamesContacts() : ServerContacts() {
  domain_names_threshold = (u_int16_t)-1;
};

/* ***************************************************** */

void DomainNamesContacts::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  u_int32_t num_domain_names = 0;

  if ((num_domain_names = h->getDomainNamesCardinality()) >
      domain_names_threshold) {
    if (!alert)
      alert = allocAlert(this, h, CLIENT_FAIR_RISK_PERCENTAGE, num_domain_names,
                         domain_names_threshold);
    if (alert) h->triggerAlert(alert);
  }

  h->resetDomainNamesCardinality();
}

bool DomainNamesContacts::loadConfiguration(json_object *config) {
  json_object *json_threshold;

  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  if (json_object_object_get_ex(config, "threshold", &json_threshold))
    domain_names_threshold = (u_int16_t)json_object_get_int64(json_threshold);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s %u",
  // json_object_to_json_string(config), ntp_bytes_threshold);

  return (true);
}

/* ***************************************************** */

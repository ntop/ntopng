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

FlowAnomaly::FlowAnomaly() : HostCheck(ntopng_edition_community) {
};

/* ***************************************************** */

void FlowAnomaly::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  bool cli_anomaly = false, srv_anomaly = false;
  const u_int8_t score_value = SCORE_LEVEL_WARNING;
  u_int32_t value = 0, lower_bound = 0, upper_bound = 0;
  risk_percentage cli_pctg = CLIENT_FULL_RISK_PERCENTAGE;

  if((cli_anomaly = h->has_flows_anomaly(true))) {
    cli_pctg = CLIENT_FULL_RISK_PERCENTAGE; /* All risk to the client */
    value = h->value_flows_anomaly(true);
    lower_bound = h->lower_bound_flows_anomaly(true);
    upper_bound = h->upper_bound_flows_anomaly(true);
  } else if((srv_anomaly = h->has_flows_anomaly(false))) {
    cli_pctg = CLIENT_NO_RISK_PERCENTAGE;   /* All risk to the server */
    value = h->value_flows_anomaly(false);
    lower_bound = h->lower_bound_flows_anomaly(false);
    upper_bound = h->upper_bound_flows_anomaly(false);
  }
  
  if(cli_anomaly || srv_anomaly) {
    if (!alert) alert = allocAlert(this, h, cli_pctg, value, lower_bound, upper_bound);
    if (alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool FlowAnomaly::loadConfiguration(json_object *config) {
  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  return(true);
}

/* ***************************************************** */


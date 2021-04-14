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
#include "host_callbacks_includes.h"

/* ***************************************************** */

FlowAnomaly::FlowAnomaly() : HostCallback(ntopng_edition_community) {
};

/* ***************************************************** */

void FlowAnomaly::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  u_int8_t cli_score = 0, srv_score = 0;
  const u_int8_t score_value = 50;
  u_int32_t value = 0, lower_bound = 0, upper_bound = 0;  

  if(h->has_flows_anomaly(true)) {
    cli_score = score_value;
    value = h->value_score_anomaly(true);
    lower_bound = h->lower_bound_score_anomaly(true);
    upper_bound = h->upper_bound_score_anomaly(true);
  }

  if(h->has_flows_anomaly(false)) {
    srv_score = score_value;
    value = h->value_score_anomaly(false);
    lower_bound = h->lower_bound_score_anomaly(false);
    upper_bound = h->upper_bound_score_anomaly(false);
  }
  
  if(cli_score || srv_score) {
    bool is_client_alert = (cli_score > 0) ? true : false;
    
    if (!alert) alert = allocAlert(this, h, alert_level_warning, cli_score, srv_score, is_client_alert, value, lower_bound, upper_bound);
    if (alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool FlowAnomaly::loadConfiguration(json_object *config) {
  HostCallback::loadConfiguration(config); /* Parse parameters in common */

  return(true);
}

/* ***************************************************** */


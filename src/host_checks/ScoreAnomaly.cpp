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

ScoreAnomaly::ScoreAnomaly() : HostCheck(ntopng_edition_community) {
};

/* ***************************************************** */

void ScoreAnomaly::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  HostAlert *alert = engaged_alert;
  bool cli_anomaly = false, srv_anomaly = false;
  risk_percentage cli_pctg = CLIENT_FULL_RISK_PERCENTAGE;
  u_int32_t value = 0, lower_bound = 0, upper_bound = 0;
  
  if((cli_anomaly = h->has_score_anomaly(true))) {
    cli_pctg = CLIENT_FULL_RISK_PERCENTAGE;
    value = h->value_score_anomaly(true);
    lower_bound = h->lower_bound_score_anomaly(true);
    upper_bound = h->upper_bound_score_anomaly(true);
  } else if((srv_anomaly = h->has_score_anomaly(false))) {
    cli_pctg = CLIENT_NO_RISK_PERCENTAGE;
    value = h->value_score_anomaly(false);
    lower_bound = h->lower_bound_score_anomaly(false);
    upper_bound = h->upper_bound_score_anomaly(false);
  }

  if(cli_anomaly || srv_anomaly) {
    if (!alert) alert = allocAlert(this, h, cli_pctg, value, lower_bound, upper_bound);
    if (alert) h->triggerAlert(alert);
  }
}

/* ***************************************************** */

bool ScoreAnomaly::loadConfiguration(json_object *config) {
  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  return(true);
}

/* ***************************************************** */


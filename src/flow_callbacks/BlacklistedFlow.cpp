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
#include "flow_callbacks_includes.h"

void BlacklistedFlow::protocolDetected(Flow *f) {
  if(f->isBlacklistedFlow()) {
    u_int16_t c_score, s_score;
    
    if(f->isBlacklistedServer())
      c_score = SCORE_MAX_SCRIPT_VALUE, s_score = 5;
    else
      c_score = 5, s_score = 10;

    f->triggerAlertAsync(BlacklistedFlowAlert::getClassType(), getSeverity(), c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *BlacklistedFlow::buildAlert(Flow *f) {
  return new BlacklistedFlowAlert(this, f);
}

/* ***************************************************** */

/* Sample configuration:
  "script_conf": {
    "severity": {
      "syslog_severity": 3,
      "severity_id": 5,
      "i18n_title": "alerts_dashboard.error",
      "emoji": "❗",
      "icon": "fas fa-exclamation-triangle text-danger",
      "label": "badge-danger"
    }
  }
*/

bool BlacklistedFlow::loadConfiguration(json_object *config) {
  FlowCallback::loadConfiguration(config); /* Parse parameters in common */

  /* Parse additional parameters */
  
  return(true);
}

/* ***************************************************** */


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
#include "flow_checks_includes.h"

/* ***************************************************** */

void BlacklistedServerContact::protocolDetected(Flow *f) {
  if (f->isBlacklistedServer() && f->isLocalToRemote()) {
    FlowAlertType alert_type = BlacklistedServerContactAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;
    
    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);
    
    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert* BlacklistedServerContact::buildAlert(Flow *f) {
  bool is_server_bl = f->isBlacklistedServer();
  bool is_client_bl = f->isBlacklistedClient();
  BlacklistedServerContactAlert *alert = new (std::nothrow) BlacklistedServerContactAlert(this, f);

  if (alert) {
    /*
      When a BLACKLISTED client contacts a normal host, the client is assumed to
      be the attacker and the server the victim When a normal client contacts a
      BLACKLISTED server, both peers are considered to be attackers When both
      peers are blacklisted, both are considered attackers
    */
    if (is_client_bl && !is_server_bl)
      alert->setCliAttacker(), alert->setSrvVictim();
    else if (!is_client_bl && is_server_bl)
      alert->setCliAttacker(), alert->setSrvAttacker();
    else if (is_client_bl && is_server_bl)
      alert->setCliAttacker(), alert->setSrvAttacker();
  }

  return alert;
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

bool BlacklistedServerContact::loadConfiguration(json_object *config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */

  /* Parse additional parameters */

  return (true);
}

/* ***************************************************** */

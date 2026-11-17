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

void BlacklistedClientContact::protocolDetected(Flow* f) {
  /* Trigger only when the server replies: a blacklisted remote client
   * contacting a local host that does not reply is just noise. */
  bool server_replied = (f->get_protocol() == IPPROTO_TCP) ? f->isThreeWayHandshakeOK() : (f->get_packets_srv2cli() > 0);

  if (f->isBlacklistedClient() && f->isRemoteToLocal() && server_replied) {
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;

    FlowAlert* alert = buildAlert(f);

    if (alert) {
      computeCliSrvScore(alert->getAlertScore(), cli_score_pctg, &c_score,
                         &s_score);
      alert->setCliSrvScores(c_score, s_score);
      f->triggerAlert(alert);
    }
  }
}

/* ***************************************************** */

FlowAlert* BlacklistedClientContact::buildAlert(Flow* f) {
  bool is_server_bl = f->isBlacklistedServer();
  bool is_client_bl = f->isBlacklistedClient();
  BlacklistedClientContactAlert* alert =
      new (std::nothrow) BlacklistedClientContactAlert(this, f);

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

    alert->setAlertScore(SCORE_LEVEL_NOTICE);
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

bool BlacklistedClientContact::loadConfiguration(json_object* config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */

  /* Parse additional parameters */

  return (true);
}

/* ***************************************************** */

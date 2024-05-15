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

void TCPFlowReset::checkFlowReset(Flow *f) {
  MinorConnectionStates current_connection_state = f->getCurrentConnectionState();
  
  bool to_trigger = f->isOnlyTCPReset() ||
      current_connection_state == REJ ||
      current_connection_state == RSTO ||
      current_connection_state == RSTR ||
      current_connection_state == RSTOS0 ||
      current_connection_state == RSTRH;
  if ((f->isTCP()) && (to_trigger)) {
    Host *cli_host = f->get_cli_host();
    Host *srv_host = f->get_srv_host();

    if (cli_host && cli_host->isLocalHost()) {
      cli_host->incResetFlow();
    }

    if (srv_host && srv_host->isLocalHost()) {
      srv_host->incResetFlow();
    }

    FlowAlertType alert_type = TCPFlowResetAlert::getClassType();
    u_int8_t c_score, s_score;

    risk_percentage cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;

    computeCliSrvScore(ntop->getFlowAlertScore(alert_type.id), cli_score_pctg, &c_score, &s_score);
    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

void TCPFlowReset::flowEnd(Flow *f) {
  checkFlowReset(f);
}

/* ***************************************************** */

FlowAlert *TCPFlowReset::buildAlert(Flow *f) {
  return new TCPFlowResetAlert(this, f);
}

/* ***************************************************** */


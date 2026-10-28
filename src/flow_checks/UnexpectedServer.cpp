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

void UnexpectedServer::protocolDetected(Flow* f) {
  if (!isAllowedProto(f)) return;

  if (!isAllowedHost(f)) {
    FlowAlertType alert_type = getAlertType();
    FlowAlert* alert = buildAlert(f);
    u_int8_t c_score, s_score;
    /* Most of the score goes to the host to blame, i.e. the attacker set by
     * buildAlert(): usually the client of the flow, which contacts a server
     * not allowed (e.g. DNS, NTP, SMTP), but the server of the flow when it is
     * the unexpected server itself (e.g. a DHCP server answering a client) */
    risk_percentage cli_score_pctg = alert->isSrvAttacker()
                                         ? CLIENT_LOW_RISK_PERCENTAGE
                                         : CLIENT_HIGH_RISK_PERCENTAGE;

    computeCliSrvScore(ntop->getFlowAlertScore(alert_type.id), cli_score_pctg,
                       &c_score, &s_score);

    alert->setCliSrvScores(c_score, s_score);
    f->triggerAlert(alert);
  }
}

/* ***************************************************** */

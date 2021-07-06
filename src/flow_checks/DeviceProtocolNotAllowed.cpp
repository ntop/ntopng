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
#include "flow_checks_includes.h"

void DeviceProtocolNotAllowed::protocolDetected(Flow *f) {
  if(!f->isDeviceAllowedProtocol()) {
    FlowAlertType alert_type = DeviceProtocolNotAllowedAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg;

    if (!f->isCliDeviceAllowedProtocol())
      cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;
    else
      cli_score_pctg = CLIENT_LOW_RISK_PERCENTAGE;

    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score); 

    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *DeviceProtocolNotAllowed::buildAlert(Flow *f) {
  DeviceProtocolNotAllowedAlert *alert = new (std::nothrow) DeviceProtocolNotAllowedAlert(this, f);

  /*
    Only the attacker is known, and it can be either the client or the server.
    Nothing can be said on the victim as the non-attacker peer can just do legitimate activities.
    E.g., a client using TOR as protocol not allowed can contact legitimate (non-victim) TOR nodes.

    As setting attacker/victim is a strong concept, the flow is checked to be unicast to avoid
    considering multicast/broadcast addresses (see https://github.com/ntop/ntopng/issues/5624)
  */

  if(f->isUnicast()) {
    if(!f->isCliDeviceAllowedProtocol())
      alert->setCliAttacker();
    else
      alert->setSrvAttacker();
  }

  return alert;
}

/* ***************************************************** */

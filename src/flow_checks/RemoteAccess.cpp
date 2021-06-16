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

/* ***************************************************** */

void RemoteAccess::protocolDetected(Flow *f) {
  FlowAlertType alert_type = RemoteAccessAlert::getClassType();
  u_int8_t c_score, s_score;
  risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;
  Host *cli = f->get_cli_host();

  switch(f->get_protocol_category()) {
  case NDPI_PROTOCOL_CATEGORY_REMOTE_ACCESS:
  case NDPI_PROTOCOL_CATEGORY_VPN:
  case NDPI_PROTOCOL_CATEGORY_FILE_SHARING:
    if(cli) cli->incrRemoteAccess();

    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

    f->triggerAlertAsync(alert_type, c_score, s_score);
    break;
  default:
    break;
  }
}

/* ***************************************************** */

void RemoteAccess::flowEnd(Flow *f) {
  Host *cli = f->get_cli_host();
  
  switch(f->get_protocol_category()) {
  case NDPI_PROTOCOL_CATEGORY_REMOTE_ACCESS:
  case NDPI_PROTOCOL_CATEGORY_VPN:
  case NDPI_PROTOCOL_CATEGORY_FILE_SHARING:
    if(cli) cli->decrRemoteAccess();

    break;
  default:
    break;
  }
}

/* ***************************************************** */

FlowAlert *RemoteAccess::buildAlert(Flow *f) {
  return new RemoteAccessAlert(this, f);
}

/* ***************************************************** */

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

void RemoteToLocalInsecureProto::protocolDetected(Flow *f) {
  if(f->isRemoteToLocal()) {
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;
    /* Remote to local */
    bool unsafe;
    
    switch(f->get_protocol_breed()) {
    case NDPI_PROTOCOL_UNSAFE:
      unsafe = true;
      cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;
      break;

    case NDPI_PROTOCOL_POTENTIALLY_DANGEROUS:
      unsafe = true;
      cli_score_pctg = CLIENT_LOW_RISK_PERCENTAGE;
      break;
      
    case NDPI_PROTOCOL_DANGEROUS:
      unsafe = true;
      cli_score_pctg = CLIENT_LOW_RISK_PERCENTAGE;
      break;

    default:
      unsafe = false;
      break;
    }  

    if(!unsafe) {
      switch(f->get_protocol_category()) {
      case CUSTOM_CATEGORY_MALWARE:
      case CUSTOM_CATEGORY_BANNED_SITE:
	cli_score_pctg = CLIENT_LOW_RISK_PERCENTAGE;
	unsafe = true;
	break;

      default:
	break;
      }
    }
  
    if(unsafe) {
      FlowAlertType alert_type = RemoteToLocalInsecureProtoAlert::getClassType();
      u_int8_t c_score, s_score;

      computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

      f->triggerAlertAsync(alert_type, c_score, s_score);
    }
  }
}

/* ***************************************************** */

FlowAlert *RemoteToLocalInsecureProto::buildAlert(Flow *f) {
  RemoteToLocalInsecureProtoAlert *alert = new RemoteToLocalInsecureProtoAlert(this, f);

  /* The remote client is considered the attacker. The victim is the local server */
  switch(f->get_protocol_category()) {
  case CUSTOM_CATEGORY_MALWARE:
  case CUSTOM_CATEGORY_BANNED_SITE:
    alert->setCliAttacker(), alert->setSrvVictim();
    break;
  default:
    break;
  }

  return alert;
}

/* ***************************************************** */

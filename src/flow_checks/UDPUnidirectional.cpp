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

void UDPUnidirectional::checkFlow(Flow *f) {
  FlowAlertType alert_type = UDPUnidirectionalAlert::getClassType();
  u_int8_t c_score, s_score;
  risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;
  int16_t network_id;

  if(f->getInterface()->isSampledTraffic())             return;
  if(f->get_protocol() != IPPROTO_UDP)                  return; /* Non UDP traffic        */
  if(f->get_bytes_srv2cli() && f->get_bytes_srv2cli())  return; /* Two way communications */
  if(!f->get_cli_ip_addr()->isNonEmptyUnicastAddress()) return; /* No client IP           */
  if(!f->get_srv_ip_addr()->isNonEmptyUnicastAddress()) return; /* Multicast server        */
  
  switch(f->get_detected_protocol().app_protocol) {
  case NDPI_PROTOCOL_MDNS:
  case NDPI_PROTOCOL_SYSLOG:
  case NDPI_PROTOCOL_DHCP:
  case NDPI_PROTOCOL_DHCPV6:
  case NDPI_PROTOCOL_RTP:
  case NDPI_PROTOCOL_SFLOW:
  case NDPI_PROTOCOL_NETFLOW:
    return; /* Whitelisted protocol */

  default:
    /* No whitelist */
    break;
  }

  if(!f->get_srv_ip_addr()->isLocalHost(&network_id)) {
    cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;
  }
  
  computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

  f->triggerAlertAsync(alert_type, c_score, s_score);
}

/* ***************************************************** */

void UDPUnidirectional::periodicUpdate(Flow *f) { checkFlow(f); }
void UDPUnidirectional::flowEnd(Flow *f)        { checkFlow(f); }
  
/* ***************************************************** */

FlowAlert *UDPUnidirectional::buildAlert(Flow *f) {
  return new UDPUnidirectionalAlert(this, f);
}

/* ***************************************************** */

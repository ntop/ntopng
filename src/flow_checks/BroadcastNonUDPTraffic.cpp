/*
 *
 * (C) 2013-22 - ntop.org
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

void BroadcastNonUDPTraffic::flowBegin(Flow *f) {
  const IpAddress *ip_addr = f->get_srv_ip_addr();
  Mac *mac_addr = f->get_srv_host() ? f->get_srv_host()->getMac() : NULL;
  
  if(ip_addr || mac_addr) {
    bool launch_alert = false;

    if((ip_addr) && (ip_addr->isBroadcastAddress()) && (f->get_protocol() != IPPROTO_UDP /* The protocol MUST not be UDP*/))
      launch_alert = true;
    
    if((mac_addr) && (mac_addr->isBroadcast()) && (f->get_protocol() != IPPROTO_UDP /* The protocol MUST not be UDP*/))
      launch_alert = true;
    
    /* 
     * This alert has to be triggered when we have traffic towards Broadcast addresses
     * and the l4 protocol is not UDP protocol (possible device scan in a network)
     */
    if(launch_alert) {
      FlowAlertType alert_type = BroadcastNonUDPTrafficAlert::getClassType();
      u_int8_t c_score, s_score;

      risk_percentage cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;

      computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

      f->triggerAlertAsync(alert_type, c_score, s_score);
    }
  } 
}

/* ***************************************************** */

FlowAlert *BroadcastNonUDPTraffic::buildAlert(Flow *f) {
  BroadcastNonUDPTrafficAlert *alert = new BroadcastNonUDPTrafficAlert(this, f);

  /* The remote client is considered the attacker. The victim is the local server */
  alert->setCliAttacker();

  return alert;
}

/* ***************************************************** */

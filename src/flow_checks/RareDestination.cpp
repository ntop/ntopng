/*
 *
 * (C) 2013-23 - ntop.org
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

#define TODO_HERE 1

/* ***************************************************** */

void RareDestination::protocolDetected(Flow *f) {
  bool is_rare_destination = false;
  

  /* TODO: check if this is a real rare destination */
  if(f->getFlowServerInfo() != NULL) {
#ifdef TODO_HERE
    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare destination %s", f->getFlowServerInfo());

    if (f->isLocalToLocal())
    {
      u_int32_t key = 0;
      Host * dest = f->get_srv_host();

      if (dest->isDHCPHost())
      {
        key = dest->getMac()->key();
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare destination MAC detected");
      }
      
      if (dest->isIPv6())
      {
        const ndpi_in6_addr * destv6 = dest->get_ip()->get_ipv6();
      }

      if (dest->isIPv4())
      {
        key = dest->get_ip()->get_ipv4();
        
      }

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare destination IP %u", key);
    }

    /*
      Host * source = f->get_cli_host();
      Host * dest = f->get_srv_host();
      source->get_ip()->equal(inet_addr("192.168.43.247"));
      dest->isDHCPHost()
      u_int8_t mac = *(dest->get_mac());
    */

    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Local Host Json %s", json_object_to_json_string_ext(source->get_ip()->getJSONObject(), JSON_C_TO_STRING_SPACED | JSON_C_TO_STRING_PRETTY));
    //is_rare_destination = true;
#endif
  }
  
  if(is_rare_destination) {
    FlowAlertType alert_type = RareDestinationAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE; 
    
    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);
    
    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert* RareDestination::buildAlert(Flow *f) {
  return new RareDestinationAlert(this, f);
}

/* ***************************************************** */

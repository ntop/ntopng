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

bool getDestinationHash(Flow *f, u_int32_t *hash) {
  Host * dest = f->get_srv_host();
  if (f->isLocalToLocal())
  {
    char buf[64];
    if (!dest->isMulticastHost() && dest->isDHCPHost())
    {
      char *mac = dest->getMac()->print(buf,sizeof(buf));
      *hash = Utils::hashString(mac);
      /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare local destination MAC %u - %s", *hash, mac); */
    }
    
    if (dest->isIPv6())
    {
      char *ipv6 = dest->get_ip()->print(buf,sizeof(buf));
      *hash = Utils::hashString(ipv6);
      /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare local destination IPv6 %u - %s", *hash, ipv6); */
    }

    if (dest->isIPv4())
    {
      char *ipv4 = dest->get_ip()->print(buf,sizeof(buf));
      *hash = Utils::hashString(ipv4);
      /* u_int32_t quick_key = ndpi_quick_hash((unsigned char *)ipv4,sizeof(ipv4)); */
      /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare local destination IPv4 %u - %s", *hash, ipv4); */
    }
  }

  if (f->isLocalToRemote())
  {
    char name_buf[128];
    char *domain = dest->get_name(name_buf, sizeof(name_buf), false);
    *hash = Utils::hashString(domain);
    /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare remote destination %u - %s", *hash, domain); */
  }
  
  if ( *hash == 0 && (!f->isLocalToLocal() || !f->isLocalToRemote()) )
  {
    /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Destination not hashed: %s", json_object_to_json_string(dest->get_ip()->getJSONObject())); */
    return (false);
  }

  return (true);
}

/* ***************************************************** */

void RareDestination::protocolDetected(Flow *f) {
  bool is_rare_destination = false;

  /* TODO: check if this is a real rare destination */
  if(f->getFlowServerInfo() != NULL) {
#ifdef TODO_HERE
    u_int32_t hash = 0;
    if(!getDestinationHash(f,&hash)) { return; }
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Rare destination hash %u", hash);



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

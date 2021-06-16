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

bool UnexpectedServer::isAllowedHost(const IpAddress *p) {
  if((p == NULL) || p->isBroadcastAddress())
    return(true);
  else {
    u_int64_t match_ip;
    int rc;
    ndpi_ip_addr_t a;

    memset(&a, 0, sizeof(a));
  
    if(p->isIPv4())
      a.ipv4 = p->get_ipv4();
    else
      memcpy(&a.ipv6, p->get_ipv6(), sizeof(struct ndpi_in6_addr));
  
    rc = ndpi_ptree_match_addr(whitelist, &a, &match_ip);
  
    if((rc != 0) || (!match_ip))
      return(false);
    else
      return(true);
  }
}

/* ***************************************************** */

bool UnexpectedServer::loadConfiguration(json_object *config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */
  json_object *whitelist_json, *whitelisted_ip_json;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() %s", __FUNCTION__, json_object_to_json_string(config));

  /*
    Format:

    { "items": [ "192.168.0.1", "172.16.0.1" ], "severity": ...
  */

  if(json_object_object_get_ex(config, "items", &whitelist_json)) {
    for(u_int i = 0; i < json_object_array_length(whitelist_json); i++) {
      IpAddress ip;
      u_int64_t naddr = 1;
      
      whitelisted_ip_json = json_object_array_get_idx(whitelist_json, i);

      ip.set(json_object_get_string(whitelisted_ip_json));

      if(!ip.isEmpty()) {
	ndpi_ip_addr_t a;

	memset(&a, 0, sizeof(a));
	
	if(ip.isIPv4()) {
	  a.ipv4 = ip.get_ipv4();
	
	  ndpi_ptree_insert(whitelist, &a, 32, naddr);
	} else {
	  memcpy(&a.ipv6, ip.get_ipv6(), sizeof(struct ndpi_in6_addr));
	
	  ndpi_ptree_insert(whitelist, &a, 128, naddr);
	}
      }
    }
  }

  return(true);
}

/* ***************************************************** */

void UnexpectedServer::protocolDetected(Flow *f) {  
  if(!isAllowedProto(f)) return;
  
  if(!isAllowedHost(getServerIP(f))) {
    FlowAlertType alert_type = getAlertType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;
   
    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);
 
    f->triggerAlertAsync(alert_type, c_score, s_score);   
  }
}

/* ***************************************************** */


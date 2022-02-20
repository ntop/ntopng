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

bool UnexpectedServer::isAllowedHost(Flow *f) {
  const IpAddress *p;
  u_int64_t match_ip;
  ndpi_ip_addr_t a;
  int rc;

  p = getServerIP(f);

  if (p == NULL 
      || p->isBroadcastAddress())
    return true;

  /* Check IP */

  memset(&a, 0, sizeof(a));
  if(p->isIPv4())
    a.ipv4 = p->get_ipv4();
  else
    memcpy(&a.ipv6, p->get_ipv6(), sizeof(struct ndpi_in6_addr));
  
  rc = ndpi_ptree_match_addr(whitelist_ptree, &a, &match_ip);
  if (rc == 0 && match_ip)
    return true;
  
  /* Check Domain */

  if(whitelist_automa) {
    char *server_name = f->getFlowServerInfo();

    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Checking server name %s", server_name);

    if (server_name != NULL
        && strlen(server_name) > 0
        && ndpi_match_string(whitelist_automa, server_name) == 1)
      return true;
  }

  return false;
}

/* ***************************************************** */

bool UnexpectedServer::loadConfiguration(json_object *config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */
  json_object *whitelist_json, *whitelisted_server_json;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() %s", __FUNCTION__, json_object_to_json_string(config));

  /*
    Format:

    { "items": [ "192.168.0.1", "172.16.0.1" ], "severity": ...
  */

  if(json_object_object_get_ex(config, "items", &whitelist_json)) {
    for(u_int i = 0; i < (u_int)json_object_array_length(whitelist_json); i++) {
      const char *server_ptr;
      
      whitelisted_server_json = json_object_array_get_idx(whitelist_json, i);
      server_ptr = json_object_get_string(whitelisted_server_json);

      if (Utils::isIPAddress(server_ptr)) {
        /* IP Address */
        IpAddress ip;
        u_int64_t naddr = 1;

        ip.set(server_ptr);

        if(!ip.isEmpty()) {
          ndpi_ip_addr_t a;

	  memset(&a, 0, sizeof(a));
	
	  if(ip.isIPv4()) {
	    a.ipv4 = ip.get_ipv4();
	
	    ndpi_ptree_insert(whitelist_ptree, &a, 32, naddr);
	  } else {
	    memcpy(&a.ipv6, ip.get_ipv6(), sizeof(struct ndpi_in6_addr));
	
	    ndpi_ptree_insert(whitelist_ptree, &a, 128, naddr);
          }
	}
      } else {
        /* Domain name */
        char whitelisted_domain[255];

	snprintf(whitelisted_domain, sizeof(whitelisted_domain), "%s", server_ptr);
	Utils::stringtolower(whitelisted_domain);

	if(!whitelist_automa)
	  whitelist_automa = ndpi_init_automa();

	if(whitelist_automa) {
          char *str = strdup(whitelisted_domain);
          if (str) {
	    ndpi_add_string_to_automa(whitelist_automa, str);
          }
        }
      }
    }
  }

  return(true);
}

/* ***************************************************** */

void UnexpectedServer::protocolDetected(Flow *f) {  
  if(!isAllowedProto(f)) return;
  
  if(!isAllowedHost(f)) {
    FlowAlertType alert_type = getAlertType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;
   
    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);
 
    f->triggerAlertAsync(alert_type, c_score, s_score);   
  }
}

/* ***************************************************** */


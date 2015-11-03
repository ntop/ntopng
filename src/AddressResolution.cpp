/*
 *
 * (C) 2013-15 - ntop.org
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

/* **************************************** */

AddressResolution::AddressResolution() {
  num_resolved_addresses = num_resolved_fails = 0, numLocalNetworks = 0;
  memset(local_networks, 0, sizeof(local_networks));
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
bool AddressResolution::setLocalNetworks(char *rule) {
  char *net = strtok(rule, ",");
  int16_t rc = -1;

  while(net != NULL) {
    if((rc = localNetworks.addAddress(net)) < 0) return false;
    net = strtok(NULL, ",");
  }
  return true;
}

/* ******************************************* */

int16_t AddressResolution::findAddress(int family, void *addr) {
  return(localNetworks.findAddress(family, addr));
}

/* **************************************** */

AddressResolution::~AddressResolution() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Address resolution stats [%u resolved][%u failures]",
			       num_resolved_addresses, num_resolved_fails);

  for(int i=0; i<numLocalNetworks; i++)
    free(local_networks[i]);
}

/* ***************************************** */

void AddressResolution::resolveHostName(char *_numeric_ip, char *symbolic, u_int symbolic_len) {
  char rsp[128], query[64], *at, *numeric_ip;
  u_int numeric_ip_len;

  snprintf(query, sizeof(query), "%s", _numeric_ip);
  if((at = strchr(query, '@')) != '\0') at[0] = '\0';
  numeric_ip = query;
  numeric_ip_len = strlen(numeric_ip)-1;

  if((symbolic != NULL) && (symbolic_len > 0)) symbolic[0] = '\0';
  if(numeric_ip[0] == '\0') return;

  if(ntop->getRedis()->getAddress(numeric_ip, rsp, sizeof(rsp), false) < 0) {
    char hostname[NI_MAXHOST];
    struct sockaddr *sa;
    struct sockaddr_in in4;
    struct sockaddr_in6 in6;
    int rc, len;

    /* Check if this is a symbolic IP */
    if(!isdigit(numeric_ip[numeric_ip_len])) {
      /* This is a symbolic IP -> numeric IP */
      struct hostent *h;

      m.lock(__FILE__, __LINE__);
      h = gethostbyname((const char*)numeric_ip); /* Non reentrant call */

      if(symbolic && h) snprintf(symbolic, symbolic_len, "%s",  h->h_name);
      ntop->getRedis()->setResolvedAddress(numeric_ip, h ? h->h_name : (char*)"");
      num_resolved_addresses++;
      m.unlock(__FILE__, __LINE__);
      return;
    }

    if(strchr(numeric_ip, ':') != NULL) {
      struct in6_addr addr6;

      if(inet_pton(AF_INET6, numeric_ip, &addr6) == 1) {
	memset(&in6, 0, sizeof(struct sockaddr_in6));

	in6.sin6_family = AF_INET6, inet_pton(AF_INET6, numeric_ip, &in6.sin6_addr);
	len = sizeof(struct sockaddr_in6), sa = (struct sockaddr*)&in6;
      } else {
	ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid IPv6 address to resolve '%s': already symbolic?", numeric_ip);
	return; /* Invalid format */
      }
    } else {
      u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;

      if(sscanf(numeric_ip, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) == 4) {
	in4.sin_family = AF_INET, in4.sin_addr.s_addr = inet_addr(numeric_ip);
	len = sizeof(struct sockaddr_in), sa = (struct sockaddr*)&in4;
      } else  {
	ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid IPv4 address to resolve '%s': already symbolic?", numeric_ip);
	return; /* Invalid format */
      }
    }

    if((rc = getnameinfo(sa, len, hostname, sizeof(hostname), NULL, 0, NI_NAMEREQD)) == 0) {
      ntop->getRedis()->setResolvedAddress(numeric_ip, hostname);
      if((symbolic != NULL) && (symbolic_len > 0)) snprintf(symbolic, symbolic_len, "%s", hostname);
      ntop->getTrace()->traceEvent(TRACE_INFO, "Resolved %s to %s", numeric_ip, hostname);
      m.lock(__FILE__, __LINE__);
      num_resolved_addresses++;
      m.unlock(__FILE__, __LINE__);
    } else {
      m.lock(__FILE__, __LINE__);
      num_resolved_fails++;
      m.unlock(__FILE__, __LINE__);
      ntop->getTrace()->traceEvent(TRACE_INFO, "Error resolution failure for %s [%d/%s/%s]",
				   numeric_ip, rc, gai_strerror(rc), strerror(errno));
      ntop->getRedis()->setResolvedAddress(numeric_ip, numeric_ip); /* So we avoid to continuously resolver the same address */
    }
  } else {
    if((symbolic != NULL) && (symbolic_len > 0)) snprintf(symbolic, symbolic_len, "%s", rsp);
  }
}

/* **************************************************** */

static void* resolveLoop(void* ptr) {
  AddressResolution *a = (AddressResolution*)ptr;
  Redis *r = ntop->getRedis();

  while(!ntop->getGlobals()->isShutdown()) {
    char numeric_ip[64];
    int rc = r->popHostToResolve(numeric_ip, sizeof(numeric_ip));

    if(rc == 0) {
      if(numeric_ip[0] != '\0')
	a->resolveHostName(numeric_ip);
    } else
      sleep(1);    
  }

  return(NULL);
}

/* **************************************************** */

void AddressResolution::startResolveAddressLoop() {
  if(ntop->getPrefs()->is_dns_resolution_enabled()) {
    int num_resolvers =
#ifdef NTOPNG_EMBEDDED_EDITION
      1
#else
      CONST_NUM_RESOLVERS
#endif
      ;

    for(int i=0; i<num_resolvers; i++)
      pthread_create(&resolveThreadLoop, NULL, resolveLoop, (void*)this);
  }
}

/* **************************************************** */

void AddressResolution::getLocalNetworks(lua_State* vm) {
  localNetworks.getAddresses(vm);
}

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

/* **************************************** */

AddressResolution::AddressResolution() {
  num_resolved_addresses = num_resolved_fails = 0;
  num_resolvers =
#ifdef NTOPNG_EMBEDDED_EDITION
      1
#else
      CONST_NUM_RESOLVERS
#endif
      ;

  if(!(resolveThreadLoop = (pthread_t*)calloc(num_resolvers, sizeof(pthread_t))))
    throw 2;
}

/* **************************************** */

AddressResolution::~AddressResolution() {
  if(ntop->getPrefs() && ntop->getPrefs()->is_dns_resolution_enabled()) {
    for(int i = 0; i < num_resolvers; i++) {
      if(resolveThreadLoop[i])
        pthread_join(resolveThreadLoop[i], NULL);
    }
  }

  free(resolveThreadLoop);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Address resolution stats [%u resolved][%u failures]",
			       num_resolved_addresses, num_resolved_fails);
}

/* ***************************************** */

void AddressResolution::resolveHostName(char *_numeric_ip, char *symbolic, u_int symbolic_len) {
  char rsp[128], query[64], *at, *numeric_ip;
  u_int numeric_ip_len;

  snprintf(query, sizeof(query), "%s", _numeric_ip);
  if((at = strchr(query, '@')) != NULL) at[0] = '\0';
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

    if(!ntop->getPrefs()->is_dns_resolution_enabled())
      return;

    /* Check if this is a symbolic IP */
    if(!isxdigit(numeric_ip[numeric_ip_len]) && (numeric_ip[numeric_ip_len] != ':')) {
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

bool AddressResolution::resolveHost(char *host, char *rsp, u_int rsp_len, bool v4) {
  struct addrinfo hints, *servinfo, *rp;
  const char *dst = NULL;

  memset(&hints, 0, sizeof(hints));

  hints.ai_family = v4 ? AF_INET : AF_INET6;
  hints.ai_socktype = SOCK_STREAM;

  if(!getaddrinfo(host, NULL, &hints, &servinfo)) {
    for(rp = servinfo; rp != NULL; rp = rp->ai_next) {
      if((v4 && (dst = inet_ntop(rp->ai_family, &((struct sockaddr_in *)rp->ai_addr)->sin_addr, rsp, rsp_len)))
	 || (dst = inet_ntop(rp->ai_family, &((struct sockaddr_in6 *)rp->ai_addr)->sin6_addr, rsp, rsp_len)))
	break;
    }

    freeaddrinfo(servinfo);
  }

  return(dst != NULL);
}

/* **************************************************** */

void* resolveLoop(void* ptr) {
  AddressResolution *a = (AddressResolution*)ptr;
  Redis *r = ntop->getRedis();
  u_int no_resolution_loops = 0;
  const u_int max_num_idle_loops = 3;

  Utils::setThreadName("resolveLoop");
  
  while(!ntop->getGlobals()->isShutdown()) {
    char numeric_ip[64];
    int rc = r->popHostToResolve(numeric_ip, sizeof(numeric_ip));

    if(rc == 0) {
      if(numeric_ip[0] != '\0')
	a->resolveHostName(numeric_ip);

      no_resolution_loops = 0;
    } else {
      if(no_resolution_loops < max_num_idle_loops) no_resolution_loops++;
      sleep(no_resolution_loops);
    }
  }

  return(NULL);
}

/* **************************************************** */

void AddressResolution::startResolveAddressLoop() {
  if(ntop->getPrefs()->is_dns_resolution_enabled()) {

    for(int i = 0; i < num_resolvers; i++)
      pthread_create(&resolveThreadLoop[i], NULL, resolveLoop, (void*)this);
  }
}

/*
 *
 * (C) 2016 - ntop.org
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

/* We keep it here as it's local to this CPP file */
struct dns_header {
  u_int16_t transaction_id;
  u_int16_t flags;
  u_int16_t num_questions;
  u_int16_t num_answers;
  u_int16_t num_authority_prs;
  u_int16_t num_other_prs;
  u_int8_t  data[1];
};

/* **************************************** */

Flashstart::Flashstart(char *_user, char *_pwd) {
  user = strdup(_user), pwd = strdup(_pwd);
  num_flashstart_categorizations = num_flashstart_fails = 0;
  sock = socket(AF_INET, SOCK_DGRAM, 0);

  dnsServer[0].sin_addr.s_addr = inet_addr("188.94.192.215"), dnsServer[0].sin_family = AF_INET, dnsServer[0].sin_port  = htons(53);
  dnsServer[1].sin_addr.s_addr = inet_addr("85.18.248.198"), dnsServer[1].sin_family = AF_INET, dnsServer[1].sin_port  = htons(53);
  dnsServerIdx = 0;

  if(sock >= 0)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enabled Flashstart traffic categorization");
  else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to start Flashstart traffic categorization");
}

/* ******************************************* */

Flashstart::~Flashstart() {
  void *res;

  if(user && pwd) {
    pthread_join(flashstartThreadLoop, &res);

    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Flashstart resolution stats [%u categorized][%u failures]",
				 num_flashstart_categorizations, num_flashstart_fails);
  }

  if(user) free(user);
  if(pwd)  free(pwd);
  closesocket(sock);
}

/* **************************************************** */

static void* flashstartThreadInfiniteLoop(void* ptr) {
  return(((Flashstart*)ptr)->flashstartLoop(ptr));
}

/* **************************************************** */

char* Flashstart::findCategory(char *name, char *buf, u_int buf_len, bool add_if_needed) {
  if(ntop->getPrefs()->is_flashstart_enabled()) {
    return(ntop->getRedis()->getTrafficFilteringCategory(name, buf, buf_len, add_if_needed));
  } else {
    buf[0] = '\0';
    return(buf);
  }
}

/* **************************************************** */

void Flashstart::queryFlashstart(char* symbolic_name) {
  char buf[32], *rsp;
  
  rsp = ntop->getRedis()->getTrafficFilteringCategory(symbolic_name, buf, sizeof(buf)-1, false);
  
  if((rsp == NULL) || (rsp[0] == '\0')) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLASHSTART] Categorizing %s", symbolic_name);
    queryDomain(sock, symbolic_name, ++num_flashstart_categorizations,
		(struct sockaddr*)&dnsServer[dnsServerIdx],
		sizeof(dnsServer[dnsServerIdx]));
    if(++dnsServerIdx == 2) dnsServerIdx = 0;
  }
}

/* **************************************************** */

void Flashstart::queryDomain(int sock, char *domain, u_int queryId,
			     const struct sockaddr *to, socklen_t tolen) {
  char data[512] = { 0 }, *p, *s;
  struct dns_header *header = (struct dns_header *)data;
  u_int domain_len = strlen(domain), query_len;
  int i, n;

  header->transaction_id = queryId,
    header->flags = htons(0x100),
    header->num_questions = htons(1); /* 1 query */

  domain_len = strlen(domain);
  p = (char *)&header->data;  // For encoding host domain into packet

  do {
    if ((s = strchr(domain, '.')) == NULL)
      s = domain + domain_len;

    n = s - domain;
    *p++ = n;
    for(i = 0; i < n; i++) *p++ = domain[i];

    if(*s == '.') n++;
    domain += n, domain_len -= n;
  } while (*s != '\0');

  *p++ = 0;
  *p++ = 0;
  *p++ = (u_int8_t)0x10; /* TXT */
  *p++ = 0;
  *p++ = 1; // Class: inet, 0x0001

  query_len = p - data;

  if(sendto(sock, data, query_len, 0, to, tolen) == -1)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Send error %d/%s\n", errno, strerror(errno));  
}

/* **************************************************** */

int Flashstart::parseDNSResponse(unsigned char *rsp, int rsp_len, struct sockaddr_in *from) {
  struct dns_header *header = (struct dns_header *)rsp;
  int i;
  u_int16_t qtype, offset;
  char qname[128], txt[128], *p;

  if(ntohs(header->num_questions) != 1) return(-1);
  
  p = (char*)&rsp[sizeof(struct dns_header)-1];

  for(i=0; (p[i] != 0) && (i < (rsp_len-sizeof(struct dns_header))); i++) {
    if(p[i] < 10) qname[i] = '.'; else qname[i] = p[i];
  }

  qname[i] = 0;
  qtype = htons(*((uint16_t *)&rsp[sizeof(struct dns_header)+i]));

  if(qtype != 0x10 /* TXT*/) return(-1);
  
  offset = sizeof(struct dns_header)+i+16+1;
  rsp[rsp_len] = 0;
  
  snprintf(txt, sizeof(txt), "%s", &rsp[offset]);

  if(qname[0] && txt[0]) {
    char *category = (char*)"???";

    if(!strncmp(txt, "BLACKLIST:", 10)) {
      category = &txt[10];
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLASHSTART] %s=%s", qname, category);
    }

    ntop->getRedis()->setTrafficFilteringAddress(qname, category);
  }

  return(0);
}

/* **************************************************** */

u_int Flashstart::recvResponses(u_int msecTimeout) {
  struct timeval tv = { 0, 0 };
  fd_set fdset;
  u_int num = 0;

  FD_ZERO(&fdset);
  FD_SET(sock, &fdset);

  if(msecTimeout >= 1000)
    tv.tv_sec = 1;
  else
    tv.tv_usec = msecTimeout*1000;

  while(select(sock + 1, &fdset, NULL, NULL, &tv)) {
    u_char rsp[512];
    struct sockaddr_in from;
    socklen_t s;
    int len = recvfrom(sock, rsp, sizeof(rsp), 0, (struct sockaddr*)&from, &s);

    if(len > sizeof(struct dns_header))
      parseDNSResponse(rsp, len, &from), num++;    
  }

  return(num);
}

/* **************************************************** */

void* Flashstart::flashstartLoop(void* ptr) {
  Flashstart *h = (Flashstart*)ptr;
  Redis *r = ntop->getRedis();

  while(!ntop->getGlobals()->isShutdown()) {
    char symbolic_ip[64];

    int rc = r->popHostToTrafficFiltering(symbolic_ip, sizeof(symbolic_ip));

    if(rc == 0) {
      h->queryFlashstart(symbolic_ip);
      h->recvResponses(100);
    } else
      h->recvResponses(1000);
  }

  return(NULL);
}

/* **************************************************** */

void Flashstart::startLoop() {
  if(user && pwd) {
    const char *format = "http://ddns.flashstart.it/nic/update?hostname=test.ntop.org&myip=&wildcard=NOCHG&username=%s&password=%s";
    char url[512], ret[64] = { 0 };
    bool rsp;

    /* 1 - Tell flashstart that we want to issue DNS queries */
    snprintf(url,sizeof(url), format, user, pwd);

    rsp = Utils::httpGet(url, ret, sizeof(ret)-1);
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Called %s [rsp: %s]",
				 url, rsp ? ret : "ERROR");

    pthread_create(&flashstartThreadLoop, NULL,
		   flashstartThreadInfiniteLoop, (void*)this);
  }
}

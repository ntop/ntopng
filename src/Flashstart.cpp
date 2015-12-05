/*
 *
 * (C) 2015 - ntop.org
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

Flashstart::Flashstart(char *_user, char *_pwd) {
  user = strdup(_user), pwd = strdup(_pwd);
  num_flashstart_categorizations = num_flashstart_fails = 0;
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enabled Flashstart traffic categorization");
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
}

/* **************************************************** */

static void* flashstartThreadInfiniteLoop(void* ptr) {
  return(((Flashstart*)ptr)->flashstartLoop(ptr));
}

/* **************************************************** */

char* Flashstart::findTrafficCategory(char *name, char *buf, u_int buf_len, bool add_if_needed) {
  if(ntop->getPrefs()->is_flashstart_enabled()) {
    return(ntop->getRedis()->getTrafficFilteringCategory(name, buf, buf_len, add_if_needed));
  } else {
    buf[0] = '\0';
    return(buf);
  }
}

/* **************************************************** */

static void *get_in_addr(struct sockaddr *sa) {
  if(sa->sa_family == AF_INET)
    return &(((struct sockaddr_in*)sa)->sin_addr);
  return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

/* **************************************************** */

static int dns_query_execute(char* query, char* resp, u_int resp_len) {
  struct addrinfo *result = NULL, *cur = NULL;
  int rc;
  struct addrinfo hint;

  memset(&hint, 0 , sizeof(hint));
  /* hint.ai_family = AF_UNSPEC; - zero anyway */
  /* Needed. Or else we will get each address twice (or more)
   * for each possible socket type (tcp,udp,raw...): */
  hint.ai_socktype = SOCK_STREAM;
  // hint.ai_flags = AI_CANONNAME;
  rc = getaddrinfo(query, NULL /* service */, &hint, &result);

  if(rc) {
    // The host is not blacklisted 
    if(rc == EAI_NONAME)
      return 1;

    // That's another error
    snprintf(resp, resp_len, "%s [errno=%d]", gai_strerror(rc), rc);
    return 0;
  }

  cur = result;

  while (cur) {
    char dotted[INET6_ADDRSTRLEN];

    inet_ntop(cur->ai_family, get_in_addr((struct sockaddr *)cur->ai_addr), dotted, sizeof(dotted));
    snprintf(resp, resp_len, "%s", dotted);

    cur = cur->ai_next;
    if(cur) {
      snprintf(resp, resp_len, "Multiple address returned. Something is wrong!");
      return 0;
    }
  }

  return 2;
}

/* **************************************************** */

void Flashstart::queryFlashstart(char* symbolic_ip) {
  char dns_query_str[256] = { 0 }, query_resp[256], alert_msg[512], *iface;
  int rc;

  /* Format symbolic_ip@interface_name */
  iface = strchr(symbolic_ip, '@');

  if(iface) {
    iface[0] = '\0';
    iface = &iface[1]; 
  } else 
    iface = (char*)"";

  rc = dns_query_execute(dns_query_str, query_resp, sizeof(query_resp));
  switch (rc) {
    case 0: // failure while querying the dns, just return
      ntop->getTrace()->traceEvent(TRACE_INFO, 
				   "HTTP:BL resolution: unable to query the DNS for [%s][%s]", 
				   dns_query_str, query_resp);

      num_flashstart_fails++;
      return;

    case 1: // the host is not blacklisted
      snprintf(query_resp, sizeof(query_resp), "%s", NULL_BL);
      break;

    case 2: // the host is blacklisted: get the response
      /* https://www.projecthoneypot.org/flashstart_api.php */

      /* We need to figure out the current list of peers speaking with this host */

      snprintf(alert_msg, sizeof(alert_msg), 
	       "Host <A HREF='/lua/host_details.lua?host=%s&ifname=%s'>%s</A> blacklisted on HTTP:BL [code=%s]",
	       symbolic_ip, iface, symbolic_ip, query_resp);

      ntop->getRedis()->queueAlert(alert_level_warning, alert_dangerous_host, alert_msg);
      break;
  }

  num_flashstart_categorizations++;
/*
  ntop->getTrace()->traceEvent(TRACE_ERROR, 
      "Flashstart resolution stats [%u categorized][%u failures][%s][%s][%s]",
      num_flashstart_categorizations, num_flashstart_fails, 
      symbolic_ip, dns_query_str, query_resp);
*/
  // Always set the response, even if not in blacklist, to avoid
  // consulting the blacklist again
  ntop->getRedis()->setTrafficFilteringAddress(symbolic_ip, query_resp);
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
    } else
      sleep(1);
  }

  return(NULL);
}

/* **************************************************** */

void Flashstart::startLoop() {
  if(user && pwd) {
    const char *format = "http://ddns.flashstart.it/nic/update?hostname=test.ntop.org&myip=&wildcard=NOCHG&username=%s&password=%s";
    char url[512];
    bool rsp;

    /* 1 - Tell flashstart that we want to issue DNS queries */
    snprintf(url,sizeof(url), format, user, pwd);

    rsp = Utils::httpGet(NULL, url, NULL, NULL, 3, false);
    ntop->getTrace()->traceEvent(TRACE_INFO, "Called %s [rsp: %s]",
				 url, rsp ? "OK" : "ERROR");

    pthread_create(&flashstartThreadLoop, NULL, 
		   flashstartThreadInfiniteLoop, (void*)this);
  }
}


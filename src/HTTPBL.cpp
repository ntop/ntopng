/*
 *
 * (C) 2013-18 - ntop.org
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

HTTPBL::HTTPBL(char *_api_key) {
  api_key = _api_key ? _api_key : NULL;
  num_httpblized_categorizations = num_httpblized_fails = 0;
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enable http:dl with API key %s", api_key);
}

/* ******************************************* */

HTTPBL::~HTTPBL() {
  void *res;

  if(api_key != NULL) {
    pthread_join(httpblThreadLoop, &res);

    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "HTTPBL resolution stats [%u categorized][%u failures]",
				 num_httpblized_categorizations, num_httpblized_fails);
  }
}

/* **************************************************** */

static void* httpblThreadInfiniteLoop(void* ptr) {
  return(((HTTPBL*)ptr)->httpblLoop(ptr));
}

/* **************************************************** */

char* HTTPBL::findCategory(char *name, char *buf, u_int buf_len, bool add_if_needed) {
  if(ntop->getPrefs()->is_httpbl_enabled()) {
    return(ntop->getRedis()->getTrafficFilteringCategory(name, buf, buf_len, add_if_needed));
  } else {
    buf[0] = '\0';
    return(buf);
  }
}

/* **************************************************** */

static char* reverse_ipv4(char* numeric_ip) {
  char *reversed = NULL;
  size_t len;
  char *saveptr, *curr_ptr;
  char *str = strdup(numeric_ip);
  char b[4][4];
  int idx = 0;

#ifdef DEBUG_HTTPBL
  char *test_ip = "1.1.1.127";
  numeric_ip = test_ip;
#endif

  len = 1 + strlen(numeric_ip);

  if(len == 0)
    return NULL;

  if((reversed = (char*) malloc(len)) == NULL)
    return NULL;

  memset(reversed, 0, len);
  memset(b, 0, sizeof(b));

#ifdef DEBUG_HTTPBL
  snprintf(reversed, len, "%s", test_ip);
#endif

  curr_ptr = strtok_r(str, ".", &saveptr);
  if(!curr_ptr)
    goto clean;

  snprintf(&(b[idx][0]), 4, "%s", curr_ptr);
  while(saveptr) {
    curr_ptr = strtok_r(NULL, ".", &saveptr);
    if(curr_ptr) {
      idx++;
      snprintf(&(b[idx][0]), 4, "%s", curr_ptr);
    }
    else saveptr = NULL;
  }

  if(idx != 3)
    goto clean;

  snprintf(reversed, len, "%s.%s.%s.%s", b[3], b[2], b[1], b[0]);
  free(str);
  return reversed;

clean:
  free(str);
  free(reversed);
  return NULL;;
}

/* **************************************************** */

static int prepare_dns_query_string(char* key, char* numeric_ip, char* buf, u_int buf_len) {
  char* reversed_ip = reverse_ipv4(numeric_ip);

  if(reversed_ip == NULL)
    return -1;

  snprintf(buf, buf_len, "%s.%s.%s", key, reversed_ip, HTTPBL_DOMAIN);
  free(reversed_ip);

  return 1;
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
  rc = getaddrinfo(query, NULL /*service*/, &hint, &result);

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

void HTTPBL::queryHTTPBL(char* numeric_ip) {
  char dns_query_str[256] = { 0 }, query_resp[256], *iface;
  int rc;

  /* Format numeric_ip@interface_name */
  iface = strchr(numeric_ip, '@');

  if(iface) {
    iface[0] = '\0';
    iface = &iface[1];
  } else
    iface = (char*)"";

  if(prepare_dns_query_string(api_key, numeric_ip, dns_query_str, sizeof(dns_query_str)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
        "HTTP:BL resolution: invalid query with [%s]", numeric_ip);
    num_httpblized_fails++;
    return;
  }

  rc = dns_query_execute(dns_query_str, query_resp, sizeof(query_resp));
  switch (rc) {
    case 0: // failure while querying the dns, just return
      ntop->getTrace()->traceEvent(TRACE_INFO,
				   "HTTP:BL resolution: unable to query the DNS for [%s][%s]",
				   dns_query_str, query_resp);

      num_httpblized_fails++;
      return;

    case 1: // the host is not blacklisted
      snprintf(query_resp, sizeof(query_resp), "%s", NULL_BL);
      break;

    case 2: // the host is blacklisted: get the response
      /* https://www.projecthoneypot.org/httpbl_api.php */

      /* We need to figure out the current list of peers speaking with this host */
      /* TODO: possibly generate an alert */

      break;
  }

  num_httpblized_categorizations++;
/*
  ntop->getTrace()->traceEvent(TRACE_ERROR,
      "HTTPBL resolution stats [%u categorized][%u failures][%s][%s][%s]",
      num_httpblized_categorizations, num_httpblized_fails,
      numeric_ip, dns_query_str, query_resp);
*/
  // Always set the response, even if not in blacklist, to avoid
  // consulting the blacklist again
  ntop->getRedis()->setTrafficFilteringAddress(numeric_ip, query_resp);
}

/* **************************************************** */

void* HTTPBL::httpblLoop(void* ptr) {
  HTTPBL *h = (HTTPBL*)ptr;
  Redis *r = ntop->getRedis();

  while(!ntop->getGlobals()->isShutdown()) {
    char numeric_ip[64];

    int rc = r->popHostToTrafficFiltering(numeric_ip, sizeof(numeric_ip));

    if(rc == 0) {
      h->queryHTTPBL(numeric_ip);
    } else
      sleep(1);
  }

  return(NULL);
}

/* **************************************************** */

void HTTPBL::startLoop() {
  pthread_create(&httpblThreadLoop, NULL, httpblThreadInfiniteLoop, (void*)this);
}


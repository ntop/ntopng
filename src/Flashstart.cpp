/*
 *
 * (C) 2016-17 - ntop.org
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

Flashstart::Flashstart(char *_user, char *_pwd,
		       char *alt_dns_ip, u_int16_t alt_dns_port,
		       bool synchronousClassification) {
  user = strdup(_user), pwd = strdup(_pwd);
  num_flashstart_categorizations = num_flashstart_fails = 0;
  sock = socket(AF_INET, SOCK_DGRAM, 0);
  syncClassification = synchronousClassification;

  if(alt_dns_ip && alt_dns_port) {
    dnsServer[0].sin_addr.s_addr = inet_addr(alt_dns_ip), dnsServer[0].sin_family = AF_INET, dnsServer[0].sin_port  = htons(alt_dns_port);
    numDnsServers = 1;
  } else {
    dnsServer[0].sin_addr.s_addr = inet_addr("188.94.192.215"), dnsServer[0].sin_family = AF_INET, dnsServer[0].sin_port  = htons(53);
    dnsServer[1].sin_addr.s_addr = inet_addr("85.18.248.198"), dnsServer[1].sin_family = AF_INET, dnsServer[1].sin_port  = htons(53);
    numDnsServers = 2;
  }

  dnsServerIdx = 0, numCategories = 0;

  if(sock >= 0)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enabled Flashstart traffic categorization");
  else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to start Flashstart traffic categorization");

  domain_cache = NULL;
  initMapping();
}

/* ******************************************* */

Flashstart::~Flashstart() {
  void *res;

  if(user && pwd) {
    if(!syncClassification) pthread_join(flashstartThreadLoop, &res);

    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Flashstart resolution stats [%u categorized][%u failures]",
				 num_flashstart_categorizations, num_flashstart_fails);
  }

  if(user) free(user);
  if(pwd)  free(pwd);
  closesocket(sock);
  purgeMapping();
  purgeCache(0);
}

/* TODO: periodically calls purgeCache() */

/* **************************************************** */

void Flashstart::addMapping(const char *label, u_int8_t id) {
  struct category_mapping *s = (struct category_mapping*)malloc(sizeof(struct category_mapping));

  s->name = strdup(label), s->category = id;
  HASH_ADD_STR(mapping, name, s);

  if(id < MAX_NUM_MAPPED_CATEGORIES)
    rev_mapping[id] = s->name;
  else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many categories (%d)", id);
}

/* **************************************************** */

void Flashstart::purgeMapping() {
  struct category_mapping *current, *tmp;

  HASH_ITER(hh, mapping, current, tmp) {
    HASH_DEL(mapping, current);
    free(current->name);
    free(current);
  }
}

/* **************************************************** */

void Flashstart::purgeCache(u_int32_t idle_purge_time) {
  struct domain_cache_entry *current, *tmp;

  HASH_ITER(hh, domain_cache, current, tmp) {
    if((idle_purge_time > 0) && (current->last_use > idle_purge_time))
      ;
    else {
      HASH_DEL(domain_cache, current);
      free(current->domain);
      free(current);
    }
  }
}

/* **************************************************** */

int Flashstart::findMapping(char *label) {
  struct category_mapping *s;

  HASH_FIND_STR(mapping, label, s);

  return((s == NULL) ? -1 : s->category);
}

/* **************************************************** */

void Flashstart::initMapping() {
  mapping = NULL;

  memset(rev_mapping, 0, sizeof(rev_mapping));
  
  /* NOTE: keep in sync with host_categories in lua_utils.lua */
  addMapping("freetime", ++numCategories);
  addMapping("chat", ++numCategories);
  addMapping("onlineauctions", ++numCategories);
  addMapping("onlinegames", ++numCategories);
  addMapping("pets", ++numCategories);
  addMapping("porn", ++numCategories);
  addMapping("religion", ++numCategories);
  addMapping("phishing", ++numCategories);
  addMapping("sexuality", ++numCategories);
  addMapping("games", ++numCategories);
  addMapping("socialnetworking", ++numCategories);
  addMapping("jobsearch", ++numCategories);
  addMapping("mail", ++numCategories);
  addMapping("news", ++numCategories);
  addMapping("proxy", ++numCategories);
  addMapping("publicite", ++numCategories);
  addMapping("sports", ++numCategories);
  addMapping("vacation", ++numCategories);
  addMapping("ecommerce", ++numCategories);
  addMapping("instantmessaging", ++numCategories);
  addMapping("kidstimewasting", ++numCategories);
  addMapping("audio-video", ++numCategories);
  addMapping("books", ++numCategories);
  addMapping("government", ++numCategories);
  addMapping("malware", ++numCategories);
  addMapping("medical", ++numCategories);
  addMapping("ann", ++numCategories);
  addMapping("drugs", ++numCategories);
  addMapping("dating", ++numCategories);
  addMapping("desktopsillies", ++numCategories);
  addMapping("filehosting", ++numCategories);
  addMapping("filesharing", ++numCategories);
  addMapping("gambling", ++numCategories);
  addMapping("warez", ++numCategories);
  addMapping("radio", ++numCategories);
  addMapping("updatesites", ++numCategories);
  addMapping("financial", ++numCategories);
  addMapping("adult", ++numCategories);
  addMapping("fashion", ++numCategories);
  addMapping("showbiz", ++numCategories);
  addMapping("ict", ++numCategories);
  addMapping("company", ++numCategories);
  addMapping("education", ++numCategories);
  addMapping("searchengines", ++numCategories);
  addMapping("blog", ++numCategories);
  addMapping("association", ++numCategories);
  addMapping("music", ++numCategories);
  addMapping("legal", ++numCategories);
  addMapping("photo", ++numCategories);
  addMapping("stats", ++numCategories);
  addMapping("content", ++numCategories);
  addMapping("domainforsale", ++numCategories);
  addMapping("weapons", ++numCategories);
  addMapping("generic", ++numCategories);
}

/* **************************************************** */

static void* flashstartThreadInfiniteLoop(void* ptr) {
  return(((Flashstart*)ptr)->flashstartLoop(ptr));
}

/* **************************************************** */

void Flashstart::setCategory(struct site_categories *category, char *rsp) {
  char *tmp, *elem;
  bool found = false;
  int n = 0;

  memset(category, 0, sizeof(struct site_categories));
  elem = strtok_r(rsp, ",", &tmp);

  while(elem != NULL) {
    int id = findMapping(elem);

    if(n == MAX_NUM_CATEGORIES) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: too many categories (%d)", n);
      break;
    }

    if((id == -1) && (!strcmp(elem, NTOP_UNKNOWN_CATEGORY_STR)))
      id = NTOP_UNKNOWN_CATEGORY_ID;

    if(id == -1)
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown category '%s'", elem);
    else {
      category->categories[n++] = id, found = true;
    }

    elem = strtok_r(NULL, ",", &tmp);
  }
}

/* **************************************************** */

bool Flashstart::cacheDomainCategory(char *name, struct site_categories *category, bool check_if_present) {
  struct domain_cache_entry *entry;
  char buf[64];
  
  m.lock(__FILE__, __LINE__);

  if(check_if_present) {
    HASH_FIND_STR(domain_cache, name, entry);

    if(entry) {     
      entry->last_use = time(NULL), entry->query_in_progress = false;
      if(category) memcpy(&entry->categories, category, sizeof(struct site_categories));
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLAHSTART] Found on cache %s [%s]", name,
				   category2str(category, buf, sizeof(buf)));
      m.unlock(__FILE__, __LINE__);
      return(true);
    }
  }

  /* Add to memory cache */
  if((entry = (struct domain_cache_entry*)malloc(sizeof(struct domain_cache_entry))) != NULL) {
    entry->domain = strdup(name), entry->last_use = time(NULL);
    if(category)
      memcpy(&entry->categories, category, sizeof(struct site_categories)), entry->query_in_progress = false;
    else
      memset(&entry->categories, 0, sizeof(struct site_categories)), entry->query_in_progress = true;
    
    HASH_ADD_STR(domain_cache, domain, entry);
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLAHSTART] Cached %s [%s]", name,
				 category2str(category, buf, sizeof(buf)));

    if(++num_cached_entries > CACHED_ENTRIES_THRESHOLD)
      purgeCache(MAX_CATEGORY_CACHE_DURATION);
  }

  m.unlock(__FILE__, __LINE__);
  return(false);
}

/* **************************************************** */

char* Flashstart::category2str(struct site_categories *category, char *buf, int buf_len) {
  buf[0] = 0;

  if(category) {
    for(int i=0, idx=0; i<MAX_NUM_CATEGORIES; i++) {
      if(category->categories[i] == 0) break;

      if(category->categories[i] < MAX_NUM_MAPPED_CATEGORIES) {
	snprintf(&buf[idx], buf_len-idx-1,
		 "%s%s", (idx > 0) ? "," : "", rev_mapping[category->categories[i]]);
      } else
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid category %d", category->categories[i]);
    }
  }
  
  return(buf);
}

/* **************************************************** */

bool Flashstart::findCategory(char *name, struct site_categories *category, bool add_if_needed) {
  if(ntop->getPrefs()->is_flashstart_enabled()) {
    char buf[64] = { 0 };
    struct domain_cache_entry *entry;

    /* Search first in memory */
    m.lock(__FILE__, __LINE__);
    HASH_FIND_STR(domain_cache, name, entry);
    if(entry != NULL) {
      /* Entry found */
      char buf[64];

      entry->last_use = time(NULL);
      if(category) memcpy(category, &entry->categories, sizeof(struct site_categories));
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLAHSTART] Found on cache %s [%s]",
				   name, category2str(&entry->categories, buf, sizeof(buf)));
      m.unlock(__FILE__, __LINE__);
      return(true);
    }

    /* Searching in cache first... */
    ntop->getRedis()->getTrafficFilteringCategory(name, buf, sizeof(buf), false);

    if(buf[0] != 0) {
#ifdef DEBUG_CATEGORIZATION
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Categorized %s as %s", name, buf);
#endif

      setCategory(category, buf);
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLAHSTART] Caching %s as [%s]", name,
				   category2str(category, buf, sizeof(buf)));
      m.unlock(__FILE__, __LINE__);
      cacheDomainCategory(name, category, false);

      return(true);
    } else if(add_if_needed) {
      /* Nothing on cache: let's query Flashstart */
      m.unlock(__FILE__, __LINE__);
      queryFlashstart(name);
    }
  }

  return(false);
}

/* **************************************************** */

char* Flashstart::getCategoryName(u_int8_t id) {
  struct category_mapping *s;

  for(s = mapping; s != NULL; s = (struct category_mapping*)s->hh.next)
    if(s->category == id)
      return(s->name);

  return((char*)NTOP_UNKNOWN_CATEGORY_STR);
}

/* **************************************************** */

void Flashstart::dumpCategories(lua_State* vm, struct site_categories *category) {
  if(category->categories[0] != NTOP_UNKNOWN_CATEGORY_ID) {
    lua_newtable(vm);

    for(int i=0; i<MAX_NUM_CATEGORIES; i++) {
      if(category->categories[i] != NTOP_UNKNOWN_CATEGORY_ID) {
	for(struct category_mapping *s=mapping; s != NULL; s = (struct category_mapping*)s->hh.next)
	  if(s->category == category->categories[i]) {
	    lua_push_int_table_entry(vm, s->name, s->category);
	    break;
	  }
      }
    }

    lua_pushstring(vm, "category"); // Key
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* **************************************************** */

void Flashstart::lua(lua_State* vm) {
  lua_newtable(vm);

  for(struct category_mapping *s=mapping; s != NULL; s = (struct category_mapping*)s->hh.next) {
    lua_pushnumber(vm, s->category);
    lua_pushstring(vm, s->name);
    lua_settable(vm, -3);
  }
}

/* **************************************************** */

void Flashstart::dumpCategories(struct site_categories *category, char *buf, u_int buf_len) {
  if(category->categories[0] != NTOP_UNKNOWN_CATEGORY_ID) {
    buf[0] = '\0';

    for(int i=0; i<MAX_NUM_CATEGORIES; i++) {
      if(category->categories[i] != NTOP_UNKNOWN_CATEGORY_ID) {
	struct category_mapping *s;

	for(s=mapping; s != NULL; s = (struct category_mapping*)s->hh.next)
	  if(s->category == category->categories[i]) {
	    int l = strlen(buf);

	    snprintf(buf, buf_len-l, "%s%s",
		     (l > 0) ? "," : "",
		     s->name);
	    break;
	  }
      }
    }
  }
}

/* **************************************************** */

void Flashstart::queryFlashstart(char* symbolic_name) {
#ifdef DEBUG_CATEGORIZATION
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLASHSTART] Looking for %s", symbolic_name);
#endif

  queryDomain(sock, symbolic_name, ++num_flashstart_categorizations,
	      (struct sockaddr*)&dnsServer[dnsServerIdx],
	      sizeof(dnsServer[dnsServerIdx]));
  if(++dnsServerIdx == numDnsServers) dnsServerIdx = 0;
}

/* **************************************************** */

void Flashstart::queryDomain(int sock, char *domain, u_int queryId,
			     const struct sockaddr *to, socklen_t tolen) {
  char data[512] = { 0 }, *p, *s;
  struct dns_header *header = (struct dns_header *)data;
  u_int domain_len = strlen(domain), query_len;
  int i, n;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLASHSTART] Sending request for %s", domain);

  if(cacheDomainCategory(domain, NULL, true))
    return;

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
  u_int32_t i, rc = 0;
  u_int16_t qtype, offset;
  char qname[128], txt[128], *p;

  if(ntohs(header->num_questions) != 1) return(rc);

  p = (char*)&rsp[sizeof(struct dns_header)-1];

  for(i=0; (i < (rsp_len-sizeof(struct dns_header))) && (p[i] != 0); i++) {
    if(p[i] < 0x20) qname[i] = '.'; else qname[i] = p[i];
  }

  qname[i] = 0;
  qtype = htons(*((uint16_t *)&rsp[sizeof(struct dns_header)+i]));

  if(qtype != 0x10 /* TXT*/) return(-1);

  offset = sizeof(struct dns_header)+i+16+1;
  rsp[rsp_len] = 0;

  snprintf(txt, sizeof(txt), "%s", &rsp[offset]);

  if(qname[0] && txt[0]) {
    char *category = (char*)NTOP_UNKNOWN_CATEGORY_STR;
    struct site_categories c;

    if(!strncmp(txt, "BLACKLIST:", 10)) {
      category = &txt[10], rc = 1;
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLASHSTART] %s=%s", qname, category);
    } else
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[FLASHSTART] **** %s=%s", qname, category);
    
    ntop->getRedis()->setTrafficFilteringAddress(qname, category);
    /* Do not swap the lines as category buffer wll be modified */
    setCategory(&c, category);
    cacheDomainCategory(qname, &c, true);
  }

  return(rc);
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
    int len = recvfrom(sock, (char*)rsp, sizeof(rsp), 0,
		       (struct sockaddr*)&from, &s);

    if(len > 0 && (u_int)len > sizeof(struct dns_header))
      num += parseDNSResponse(rsp, len, &from);

    if(num > 0)
      break;
  }

  return(num);
}

/* **************************************************** */

void* Flashstart::flashstartLoop(void* ptr) {
  Flashstart *h = (Flashstart*)ptr;

  while(!ntop->getGlobals()->isShutdown()) {
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
    u_int numLoops = 0;

    /* 1 - Tell flashstart that we want to issue DNS queries */
    snprintf(url,sizeof(url), format, user, pwd);

    rsp = Utils::httpGet(url, ret, sizeof(ret)-1);
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Called %s [rsp: %s]",
				 url, rsp ? ret : "ERROR");

    if(rsp) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Waiting for Flashstart to initialize. Please wait...");

      while(true) {
	queryFlashstart((char*)"ntop.org");
	if(recvResponses(1000) > 0)
	  break;
	ntop->getTrace()->traceEvent(TRACE_NORMAL, ".");
	if(++numLoops == 10) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize Flashstart");
	  return;
	}
      }
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flashstart ready to serve requests...");

      if(!syncClassification)
	pthread_create(&flashstartThreadLoop, NULL, flashstartThreadInfiniteLoop, (void*)this);
    }
  }
}

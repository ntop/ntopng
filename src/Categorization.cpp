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

#define DEFAULT_CATEGORIZATION_KEY "9hoAtewwpC2tXRMJBfifrY24B"
#define CATEGORIZATION_URL         "http://api.block.si/getRatingurl"
#define NULL_CATEGORY              "''"

/* **************************************** */

Categorization::Categorization(char *_api_key) {
  api_key = _api_key ? strdup(_api_key) : NULL;
  num_categorized_categorizationes = num_categorized_fails = 0;
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enable host categorizazion with API key %s", api_key);
}

/* ******************************************* */

char* Categorization::findCategory(char *name, char *buf, u_int buf_len, bool add_if_needed) {
  if(ntop->getPrefs()->is_categorization_enabled()) {
    return(ntop->getRedis()->getFlowCategory(name, buf, buf_len, add_if_needed));
  } else {
    buf[0] = '\0';
    return(buf);
  }
}

/* **************************************** */

Categorization::~Categorization() {
  void *res;

  if(api_key != NULL) {
    pthread_join(categorizeThreadLoop, &res);

    ntop->getTrace()->traceEvent(TRACE_NORMAL, 
				 "Categorization resolution stats [%u categorized][%u failures]",
				 num_categorized_categorizationes, num_categorized_fails);
  }
}

/* ***************************************** */

void Categorization::categorizeHostName(char *_url, char *buf, u_int buf_len) {
  if(ntop->getPrefs()->is_categorization_enabled()) {
    char key[256];

    snprintf(key, sizeof(key), "%s.%s", DOMAIN_CATEGORY, _url);
    if(ntop->getRedis()->get(key, buf, buf_len) == 0) {
      ntop->getRedis()->expire(key, Categorization::default_expire_time);
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s => %s (cached)", _url, buf);
    } else {
      char url_buf[256], body[256];
    
      /*
	Save category into the cache so that if the categorization service is slow, we do not
	recursively add the domain into the list of domains to solve
      */
      ntop->getRedis()->set(key, (char*)NULL_CATEGORY, Categorization::default_expire_time);

      snprintf(url_buf, sizeof(url_buf), "%s?url=%s&apikey=%s", CATEGORIZATION_URL, _url, api_key);

	ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", url_buf);

      if(Utils::httpGet(url_buf, body, sizeof(body))) {
	char *doublecolumn;

	ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", body);

	if((doublecolumn = strrchr(body, ':')) != NULL) {
	  char *end;

	  doublecolumn += 2;

	  if((end = strchr(doublecolumn, '"')) != NULL) {
	    int major, minor;

	    end[0] = '\0';

	    ntop->getTrace()->traceEvent(TRACE_INFO, "%s => %s", _url, doublecolumn);

	    /* The category format is XX_YY so it can very well with into a 16 bit value */
	    if(sscanf(doublecolumn, "%d_%d", &major, &minor) != 2) {
	      if((strcmp(doublecolumn, "error") != 0) && (doublecolumn[0] != '-' /* Negative error code */))
		ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid format for category '%s'", doublecolumn);

	      doublecolumn = (char*)NULL_CATEGORY;
	    } else	    
	      ntop->getRedis()->set(key, doublecolumn,
				    Categorization::default_expire_time); /* Save category into the cache */

	    snprintf(buf, buf_len, "%s", doublecolumn);
	  }
	}
      }
    }
  } else 
    buf[0] = '\0';
}

/* **************************************************** */

static void* categorizeThreadInfiniteLoop(void* ptr) {
  Categorization *a = (Categorization*)ptr;

  return(a->categorizeLoop());
}

/* **************************************************** */

void* Categorization::categorizeLoop() {
  Redis *r = ntop->getRedis();

  while(!ntop->getGlobals()->isShutdown()) {
    char domain_name[64];

    int rc = r->popDomainToCategorize(domain_name, sizeof(domain_name));

    if((rc == 0) && (domain_name[0] != '\0')) {
      char buf[8];
      
      categorizeHostName(domain_name, buf, sizeof(buf));
    } else
      sleep(1);
  }

  return(NULL);
}

/* **************************************************** */

void Categorization::startCategorizeCategorizationLoop() {
  if(ntop->getPrefs()->is_categorization_enabled())
    pthread_create(&categorizeThreadLoop, NULL, categorizeThreadInfiniteLoop, (void*)this);
}


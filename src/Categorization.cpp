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

// Please notice that DEFAULT_CATEGORIZATION_KEY has already been defined in "src/Prefs.cpp".
#define CATEGORIZATION_URL "https://sb-ssl.google.com/safebrowsing/api/lookup"
#define CLIENT "ntopng"
#define APPVER "1.0"
#define PVER "3.0"
#define NULL_CATEGORY "''"

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

/*
  NOTICE: This function categorizes the given URL by using Google Safe Browsing API and stores
  the result into Redis Server.
  The request is performed using the HTTP GET method on a URL which has the following format:
    https://sb-ssl.google.com/safebrowsing/api/lookup?client=CLIENT&apikey=APIKEY&appver=APPVER&pver=PVER&url=ENCODED_URL
  According to Safe Browsing API reply, the websites are then classified either as "reliable" or "malware".
*/

void Categorization::categorizeHostName(char *_url, char *buf, u_int buf_len) {
  long replyCode = 0;

  if (ntop->getPrefs()->is_categorization_enabled()) {
    char key[256]; // This is the key to be stored in Redis Server.

    snprintf(key, sizeof(key), "%s.%s", DOMAIN_CATEGORY, _url); // DOMAIN_CATEGORY = "ntopng.domain.category" is declared in ntop_defines.h!
    if (ntop->getRedis()->get(key, buf, buf_len) == 0) {
      ntop->getRedis()->expire(key, Categorization::default_expire_time);
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s => %s (cached)", _url, buf);
    }
    else {
      char REQUEST_URL[1024]; // This is the URL for the GET request.
      char ENCODED_URL[512]; // This is the encoded URL which is part of the REQUEST_URL.
      char REQUEST_REPLY[256]; // This is the string that will contain the libcurl output.

      // Please do not uncomment the following line, otherwise every domain will be categorized with the NULL category!
      //ntop->getRedis()->set(key, (char*)NULL_CATEGORY, Categorization::default_expire_time); LEAVE DISABLED!

      // 1. Encode _url to ENCODED_URL.
      snprintf(ENCODED_URL, sizeof(ENCODED_URL), "%s", Utils::urlEncode((char *) _url));

      // 2. Create the REQUEST_URL for GET request.
      snprintf(REQUEST_URL, sizeof(REQUEST_URL), "%s?client=%s&apikey=%s&appver=%s&pver=%s&url=%s", CATEGORIZATION_URL, CLIENT, api_key,
        APPVER, PVER, ENCODED_URL);

      // 2.5 Print some information.
      ntop->getTrace()->traceEvent(TRACE_INFO, "Performing GET request with URL: %s", REQUEST_URL);

      // 3. Perform request and save the output to REQUEST_REPLY.
      snprintf(REQUEST_REPLY, sizeof(REQUEST_REPLY), "%s", (char *) Utils::curlHTTPGet(REQUEST_URL, &replyCode));

      // 4. Classification based on HTTP request code.
      if (replyCode == 0) { // GET request failed. Exiting on failure.
        ntop->getTrace()->traceEvent(TRACE_WARNING, "ERROR: GET request failed.");
        return;
      }
      else { // GET request was performed.
        if (replyCode == 200) {
          ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: 200 OK.");
        }
        else {
          if (replyCode == 204) {
            ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: 204 NO CONTENT.");
            if (REQUEST_REPLY[0] == '\0') {
              snprintf(REQUEST_REPLY, sizeof(REQUEST_REPLY), "%s", "reliable");
            }
          }
          else {
            if (replyCode == 400) {
              ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: 400 BAD REQUEST.");
            }
            else ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: %ld.", replyCode);
            return;
          }
        }
      }

      // 4.5 Printing some results.
      ntop->getTrace()->traceEvent(TRACE_INFO, "REPLY: It seems that %s is %s.\n", _url, REQUEST_REPLY);
      snprintf(buf, buf_len, "%s", REQUEST_REPLY);
      //std::cout << "Buf in categorizeHostName is " << buf << std::endl;

      // 5. Storing into Redis.
      //  Save category into the cache so that if the categorization service is slow, we do not
      //  recursively add the domain into the list of domains to solve.
      // std::cout << "KEY in categorizeHostName is now equal to: " << key << std::endl;
      ntop->getRedis()->set(key, REQUEST_REPLY, Categorization::default_expire_time);
    }
  }
  return;
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


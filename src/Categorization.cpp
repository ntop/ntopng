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

Categorization::Categorization(char *_api_key) {
  api_key = _api_key ? strdup(_api_key) : NULL;
  num_categorized_categorizationes = num_categorized_fails = 0;
  ntop->getTrace()->traceEvent(TRACE_INFO, "Enabled host categorizazion with API key %s", api_key);
}

/* ******************************************* */

char* Categorization::findCategory(char *name, char *buf, u_int buf_len, bool add_if_needed) {
  if(ntop->getPrefs()->is_categorization_enabled()) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "[Categorization] %s(%s, %s)", 
				 __FUNCTION__, name, add_if_needed ? "true" : "false");
    
    if(!Utils::isGoodNameToCategorize(name))
      return((char*)CATEGORIZATION_SAFE_SITE);
    else {
      char *ret = ntop->getRedis()->getFlowCategory(name, buf, buf_len, add_if_needed);
      
#if 0
      if(ret[0] && strcmp(ret, CATEGORIZATION_SAFE_SITE))
	ntop->getTrace()->traceEvent(TRACE_WARNING, "[Categorization] Site %s detected as %s", name, ret);
#endif
 
      return(ret);
    }
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

    ntop->getTrace()->traceEvent(TRACE_INFO,
				 "Categorization resolution stats [%u categorized][%u failures]",
				 num_categorized_categorizationes, num_categorized_fails);
  }
}

/* ***************************************** */

void Categorization::httpCategorizeHostName(char *_url, char *buf, u_int buf_len) {
  long replyCode = 0;

  if(ntop->getPrefs()->is_categorization_enabled()) {
    char key[256]; // This is the key to be stored in Redis Server.

    // DOMAIN_CATEGORY = "ntopng.domain.category" is declared in ntop_defines.h!
    snprintf(key, sizeof(key), "%s.%s", DOMAIN_CATEGORY, _url);
    if(ntop->getRedis()->get(key, buf, buf_len) == 0) {
      ntop->getRedis()->expire(key, Categorization::default_expire_time);
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s => %s (cached)", _url, buf);
    } else {
      char request_url[1024]; // This is the URL for the GET request.
      char categorization_response[256]; // This is the string that will contain the libcurl output.
      
      // 2. Create the request_url for GET request.
      snprintf(request_url, sizeof(request_url), "%s%s", api_key, _url);
      
      // 2.5 Print some information.
      ntop->getTrace()->traceEvent(TRACE_INFO, "Performing GET request with URL: %s", request_url);
      
      // 3. Perform request and save the output to categorization_response.
      snprintf(categorization_response, sizeof(categorization_response), 
	       "%s", (char *) Utils::curlHTTPGet(request_url, &replyCode));

      // 4. Classification based on HTTP request code.
      if(replyCode == 0) { 
	// GET request failed. Exiting on failure.
        ntop->getTrace()->traceEvent(TRACE_WARNING, "ERROR: GET request failed.");
        return;
      }

      // 4.5 Printing some results.
      ntop->getTrace()->traceEvent(TRACE_INFO, "REPLY: It seems that %s is %s.\n", _url, categorization_response);
      snprintf(buf, buf_len, "%s", categorization_response);
      //std::cout << "Buf in categorizeHostName is " << buf << std::endl;

      // 5. Storing result into Redis.
      //  Save category into the cache so that if the categorization service is slow, we do not
      //  recursively add the domain into the list of domains to solve.
      // std::cout << "KEY in categorizeHostName is now equal to: " << key << std::endl;

      ntop->getTrace()->traceEvent(TRACE_WARNING, "[Categorization] Site %s detected as %s",
				   _url, categorization_response);

      ntop->getRedis()->set(key, categorization_response, Categorization::default_expire_time);
    }
  }
}

/* ***************************************** */

/*
  NOTICE: This function categorizes the given URL by using Google Safe Browsing API and stores
  the result into Redis Server.
  The request is performed using the HTTP GET method on a URL which has the following format:
  https://sb-ssl.google.com/safebrowsing/api/lookup?client=CLIENT&key=XXXXXX&appver=1.5.2&pver=3.1&url=http%3A%2F%2Fianfette.org%2F
  According to Safe Browsing API reply, the websites are then classified either as CATEGORIZATION_SAFE_SITE or "malware".
*/

void Categorization::googleCategorizeHostName(char *_url, char *buf, u_int buf_len) {
  long replyCode = 0;

  if(ntop->getPrefs()->is_categorization_enabled()) {
    char key[256]; // This is the key to be stored in Redis Server.

    // DOMAIN_CATEGORY = "ntopng.domain.category" is declared in ntop_defines.h!
    snprintf(key, sizeof(key), "%s.%s", DOMAIN_CATEGORY, _url);
    if(ntop->getRedis()->get(key, buf, buf_len) == 0) {
      ntop->getRedis()->expire(key, Categorization::default_expire_time);
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s => %s (cached)", _url, buf);
    } else {
      char request_url[1024]; // This is the URL for the GET request.
      char encoded_url[512]; // This is the encoded URL which is part of the request_url.
      char categorization_response[256]; // This is the string that will contain the libcurl output.

      // Please do not uncomment the following line, otherwise every domain will be categorized with the NULL category!
      //ntop->getRedis()->set(key, (char*)CATEGORIZATION_NULL_CATEGORY, Categorization::default_expire_time); LEAVE DISABLED!

      // 1. Encode _url to encoded_url.
      snprintf(encoded_url, sizeof(encoded_url), "%s", Utils::urlEncode((char *) _url));

      // 2. Create the request_url for GET request.
      snprintf(request_url, sizeof(request_url),
	       "%s?client=%s&key=%s&appver=%s&pver=%s&url=%s",
	       CATEGORIZATION_URL, CATEGORIZATION_CLIENT, api_key,
	       CATEGORIZATION_APPVER, CATEGORIZATION_PVER, encoded_url);
      
      // 2.5 Print some information.
      ntop->getTrace()->traceEvent(TRACE_INFO, "Performing GET request with URL: %s", request_url);

      // 3. Perform request and save the output to categorization_response.
      snprintf(categorization_response, sizeof(categorization_response), 
	       "%s", (char *) Utils::curlHTTPGet(request_url, &replyCode));

      // 4. Classification based on HTTP request code.
      if(replyCode == 0) { // GET request failed. Exiting on failure.
        ntop->getTrace()->traceEvent(TRACE_WARNING, "ERROR: GET request failed.");
        return;
      } else { // GET request was performed.
        if(replyCode == 200) {
          ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: 200 OK.");
        } else {
          if(replyCode == 204) {
            ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: 204 NO CONTENT.");
            if(categorization_response[0] == '\0') {
              snprintf(categorization_response, sizeof(categorization_response), "%s", CATEGORIZATION_SAFE_SITE);
            }
          } else {
            if(replyCode == 400) {
              ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: 400 BAD REQUEST.");
            } else ntop->getTrace()->traceEvent(TRACE_INFO, "GET request performed with code: %ld.", replyCode);
            return;
          }
        }
      }

      // 4.5 Printing some results.
      ntop->getTrace()->traceEvent(TRACE_INFO, "REPLY: It seems that %s is %s.\n", _url, categorization_response);
      snprintf(buf, buf_len, "%s", categorization_response);
      //std::cout << "Buf in categorizeHostName is " << buf << std::endl;

      // 5. Storing result into Redis.
      //  Save category into the cache so that if the categorization service is slow, we do not
      //  recursively add the domain into the list of domains to solve.
      // std::cout << "KEY in categorizeHostName is now equal to: " << key << std::endl;

      if(strcmp(categorization_response, CATEGORIZATION_SAFE_SITE))
	 ntop->getTrace()->traceEvent(TRACE_WARNING, "[Categorization] Site %s detected as %s",
				      _url, categorization_response);

      ntop->getRedis()->set(key, categorization_response, Categorization::default_expire_time);
    }
  } 
}

/* **************************************************** */

static void* categorizeThreadInfiniteLoop(void* ptr) {
  Categorization *a = (Categorization*)ptr;

  return(a->categorizeLoop());
}

/* **************************************************** */

void* Categorization::categorizeLoop() {
  Redis *r = ntop->getRedis();
  bool useGoogle = (!strncmp(api_key, "http", 4)) ? false : true;

  while(!ntop->getGlobals()->isShutdown()) {
    char domain_name[64];

    int rc = r->popDomainToCategorize(domain_name, sizeof(domain_name));

    if((rc == 0) && (domain_name[0] != '\0')) {
      char buf[8];

      if(useGoogle)
	googleCategorizeHostName(domain_name, buf, sizeof(buf));
      else
	httpCategorizeHostName(domain_name, buf, sizeof(buf));
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


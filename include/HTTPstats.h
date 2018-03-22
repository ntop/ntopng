/*
 *
 * (C) 2014-18 - ntop.org
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

#ifndef _HTTP_STATS_H_
#define _HTTP_STATS_H_

#include "ntop_includes.h"

class Host;

struct http_query_stats {
  u_int32_t num_get, num_post, num_head, num_put, num_other;
};
struct http_response_stats {
  u_int32_t num_1xx, num_2xx, num_3xx, num_4xx, num_5xx;
};

// to be more efficient, we keep rates as 16 bit integers
// rather than float. Indeed, decimal places in request rates
// are not so informative to justify the use of floats. For example
// if a host is making 198 or 198.1 reqs/sec there is not a big deal of
// difference
struct http_response_rates {
  u_int16_t rate_1xx, rate_2xx, rate_3xx, rate_4xx, rate_5xx;
};
struct http_query_rates {
  u_int16_t rate_get, rate_post, rate_head, rate_put, rate_other;
};

enum {
  AS_SENDER  = 0,
  AS_RECEIVER
};

class HTTPstats {
 private:
  struct http_query_stats    query[2];
  struct http_response_stats response[2];
  struct http_query_rates    query_rate[2];
  struct http_response_rates response_rate[2];
  struct http_query_stats    last_query_sample[2];
  struct http_response_stats last_response_sample[2];
  struct timeval last_update_time;

  Mutex m;
  HostHash *h;
  bool warning_shown;
  VirtualHostHash *virtualHosts;

  void incRequest(struct http_query_stats *q, const char *method);
  void incResponse(struct http_response_stats *r, const char *method);

  void getRequests(const struct http_query_stats *q,
		   u_int32_t *num_get, u_int32_t *num_post, u_int32_t *num_head,
		   u_int32_t *num_put, u_int32_t *num_other);

  void getResponses(const struct http_response_stats *r,
		   u_int32_t *num_1xx, u_int32_t *num_2xx, u_int32_t *num_3xx,
		   u_int32_t *num_4xx, u_int32_t *num_5xx);

  void getRequestsRates(const struct http_query_rates *dq,
		   u_int16_t *rate_get, u_int16_t *rate_post, u_int16_t *rate_head,
		   u_int16_t *rate_put, u_int16_t *rate_other);

  void getResponsesRates(const struct http_response_rates *dr,
		   u_int16_t *rate_1xx, u_int16_t *rate_2xx, u_int16_t *rate_3xx,
		   u_int16_t *rate_4xx, u_int16_t *rate_5xx);

  void getRequestsDelta(const struct http_query_stats *q0, const struct http_query_stats *q1,
		   u_int32_t *delta_get, u_int32_t *delta_post, u_int32_t *delta_head,
		   u_int32_t *delta_put, u_int32_t *delta_other);

  void getResponsesDelta(const struct http_response_stats *r0 , const struct http_response_stats *r1,
		   u_int32_t *delta_1xx, u_int32_t *delta_2xx, u_int32_t *delta_3xx,
		   u_int32_t *delta_4xx, u_int32_t *delta_5xx);

  void luaAddCounters(lua_State *vm, bool as_sender);
  void luaAddRates(lua_State *vm, bool as_sender);
  void JSONObjectAddCounters(json_object *j, bool as_sender);
  void JSONObjectAddRates(json_object *j, bool as_sender);
  inline u_int16_t makeRate(u_int16_t v, float tdiff) { return((u_int16_t)((((float)v* 1000)/tdiff) + .5f)); }

 public:
  HTTPstats(HostHash *_h);
  ~HTTPstats();

  inline u_int32_t get_num_virtual_hosts() { return(virtualHosts ? virtualHosts->getNumEntries() : 0); }

  inline void incRequestAsReceiver(const char *method)       { incRequest(&query[AS_RECEIVER], method);        };
  inline void incRequestAsSender(const char *method)         { incRequest(&query[AS_SENDER], method);          };
  inline void incResponseAsSender(const char *return_code)   { incResponse(&response[AS_SENDER], return_code); };
  inline void incResponseAsReceiver(const char *return_code) { incResponse(&response[AS_RECEIVER], return_code);};

  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();

  void lua(lua_State *vm);
  u_int32_t luaVirtualHosts(lua_State *vm, char *virtual_host, Host *h);

  void updateStats(struct timeval *tv);
  bool updateHTTPHostRequest(char *virtual_host_name,
			     u_int32_t num_requests,
			     u_int32_t bytes_sent,
			     u_int32_t bytes_rcvd);
};

#endif /* _HTTP_STATS_H_ */

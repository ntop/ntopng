/*
 *
 * (C) 2014-16 - ntop.org
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

enum {
  AS_SENDER  = 0,
  AS_RECEIVER
};

class HTTPStats {
 private:
  struct http_query_stats query[2];
  struct http_response_stats response[2];
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

  void luaAddDirection(lua_State *vm, char *direction);
  void JSONObjectAddDirection(json_object *j, char *direction);

 public:
  HTTPStats(HostHash *_h);
  ~HTTPStats();

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

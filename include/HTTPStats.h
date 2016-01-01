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

class HTTPStats {
 private:
  struct http_query_stats query;
  struct http_response_stats response;
  Mutex m;
  HostHash *h;
  bool warning_shown;
  VirtualHostHash *virtualHosts;

 public:
  HTTPStats(HostHash *_h);
  ~HTTPStats();

  inline u_int32_t get_num_virtual_hosts() { return(virtualHosts ? virtualHosts->getNumEntries() : 0); }

  void incRequest(char *method);
  void incResponse(char *return_code);

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

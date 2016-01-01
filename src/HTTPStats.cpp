/*
 *
 * (C) 2013-16 - ntop.org
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

struct http_walk_info {
  char *virtual_host;
  Host *h;
  lua_State *vm;
  u_int32_t num;
};

/* *************************************** */

HTTPStats::HTTPStats(HostHash *_h) {
  h = _h, warning_shown = false;
  memset(&query, 0, sizeof(query));
  memset(&response, 0, sizeof(response));

  if((virtualHosts = new VirtualHostHash(NULL, 1, 4096)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: are you running out of memory?");
  }
}

/* *************************************** */

HTTPStats::~HTTPStats() {
  if(virtualHosts) delete(virtualHosts);
}

/* *************************************** */

static bool http_stats_summary(GenericHashEntry *node, void *user_data) {
  VirtualHost *host = (VirtualHost*)node;
  struct http_walk_info *info =  (struct http_walk_info*)user_data;

 if(host->get_name()) {
   if((info->virtual_host != NULL) && strcmp(info->virtual_host, host->get_name()))
     return(false); /* false = keep on walking */

   info->num++;

    lua_newtable(info->vm);

    if(info->h) {
      IpAddress *ip = info->h->get_ip();

      if(ip) {
	char ip_buf[64];

	lua_push_str_table_entry(info->vm, "server.ip", ip->print(ip_buf, sizeof(ip_buf)));
	lua_push_int_table_entry(info->vm, "server.vlan", info->h->get_vlan_id());
      }
    }

    lua_push_int_table_entry(info->vm, "bytes.sent", host->get_sent_bytes());
    lua_push_int_table_entry(info->vm, "bytes.rcvd", host->get_rcvd_bytes());
    lua_push_int_table_entry(info->vm, "http.requests", host->get_num_requests());
    lua_push_int_table_entry(info->vm, "http.act_num_requests", host->get_diff_num_requests());
    lua_push_int_table_entry(info->vm, "http.requests_trend", host->get_trend());

    lua_pushstring(info->vm, host->get_name());
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

u_int32_t HTTPStats::luaVirtualHosts(lua_State *vm, char *virtual_host, Host *h) {
  if(virtualHosts) {
    struct http_walk_info info;

    info.virtual_host = virtual_host, info.h = h, info.vm = vm, info.num = 0;
    virtualHosts->walk(http_stats_summary, &info);
    return(info.num);
  } else
    return(0);
}

/* **************************************************** */

void HTTPStats::lua(lua_State *vm) {
  lua_newtable(vm);

  if(virtualHosts) {
    struct http_walk_info info;

    info.virtual_host = NULL, info.h = NULL, info.vm = vm;

    lua_newtable(vm);
    virtualHosts->walk(http_stats_summary, &info);
    lua_pushstring(vm, "virtual_hosts");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  lua_push_int_table_entry(vm, "query.total", query.num_get+query.num_get+query.num_post+query.num_head+query.num_put);
  lua_push_int_table_entry(vm, "query.num_get", query.num_get);
  lua_push_int_table_entry(vm, "query.num_post", query.num_post);
  lua_push_int_table_entry(vm, "query.num_head", query.num_head);
  lua_push_int_table_entry(vm, "query.num_put", query.num_put);
  lua_push_int_table_entry(vm, "query.num_other", query.num_other);

  lua_push_int_table_entry(vm, "response.total", response.num_1xx+response.num_2xx+response.num_3xx+response.num_4xx+response.num_5xx);
  lua_push_int_table_entry(vm, "response.num_1xx", response.num_1xx);
  lua_push_int_table_entry(vm, "response.num_2xx", response.num_2xx);
  lua_push_int_table_entry(vm, "response.num_3xx", response.num_3xx);
  lua_push_int_table_entry(vm, "response.num_4xx", response.num_4xx);
  lua_push_int_table_entry(vm, "response.num_5xx", response.num_5xx);

  lua_pushstring(vm, "http");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

char* HTTPStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void HTTPStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  memset(&query, 0, sizeof(query)), memset(&response, 0, sizeof(response));

  if (json_object_object_get_ex(o, "query.num_get", &obj))   query.num_get = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "query.num_post", &obj))  query.num_post = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "query.num_head", &obj))  query.num_head = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "query.num_put", &obj))   query.num_put = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "query.num_other", &obj)) query.num_other = (u_int32_t)json_object_get_int64(obj);

  if (json_object_object_get_ex(o, "response.num_1xx", &obj)) response.num_1xx = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "response.num_2xx", &obj)) response.num_2xx = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "response.num_3xx", &obj)) response.num_3xx = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "response.num_4xx", &obj)) response.num_4xx = (u_int32_t)json_object_get_int64(obj);
  if (json_object_object_get_ex(o, "response.num_1xx", &obj)) response.num_1xx = (u_int32_t)json_object_get_int64(obj);
}

/* ******************************************* */

json_object* HTTPStats::getJSONObject() {
  json_object *my_object = json_object_new_object();

  if(query.num_get > 0) json_object_object_add(my_object, "query.num_get", json_object_new_int64(query.num_get));
  if(query.num_post > 0) json_object_object_add(my_object, "query.num_post", json_object_new_int64(query.num_post));
  if(query.num_head > 0) json_object_object_add(my_object, "query.num_head", json_object_new_int64(query.num_head));
  if(query.num_put > 0) json_object_object_add(my_object, "query.num_put", json_object_new_int64(query.num_put));
  if(query.num_other > 0) json_object_object_add(my_object, "query.num_other", json_object_new_int64(query.num_other));

  if(response.num_1xx > 0) json_object_object_add(my_object, "response.num_1xx", json_object_new_int64(response.num_1xx));
  if(response.num_2xx > 0) json_object_object_add(my_object, "response.num_2xx", json_object_new_int64(response.num_2xx));
  if(response.num_3xx > 0) json_object_object_add(my_object, "response.num_3xx", json_object_new_int64(response.num_3xx));
  if(response.num_4xx > 0) json_object_object_add(my_object, "response.num_4xx", json_object_new_int64(response.num_4xx));
  if(response.num_5xx > 0) json_object_object_add(my_object, "response.num_5xx", json_object_new_int64(response.num_5xx));

  return(my_object);
}

/* ******************************************* */

void HTTPStats::incRequest(char *method) {
  if(method[0] == 'G') query.num_get++;
  else if((method[0] == 'P') && (method[1] == 'O')) query.num_post++;
  else if(method[0] == 'H') query.num_head++;
  else if((method[0] == 'P') && (method[1] == 'U')) query.num_put++;
  else query.num_other++;
}

/* ******************************************* */

void HTTPStats::incResponse(char *return_code) {
  char *code;

  if(!return_code) return; else code = strchr(return_code, ' ');
  if(!code) return;

  switch(code[1]) {
  case '1': response.num_1xx++; break;
  case '2': response.num_2xx++; break;
  case '3': response.num_3xx++; break;
  case '4': response.num_4xx++; break;
  case '5': response.num_5xx++; break;
  }
}

/* ******************************************* */

bool HTTPStats::updateHTTPHostRequest(char *virtual_host_name, u_int32_t num_requests,
				      u_int32_t bytes_sent, u_int32_t bytes_rcvd) {
  VirtualHost *vh;
  bool rc = false;

  if((num_requests == 0)
     && (bytes_sent == 0)
     && (bytes_rcvd == 0))
    return(rc);

  if(!virtualHosts) return(rc); /* Looks like we're running out of memory */

  /* 
     Needed because this method can be called by both
     NetworkInterface::updateHostStats() and 
     Flow::~Flow() on the same instance and thus
     create a memory leak
  */
  m.lock(__FILE__, __LINE__);
  if((vh = virtualHosts->get(virtual_host_name)) == NULL) {
    if(virtualHosts->hasEmptyRoom()) {
      if((vh = new VirtualHost(h, virtual_host_name)) == NULL) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: are you running out of memory?");
      } else {	
	if(virtualHosts->add(vh) == false) {
	  /* Unable to add a new virtual host */
	  delete vh;
	  vh = NULL;
	} else
	  rc = true;
      }
    } else {
      if(!warning_shown) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, 
				     "Too many virtual hosts %u: enlarge hash", 
				     virtualHosts->getNumEntries());
	warning_shown = true;
      }
    }
  }
  m.unlock(__FILE__, __LINE__);

  if(vh)
    vh->incStats(num_requests, bytes_sent, bytes_rcvd);

  return(rc);
}

/* *************************************** */

static bool update_http_stats(GenericHashEntry *node, void *user_data) {
  VirtualHost *host = (VirtualHost*)node;

  host->update_stats();
  return(false); /* false = keep on walking */
}

/* ******************************************* */

void HTTPStats::updateStats(struct timeval *tv) {
  if(virtualHosts) {
    virtualHosts->walk(update_http_stats, tv);
    virtualHosts->purgeIdle();
  }
}

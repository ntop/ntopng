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

void HTTPStats::getRequests(const struct http_query_stats *q,
			    u_int32_t *num_get, u_int32_t *num_post, u_int32_t *num_head,
			    u_int32_t *num_put, u_int32_t *num_other){
  if (q == NULL)
    return;
  *num_get   += q->num_get;
  *num_post  += q->num_post;
  *num_head  += q->num_head;
  *num_put   += q->num_put;
  *num_other += q->num_other;
}

void HTTPStats::getResponses(const struct http_response_stats *r,
			     u_int32_t *num_1xx, u_int32_t *num_2xx, u_int32_t *num_3xx,
			     u_int32_t *num_4xx, u_int32_t *num_5xx){
  if (r == NULL)
    return;
  *num_1xx  += r->num_1xx;
  *num_2xx  += r->num_2xx;
  *num_3xx  += r->num_3xx;
  *num_4xx  += r->num_4xx;
  *num_5xx  += r->num_5xx;
}

void HTTPStats::luaAddDirection(lua_State *vm, char* direction) {
  u_int32_t num_get = 0, num_post = 0, num_head = 0, num_put = 0, num_other = 0;
  u_int32_t num_1xx = 0, num_2xx = 0, num_3xx = 0, num_4xx = 0, num_5xx =0;
  char buf[64];

  if(strncmp(direction, (char*)".as_sender", 9)    == 0 || direction[0] == '\0'){
    getRequests(&query[AS_SENDER], &num_get, &num_post, &num_head, &num_put, &num_other);
    getResponses(&response[AS_SENDER], &num_1xx, &num_2xx, &num_3xx, &num_4xx, &num_5xx);
  }

  if(strncmp(direction, (char*)".as_receiver", 11) == 0 || direction[0] == '\0'){
    getRequests(&query[AS_RECEIVER], &num_get, &num_post, &num_head, &num_put, &num_other);
    getResponses(&response[AS_RECEIVER], &num_1xx, &num_2xx, &num_3xx, &num_4xx, &num_5xx);
  }

  snprintf(buf, sizeof(buf), "query%s.total", direction);
  lua_push_int_table_entry(vm, buf, num_get + num_post + num_head + num_put + num_other);

  snprintf(buf, sizeof(buf), "query%s.num_get", direction);
  lua_push_int_table_entry(vm, buf, num_get);

  snprintf(buf, sizeof(buf), "query%s.num_post", direction);
  lua_push_int_table_entry(vm, buf, num_post);

  snprintf(buf, sizeof(buf), "query%s.num_head", direction);
  lua_push_int_table_entry(vm, buf, num_head);

  snprintf(buf, sizeof(buf), "query%s.num_put", direction);
  lua_push_int_table_entry(vm, buf, num_put);

  snprintf(buf, sizeof(buf), "query%s.num_other", direction);
  lua_push_int_table_entry(vm, buf, num_other);

  snprintf(buf, sizeof(buf), "response%s.total", direction);
  lua_push_int_table_entry(vm, buf, num_1xx + num_2xx + num_3xx + num_4xx + num_5xx);

  snprintf(buf, sizeof(buf), "response%s.num_1xx", direction);
  lua_push_int_table_entry(vm, buf, num_1xx);

  snprintf(buf, sizeof(buf), "response%s.num_2xx", direction);
  lua_push_int_table_entry(vm, buf, num_2xx);

  snprintf(buf, sizeof(buf), "response%s.num_3xx", direction);
  lua_push_int_table_entry(vm, buf, num_3xx);

  snprintf(buf, sizeof(buf), "response%s.num_4xx", direction);
  lua_push_int_table_entry(vm, buf, num_4xx);

  snprintf(buf, sizeof(buf), "response%s.num_5xx", direction);
  lua_push_int_table_entry(vm, buf, num_5xx);
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

  luaAddDirection(vm, (char*)"\0"); /* sum sender + receiver */
  luaAddDirection(vm, (char*)".as_sender");
  luaAddDirection(vm, (char*)".as_receiver");

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
  struct http_query_stats    *q;
  struct http_response_stats *r;
  const char *        direction;
  char buf[64];
  const char *directions[2]  = {".as_sender", ".as_receiver"};
  const u_int8_t indices[2]  = {AS_SENDER,       AS_RECEIVER};

  if(!o) return;

  memset(&query, 0, sizeof(query)), memset(&response, 0, sizeof(response));

  for(u_int8_t i = 0; i <2; i++){
    direction = directions[i];
    q = &query[indices[i]];
    r = &response[indices[i]];

    snprintf(buf, sizeof(buf), "query%s.num_get", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      q->num_get = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "query%s.num_post", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      q->num_post = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "query%s.num_head", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      q->num_head = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "query%s.num_put", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      q->num_put = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "query%s.num_other", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      q->num_other = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "response%s.num_1xx", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      r->num_1xx = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "response%s.num_2xx", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      r->num_2xx = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "response%s.num_3xx", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      r->num_3xx = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "response%s.num_4xx", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      r->num_4xx = (u_int32_t)json_object_get_int64(obj);

    snprintf(buf, sizeof(buf), "response%s.num_5xx", direction);
    if (json_object_object_get_ex(o, buf, &obj))
      r->num_5xx = (u_int32_t)json_object_get_int64(obj);
  }
}

/* ******************************************* */

void  HTTPStats::JSONObjectAddDirection(json_object *my_object, char *direction) {
  u_int32_t num_get = 0, num_post = 0, num_head = 0, num_put = 0, num_other = 0;
  u_int32_t num_1xx = 0, num_2xx = 0, num_3xx = 0, num_4xx = 0, num_5xx =0;
  char buf[64];

  if(my_object == NULL)
    return;

  if(strncmp(direction, (char*)".as_sender", 9)         == 0){
    getRequests(&query[AS_SENDER], &num_get, &num_post, &num_head, &num_put, &num_other);
    getResponses(&response[AS_SENDER], &num_1xx, &num_2xx, &num_3xx, &num_4xx, &num_5xx);
  }else if(strncmp(direction, (char*)".as_receiver", 11) == 0){
    getRequests(&query[AS_RECEIVER], &num_get, &num_post, &num_head, &num_put, &num_other);
    getResponses(&response[AS_RECEIVER], &num_1xx, &num_2xx, &num_3xx, &num_4xx, &num_5xx);
  } else {
    return;
  }

  if(num_get > 0){
    snprintf(buf, sizeof(buf), "query%s.num_get", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_get));
  }

  if(num_post > 0){
    snprintf(buf, sizeof(buf), "query%s.num_post", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_post));
  }

  if(num_head > 0){
    snprintf(buf, sizeof(buf), "query%s.num_head", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_head));
  }

  if(num_put > 0){
    snprintf(buf, sizeof(buf), "query%s.num_put", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_put));
  }

  if(num_other > 0){
    snprintf(buf, sizeof(buf), "query%s.num_other", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_other));
  }

  if(num_1xx > 0){
    snprintf(buf, sizeof(buf), "response%s.num_1xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_1xx));
  }

  if(num_2xx > 0){
    snprintf(buf, sizeof(buf), "response%s.num_2xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_2xx));
  }

  if(num_3xx > 0){
    snprintf(buf, sizeof(buf), "response%s.num_3xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_3xx));
  }

  if(num_4xx > 0){
    snprintf(buf, sizeof(buf), "response%s.num_4xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_4xx));
  }

  if(num_5xx > 0){
    snprintf(buf, sizeof(buf), "response%s.num_5xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(num_5xx));
  }
}

/* ******************************************* */

json_object* HTTPStats::getJSONObject() {
  json_object *my_object = json_object_new_object();
  JSONObjectAddDirection(my_object, (char*)".as_sender");
  JSONObjectAddDirection(my_object, (char*)".as_receiver");
  return(my_object);
}

/* ******************************************* */

void HTTPStats::incRequest(struct http_query_stats *q, const char *method) {
  if(method[0] == 'G') q->num_get++;
  else if((method[0] == 'P') && (method[1] == 'O')) q->num_post++;
  else if(method[0] == 'H') q->num_head++;
  else if((method[0] == 'P') && (method[1] == 'U')) q->num_put++;
  else q->num_other++;
}

/* ******************************************* */

void HTTPStats::incResponse(struct http_response_stats *r, const char *return_code) {
  char *code;

  if(!return_code) return; else code = strchr(return_code, ' ');
  if(!code) return;

  switch(code[1]) {
  case '1': r->num_1xx++; break;
  case '2': r->num_2xx++; break;
  case '3': r->num_3xx++; break;
  case '4': r->num_4xx++; break;
  case '5': r->num_5xx++; break;
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

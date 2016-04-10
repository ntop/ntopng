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
  struct timeval tv;

  h = _h, warning_shown = false;
  memset(&query, 0, sizeof(query));
  memset(&response, 0, sizeof(response));
  memset(&query_rate, 0, sizeof(query_rate));
  memset(&response_rate, 0, sizeof(response_rate));
  memset(&last_query_sample, 0, sizeof(last_query_sample));
  memset(&last_response_sample, 0, sizeof(last_response_sample));

  gettimeofday(&tv, NULL);
  memcpy(&last_update_time, &tv, sizeof(struct timeval));
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

/* *************************************** */

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

/* *************************************** */

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

/* *************************************** */

void HTTPStats::getRequestsRates(const struct http_query_rates *dq,
				 u_int16_t *rate_get, u_int16_t *rate_post, u_int16_t *rate_head,
				 u_int16_t *rate_put, u_int16_t *rate_other){
  if (dq == NULL)
    return;
  *rate_get   += dq->rate_get;
  *rate_post  += dq->rate_post;
  *rate_head  += dq->rate_head;
  *rate_put   += dq->rate_put;
  *rate_other += dq->rate_other;
}

/* *************************************** */

void HTTPStats::getResponsesRates(const struct http_response_rates *dr,
				  u_int16_t *rate_1xx, u_int16_t *rate_2xx, u_int16_t *rate_3xx,
				  u_int16_t *rate_4xx, u_int16_t *rate_5xx){
  if (dr == NULL)
    return;
  *rate_1xx  += dr->rate_1xx;
  *rate_2xx  += dr->rate_2xx;
  *rate_3xx  += dr->rate_3xx;
  *rate_4xx  += dr->rate_4xx;
  *rate_5xx  += dr->rate_5xx;
}

/* *************************************** */

void HTTPStats::getRequestsDelta(const struct http_query_stats *q0, const struct http_query_stats *q1,
				 u_int32_t *delta_get, u_int32_t *delta_post, u_int32_t *delta_head,
				 u_int32_t *delta_put, u_int32_t *delta_other){
  if (q0 == NULL || q1 == NULL)
    return;
  *delta_get   += q1->num_get   - q0->num_get;
  *delta_post  += q1->num_post  - q0->num_post;
  *delta_head  += q1->num_head  - q0->num_head;
  *delta_put   += q1->num_put   - q0->num_put;
  *delta_other += q1->num_other - q0->num_other;
}

/* *************************************** */

void HTTPStats::getResponsesDelta(const struct http_response_stats *r0, const struct http_response_stats *r1,
				  u_int32_t *delta_1xx, u_int32_t *delta_2xx, u_int32_t *delta_3xx,
				  u_int32_t *delta_4xx, u_int32_t *delta_5xx){
  if (r0 == NULL || r1 == NULL)
    return;
  *delta_1xx  += r1->num_1xx - r0->num_1xx;
  *delta_2xx  += r1->num_2xx - r0->num_2xx;
  *delta_3xx  += r1->num_3xx - r0->num_3xx;
  *delta_4xx  += r1->num_4xx - r0->num_4xx;
  *delta_5xx  += r1->num_5xx - r0->num_5xx;
}

/* *************************************** */

void HTTPStats::luaAddCounters(lua_State *vm, char* direction) {
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

/* *************************************** */

void HTTPStats::luaAddRates(lua_State *vm, char* direction) {
  u_int16_t rate_get = 0, rate_post = 0, rate_head = 0, rate_put = 0, rate_other = 0;
  u_int16_t rate_1xx = 0, rate_2xx = 0, rate_3xx = 0, rate_4xx = 0, rate_5xx =0;
  char buf[64];

  if(strncmp(direction, (char*)".as_sender", 9)    == 0 || direction[0] == '\0'){
    getRequestsRates(&query_rate[AS_SENDER], &rate_get, &rate_post, &rate_head, &rate_put, &rate_other);
    getResponsesRates(&response_rate[AS_SENDER], &rate_1xx, &rate_2xx, &rate_3xx, &rate_4xx, &rate_5xx);
  }

  if(strncmp(direction, (char*)".as_receiver", 11) == 0 || direction[0] == '\0'){
    getRequestsRates(&query_rate[AS_RECEIVER], &rate_get, &rate_post, &rate_head, &rate_put, &rate_other);
    getResponsesRates(&response_rate[AS_RECEIVER], &rate_1xx, &rate_2xx, &rate_3xx, &rate_4xx, &rate_5xx);
  }

  snprintf(buf, sizeof(buf), "query%s.rate_total", direction);
  //  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s %f", buf, rate_get + rate_post + rate_head + rate_put + rate_other);
  lua_push_int_table_entry(vm, buf, rate_get + rate_post + rate_head + rate_put + rate_other);

  snprintf(buf, sizeof(buf), "query%s.rate_get", direction);
  lua_push_int_table_entry(vm, buf, rate_get);

  snprintf(buf, sizeof(buf), "query%s.rate_post", direction);
  lua_push_int_table_entry(vm, buf, rate_post);

  snprintf(buf, sizeof(buf), "query%s.rate_head", direction);
  lua_push_int_table_entry(vm, buf, rate_head);

  snprintf(buf, sizeof(buf), "query%s.rate_put", direction);
  lua_push_int_table_entry(vm, buf, rate_put);

  snprintf(buf, sizeof(buf), "query%s.rate_other", direction);
  lua_push_int_table_entry(vm, buf, rate_other);

  snprintf(buf, sizeof(buf), "response%s.rate_total", direction);
  lua_push_int_table_entry(vm, buf, rate_1xx + rate_2xx + rate_3xx + rate_4xx + rate_5xx);

  snprintf(buf, sizeof(buf), "response%s.rate_1xx", direction);
  lua_push_int_table_entry(vm, buf, rate_1xx);

  snprintf(buf, sizeof(buf), "response%s.rate_2xx", direction);
  lua_push_int_table_entry(vm, buf, rate_2xx);

  snprintf(buf, sizeof(buf), "response%s.rate_3xx", direction);
  lua_push_int_table_entry(vm, buf, rate_3xx);

  snprintf(buf, sizeof(buf), "response%s.rate_4xx", direction);
  lua_push_int_table_entry(vm, buf, rate_4xx);

  snprintf(buf, sizeof(buf), "response%s.rate_5xx", direction);
  lua_push_int_table_entry(vm, buf, rate_5xx);
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

  luaAddCounters(vm, (char*)"\0"); /* sum sender + receiver */
  luaAddCounters(vm, (char*)".as_sender");
  luaAddCounters(vm, (char*)".as_receiver");
  luaAddRates(vm, (char*)"\0"); /* sum sender + receiver */
  luaAddRates(vm, (char*)".as_sender");
  luaAddRates(vm, (char*)".as_receiver");

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

  // please keep in mind that we no not deserialize rates
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

  memcpy(&last_query_sample,    &query,    sizeof(query));
  memcpy(&last_response_sample, &response, sizeof(response));
  struct timeval tv;
  gettimeofday(&tv, NULL);
  memcpy(&last_update_time, &tv, sizeof(struct timeval));
}

/* ******************************************* */

void  HTTPStats::JSONObjectAddCounters(json_object *my_object, char *direction) {
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

void  HTTPStats::JSONObjectAddRates(json_object *my_object, char *direction) {
  u_int16_t rate_get = 0, rate_post = 0, rate_head = 0, rate_put = 0, rate_other = 0;
  u_int16_t rate_1xx = 0, rate_2xx  = 0, rate_3xx  = 0, rate_4xx = 0, rate_5xx   = 0;
  char buf[64];

  if(my_object == NULL)
    return;

  if(strncmp(direction, (char*)".as_sender", 9)         == 0){
    getRequestsRates(&query_rate[AS_SENDER], &rate_get, &rate_post, &rate_head, &rate_put, &rate_other);
    getResponsesRates(&response_rate[AS_SENDER], &rate_1xx, &rate_2xx, &rate_3xx, &rate_4xx, &rate_5xx);
  }else if(strncmp(direction, (char*)".as_receiver", 11) == 0){
    getRequestsRates(&query_rate[AS_RECEIVER], &rate_get, &rate_post, &rate_head, &rate_put, &rate_other);
    getResponsesRates(&response_rate[AS_RECEIVER], &rate_1xx, &rate_2xx, &rate_3xx, &rate_4xx, &rate_5xx);
  } else {
    return;
  }

  if(rate_get > 0){
    snprintf(buf, sizeof(buf), "query%s.rate_get", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_get));
  }

  if(rate_post > 0){
    snprintf(buf, sizeof(buf), "query%s.rate_post", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_post));
  }

  if(rate_head > 0){
    snprintf(buf, sizeof(buf), "query%s.rate_head", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_head));
  }

  if(rate_put > 0){
    snprintf(buf, sizeof(buf), "query%s.rate_put", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_put));
  }

  if(rate_other > 0){
    snprintf(buf, sizeof(buf), "query%s.rate_other", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_other));
  }

  if(rate_1xx > 0){
    snprintf(buf, sizeof(buf), "response%s.rate_1xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_1xx));
  }

  if(rate_2xx > 0){
    snprintf(buf, sizeof(buf), "response%s.rate_2xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_2xx));
  }

  if(rate_3xx > 0){
    snprintf(buf, sizeof(buf), "response%s.rate_3xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_3xx));
  }

  if(rate_4xx > 0){
    snprintf(buf, sizeof(buf), "response%s.rate_4xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_4xx));
  }

  if(rate_5xx > 0){
    snprintf(buf, sizeof(buf), "response%s.rate_5xx", direction);
    json_object_object_add(my_object, buf, json_object_new_int64(rate_5xx));
  }
}

/* ******************************************* */

json_object* HTTPStats::getJSONObject() {
  json_object *my_object = json_object_new_object();
  JSONObjectAddCounters(my_object, (char*)".as_sender");
  JSONObjectAddCounters(my_object, (char*)".as_receiver");
  JSONObjectAddRates(my_object, (char*)".as_sender");
  JSONObjectAddRates(my_object, (char*)".as_receiver");
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
  const char *code;

  if(!return_code)
    return;

  code = strchr(return_code, ' ');
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
  float tdiff_msec = ((float)(tv->tv_sec-last_update_time.tv_sec)*1000)+((tv->tv_usec-last_update_time.tv_usec)/(float)1000);
  if (tdiff_msec < 1000)
    return;  // too earl

  if(virtualHosts) {
    virtualHosts->walk(update_http_stats, tv);
    virtualHosts->purgeIdle();
  }

  // refresh the last update time with the new values
  // also refresh the statistics on request variations
  const u_int8_t indices[2]  = {AS_SENDER, AS_RECEIVER};
  for(u_int8_t i = 0; i < 2 ; i++){
    u_int8_t direction = indices[i];
    struct http_query_rates    *dq = &query_rate[direction];
    struct http_response_rates *dr = &response_rate[direction];
    u_int32_t      d_get = 0,      d_post = 0,      d_head = 0,      d_put = 0,      d_other = 0;
    u_int32_t      d_1xx = 0,      d_2xx  = 0,       d_3xx = 0,      d_4xx = 0,        d_5xx = 0;

    getRequestsDelta(&last_query_sample[direction], &query[direction], &d_get, &d_post, &d_head, &d_put, &d_other);
    getResponsesDelta(&last_response_sample[direction],&response[direction], &d_1xx, &d_2xx, &d_3xx, &d_4xx, &d_5xx);

    dq -> rate_get   = (u_int16_t)(d_get   * 1000 / tdiff_msec + .5f);
    dq -> rate_post  = (u_int16_t)(d_post  * 1000 / tdiff_msec + .5f);
    dq -> rate_head  = (u_int16_t)(d_head  * 1000 / tdiff_msec + .5f);
    dq -> rate_put   = (u_int16_t)(d_put   * 1000 / tdiff_msec + .5f);
    dq -> rate_other = (u_int16_t)(d_other * 1000 / tdiff_msec + .5f);

    dr -> rate_1xx   = (u_int16_t)(d_1xx   * 1000 / tdiff_msec + .5f);
    dr -> rate_2xx   = (u_int16_t)(d_2xx   * 1000 / tdiff_msec + .5f);
    dr -> rate_3xx   = (u_int16_t)(d_3xx   * 1000 / tdiff_msec + .5f);
    dr -> rate_4xx   = (u_int16_t)(d_4xx   * 1000 / tdiff_msec + .5f);
    dr -> rate_5xx   = (u_int16_t)(d_5xx   * 1000 / tdiff_msec + .5f);
  }

  last_update_time.tv_sec  = tv->tv_sec;
  last_update_time.tv_usec = tv->tv_usec;
  memcpy(&last_query_sample,    &query,    sizeof(query));
  memcpy(&last_response_sample, &response, sizeof(response));
}

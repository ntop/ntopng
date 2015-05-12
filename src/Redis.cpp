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

#if !defined(HAVE_HIREDIS) && !defined(WIN32)
#include "third-party/hiredis/hiredis.c"
#include "third-party/hiredis/net.c"
#include "third-party/hiredis/sds.c"
#endif

/* **************************************************** */

static void* esLoop(void* ptr) {
  ntop->getRedis()->indexESdata();
  return(NULL);
}

/* **************************************** */

Redis::Redis(char *_redis_host, u_int16_t _redis_port, u_int8_t _redis_db_id) {
  redis_host = _redis_host, redis_port= _redis_port, redis_db_id = _redis_db_id;

  redis = NULL;
  reconnectRedis();

  l = new Mutex();
  setDefaults();

  if(ntop->getPrefs()->do_dump_flows_on_es())
    pthread_create(&esThreadLoop, NULL, esLoop, (void*)this);
}

/* **************************************** */

Redis::~Redis() {
  redisFree(redis);
  delete l;
}

/* **************************************** */

void Redis::reconnectRedis() {
  struct timeval timeout = { 1, 500000 }; // 1.5 seconds
  redisReply *reply;

  if(redis != NULL) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Redis has disconnected: reconnecting...");
    redisFree(redis);
  }

  redis = redisConnectWithTimeout(redis_host, redis_port, timeout);

  if(redis) reply = (redisReply*)redisCommand(redis, "PING"); else reply = NULL;
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if((redis == NULL) || (reply == NULL)) {
  redis_error_handler:
    ntop->getTrace()->traceEvent(TRACE_ERROR, "ntopng requires redis server to be up and running");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Please start it and try again or use -r");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "to specify a redis server other than the default");
    _exit(-1);
  } else {
    freeReplyObject(reply);

    reply = (redisReply*)redisCommand(redis, "SELECT %u", redis_db_id);
    if(reply && (reply->type == REDIS_REPLY_ERROR)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
      goto redis_error_handler;
    } else
      freeReplyObject(reply);
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Successfully connected to Redis %s:%u@%u",
			       redis_host, redis_port, redis_db_id);
}

/* **************************************** */

int Redis::expire(char *key, u_int expire_sec) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "EXPIRE %s %u", key, expire_sec);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::get(char *key, char *rsp, u_int rsp_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "GET %s", key);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str) {
    snprintf(rsp, rsp_len, "%s", reply->str), rc = 0;
  } else
    rsp[0] = 0, rc = -1;

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::hashGet(char *key, char *field, char *rsp, u_int rsp_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "HGET %s %s", key, field);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str) {
    snprintf(rsp, rsp_len, "%s", reply->str), rc = 0;
  } else
    rsp[0] = 0, rc = -1;
  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::hashSet(char *key, char *field, char *value) {
  int rc = 0;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "HSET %s %s %s", key, field, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = -1;
  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::hashDel(char *key, char *field) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "HDEL %s %s", key, field);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply) {
    freeReplyObject(reply), rc = 0;
  } else
    rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::set(char *key, char *value, u_int expire_secs) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "SET %s %s", key, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;

  if((rc == 0) && (expire_secs != 0)) {
    reply = (redisReply*)redisCommand(redis, "EXPIRE %s %u", key, expire_secs);
    if(!reply) reconnectRedis();
    if(reply && (reply->type == REDIS_REPLY_ERROR))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  }
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

char* Redis::popSet(char *pop_name, char *rsp, u_int rsp_len) {
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "SPOP %s", pop_name);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str) {
    snprintf(rsp, rsp_len, "%s", reply->str);
  } else
    rsp[0] = 0;

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rsp);
}

/* **************************************** */

/*
  Increment a key and return its update value
*/
u_int32_t Redis::incrKey(char *key) {
  u_int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "INCR %s", key);
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = 0;
    else
      rc = (u_int)reply->integer;

    freeReplyObject(reply);
  } else {
    if(!reply) reconnectRedis();
    rc = -1;
  }

  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

/*
  Increment key.member of +value and keeps at most trim_len elements
*/
int Redis::zincrbyAndTrim(char *key, char *member, u_int value, u_int trim_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "ZINCRBY %s %u", key, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;

  if((rc == 0) && (trim_len > 0)) {
    reply = (redisReply*)redisCommand(redis, "ZREMRANGEBYRANK %s 0 %u", key, -1*trim_len);
    if(!reply) reconnectRedis();
    if(reply && (reply->type == REDIS_REPLY_ERROR))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  }
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::keys(const char *pattern, char ***keys_p) {
  int rc = 0;
  u_int i;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "KEYS %s", pattern);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && (reply->type == REDIS_REPLY_ARRAY)) {
    (*keys_p) = (char**) malloc(reply->elements * sizeof(char*));
    rc = (int)reply->elements;

    for(i = 0; i < reply->elements; i++) {
      (*keys_p)[i] = strdup(reply->element[i]->str);
    }
  }

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::hashKeys(const char *pattern, char ***keys_p) {
  int rc = 0;
  u_int i;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "HKEYS %s", pattern);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  (*keys_p) = NULL;

  if(reply && (reply->type == REDIS_REPLY_ARRAY)) {
    rc = (int)reply->elements;

    if(rc > 0) {
      if(((*keys_p) = (char**)malloc(reply->elements * sizeof(char*))) != NULL) {    
	
	for(i = 0; i < reply->elements; i++)
	  (*keys_p)[i] = strdup(reply->element[i]->str);
      }
    }
  }

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::del(char *key) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "DEL %s", key);
  if(!reply) reconnectRedis();

  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::pushHostToHTTPBL(char *hostname, bool dont_check_for_existance, bool localHost) {
  if(!ntop->getPrefs()->is_httpbl_enabled()) return(0);
  if(hostname == NULL) return(-1);
  return(pushHost(HTTPBL_CACHE, HTTPBL_TO_RESOLVE, hostname, dont_check_for_existance, localHost));
}

/* **************************************** */

int Redis::pushHostToResolve(char *hostname, bool dont_check_for_existance, bool localHost) {
  if(!ntop->getPrefs()->is_dns_resolution_enabled()) return(0);
  if(hostname == NULL) return(-1);
  return(pushHost(DNS_CACHE, DNS_TO_RESOLVE, hostname, dont_check_for_existance, localHost));
}

/* **************************************** */

int Redis::pushHost(const char* ns_cache, const char* ns_list, char *hostname,
		    bool dont_check_for_existance, bool localHost) {
  int rc = 0;
  char key[CONST_MAX_LEN_REDIS_KEY];
  bool found;
  redisReply *reply;

  if(hostname == NULL) return(-1);

  snprintf(key, sizeof(key), "%s.%s", ns_cache, hostname);

  l->lock(__FILE__, __LINE__);

  if(dont_check_for_existance)
    found = false;
  else {
    /*
      Add only if the address has not been resolved yet
    */

    reply = (redisReply*)redisCommand(redis, "GET %s", key);
    if(!reply) reconnectRedis();

    if(reply && (reply->type == REDIS_REPLY_ERROR))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

    if(reply && reply->str)
      found = true;
    else
      found = false;

    if(reply)
      freeReplyObject(reply);
    else
      rc = -1;
  }

  l->unlock(__FILE__, __LINE__);

  if(!found) {
    /* Add to the list of addresses to resolve */

    if(localHost)
      rc = rpush(ns_list, hostname, MAX_NUM_QUEUED_ADDRS);
    else
      rc = lpush(ns_list, hostname, MAX_NUM_QUEUED_ADDRS);
  } else
    reply = 0;

  return(rc);
}

/* **************************************** */

int Redis::popHostToHTTPBL(char *hostname, u_int hostname_len) {
  return(popHost(HTTPBL_TO_RESOLVE, hostname, hostname_len));
}

/* **************************************** */

int Redis::popHostToResolve(char *hostname, u_int hostname_len) {
  return(popHost(DNS_TO_RESOLVE, hostname, hostname_len));
}

/* **************************************** */

int Redis::popHost(const char* ns_list, char *hostname, u_int hostname_len) {
  return(lpop(ns_list, hostname, hostname_len));
}

/* **************************************** */

char* Redis::getHTTPBLCategory(char *numeric_ip, char *buf,
			       u_int buf_len, bool categorize_if_unknown) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  redisReply *reply;

  buf[0] = '\0';

  if(!ntop->getPrefs()->is_httpbl_enabled())  return(NULL);

  l->lock(__FILE__, __LINE__);

  snprintf(key, sizeof(key), "%s.%s", HTTPBL_CACHE, numeric_ip);

  /*
    Add only if the ip has not been checked against the blacklist
  */
  reply = (redisReply*)redisCommand(redis, "GET %s", key);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str) {
    snprintf(buf, buf_len, "%s", reply->str);
    freeReplyObject(reply);
  } else {
    buf[0] = '\0';

    if(categorize_if_unknown) {
      reply = (redisReply*)redisCommand(redis, "RPUSH %s %s", HTTPBL_TO_RESOLVE, numeric_ip);
      if(!reply) reconnectRedis();
      if(reply && (reply->type == REDIS_REPLY_ERROR))
	ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
      if(reply) freeReplyObject(reply);
    }
  }

  l->unlock(__FILE__, __LINE__);

  return(buf);
}

/* **************************************** */

char* Redis::getFlowCategory(char *domainname, char *buf,
			     u_int buf_len, bool categorize_if_unknown) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  redisReply *reply;

  buf[0] = 0;

  if(!ntop->getPrefs()->is_categorization_enabled())  return(NULL);

  /* Check if the host is 'categorizable' */
  if(Utils::isIPAddress(domainname)) {
    return(buf);
  }

  l->lock(__FILE__, __LINE__);

  snprintf(key, sizeof(key), "%s.%s", DOMAIN_CATEGORY, domainname);

  /*
    Add only if the domain has not been categorized yet
  */
  reply = (redisReply*)redisCommand(redis, "GET %s", key);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str) {
    snprintf(buf, buf_len, "%s", reply->str);
    freeReplyObject(reply);
  } else {
    buf[0] = 0;

    if(categorize_if_unknown) {
      reply = (redisReply*)redisCommand(redis, "RPUSH %s %s", DOMAIN_TO_CATEGORIZE, domainname);
      if(!reply) reconnectRedis();
      if(reply && (reply->type == REDIS_REPLY_ERROR))
	ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
      if(reply) freeReplyObject(reply);
    }
  }

  l->unlock(__FILE__, __LINE__);

  return(buf);
}

/* **************************************** */

int Redis::popDomainToCategorize(char *domainname, u_int domainname_len) {
  return(lpop(DOMAIN_TO_CATEGORIZE, domainname, domainname_len));
}

/* **************************************** */

void Redis::setDefaults() {
  char value[CONST_MAX_LEN_REDIS_VALUE];

  setResolvedAddress((char*)"127.0.0.1", (char*)"localhost");
  setResolvedAddress((char*)"255.255.255.255", (char*)"Broadcast");
  setResolvedAddress((char*)"0.0.0.0", (char*)"NoIP");

  if(get((char*)"ntopng.user.admin.password", value, sizeof(value)) < 0) {
    set((char*)"ntopng.user.admin.password", (char*)"21232f297a57a5a743894a0e4a801fc3");
    set((char*)"ntopng.user.admin.full_name", (char*)"ntopng Administrator");
    set((char*)"ntopng.user.admin.group", (char*)"administrator");
    set((char*)"ntopng.user.admin.allowed_nets", (char*)"0.0.0.0/0,::/0");
  }
}

/* **************************************** */

int Redis::getAddressHTTPBL(char *numeric_ip,
			    NetworkInterface *iface,
			    char *rsp, u_int rsp_len,
			    bool queue_if_not_found) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  int rc;

  rsp[0] = '\0';
  snprintf(key, sizeof(key), "%s.%s", HTTPBL_CACHE, numeric_ip);

  rc = get(key, rsp, rsp_len);

  if(rc != 0) {
    if(queue_if_not_found) {
      char buf[64];

      snprintf(buf, sizeof(buf), "%s@%s", numeric_ip, iface->get_name());
      pushHostToHTTPBL(buf, true, false);
    }
  } else {
    /* We need to extend expire */

    expire(numeric_ip, HTTPBL_CACHE_DURATIION /* expire */);
  }

  return(rc);
}

/* **************************************** */

int Redis::getAddress(char *numeric_ip, char *rsp,
		      u_int rsp_len, bool queue_if_not_found) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  int rc;

  rsp[0] = '\0';
  snprintf(key, sizeof(key), "%s.%s", DNS_CACHE, numeric_ip);

  rc = get(key, rsp, rsp_len);

  if(rc != 0) {
    if(queue_if_not_found)
      pushHostToResolve(numeric_ip, true, false);
  } else {
    /* We need to extend expire */

    expire(numeric_ip, DNS_CACHE_DURATION /* expire */);
  }

  return(rc);
}

/* **************************************** */

int Redis::setHTTPBLAddress(char *numeric_ip, char *httpbl) {
  char key[CONST_MAX_LEN_REDIS_KEY];

  snprintf(key, sizeof(key), "%s.%s", HTTPBL_CACHE, numeric_ip);
  return(set(key, httpbl, HTTPBL_CACHE_DURATIION));
}

/* **************************************** */

int Redis::setResolvedAddress(char *numeric_ip, char *symbolic_ip) {
  char key[CONST_MAX_LEN_REDIS_KEY], numeric[256], *w, *h;
  int rc = 0;

#if 0
  if(strcmp(symbolic_ip, "broadcasthost") == 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "********");
#endif

  snprintf(numeric, sizeof(numeric), "%s", numeric_ip);

  h = strtok_r(numeric, ";", &w);

  while(h != NULL) {
    snprintf(key, sizeof(key), "%s.%s", DNS_CACHE, h);
    rc = set(key, symbolic_ip, DNS_CACHE_DURATION);
    h = strtok_r(NULL, ";", &w);
  }

  return(rc);
}

/* **************************************** */

char* Redis::getVersion(char *str, u_int str_len) {
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "INFO");
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  snprintf(str, str_len, "%s" , "????");

  if(reply) {
    if(reply->str) {
      char *buf, *line = strtok_r(reply->str, "\n", &buf);
      const char *tofind = "redis_version:";
      u_int tofind_len = (u_int)strlen(tofind);

      while(line != NULL) {
	if(!strncmp(line, tofind, tofind_len)) {
	  snprintf(str, str_len, "%s" , &line[tofind_len]);
	  break;
	}

	line = strtok_r(NULL, "\n", &buf);
      }
    }

    freeReplyObject(reply);
  }
  l->unlock(__FILE__, __LINE__);

  return(str);
}

/* **************************************** */

void Redis::getHostContacts(lua_State* vm, GenericHost *h, bool client_contacts) {
  char hkey[CONST_MAX_LEN_REDIS_KEY], key[CONST_MAX_LEN_REDIS_KEY];
  redisReply *reply;

  h->get_string_key(hkey, sizeof(hkey));
  if(hkey[0] == '\0') return;

  snprintf(key, sizeof(key), "%s.%s", hkey,
	   client_contacts ? "client" : "server");

  lua_newtable(vm);

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis,
				    "ZREVRANGE %s %u %u WITHSCORES",
				    key, 0, -1);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply
     && (reply->type == REDIS_REPLY_ARRAY)
     && (reply->elements > 0)) {
    for(u_int i=0; i<(reply->elements-1); i++) {
      if((i % 2) == 0) {
	const char *key = (const char*)reply->element[i]->str;
	u_int64_t value = (u_int64_t)atol(reply->element[i+1]->str);

	//ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s:%llu", key, value);
	lua_push_int_table_entry(vm, key, value);
      }
    }
  }

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);
}

/* **************************************** */

int Redis::hashIncr(char *key, char *field, u_int32_t value) {
  int rc;
  redisReply *reply;

  if(key == NULL || field == NULL) return 0;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "HINCRBY %s %s %u", key, field, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::incrHostContacts(char *key, u_int16_t family_id,
			    u_int32_t peer_id, u_int32_t value) {
  char buf[128];

  snprintf(buf, sizeof(buf), "%u@%u", peer_id, family_id);
  return(hashIncr(key, buf, value));
}

/* **************************************** */

/*
  Hosts:       [name == NULL] && [ip != NULL]
  StringHosts: [name != NULL] && [ip == NULL]
*/
int Redis::addHostToDBDump(NetworkInterface *iface, IpAddress *ip, char *name) {
  char buf[64], daybuf[32], *what;
  time_t when = time(NULL);
  bool new_key;

  strftime(daybuf, sizeof(daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
  what = ip ? ip->print(buf, sizeof(buf)) : name;
  return(host_to_id(iface, daybuf, what, &new_key));
}

/* **************************************** */

int Redis::smembers(lua_State* vm, char *setName) {
  int rc;
  redisReply *reply;

  lua_newtable(vm);

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "SMEMBERS %s", setName);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && (reply->type == REDIS_REPLY_ARRAY)) {
    for(u_int i=0; i<reply->elements; i++) {
      const char *key = (const char*)reply->element[i]->str;
      //ntop->getTrace()->traceEvent(TRACE_ERROR, "[%u] %s", i, key);
      lua_pushstring(vm, key);
      lua_rawseti(vm, -2, i + 1);
    }

    rc = 0;
  } else
    rc = -1;

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* *************************************** */

void Redis::setHostId(NetworkInterface *iface, char *daybuf, char *host_name, u_int32_t id) {
  char buf[32], keybuf[384], host_id[16], _daybuf[32], value[32];
  //redisReply *reply;

  if(daybuf == NULL) {
    time_t when = time(NULL);

    strftime(_daybuf, sizeof(_daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
    daybuf = _daybuf;
  }

  snprintf(keybuf, sizeof(keybuf), "%s|%s", iface->get_name(), host_name);

  /* Set the data */
  snprintf(buf, sizeof(buf), "ntopng.%s.hostkeys", daybuf);
  snprintf(host_id, sizeof(host_id), "%u", id);
  hashSet(buf, keybuf, host_id); /* Forth */
  hashSet(buf, host_id, keybuf); /* ...and back */
  snprintf(value, sizeof(value), "%s|%u", iface->get_name(), id);

#if 0
  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "SADD %s.keys %s", daybuf, value);
  if(!reply) reconnectRedis();

  if(reply) {
    if(reply->type == REDIS_REPLY_INTEGER) {
      if(reply->integer != 1)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "'SADD %s.keys %s|%u' returned %lld",
				     daybuf, iface->get_name(), id, reply->integer);
    } else if(reply->type == REDIS_REPLY_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid reply type [%d]", reply->type);
  }

  ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping %u", host_id);

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);
#endif
}

/* *************************************** */

u_int32_t Redis::host_to_id(NetworkInterface *iface, char *daybuf, char *host_name, bool *new_key) {
  u_int32_t id;
  int rc;
  char buf[32], keybuf[384], rsp[CONST_MAX_LEN_REDIS_VALUE];

  if(iface == NULL) return(-1);

  snprintf(keybuf, sizeof(keybuf), "%s|%s", iface->get_name(), host_name);

  /* Add host key if missing */
  snprintf(buf, sizeof(buf), "ntopng.%s.hostkeys", daybuf);
  rc = hashGet(buf, keybuf, rsp, sizeof(rsp));

  if(rc == -1) {
    /* Not found */
    char host_id[16];

    snprintf(host_id, sizeof(host_id), "%u", id = incrKey((char*)NTOP_HOSTS_SERIAL));
    setHostId(iface, daybuf, host_name, id);
    *new_key = true;
  } else
    id = atol(rsp), *new_key = false;

  return(id);
}

/* *************************************** */

int Redis::id_to_host(char *daybuf, char *host_idx, char *buf, u_int buf_len) {
  char key[CONST_MAX_LEN_REDIS_KEY];

  /* Add host key if missing */
  snprintf(key, sizeof(key), "ntopng.%s.hostkeys", daybuf);
  return(hashGet(key, host_idx, buf, buf_len));
}

/* ******************************************* */

bool Redis::createOpenDB(sqlite3 **db, char *day, char **zErrMsg)
{
  char path[MAX_PATH];
  char buf[256];

  if(*db)
    return true;

  snprintf(path, sizeof(path), "%s/datadump",
	   ntop->get_working_dir());
  Utils::mkdir_tree(path);

  snprintf(path, sizeof(path), "%s/datadump/20%s.sqlite",
	   ntop->get_working_dir(), day);

  if(sqlite3_open(path, db) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] Unable to create file %s", path);
    return(false);
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Started dump on %s", path);

  if(sqlite3_exec(*db,
		  (char*)"CREATE TABLE IF NOT EXISTS `interfaces` (`idx` INTEGER PRIMARY KEY, `interface_name` STRING);"
		  "CREATE TABLE IF NOT EXISTS `hosts` (`idx` INTEGER PRIMARY KEY, `interface_idx` INTEGER, `host_name` STRING KEY);"
		  "CREATE TABLE IF NOT EXISTS `contacts` (`idx` INTEGER PRIMARY KEY, "
		  "`client_host_idx` KEY INTEGER, `server_host_idx` INTEGER KEY, `contact_family` INTEGER, `num_contacts` INTEGER);"
		  "BEGIN;",  NULL, 0, zErrMsg) != SQLITE_OK) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] SQL error: [%s][%s]", *zErrMsg, buf);
    sqlite3_free(*zErrMsg);
    sqlite3_close(*db);
    return(false);
  }

  return true;
}

/* ******************************************* */

bool Redis::dumpDailyStatsKeys(char *day) {
  bool rc = false;
  sqlite3 *db = NULL;
  char buf[256];
  char *zErrMsg;
  u_int32_t contact_idx = 0;
  time_t begin = time(NULL);
  u_int num_interfaces = 0, num_hosts = 0, num_activities = 0;


  /* *************************************** */

  l->lock(__FILE__, __LINE__);
  redisReply *kreply = (redisReply*)redisCommand(redis, "KEYS %s|*", day);
  if(!kreply) reconnectRedis();
  if(kreply && (kreply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", kreply->str ? kreply->str : "???");
  l->unlock(__FILE__, __LINE__);

  if(kreply && (kreply->type == REDIS_REPLY_ARRAY)) {
    for(u_int kid = 0; kid < kreply->elements; kid++) {
      char *_key = (char*)kreply->element[kid]->str, key[CONST_MAX_LEN_REDIS_KEY];
      char ifname[32];
      char *host, *token, *pipe;

      snprintf(ifname, sizeof(ifname), "%s", _key);
      pipe = strchr(ifname, '|');
      if(pipe) pipe[0] = '\0';

      num_activities++;

      if((num_activities % 10000) == 0) {
	u_int diff = (u_int)(time(NULL)-begin);

	if(diff == 0) diff = 1;
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u activities processed [%.f activities/sec]",
				     num_activities, (float)num_activities/(float)diff);
      }

      snprintf(key, sizeof(key), "%s", _key);

      // key = ethX|mail.xxxxxx.com
      if(strtok_r(key, "|", &token) != NULL) {
	char *iface;

	if((iface = strtok_r(NULL, "|", &token)) != NULL) {
	  if((host = strtok_r(NULL, "|", &token)) != NULL) {
	    u_int32_t host_index = atol(host);
	    u_int32_t interface_idx = (u_int32_t)-1;
	    char host_buf[256];
	    u_char ifnames[MAX_NUM_INTERFACES][MAX_INTERFACE_NAME_LEN];

	    /* Compute interface id */
	    for(u_int i=0; i<num_interfaces; i++) {
	      if(strcmp((const char*)ifnames[i], (const char*)iface) == 0) {
		interface_idx = i;
		break;
	      }
	    }

	    if(interface_idx == (u_int32_t)-1) {
	      if(num_interfaces < MAX_NUM_INTERFACES) {
		snprintf((char*)ifnames[num_interfaces], MAX_INTERFACE_NAME_LEN, "%s", iface);

		snprintf(buf, sizeof(buf), "INSERT INTO interfaces VALUES (%u,'%s');",
			 num_interfaces, iface);
		ntop->getTrace()->traceEvent(TRACE_INFO, "%s", buf);

		if(!createOpenDB(&db, key, &zErrMsg) ||
                   sqlite3_exec(db, buf, NULL, 0, &zErrMsg) != SQLITE_OK) {
		  ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] SQL error [%s][%s]", zErrMsg, buf);
		  sqlite3_free(zErrMsg);
		}

		interface_idx = num_interfaces;
		num_interfaces++;
	      }
	    }

	    if(id_to_host(day, host, host_buf, sizeof(host_buf)) == -1) {
	      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to find host hash entry %s", host);
	    } else {
	      char *zErrMsg, *pipe = strchr(host_buf,'|');

	      if(pipe) {
		char buf[256];
		int rc = 0;

		snprintf(buf, sizeof(buf), "INSERT INTO hosts VALUES (%u,%u,'%s');",
			 host_index, interface_idx, &pipe[1]);

		ntop->getTrace()->traceEvent(TRACE_INFO, "%s", buf);

		if(!createOpenDB(&db, key, &zErrMsg) ||
                   (rc = sqlite3_exec(db, buf, NULL, 0, &zErrMsg)) != SQLITE_OK) {
		  if(rc != SQLITE_CONSTRAINT /* Key already existing */)
		    ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] SQL error [%s][%s][%d/%d]", zErrMsg,
						 buf, rc, SQLITE_MISMATCH);

		  sqlite3_free(zErrMsg);
		}

		num_hosts++;
	      }
	    }

	    /*
	      As redis is a key-value DB, we must insert two records
	      a -contacted- b
	      and
	      b -has been contacted by- a

	      But on the DB we need just one of them and not both
	    */
	    for(u_int32_t loop=0; loop<2; loop++) {
	      char hash_key[512];
	      redisReply *r;

	      snprintf(hash_key, sizeof(hash_key), "%s|%s|%s", day, _key,
		       (loop == 0) ? CONST_CONTACTED_BY : CONST_CONTACTS);

	      snprintf(hash_key, sizeof(hash_key), "%s|%s|%s|%s", day, iface, host,
		       (loop == 0) ? CONST_CONTACTED_BY : CONST_CONTACTS);

	      l->lock(__FILE__, __LINE__);
	      r = (redisReply*)redisCommand(redis, "HKEYS %s", hash_key);
	      if(!r) reconnectRedis();
	      if(r && (r->type == REDIS_REPLY_ERROR))
		ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", r->str);
	      l->unlock(__FILE__, __LINE__);

	      if(r) {
		if(r->type == REDIS_REPLY_ARRAY) {
		  for(u_int32_t j = 0; j < r->elements; j++) {
		    redisReply *r1, *r2;

		    l->lock(__FILE__, __LINE__);
		    r1 = (redisReply*)redisCommand(redis, "HGET %s %s", hash_key, r->element[j]->str);
		    if(!r1) reconnectRedis();
		    if(r1 && (r1->type == REDIS_REPLY_ERROR))
		      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", r1->str);
		    l->unlock(__FILE__, __LINE__);

		    if(r1 && r1->str) {
		      char *contact_host, *subtoken;

		      if((contact_host = strtok_r(r->element[j]->str, "@", &subtoken)) != NULL) {
			char *contact_family;

			if((contact_family = strtok_r(NULL, "@", &subtoken)) != NULL) {
			  char *client_idx, *server_idx, buf[512];

			  if(loop == 0)
			    client_idx = contact_host, server_idx = host; /* contacted_by */
			  else
			    client_idx = host, server_idx = contact_host; /* contacted_peer */

			  snprintf(buf, sizeof(buf), "INSERT INTO contacts VALUES (%u,%s,%s,%s,%s);",
				   contact_idx++, client_idx, server_idx, contact_family, r1->str);

			  ntop->getTrace()->traceEvent(TRACE_INFO, "%s", buf);
			  if(!createOpenDB(&db, day, &zErrMsg) ||
                             sqlite3_exec(db, buf, NULL, 0, &zErrMsg) != SQLITE_OK) {
			    ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] SQL error [%s][%s]", zErrMsg, buf);
			    sqlite3_free(zErrMsg);
			  }

			  /* Now in order to avoid duplicated records we delete the opposite */
			  snprintf(hash_key, sizeof(hash_key), "%s|%s|%s|%s", day, ifname,
				   (loop == 1) ? server_idx : client_idx,
				   (loop == 1) ? CONST_CONTACTED_BY : CONST_CONTACTS);
			  snprintf(buf, sizeof(buf), "%s@%s",
				   (loop == 1) ? server_idx : client_idx, contact_family);
			  hashDel(hash_key, buf);
			}
		      }

		      l->lock(__FILE__, __LINE__);
		      r2 = (redisReply*)redisCommand(redis, "HDEL %s %s", hash_key, r->element[j]->str);
		      if(!r2) reconnectRedis();
		      if(r2 && (r2->type == REDIS_REPLY_ERROR))
			ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", r2->str);
		      l->unlock(__FILE__, __LINE__);

		      if(r2) freeReplyObject(r2);
		    }

		    if(r1) freeReplyObject(r1);
		  }
		}

		freeReplyObject(r);
	      }

	      l->lock(__FILE__, __LINE__);
	      r = (redisReply*)redisCommand(redis, "DEL %s", hash_key);
	      if(!r) reconnectRedis();
	      if(r && (r->type == REDIS_REPLY_ERROR))
		ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", r->str);
	      l->unlock(__FILE__, __LINE__);
	      freeReplyObject(r);
	    }
	  }
	}

	l->lock(__FILE__, __LINE__);
	redisReply *r = (redisReply*)redisCommand(redis, "DEL %s", _key);

	if(!r) reconnectRedis();
	if(r && (r->type == REDIS_REPLY_ERROR))
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", r->str);
	l->unlock(__FILE__, __LINE__);
	freeReplyObject(r);
      }
    } /* for */
  }

  if(kreply) freeReplyObject(kreply);

  rc = true;

  if(db && sqlite3_exec(db, "COMMIT;", NULL, 0, &zErrMsg) != SQLITE_OK) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] SQL error [%s][%s]", zErrMsg, buf);
    sqlite3_free(zErrMsg);
  }

  begin = time(NULL)-begin;
  if(begin == 0) begin = 1;
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "[%s] Processed %u hosts, %u contacts in %u sec [%.1f contacts/sec]",
			       day, num_hosts, contact_idx,
			       begin, (float)((float)contact_idx)/((float)begin));

  snprintf(buf, sizeof(buf), "ntopng.%s.hostkeys", day);
  del(buf);

  snprintf(buf, sizeof(buf), "%s.keys", day);
  del(buf);

  if(db)
    sqlite3_close(db);

  return(rc);
}

/* ******************************************* */

int Redis::lpush(const char *queue_name, char *msg, u_int queue_trim_size) {
  return(msg_push("LPUSH", queue_name, msg, queue_trim_size));
}

/* ******************************************* */

int Redis::rpush(const char *queue_name, char *msg, u_int queue_trim_size) {
  return(msg_push("RPUSH", queue_name, msg, queue_trim_size));
}

/* ******************************************* */

int Redis::msg_push(const char *cmd, const char *queue_name, char *msg, u_int queue_trim_size) {
  redisReply *reply;
  int rc = 0;

  l->lock(__FILE__, __LINE__);
  /* Put the latest messages on top so old messages (if any) will be discarded */
  reply = (redisReply*)redisCommand(redis, "%s %s %s", cmd,  queue_name, msg);

  if(!reply) reconnectRedis();
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = -1;

    freeReplyObject(reply);

    if(queue_trim_size > 0) {
      reply = (redisReply*)redisCommand(redis, "LTRIM %s 0 %u", queue_name, queue_trim_size);
      if(!reply) reconnectRedis();
      if(reply) {
	if(reply->type == REDIS_REPLY_ERROR)
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = -1;

	freeReplyObject(reply);
      } else
	rc = -1;
    }
  } else
    rc = -1;

  l->unlock(__FILE__, __LINE__);
  return(rc);
}

/* ******************************************* */

void Redis::queueAlert(AlertLevel level, AlertType t, char *msg) {
  char what[1024];

  if(ntop->getPrefs()->are_alerts_disabled()) return;

  snprintf(what, sizeof(what), "%u|%u|%u|%s",
	   (unsigned int)time(NULL), (unsigned int)level,
	   (unsigned int)t, msg);

#ifndef WIN32
  // Print alerts into syslog
  if(ntop->getRuntimePrefs()->are_alerts_syslog_enable()) {
    if( alert_level_info == level) syslog(LOG_INFO, "%s", what);
    else if( alert_level_warning == level) syslog(LOG_WARNING, "%s", what);
    else if( alert_level_error == level) syslog(LOG_ALERT, "%s", what);
  }
#endif

  lpush(CONST_ALERT_MSG_QUEUE, what, CONST_MAX_ALERT_MSG_QUEUE_LEN);

#ifdef NTOPNG_PRO
  if(ntop->getNagios())
    ntop->getNagios()->sendEvent(level, t, msg);
#endif

}

/* ******************************************* */

u_int Redis::llen(const char *queue_name) {
  redisReply *reply;
  u_int num = 0;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "LLEN %s", queue_name);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  else
    num = (u_int)reply->integer;
  l->unlock(__FILE__, __LINE__);
  if(reply) freeReplyObject(reply);

  return(num);
}

/* ******************************************* */

int Redis::lpop(const char *queue_name, char *buf, u_int buf_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "LPOP %s", queue_name);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str)
    snprintf(buf, buf_len, "%s", reply->str), rc = 0;
  else
    buf[0] = '\0', rc = -1;

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* ******************************************* */

void Redis::deleteQueuedAlert(u_int32_t idx_to_delete) {
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  reply = (redisReply*)redisCommand(redis, "LSET %s %u __deleted__", CONST_ALERT_MSG_QUEUE, idx_to_delete);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply);

  reply = (redisReply*)redisCommand(redis, "LREM %s 0 __deleted__", CONST_ALERT_MSG_QUEUE, idx_to_delete);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  l->unlock(__FILE__, __LINE__);
  if(reply) freeReplyObject(reply);
}

/* **************************************** */

u_int Redis::getQueuedAlerts(patricia_tree_t *allowed_hosts, char **alerts, u_int start_idx, u_int num) {
  u_int i = 0;
  redisReply *reply = NULL;

  // TODO - We need to filter events that belong to allowed_hosts only

  l->lock(__FILE__, __LINE__);
  while(i < num) {
    reply = (redisReply*)redisCommand(redis, "LINDEX %s %u", CONST_ALERT_MSG_QUEUE, start_idx++);
    if(!reply) reconnectRedis();
    if(reply && (reply->type == REDIS_REPLY_ERROR)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
      break;
    }

    if(reply && reply->str) {
      alerts[i++] = strdup(reply->str);
      freeReplyObject(reply);
      reply = NULL;
    } else
      break;
  }

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(i);
}

/* **************************************** */

void Redis::indexESdata() {
  const u_int watermark = 8, min_buf_size = 512;
  char postbuf[16384];

  while(!ntop->getGlobals()->isShutdown()) {
    u_int l = llen(CONST_ES_QUEUE_NAME);

    if(l >= watermark) {
      u_int len, num_flows;
      char index_name[64], header[256];
      struct tm* tm_info;
      struct timeval tv;
      time_t t;

      gettimeofday(&tv, NULL);
      t = tv.tv_sec;
      tm_info = gmtime(&t);

      strftime(index_name, sizeof(index_name), ntop->getPrefs()->get_es_index(), tm_info);

      snprintf(header, sizeof(header),
	       "{\"index\": {\"_type\": \"%s\", \"_index\": \"%s\"}}",
	       ntop->getPrefs()->get_es_type(), index_name);
      len = 0, num_flows = 0;

      for(u_int i=0; (i<watermark) && ((sizeof(postbuf)-len) > min_buf_size); i++) {
	char rsp[4096];
	int rc = lpop(CONST_ES_QUEUE_NAME, rsp, sizeof(rsp));

	if(rc >= 0) {
	  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", rsp);
	  len += snprintf(&postbuf[len], sizeof(postbuf)-len, "%s\n%s\n", header, rsp), num_flows++;
	} else
	  break;
      } /* for */

      postbuf[len] = '\0';

      if(!Utils::postHTTPJsonData(ntop->getPrefs()->get_es_user(),
				  ntop->getPrefs()->get_es_pwd(),
				  ntop->getPrefs()->get_es_url(),
				  postbuf)) {
	/* Post failure */
	sleep(1);
      } else
	ntop->getTrace()->traceEvent(TRACE_INFO, "Sent %u flow(s) to ES", num_flows);
    } else
      sleep(1);
  } /* while */
}

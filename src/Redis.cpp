/*
 *
 * (C) 2013-17 - ntop.org
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

// #define CACHE_DEBUG 1

/* **************************************** */

Redis::Redis(char *_redis_host, char *_redis_password, u_int16_t _redis_port, u_int8_t _redis_db_id) {
  redis_host = _redis_host, redis_password = _redis_password;
  redis_port = _redis_port, redis_db_id = _redis_db_id;

  num_requests = num_reconnections = 0;
  redis = NULL, operational = false;
  reconnectRedis();
  stringCache = NULL, numCached = 0;
  l = new Mutex();
  setDefaults();
}

/* **************************************** */

Redis::~Redis() {
  flushCache();
  redisFree(redis);
  // flushCache();
  delete l;
}

/* **************************************** */

void Redis::reconnectRedis() {
  struct timeval timeout = { 1, 500000 }; // 1.5 seconds
  redisReply *reply;
  u_int num_attempts = 10;

  operational = false;

  if(redis != NULL) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Redis has disconnected: reconnecting...");
    redisFree(redis);
  }

  redis = redisConnectWithTimeout(redis_host, redis_port, timeout);

  if(redis_password) {
    num_requests++;
    reply = (redisReply*)redisCommand(redis, "AUTH %s", redis_password);
    if(reply && (reply->type == REDIS_REPLY_ERROR)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Redis authentication failed: %s", reply->str ? reply->str : "???");
      goto redis_error_handler;
    }
  }

  while(redis && num_attempts > 0) {
    num_requests++;
    reply = (redisReply*)redisCommand(redis, "PING");
    if(reply && (reply->type == REDIS_REPLY_ERROR)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
      sleep(1);
      num_attempts--;
    } else
      break;
  }

  if((redis == NULL) || (reply == NULL)) {
  redis_error_handler:
    if(ntop->getTrace()->get_trace_level() == 0) ntop->getTrace()->set_trace_level(MAX_TRACE_LEVEL);
    ntop->getTrace()->traceEvent(TRACE_ERROR, "ntopng requires redis server to be up and running");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Please start it and try again or use -r");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "to specify a redis server other than the default");
    exit(0);
  } else {
    freeReplyObject(reply);

    num_requests++;
    reply = (redisReply*)redisCommand(redis, "SELECT %u", redis_db_id);
    if(reply && (reply->type == REDIS_REPLY_ERROR)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
      goto redis_error_handler;
    } else {
      freeReplyObject(reply);
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Successfully connected to redis %s:%u@%u",
				   redis_host, redis_port, redis_db_id);
      operational = true;
    }
  }

  num_reconnections++;
}

/* **************************************** */

int Redis::expire(char *key, u_int expire_secs) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);

  if(expireCache(key, expire_secs)) {
    l->unlock(__FILE__, __LINE__);
    return(0);
  }
  
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "EXPIRE %s %u", key, expire_secs);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

bool Redis::isCacheable(char *key) {
  if(strstr(key, "ntopng.prefs.")
     || (strstr(key, "ntopng.user.") && (!strstr(key, ".password")))
     )
    return(true);

  return(false);
}

/* **************************************** */

bool Redis::expireCache(char *key, u_int expire_secs) {
  StringCache_t *cached = NULL;
  
#ifdef CACHE_DEBUG
  printf("**** Setting cache expire for %s [%u sec]\n", key, expire_secs);
#endif

  HASH_FIND_STR(stringCache, key, cached);

  if(cached) {
    cached->expire = expire_secs ? time(NULL)+expire_secs : 0;
    return(true);
  }

  return(false);
}

/* **************************************** */

/* NOTE: We assume that the addToCache() caller locks this instance */
void Redis::addToCache(char *key, char *value, u_int expire_secs) { 
  StringCache_t *cached = NULL;
 
#ifdef CACHE_DEBUG
  printf("**** Caching %s=%s\n", key, value ? value : "<NULL>");
#endif

  HASH_FIND_STR(stringCache, key, cached);

  if(cached) {
    if(cached->value) free(cached->value);
    cached->value = strdup(value);
    cached->expire = expire_secs ? time(NULL)+expire_secs : 0;
    return;
  }
  
  cached = (StringCache_t*)malloc(sizeof(StringCache_t));
  if(cached) {
    cached->key = strdup(key), cached->value = strdup(value);
    cached->expire = expire_secs ? time(NULL)+expire_secs : 0;
    
    if(cached->key && cached->value) {
      HASH_ADD_STR(stringCache, key, cached);
      numCached++;
    } else {
      if(cached->key)   free(cached->key);
      if(cached->value) free(cached->value);
      free(cached);
    }
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
}

/* **************************************** */

int Redis::get(char *key, char *rsp, u_int rsp_len, bool cache_it) {
  int rc;
  bool cacheable = false;
  redisReply *reply;
  StringCache_t *cached = NULL;

  l->lock(__FILE__, __LINE__);

  HASH_FIND_STR(stringCache, key, cached);
  if(cached) {
    snprintf(rsp, rsp_len, "%s", cached->value);

#ifdef CACHE_DEBUG
    printf("**** Read from cache %s=%s\n", key, rsp);
#endif
    l->unlock(__FILE__, __LINE__);
    return(rsp[0] == '\0' ? -1 : 0);
  } else {
#ifdef CACHE_DEBUG
    printf("**** Unable to find on cache %s\n", key);
#endif
  }

  num_requests++;
  reply = (redisReply*)redisCommand(redis, "GET %s", key);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  cacheable = isCacheable(key);
  if(reply && reply->str) {
    snprintf(rsp, rsp_len, "%s", reply->str), rc = 0;
  } else
    rsp[0] = 0, rc = -1;

  if(cache_it || cacheable)
    addToCache(key, rsp, 0);

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  if(cacheable && (rc == -1)) {
    /* Add default */
    set(key, (char*)"", 0);
  }

  return(rc);
}
/* **************************************** */

int Redis::del(char *key){
  int rc;
  redisReply *reply;
  StringCache_t *cached = NULL;
  
  l->lock(__FILE__, __LINE__);
  
  HASH_FIND_STR(stringCache, key, cached);

  if(cached) {
    HASH_DEL(stringCache, cached);
    if(cached->key)   free(cached->key);
    if(cached->value) free(cached->value);
    free(cached);    
  }
  
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "DEL %s", key);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR)){
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    rc = -1;
  } else {
    rc = 0;
  }

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::hashGet(char *key, char *field, char *rsp, u_int rsp_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
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
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "HSET %s %s %s", key, field, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s [HSET %s %s %s]", reply->str ? reply->str : "???", key, field, value), rc = -1;
  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::hashDel(char *key, char *field) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
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

  if(isCacheable(key))
    addToCache(key, value, expire_secs);
  
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "SET %s %s", key, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;

  if((rc == 0) && (expire_secs != 0)) {
    num_requests++;
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
  num_requests++;
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
  num_requests++;
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
int Redis::zIncr(char *key, char *member) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "ZINCRBY %s 1 %s", key, member);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

/*
  Increment key.member of +value and keeps at most trim_len elements
*/
int Redis::zTrim(char *key, u_int trim_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "ZREMRANGEBYRANK %s 0 %d", key, -1*trim_len);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::zRevRange(const char *pattern, char ***keys_p) {
  int rc = 0;
  u_int i;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "ZREVRANGE %s 0 -1 WITHSCORES", pattern);
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

int Redis::keys(const char *pattern, char ***keys_p) {
  int rc = 0;
  u_int i;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
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
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "HKEYS %s", pattern);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s [HKEYS %s]", reply->str ? reply->str : "???", pattern);

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

int Redis::hashGetAll(const char *key, char ***keys_p, char ***values_p) {
  int rc = 0;
  int i, j;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "HGETALL %s", key);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s [HGETALL %s]", reply->str ? reply->str : "???", key);

  (*keys_p) = NULL;

  if(reply && (reply->type == REDIS_REPLY_ARRAY) && (reply->elements % 2 == 0)) {
    rc = (int)reply->elements / 2;

    if(rc > 0) {
      if(((*keys_p) = (char**)malloc(rc * sizeof(char*))) != NULL) {
        if(((*values_p) = (char**)malloc(rc * sizeof(char*))) != NULL) {

          i = 0;
          for(j = 0; j < rc; j++) {
            /* Keys and values are interleaved */
            (*keys_p)[j] = strdup(reply->element[i]->str);
            (*values_p)[j] = strdup(reply->element[i+1]->str);
            i += 2;
          }
        } else {
          free(*keys_p);
          *keys_p = NULL;
        }
      }
    }
  }

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::oneOperator(const char *operation, char *key) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "%s %s", operation, key);
  if(!reply) reconnectRedis();

  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::twoOperators(const char *operation, char *op1, char *op2) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "%s %s %s", operation, op1, op2);
  if(!reply) reconnectRedis();

  if(reply
     && (reply->type == REDIS_REPLY_ERROR)
     && strcmp(reply->str, "ERR no such key"))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::pushHostToTrafficFiltering(char *hostname, bool dont_check_for_existence, bool localHost) {
  if(ntop->getPrefs()->is_httpbl_enabled() || ntop->getPrefs()->is_flashstart_enabled()) {
    if(hostname == NULL) return(-1);
    return(pushHost(TRAFFIC_FILTERING_CACHE, TRAFFIC_FILTERING_TO_RESOLVE,
		    hostname, dont_check_for_existence, localHost));
  } else
    return(0);
}

/* **************************************** */

int Redis::pushHostToResolve(char *hostname, bool dont_check_for_existence, bool localHost) {
  if(!ntop->getPrefs()->is_dns_resolution_enabled()) return(0);
  if(hostname == NULL) return(-1);

  if(!ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
    /*
      In case only local addresses need to be resolved, skip
      remote hosts
    */
    IpAddress ip;
    int16_t network_id;
    
    ip.set(hostname);
    if(!ip.isLocalHost(&network_id))
      return(-1);
  }
  
  return(pushHost(DNS_CACHE, DNS_TO_RESOLVE, hostname, dont_check_for_existence, localHost));
}

/* **************************************** */

int Redis::pushHost(const char* ns_cache, const char* ns_list, char *hostname,
		    bool dont_check_for_existence, bool localHost) {
  int rc = 0;
  char key[CONST_MAX_LEN_REDIS_KEY];
  bool found;
  redisReply *reply;

  if(hostname == NULL) return(-1);

  snprintf(key, sizeof(key), "%s.%s", ns_cache, hostname);

  l->lock(__FILE__, __LINE__);

  if(dont_check_for_existence)
    found = false;
  else {
    /*
      Add only if the address has not been resolved yet
    */

    num_requests++;
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

int Redis::popHostToTrafficFiltering(char *hostname, u_int hostname_len) {
  return(popHost(TRAFFIC_FILTERING_TO_RESOLVE, hostname, hostname_len));
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

char* Redis::getTrafficFilteringCategory(char *numeric_ip, char *buf,
					 u_int buf_len, bool categorize_if_unknown) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  redisReply *reply;

  if((!ntop->getPrefs()->is_httpbl_enabled())
     && (!ntop->getPrefs()->is_flashstart_enabled()))
    return(NULL);

  buf[0] = '\0';
  l->lock(__FILE__, __LINE__);

  snprintf(key, sizeof(key), "%s.%s", TRAFFIC_FILTERING_CACHE, numeric_ip);

  /*
    Add only if the ip has not been checked against the blacklist
  */
  num_requests++;
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
      num_requests++;

      if(ntop->getPrefs()->is_httpbl_enabled()) {
	reply = (redisReply*)redisCommand(redis, "RPUSH %s %s", TRAFFIC_FILTERING_TO_RESOLVE, numeric_ip);
	if(!reply) reconnectRedis();
	if(reply && (reply->type == REDIS_REPLY_ERROR))
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
	if(reply) freeReplyObject(reply);
      }
    }
  }

  l->unlock(__FILE__, __LINE__);

  return(buf);
}

/* **************************************** */

#ifdef NOTUSED
int Redis::popDomainToCategorize(char *domainname, u_int domainname_len) {
  return(lpop(DOMAIN_TO_CATEGORIZE, domainname, domainname_len));
}
#endif

/* **************************************** */

void Redis::setDefaults() {
  char *admin_md5 = (char*)"21232f297a57a5a743894a0e4a801fc3";
  char value[CONST_MAX_LEN_REDIS_VALUE];

  setResolvedAddress((char*)"127.0.0.1", (char*)"localhost");
  setResolvedAddress((char*)"::1", (char*)"localhostV6");
  setResolvedAddress((char*)"255.255.255.255", (char*)"Broadcast");
  setResolvedAddress((char*)"0.0.0.0", (char*)"NoIP");

  if(get((char*)"ntopng.user.admin.password", value, sizeof(value)) < 0) {
    set((char*)"ntopng.user.admin.password", admin_md5);
    set((char*)"ntopng.user.admin.full_name", (char*)"ntopng Administrator");
    set((char*)"ntopng.user.admin.group", (char*)CONST_USER_GROUP_ADMIN);
    set((char*)"ntopng.user.admin.allowed_nets", (char*)"0.0.0.0/0,::/0");
  } else if(strncmp(value, admin_md5, strlen(admin_md5))) {
    set((char*)CONST_DEFAULT_PASSWORD_CHANGED, (char*)"1");
  }
}

/* **************************************** */

int Redis::getAddressTrafficFiltering(char *numeric_ip,
				      NetworkInterface *iface,
				      char *rsp, u_int rsp_len,
				      bool queue_if_not_found) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  int rc;

  rsp[0] = '\0';
  snprintf(key, sizeof(key), "%s.%s", TRAFFIC_FILTERING_CACHE, numeric_ip);

  rc = get(key, rsp, rsp_len);

  if(rc != 0) {
    if(queue_if_not_found) {
      char buf[64];

      snprintf(buf, sizeof(buf), "%s@%s", numeric_ip, iface->get_name());
      pushHostToTrafficFiltering(buf, true, false);
    }
  } else {
    /* We need to extend expire */

    expire(numeric_ip, TRAFFIC_FILTERING_CACHE_DURATION /* expire */);
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

int Redis::setTrafficFilteringAddress(char *numeric_ip, char *httpbl) {
  char key[CONST_MAX_LEN_REDIS_KEY];

  snprintf(key, sizeof(key), "%s.%s", TRAFFIC_FILTERING_CACHE, numeric_ip);
  return(set(key, httpbl, TRAFFIC_FILTERING_CACHE_DURATION));
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
  num_requests++;
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

#ifdef NOTUSED
int Redis::hashIncr(char *key, char *field, u_int32_t value) {
  int rc;
  redisReply *reply;

  if(key == NULL || field == NULL) return 0;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "HINCRBY %s %s %u", key, field, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}
#endif

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

/* ******************************************* */

int Redis::sadd(const char *set_name, char *item) {
  return(msg_push("SADD", set_name, item, 0 /* do not trim, this is not a queue */));
}

/* ******************************************* */

int Redis::srem(const char *set_name, char *item) {
  return(msg_push("SREM", set_name, item, 0 /* do not trim, this is not a queue */));
}

/* **************************************** */

int Redis::smembers(lua_State* vm, char *setName) {
  int rc;
  redisReply *reply;

  lua_newtable(vm);

  l->lock(__FILE__, __LINE__);
  num_requests++;
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

/* **************************************** */

int Redis::smembers(const char *set_name, char ***members) {
  int rc = -1;
  u_int i;
  redisReply *reply = NULL;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "SMEMBERS %s", set_name);

  if(!reply) reconnectRedis();

  if(reply && (reply->type == REDIS_REPLY_ERROR)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s [SMEMBERS %s]", reply->str ? reply->str : "???", set_name);
    goto out;
  }

  (*members) = NULL;

  if(reply && (reply->type == REDIS_REPLY_ARRAY)) {
    rc = (int)reply->elements;

    if(rc > 0) {
      if(((*members) = (char**)malloc(reply->elements * sizeof(char*))) != NULL) {

	for(i = 0; i < reply->elements; i++)
	  (*members)[i] = strdup(reply->element[i]->str);
      }
    }
  }

 out:
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
  num_requests++;
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
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "%s %s %s", cmd,  queue_name, msg);

  if(!reply) reconnectRedis();
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = -1;
    else
      rc = reply->integer;

    freeReplyObject(reply);

    if(queue_trim_size > 0) {
      num_requests++;
      reply = (redisReply*)redisCommand(redis, "LTRIM %s 0 %u", queue_name, queue_trim_size - 1);
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

u_int Redis::llen(const char *queue_name) {
  redisReply *reply;
  u_int num = 0;

  l->lock(__FILE__, __LINE__);
  num_requests++;
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

int Redis::lset(const char *queue_name, u_int32_t idx, const char *value) {
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "LSET %s %u %s", queue_name, idx, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  l->unlock(__FILE__, __LINE__);

  if(reply) freeReplyObject(reply);

  return 0;
}

/* ******************************************* */

int Redis::lrem(const char *queue_name, const char *value) {
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "LREM %s 0 %s", queue_name, value);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  l->unlock(__FILE__, __LINE__);

  if(reply) freeReplyObject(reply);

  return 0;
}

/* ******************************************* */

int Redis::lpop(const char *queue_name, char *buf, u_int buf_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
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

int Redis::lindex(const char *queue_name, int idx, char *buf, u_int buf_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "LINDEX %s %d", queue_name, idx);

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

int Redis::lpop(const char *queue_name, char ***elements, u_int num_elements) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  // make a redis pipeline that pops multiple elements
  // with just 1 redis command (so we pay only one RTT
  // and the operation is atomic)
  /*

    reply = (redisReply*)redisCommand(redis,
				    "LRANGE %s -%u -1 \r\n LTRIM %s 0 -%u \r\n",
				    queue_name, num_elements, queue_name, num_elements + 1);
  */
  redisAppendCommand(redis, "LRANGE %s -%u -1", queue_name, num_elements);
  redisAppendCommand(redis, "LTRIM %s 0 -%u",   queue_name, num_elements + 1);

  redisGetReply(redis, (void**)&reply);  // reply for LRANGE
  if(!reply) reconnectRedis();

  if(reply && (reply->type == REDIS_REPLY_ERROR)){
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    rc = -1;

  } else if(reply && (reply->type == REDIS_REPLY_ARRAY)) {
    (*elements) = (char**) calloc(reply->elements, sizeof(char*));
    rc = (int)reply->elements;

    int i = rc - 1, j = 0;
    for(; i >= 0; i--, j++) {
      (*elements)[j] = strdup(reply->element[i]->str);
    }

  } else
    rc = -1;

  if(reply) freeReplyObject(reply);
  // empty also the second reply for the LTRIM
  redisGetReply(redis, (void**)&reply);  // reply for LTRIM
  if(!reply)
    reconnectRedis();
  else
    freeReplyObject(reply);

  l->unlock(__FILE__, __LINE__);
  return(rc);
}

/* **************************************** */

int Redis::lrange(const char *list_name, char ***elements, int start_offset, int end_offset) {
  int rc = 0;
  u_int i;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "LRANGE %s %i %i", list_name, start_offset, end_offset);

  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && (reply->type == REDIS_REPLY_ARRAY)) {
    (*elements) = (char**) malloc(reply->elements * sizeof(char*));
    rc = (int)reply->elements;

    for(i = 0; i < reply->elements; i++) {
      (*elements)[i] = strdup(reply->element[i]->str);
    }
  }

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

void Redis::lua(lua_State *vm) {
  lua_newtable(vm);

  lua_push_int_table_entry(vm, "num_requests", num_requests);
  lua_push_int_table_entry(vm, "num_reconnections", num_reconnections);

  lua_pushstring(vm, "redis");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* **************************************** */

void Redis::flushCache() {
  StringCache_t *sd, *current, *tmp;

  l->lock(__FILE__, __LINE__);
  sd = stringCache;
    
  HASH_ITER(hh, sd, current, tmp) {
    HASH_DEL(sd, current);
    if(current->key)   free(current->key);
    if(current->value) free(current->value);
    free(current);
  }

  numCached = 0;
  l->unlock(__FILE__, __LINE__);
  
#ifdef CACHE_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "**** Successfully flushed cache\n");
#endif
}

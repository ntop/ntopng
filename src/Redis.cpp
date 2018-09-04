/*
 *
 * (C) 2013-18 - ntop.org
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

Redis::Redis(const char *_redis_host, const char *_redis_password, u_int16_t _redis_port, u_int8_t _redis_db_id) {
  redis_host = _redis_host ? strdup(_redis_host) : NULL;
  redis_password = _redis_password ? strdup(_redis_password) : NULL;
  redis_port = _redis_port, redis_db_id = _redis_db_id;
#ifdef __linux__
  is_socket_connection = false;
#endif

  num_requests = num_reconnections = 0;
  redis = NULL, operational = false;
  initializationCompleted = false;
  reconnectRedis();
  stringCache = NULL, numCached = 0;
  l = new Mutex();

  getRedisVersion();
}

/* **************************************** */

Redis::~Redis() {
  flushCache();
  redisFree(redis);
  // flushCache();
  delete l;
  
  if(redis_host)     free(redis_host);
  if(redis_password) free(redis_password);
  if(redis_version)  free(redis_version);
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
#ifdef __linux__
  struct stat buf;

  if(!stat(redis_host, &buf) && S_ISSOCK(buf.st_mode))
    redis = redisConnectUnixWithTimeout(redis_host, timeout), is_socket_connection = true;
  else
#endif
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
#ifdef __linux__
      if(!is_socket_connection)
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Successfully connected to redis %s:%u@%u",
				     redis_host, redis_port, redis_db_id);
      else
#endif
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Successfully connected to redis %s@%u",
				     redis_host, redis_db_id);
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
  if((strstr(key, "ntopng.cache."))
     || (strstr(key, "ntopng.prefs."))
     || (strstr(key, "ntopng.user.") && (!strstr(key, ".password"))))
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

void Redis::checkDumpable(const char * const key) {
  if(!initializationCompleted) return;

  /* We use this function to check and possibly request a preference dump to a file.
     This ensures settings persistance also upon redis flushes */
  if(!strncmp(key, "ntopng.prefs.", 13)
     || !strncmp(key, "ntopng.user.", 12)) {
    ntop->getPrefs()->reloadPrefsFromRedis();
    /* Tell housekeeping.lua to dump prefs to disk */
    ntop->getRedis()->set((char*)PREFS_CHANGED, (char*)"true");
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Going to refresh after change of: %s", key);
  }
}

/* **************************************** */

/* NOTE: We assume that the addToCache() caller locks this instance */
void Redis::addToCache(char *key, char *value, u_int expire_secs) {
  StringCache_t *cached = NULL;
  if(!initializationCompleted) return;

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
    /* Don't fill redis with default empty strings.
       Those empty strings have already been set
       into the memory cache by addToCache, leave
       them out from redis */
    /* Add default */
    // set(key, (char*)"", 0);
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

  if(reply) checkDumpable(key);

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

  if(reply) checkDumpable(key);

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

  if(reply) checkDumpable(key);

  return(rc);
}

/* **************************************** */

int Redis::set(char *key, char *value, u_int expire_secs) {
  int rc;
  redisReply *reply;

  if((value == NULL) || (value[0] == '\0')) {    
    if(strncmp(key, NTOPNG_PREFS_PREFIX, sizeof(NTOPNG_PREFS_PREFIX)) == 0) {
      /* This is an empty preference value that we can discard*/
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarding empty prefence value %s", key);
    }
  }
  
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

  if(reply && expire_secs == 0)
    checkDumpable(key);

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

int Redis::pushHostToTrafficFiltering(char *hostname, bool dont_check_for_existence, bool localHost) {
  if(ntop->getPrefs()->is_httpbl_enabled()) {
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

  if(!ntop->getPrefs()->is_httpbl_enabled())
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
  char *value;

  if((value = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL)
    return;
  
  setResolvedAddress((char*)"127.0.0.1", (char*)"localhost");
  setResolvedAddress((char*)"::1", (char*)"localhostV6");
  setResolvedAddress((char*)"255.255.255.255", (char*)"Broadcast");
  setResolvedAddress((char*)"0.0.0.0", (char*)"NoIP");

  if(get((char*)"ntopng.user.admin.password", value,
	 CONST_MAX_LEN_REDIS_VALUE) < 0) {
    set((char*)"ntopng.user.admin.password", admin_md5);
    set((char*)"ntopng.user.admin.full_name",
#ifdef HAVE_NEDGE
		(char*)((ntop->getPro()->is_oem()) ? "Administrator" : "ntopng Administrator")
#else
		(char*)"ntopng Administrator"
#endif
    );
    set((char*)"ntopng.user.admin.group", (char*)CONST_USER_GROUP_ADMIN);
    set((char*)"ntopng.user.admin.allowed_nets", (char*)"0.0.0.0/0,::/0");
  } else if(strncmp(value, admin_md5, strlen(admin_md5))) {
    set((char*)CONST_DEFAULT_PASSWORD_CHANGED, (char*)"1");
  }

  free(value);
}

/* **************************************** */

int Redis::flushDb() {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);

  num_requests++;
  reply = (redisReply*)redisCommand(redis, "FLUSHDB");
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;

  l->unlock(__FILE__, __LINE__);

  if (rc == 0) {
    flushCache();
    setDefaults();
  }

  return(rc);
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

char* Redis::getRedisVersion() {
  redisReply *reply;
  char str[32];
  int a, b, c;
  
  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "INFO");
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  snprintf(str, sizeof(str), "%s" , "????");

  if(reply) {
    if(reply->str) {
      char *buf, *line = strtok_r(reply->str, "\n", &buf);
      const char *tofind = "redis_version:";
      u_int tofind_len = (u_int)strlen(tofind);

      while(line != NULL) {
	if(!strncmp(line, tofind, tofind_len)) {
	  snprintf(str, sizeof(str), "%s" , &line[tofind_len]);
	  break;
	}

	line = strtok_r(NULL, "\n", &buf);
      }
    }

    freeReplyObject(reply);
  }
  
  l->unlock(__FILE__, __LINE__);
  redis_version = strdup(str);
  sscanf(redis_version, "%d.%d.%d", &a, &b, &c);
  num_redis_version = (a << 16) + (b << 8) + c;

  return(redis_version);
}

/* ******************************************* */

int Redis::sadd(const char *set_name, char *item) {
  int ret = msg_push("SADD", set_name, item, 0 /* do not trim, this is not a queue */);
  checkDumpable(set_name);
  return ret;
}

/* ******************************************* */

int Redis::srem(const char *set_name, char *item) {
  int ret = msg_push("SREM", set_name, item, 0 /* do not trim, this is not a queue */);
  checkDumpable(set_name);
  return ret;
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

/* ******************************************* */

/*  Add at the top of queue */
int Redis::lpush(const char *queue_name, char *msg, u_int queue_trim_size, bool trace_errors) {
  return(msg_push("LPUSH", queue_name, msg, queue_trim_size, trace_errors));
}

/* ******************************************* */

/* Add at the bottom of the queue */
int Redis::rpush(const char *queue_name, char *msg, u_int queue_trim_size) {
  return(msg_push("RPUSH", queue_name, msg, queue_trim_size, true, false));
}

/* ******************************************* */

int Redis::msg_push(const char *cmd, const char *queue_name, char *msg,
          u_int queue_trim_size, bool trace_errors, bool head_trim) {
  redisReply *reply;
  int rc = 0;

  l->lock(__FILE__, __LINE__);
  /* Put the latest messages on top so old messages (if any) will be discarded */
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "%s %s %s", cmd,  queue_name, msg);

  if(!reply) reconnectRedis();
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR && trace_errors)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = -1;
    else
      rc = reply->integer;

    freeReplyObject(reply);

    if(queue_trim_size > 0) {
      num_requests++;
      if(head_trim)
        reply = (redisReply*)redisCommand(redis, "LTRIM %s 0 %u", queue_name, queue_trim_size - 1);
      else
        reply = (redisReply*)redisCommand(redis, "LTRIM %s -%u -1", queue_name, queue_trim_size);
      if(!reply) reconnectRedis();
      if(reply) {
	if(reply->type == REDIS_REPLY_ERROR && trace_errors)
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
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    else
      num = (u_int)reply->integer;
  }
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

int Redis::ltrim(const char *queue_name, int start_idx, int end_idx) {
  int rc = 0;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;

  reply = (redisReply*)redisCommand(redis, "LTRIM %s %d %d", queue_name, start_idx, end_idx);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    rc = -1, ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

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

  stringCache = NULL, numCached = 0;
  l->unlock(__FILE__, __LINE__);

#ifdef CACHE_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "**** Successfully flushed cache\n");
#endif
}

/* **************************************** */

/* https://github.com/nullptr-cc/redis-extra-tools */
static void bin2hex(char * in, int len, char * out) {
  int i;

  char table[] = "0123456789ABCDEF";

  for (i = 0; i < len; ++i) {
    out[i*2+0] = table[in[i] >> 4 & 0x0F];
    out[i*2+1] = table[in[i] & 0x0F];
  }

  out[len*2] = 0;
}

static char hdig2bin(char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  } else {
    return c - 'A' + 0x0A;
  }
}

static void hex2bin(char * in, char * out) {
  int unsigned i, len = strlen(in);

  for (i = 0; i < len; i += 2) {
    out[i / 2] = (hdig2bin(in[i]) << 4) + hdig2bin(in[i+1]);
  }
}

/* **************************************** */

char* Redis::dump(char *key) {
  char *rsp = NULL;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  num_requests++;
  reply = (redisReply*)redisCommand(redis, "DUMP %s", key);
  if(!reply) reconnectRedis();
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply) {
    if((rsp = (char*)malloc(1 + reply->len * 2)) != NULL)
      bin2hex(reply->str, reply->len, rsp);

    freeReplyObject(reply);
  }

  l->unlock(__FILE__, __LINE__);

  return(rsp);
}

/* **************************************** */

int Redis::restore(char *key, char *buf) {
  int rc;
  redisReply *reply;
  char *buf_bin = (char*)malloc(strlen(buf));
  const char * argv[5] = {"RESTORE", key, "0", buf_bin};
  size_t argvlen[5] = {7, 0, 0, 0, 7};

  if(buf_bin == NULL)
    return(-1);

  hex2bin(buf, buf_bin);

  l->lock(__FILE__, __LINE__);
  num_requests++;

  /* Delete the key first */
  reply = (redisReply*)redisCommand(redis, "DEL %s", key);
  if(!reply) reconnectRedis();

  if(reply && (reply->type == REDIS_REPLY_ERROR)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    rc = -1;
  } else if(reply) {
    freeReplyObject(reply);

    argvlen[1] = strlen(argv[1]);
    argvlen[2] = strlen(argv[2]);
    argvlen[3] = strlen(buf) / 2;

    reply = (redisReply*)redisCommandArgv(redis, 4, argv, argvlen);

    rc = reply ? 0 : -1;

    if(reply && (reply->type == REDIS_REPLY_ERROR))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s [RESTORE %s]", reply->str ? reply->str : "???", key), rc = -1;
  } else
    rc = -1;

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  free(buf_bin);

  return(rc);
}

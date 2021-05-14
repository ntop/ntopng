/*
 *
 * (C) 2013-21 - ntop.org
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

Redis::Redis(const char *_redis_host, const char *_redis_password, u_int16_t _redis_port,
	     u_int8_t _redis_db_id, bool giveup_on_failure) {
  redis_host = _redis_host ? strdup(_redis_host) : NULL;
  redis_password = _redis_password ? strdup(_redis_password) : NULL;
  redis_port = _redis_port, redis_db_id = _redis_db_id;
#ifdef __linux__
  is_socket_connection = false;
#endif

  memset(&stats, 0, sizeof(stats));

  redis = NULL, operational = false;
  initializationCompleted = false;
  localToResolve = new (std::nothrow) StringFifoQueue(MAX_NUM_QUEUED_ADDRS);
  remoteToResolve = new (std::nothrow) StringFifoQueue(MAX_NUM_QUEUED_ADDRS);
  reconnectRedis(giveup_on_failure);
  numCached = 0;
  l = new (std::nothrow) Mutex();

  if(operational) getRedisVersion();
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
  if(localToResolve)  delete(localToResolve);
  if(remoteToResolve) delete(remoteToResolve);
}

/* **************************************** */

void Redis::reconnectRedis(bool giveup_on_failure) {
  struct timeval timeout = { 1, 500000 }; // 1.5 seconds
  redisReply *reply = NULL;
  u_int num_attempts;
  bool connected;

  operational = connected = false;

  for(num_attempts = CONST_MAX_REDIS_CONN_RETRIES; num_attempts > 0; num_attempts--) {
    if(redis) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Redis has disconnected, reconnecting [remaining attempts: %u]",
				   num_attempts - 1);
      redisFree(redis);
    }

#ifdef __linux__
    struct stat buf;

    if(!stat(redis_host, &buf) && S_ISSOCK(buf.st_mode))
      redis = redisConnectUnixWithTimeout(redis_host, timeout), is_socket_connection = true;
    else
#endif
      redis = redisConnectWithTimeout(redis_host, redis_port, timeout);

    if(redis == NULL || redis->err) {
      if(redis)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Connection error [%s]", redis->errstr);

      goto conn_retry;
    }

    if(redis_password) {
      stats.num_other++;
      reply = (redisReply*)redisCommand(redis, "AUTH %s", redis_password);
      if(reply && (reply->type == REDIS_REPLY_ERROR)) {
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "Redis authentication failed: %s", reply->str ? reply->str : "???");

	break;
      }
    }

    if(reply) freeReplyObject(reply);
    stats.num_other++;
    reply = (redisReply*)redisCommand(redis, "PING");
    if(reply && (reply->type == REDIS_REPLY_ERROR)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

      goto conn_retry;
    }

    if(reply) freeReplyObject(reply);
    stats.num_other++;
    reply = (redisReply*)redisCommand(redis, "SELECT %u", redis_db_id);
    if(reply && (reply->type == REDIS_REPLY_ERROR)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

      goto conn_retry;
    }

    if(reply) freeReplyObject(reply);
    connected = true;
    break;

  conn_retry:
    if(giveup_on_failure) {
      operational = false;
      return;
    }
    
    sleep(1);
  }

  if(!connected) {
    if(ntop->getTrace()->get_trace_level() == 0) ntop->getTrace()->set_trace_level(MAX_TRACE_LEVEL);
    ntop->getTrace()->traceEvent(TRACE_ERROR, "ntopng requires redis server to be up and running");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Please start it and try again or use -r");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "to specify a redis server other than the default");

    exit(1);
  }

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

  stats.num_reconnections++;
  operational = true;
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

  stats.num_expire++;
  reply = (redisReply*)redisCommand(redis, "EXPIRE %s %u", key, expire_secs);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

bool Redis::isCacheable(const char * const key) {
  if((strstr(key, "ntopng.cache."))
     || (strstr(key, "ntopng.prefs."))
     || (strstr(key, "ntopng.user.") && (!strstr(key, ".password"))))
    return(true);

  return(false);
}

/* **************************************** */

bool Redis::expireCache(char *key, u_int expire_secs) {
  std::map<std::string, StringCache>::iterator it;

#ifdef CACHE_DEBUG
  printf("**** Setting cache expire for %s [%u sec]\n", key, expire_secs);
#endif

  if((it = stringCache.find(key)) != stringCache.end()) {
    it->second.expire = expire_secs ? time(NULL)+expire_secs : 0;
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
    /* Tell housekeeping.lua to refresh in-memory prefs (and possibly dump them to runtimeprefs.json) */
    ntop->getRedis()->set((char*)PREFS_CHANGED, "1");
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Going to refresh after change of: %s", key);
  }
}

/* **************************************** */

int Redis::info(char *rsp, u_int rsp_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "INFO");
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str) {
    snprintf(rsp, rsp_len-1, "%s", reply->str ? reply->str : ""), rc = 0;
  } else
    rsp[0] = 0, rc = -1;
  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

u_int Redis::dbsize() {
  redisReply *reply;
  u_int num = 0;

  l->lock(__FILE__, __LINE__);

  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "DBSIZE");

  if(!reply) reconnectRedis(true);
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

/* **************************************** */

/* NOTE: We assume that the addToCache() caller locks this instance */
void Redis::addToCache(const char * const key, const char * const value, u_int expire_secs) {
  std::map<std::string, StringCache>::iterator it;
  if(!initializationCompleted) return;

#ifdef CACHE_DEBUG
  printf("**** Caching %s=%s [len: %lu]\n", key, value ? value : "<NULL>", value ? strlen(value) : 0);
#endif

  if((it = stringCache.find(key)) != stringCache.end()) {
    StringCache *cached = &it->second;

    cached->value = value;
    cached->expire = expire_secs ? time(NULL)+expire_secs : 0;
    return;
  } else {
    StringCache item;

    item.value = value;
    item.expire = expire_secs ? time(NULL)+expire_secs : 0;

    stringCache[key] = item;
    numCached++;
  }
}

/* **************************************** */

int Redis::get(char *key, char *rsp, u_int rsp_len, bool cache_it) {
  int rc;
  bool cacheable = false;
  redisReply *reply;
  std::map<std::string, StringCache>::iterator it;

  l->lock(__FILE__, __LINE__);

  if((it = stringCache.find(key)) != stringCache.end()) {
    StringCache *cached = &it->second;

    if((cached->expire > 0) && (time(NULL) >= cached->expire)) {
#ifdef CACHE_DEBUG
      printf("**** Cache expired %s\n", key);
#endif

      stringCache.erase(it);
      rsp[0] = '\0';
    } else
      snprintf(rsp, rsp_len, "%s", cached->value.c_str());

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

  stats.num_get++;
  reply = (redisReply*)redisCommand(redis, "GET %s", key);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  cacheable = isCacheable(key);
  if(reply && reply->str) {
    snprintf(rsp, rsp_len, "%s", reply->str ? reply->str : ""), rc = 0;
  } else {
    rsp[0] = 0, rc = -1;
  }
    
  if(cache_it || cacheable) {
    u_int expire_sec = 0;

    if(reply) freeReplyObject(reply);
    stats.num_ttl++;
    reply = (redisReply*)redisCommand(redis, "TTL %s", key);
    if(!reply) reconnectRedis(true);
    if(reply && (reply->type != REDIS_REPLY_INTEGER))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

    if(reply && (((int32_t)reply->integer)) >= 0)
      expire_sec = reply->integer;

#ifdef CACHE_DEBUG
    printf("**** ADD TO CACHE %s=%s [expire_sec=%u]\n", key, rsp, expire_sec);
#endif

    addToCache(key, rsp, expire_sec);
  }

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

  l->lock(__FILE__, __LINE__);

  stringCache.erase(key);

  stats.num_del++;
  reply = (redisReply*)redisCommand(redis, "DEL %s", key);
  if(!reply) reconnectRedis(true);
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

int Redis::hashGet(const char * const key, const char * const field, char * const rsp, u_int rsp_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_hget++;
  reply = (redisReply*)redisCommand(redis, "HGET %s %s", key, field);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "failure on HGET %s %s (%s)", key, field, reply->str ? reply->str : "???");

  if(reply && reply->str) {
    snprintf(rsp, rsp_len-1, "%s", reply->str ? reply->str : ""), rc = 0;
  } else
    rsp[0] = 0, rc = -1;
  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::hashSet(const char * const key, const char * const field, const char * const value) {
  int rc = 0;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_hset++;
  reply = (redisReply*)redisCommand(redis, "HSET %s %s %s", key, field, value);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s [HSET %s %s %s]", reply->str ? reply->str : "???", key, field, value), rc = -1;
  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  if(reply) checkDumpable(key);

  return(rc);
}

/* **************************************** */

int Redis::hashDel(const char * const key, const char * const field) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_hdel++;
  reply = (redisReply*)redisCommand(redis, "HDEL %s %s", key, field);
  if(!reply) reconnectRedis(true);
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

int Redis::_set(bool use_nx, const char * const key, const char * const value, u_int expire_secs) {
  int rc, ret_code = 0;
  redisReply *reply;
  const char* cmd = use_nx ? "SETNX" : "SET";
    
  if((value == NULL) || (value[0] == '\0')) {    
    if(strncmp(key, NTOPNG_PREFS_PREFIX, sizeof(NTOPNG_PREFS_PREFIX)) == 0) {
      /* This is an empty preference value that we can discard*/
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarding empty prefence value %s", key);
    }
  }
  
  l->lock(__FILE__, __LINE__);

  if(isCacheable(key))
    addToCache(key, value, expire_secs);

  stats.num_set++;
  reply = (redisReply*)redisCommand(redis, "%s %s %s", cmd, key, value);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
  if(reply) {
    if(reply->type == REDIS_REPLY_INTEGER) {
      /* SETNX */
      ret_code = reply->integer; /* 1=value not existing, 0=value already existing */
    }
    
    freeReplyObject(reply), rc = 0;
  } else
    rc = -1;

  if((expire_secs != 0)
     && ((use_nx && (ret_code == 1))
	 || ((!use_nx) && (rc == 0)))) {
    stats.num_expire++;
    reply = (redisReply*)redisCommand(redis, "EXPIRE %s %u", key, expire_secs);
    if(!reply) reconnectRedis(true);
    if(reply && (reply->type == REDIS_REPLY_ERROR))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    if(reply) freeReplyObject(reply), rc = 0; else rc = -1;
  }
  l->unlock(__FILE__, __LINE__);

  if(reply && expire_secs == 0)
    checkDumpable(key);

  if(use_nx)
    rc = ret_code;
  
  return(rc);
}

/* **************************************** */

int Redis::keys(const char *pattern, char ***keys_p) {
  int rc = 0;
  u_int i;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_keys++;
  reply = (redisReply*)redisCommand(redis, "KEYS %s", pattern);
  if(!reply) reconnectRedis(true);
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
  stats.num_hkeys++;
  reply = (redisReply*)redisCommand(redis, "HKEYS %s", pattern);
  if(!reply) reconnectRedis(true);
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
  stats.num_hgetall++;
  reply = (redisReply*)redisCommand(redis, "HGETALL %s", key);
  if(!reply) reconnectRedis(true);
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

int Redis::pushHostToResolve(char *hostname, bool dont_check_for_existence, bool localHost) {
  int rc = 0;
  char key[CONST_MAX_LEN_REDIS_KEY];
  bool found;
  redisReply *reply;

  if(!ntop->getPrefs()->is_dns_resolution_enabled()) return(0);
  if(hostname == NULL) return(-1);

  if(!Utils::shouldResolveHost(hostname))
    return(-1);

  snprintf(key, sizeof(key), "%s.%s", DNS_CACHE, hostname);

  l->lock(__FILE__, __LINE__);

  if(dont_check_for_existence)
    found = false;
  else {
    /*
      Add only if the address has not been resolved yet
    */

    stats.num_get++;
    reply = (redisReply*)redisCommand(redis, "GET %s", key);
    if(!reply) reconnectRedis(true);

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
    StringFifoQueue *q = localHost ? localToResolve : remoteToResolve;

    q->enqueue(hostname);
  } else
    reply = 0;

  return(rc);
}

/* **************************************** */

int Redis::popHostToResolve(char *hostname, u_int hostname_len) {
  char *item = localToResolve->dequeue();
  int rv = -1;

  if(!item)
    item = remoteToResolve->dequeue();

  if(item) {
    strncpy(hostname, item, hostname_len);
    hostname[hostname_len - 1] = '\0';
    free(item);
    rv = 0;
  }

  return(rv);
}

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
    set((char*)"ntopng.user.admin.allowed_nets", CONST_DEFAULT_ALL_NETS);
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

  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "FLUSHDB");
  if(!reply) reconnectRedis(true);
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

int Redis::getAddress(char *numeric_ip, char *rsp,
		      u_int rsp_len, bool queue_if_not_found) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  int rc;
  bool already_in_bloom;
  
  rsp[0] = '\0';
  snprintf(key, sizeof(key), "%s.%s", DNS_CACHE, numeric_ip);

  stats.num_get_address++;
  
  if(!ntop->getResolutionBloom()->isSetBit(numeric_ip)) {
    already_in_bloom = false, stats.num_saved_lookups++, rc = -1; /* No way to find it */
#ifdef CACHE_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Saved %s lookup", numeric_ip);
#endif
  } else
    already_in_bloom = true, rc = get(key, rsp, rsp_len);
  
  if(rc != 0) {
    if(queue_if_not_found) {
      if(already_in_bloom)
	ntop->getResolutionBloom()->unsetBit(numeric_ip); /* Expired key ? */
      
      pushHostToResolve(numeric_ip, true, false);
    }
  } else {
    /* We need to extend expire */
    if(!already_in_bloom)
      ntop->getResolutionBloom()->setBit(numeric_ip); /* Previously cached ? */
    
    expire(key, DNS_CACHE_DURATION /* expire */);
  }

  return(rc);
}

/* **************************************** */

int Redis::setResolvedAddress(char *numeric_ip, char *symbolic_ip) {
  char key[CONST_MAX_LEN_REDIS_KEY], numeric[256], *w, *h;
  int rc = 0;

  stats.num_set_resolved_address++;
#if 0
  if(strcmp(symbolic_ip, "broadcasthost") == 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "********");
#endif

  snprintf(numeric, sizeof(numeric), "%s", numeric_ip);

  h = strtok_r(numeric, ";", &w);

  while(h != NULL) {
    snprintf(key, sizeof(key), "%s.%s", DNS_CACHE, h);
    ntop->getResolutionBloom()->setBit(h);
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
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "INFO");
  if(!reply) reconnectRedis(true);
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
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "SMEMBERS %s", setName);
  if(!reply) reconnectRedis(true);
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

bool Redis::sismember(const char *set_name, const char * const member) {
  redisReply *reply = NULL;
  bool res = false;

  l->lock(__FILE__, __LINE__);
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "SISMEMBER %s %s", set_name, member);

  if(!reply) reconnectRedis(true);

  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    else
      res = (u_int)reply->integer == 1 ? true : false;
  }

  l->unlock(__FILE__, __LINE__);
  if(reply) freeReplyObject(reply);

  return res;
}

/* **************************************** */

int Redis::smembers(const char *set_name, char ***members) {
  int rc = -1;
  u_int i;
  redisReply *reply = NULL;

  l->lock(__FILE__, __LINE__);
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "SMEMBERS %s", set_name);

  if(!reply) reconnectRedis(true);

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
int Redis::lpush(const char * const queue_name, const char * const msg, u_int queue_trim_size, bool trace_errors) {
  stats.num_lpush_rpush++;
  return(msg_push("LPUSH", queue_name, msg, queue_trim_size, trace_errors));
}

/* ******************************************* */

/* Add at the bottom of the queue */
int Redis::rpush(const char * const queue_name, const char * const msg, u_int queue_trim_size) {
  stats.num_lpush_rpush++;
  return(msg_push("RPUSH", queue_name, msg, queue_trim_size, true, false));
}

/* ******************************************* */

int Redis::msg_push(const char * const cmd, const char * const queue_name, const char * const msg,
		    u_int queue_trim_size, bool trace_errors, bool head_trim) {
  redisReply *reply;
  int rc = 0;

#ifdef MEASURE_RPUSH
  struct timeval begin, end;
  char theDate[32];
  struct tm result;

  gettimeofday(&begin, NULL);
#endif

  l->lock(__FILE__, __LINE__, trace_errors);
  /* Put the latest messages on top so old messages (if any) will be discarded */
  reply = (redisReply*)redisCommand(redis, "%s %s %s", cmd,  queue_name, msg);

  if(!reply) reconnectRedis(true);
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR && trace_errors)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = -1;
    else
      rc = reply->integer;

#ifdef MEASURE_RPUSH
    {
      time_t theTime = time(NULL);
      gettimeofday(&end, NULL);

      /* IMPORTANT: do not call traceEvent here otherwise it will call rpush again in a loop! */
      strftime(theDate, sizeof(theDate), "%d/%b/%Y %H:%M:%S", localtime_r(&theTime, &result));
      printf("%s %s took %.2f ms\n", theDate, cmd, Utils::msTimevalDiff(&end, &begin));
    }
#endif

    freeReplyObject(reply);

    if(queue_trim_size > 0) {
      stats.num_trim++;
      if(head_trim)
        reply = (redisReply*)redisCommand(redis, "LTRIM %s 0 %u", queue_name, queue_trim_size - 1);
      else
        reply = (redisReply*)redisCommand(redis, "LTRIM %s -%u -1", queue_name, queue_trim_size);
      if(!reply) reconnectRedis(true);
      if(reply) {
	if(reply->type == REDIS_REPLY_ERROR && trace_errors)
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???"), rc = -1;

	freeReplyObject(reply);
      } else
	rc = -1;
    }
  } else
    rc = -1;

  l->unlock(__FILE__, __LINE__, trace_errors);
  return(rc);
}

/* **************************************** */

u_int Redis::len(const char * const key) {
  redisReply *reply;
  u_int num = 0;

  l->lock(__FILE__, __LINE__);

  stats.num_strlen++;
  reply = (redisReply*)redisCommand(redis, "STRLEN %s", key);

  if(!reply) reconnectRedis(true);

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

/* **************************************** */

/* Only available since Redis 3.2.0 */
u_int Redis::hstrlen(const char * const key, const char * const value) {
  redisReply *reply;
  u_int num = 0;
  static bool error_sent = false;

  l->lock(__FILE__, __LINE__);

  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "HSTRLEN %s %s", key, value);

  if(!reply) reconnectRedis(true);
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR) {
      if(!error_sent) {
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", reply->str ? reply->str : "???");
	error_sent = true;
      }
    } else
      num = (u_int)reply->integer;
  }

  l->unlock(__FILE__, __LINE__);
  if(reply) freeReplyObject(reply);

  return(num);
}

/* ******************************************* */

u_int Redis::llen(const char *queue_name) {
  redisReply *reply;
  u_int num = 0;

  l->lock(__FILE__, __LINE__);
  stats.num_llen++;
  reply = (redisReply*)redisCommand(redis, "LLEN %s", queue_name);
  if(!reply) reconnectRedis(true);
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
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "LSET %s %u %s", queue_name, idx, value);
  if(!reply) reconnectRedis(true);
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
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "LREM %s 0 %s", queue_name, value);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  l->unlock(__FILE__, __LINE__);

  if(reply) freeReplyObject(reply);

  return 0;
}

/* ******************************************* */

int Redis::lrpop(const char *queue_name, char *buf, u_int buf_len, bool lpop) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_lpop_rpop++;
  reply = (redisReply*)redisCommand(redis, "%sPOP %s", lpop ? "L" : "R", queue_name);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str)
    snprintf(buf, buf_len, "%s", reply->str ? reply->str : ""), rc = 0;
  else
    buf[0] = '\0', rc = -1;

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* ******************************************* */

int Redis::lpop(const char *queue_name, char *buf, u_int buf_len) {
  return lrpop(queue_name, buf, buf_len, true /* LPOP */);
}

/* ******************************************* */

int Redis::rpop(const char *queue_name, char *buf, u_int buf_len) {
  return lrpop(queue_name, buf, buf_len, false /* RPOP */);
}

/* ******************************************* */

int Redis::lindex(const char *queue_name, int idx, char *buf, u_int buf_len) {
  int rc;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "LINDEX %s %d", queue_name, idx);

  if(!reply) reconnectRedis(true);

  if(reply && (reply->type == REDIS_REPLY_ERROR))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply && reply->str)
    snprintf(buf, buf_len, "%s", reply->str ? reply->str : ""), rc = 0;
  else
    buf[0] = '\0', rc = -1;

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************** */

int Redis::lrange(const char *list_name, char ***elements, int start_offset, int end_offset) {
  int rc = 0;
  u_int i;
  redisReply *reply;

  l->lock(__FILE__, __LINE__);
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "LRANGE %s %i %i", list_name, start_offset, end_offset);

  if(!reply) reconnectRedis(true);
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
  stats.num_other++;

  reply = (redisReply*)redisCommand(redis, "LTRIM %s %d %d", queue_name, start_idx, end_idx);
  if(!reply) reconnectRedis(true);
  if(reply && (reply->type == REDIS_REPLY_ERROR))
    rc = -1, ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");

  if(reply) freeReplyObject(reply);
  l->unlock(__FILE__, __LINE__);

  return(rc);
}

/* ******************************************* */

int Redis::incr(const char *key, int amount) {
  redisReply *reply;
  int num = 0;

  l->lock(__FILE__, __LINE__);
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "INCRBY %s %d", key, amount);
  if(!reply) reconnectRedis(true);
  if(reply) {
    if(reply->type == REDIS_REPLY_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", reply->str ? reply->str : "???");
    else {
      num = (int)reply->integer;

      if(isCacheable(key)) {
        char value[64];

        snprintf(value, sizeof(value), "%d", num);
        addToCache(key, value, 0);
      }
    }
  }
  l->unlock(__FILE__, __LINE__);
  if(reply) freeReplyObject(reply);

  return(num);
}

/* **************************************** */

void Redis::lua(lua_State *vm) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "num_expire", stats.num_expire);
  lua_push_uint64_table_entry(vm, "num_get", stats.num_get);
  lua_push_uint64_table_entry(vm, "num_ttl", stats.num_ttl);
  lua_push_uint64_table_entry(vm, "num_del", stats.num_del);
  lua_push_uint64_table_entry(vm, "num_hget", stats.num_hget);
  lua_push_uint64_table_entry(vm, "num_hset", stats.num_hset);
  lua_push_uint64_table_entry(vm, "num_hdel", stats.num_hdel);
  lua_push_uint64_table_entry(vm, "num_set", stats.num_set);
  lua_push_uint64_table_entry(vm, "num_expire", stats.num_expire);
  lua_push_uint64_table_entry(vm, "num_keys", stats.num_keys);
  lua_push_uint64_table_entry(vm, "num_hkeys", stats.num_hkeys);
  lua_push_uint64_table_entry(vm, "num_hgetall", stats.num_hgetall);
  lua_push_uint64_table_entry(vm, "num_trim", stats.num_trim);
  lua_push_uint64_table_entry(vm, "num_reconnections", stats.num_reconnections);
  lua_push_uint64_table_entry(vm, "num_lpush_rpush", stats.num_lpush_rpush);
  lua_push_uint64_table_entry(vm, "num_lpop_rpop", stats.num_lpop_rpop);
  lua_push_uint64_table_entry(vm, "num_llen", stats.num_llen);
  lua_push_uint64_table_entry(vm, "num_strlen", stats.num_strlen);
  lua_push_uint64_table_entry(vm, "num_other", stats.num_other);

  /* Address resolution */
  lua_push_uint64_table_entry(vm, "num_resolver_saved_lookups", stats.num_saved_lookups);
  lua_push_uint64_table_entry(vm, "num_resolver_get_address",   stats.num_get_address);
  lua_push_uint64_table_entry(vm, "num_resolver_set_address",   stats.num_set_resolved_address);  
}

/* **************************************** */

void Redis::flushCache() {
  l->lock(__FILE__, __LINE__);
  stringCache.clear();
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
  stats.num_other++;
  reply = (redisReply*)redisCommand(redis, "DUMP %s", key);
  if(!reply) reconnectRedis(true);
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
  const char * argv[5] = {"RESTORE", key, "0" /* <-- TTL */, buf_bin};
  size_t argvlen[5] = {7, 0, 0, 0, 7};

  if(buf_bin == NULL)
    return(-1);

  hex2bin(buf, buf_bin);

  l->lock(__FILE__, __LINE__);
  stats.num_del++;

  /* Delete the key first */
  reply = (redisReply*)redisCommand(redis, "DEL %s", key);
  if(!reply) reconnectRedis(true);

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

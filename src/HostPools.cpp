/*
 *
 * (C) 2015-17 - ntop.org
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

/* #define HOST_POOLS_DEBUG 1 */

/* *************************************** */

HostPools::HostPools(NetworkInterface *_iface) {
  tree = tree_shadow = NULL;
#ifdef NTOPNG_PRO
  stats = stats_shadow = NULL;
#endif
  if(_iface)
    iface = _iface;

  reloadPools();

#ifdef NTOPNG_PRO
  loadFromRedis();
#endif
}

HostPools::~HostPools() {
#ifdef NTOPNG_PRO
  dumpToRedis();
#endif

  /* Note: no need to deallocate here, ntopng is shutting down */
}

/* *************************************** */

#ifdef NTOPNG_PRO

void HostPools::dumpToRedis() {
  char key[128];
  char buf[32];
  Redis *redis = ntop->getRedis();

  if((!redis) || (! stats) || (! iface)) return;

  snprintf(key, sizeof(key), HOST_POOL_DUMP_KEY, iface->get_id());

  for (int i = 1 /*exclude default*/; i<MAX_NUM_HOST_POOLS; i++) {
    if(stats[i]) {
      snprintf(buf, sizeof(buf), "%d", i);
      char *value = stats[i]->serialize(iface);
      if (value) {
        redis->hashSet(key, buf, value);
        free(value);
      }
    }
  }
}

void HostPools::loadFromRedis() {
  char key[128];
  char buf[32];
  char *value;
  json_object *obj;
  enum json_tokener_error jerr = json_tokener_success;
  Redis *redis = ntop->getRedis();

  snprintf(key, sizeof(key), HOST_POOL_DUMP_KEY, iface->get_id());

  if((!redis) || (! stats) || (! iface)) return;
  if((value = (char *) malloc(POOL_MAX_SERIALIZED_LEN)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "Unable to allocate memory to deserialize %s", key);
    return;
  }

  for (int i = 1 /*exclude default*/; i<MAX_NUM_HOST_POOLS; i++) {
    if(stats[i]) {
      snprintf(buf, sizeof(buf), "%d", i);
      if (redis->hashGet(key, buf, value, POOL_MAX_SERIALIZED_LEN) != 1) {
        if((obj = json_tokener_parse_verbose(value, &jerr)) == NULL) {
          ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] key: %s: %s",
                  json_tokener_error_desc(jerr),
                  key,
                  value);
        } else {
          stats[i]->deserialize(iface, obj);
          json_object_put(obj);
        }
      }
    }
  }

  free(value);
}

void HostPools::incPoolStats(u_int16_t host_pool_id, u_int ndpi_proto,
			     u_int64_t sent_packets, u_int64_t sent_bytes,
			     u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
  if(host_pool_id == 0 || host_pool_id > MAX_NUM_HOST_POOLS || !stats || !stats[host_pool_id])
    return;
  stats[host_pool_id]->incStats(ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
};

/* *************************************** */

void HostPools::updateStats(struct timeval *tv) {

  if(stats && tv) {
    for(int i = 1 /*exclude default*/; i < MAX_NUM_HOST_POOLS; i++)
      if(stats[i])
        stats[i]->updateStats(tv);
  }
};

/* *************************************** */

void HostPools::lua(lua_State *vm) {
  if(stats && vm) {
    lua_newtable(vm);
    for(int i = 1; i < MAX_NUM_HOST_POOLS; i++) {
      if(stats[i]) {
	stats[i]->lua(vm, iface);
	lua_rawseti(vm, -2, i);
      }
    }
  }
};
#endif

/* *************************************** */

void HostPools::reloadPools() {
  char kname[CONST_MAX_LEN_REDIS_KEY];
  char **pools, **pool_members, *at, *member;
  int num_pools, num_members;
  u_int16_t _pool_id, vlan_id;
  AddressTree **new_tree;
#ifdef NTOPNG_PRO
  HostPoolStats **new_stats;
#endif
  Redis *redis = ntop->getRedis();

  if(!iface || iface->get_id() == -1)
    return;

  if((new_tree = new AddressTree*[MAX_NUM_VLAN]) == NULL
#ifdef NTOPNG_PRO
     || (new_stats = new HostPoolStats*[MAX_NUM_HOST_POOLS]) == NULL
#endif
     ) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Not enough memory");
    return;
  }
  for(u_int32_t i = 0; i < MAX_NUM_VLAN; i++)
    new_tree[i] = NULL;
#ifdef NTOPNG_PRO
  for(u_int32_t i = 0; i < MAX_NUM_HOST_POOLS; i++)
    new_stats[i] = NULL;
#endif

  snprintf(kname, sizeof(kname),
	   HOST_POOL_IDS_KEY, iface->get_id());

  /* Keys are pool ids */
  if((num_pools = redis->smembers(kname, &pools)) <= 0) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "No host pools for interface %s", iface->get_name());
    delete new_tree; /* No need to invoke destructors here as elements are empty */
    return;
  }

  for(int i = 0; i < num_pools; i++) {
    if(!pools[i])
      continue;

    _pool_id = (u_int16_t)atoi(pools[i]);
    if(_pool_id == 0 || _pool_id > MAX_NUM_HOST_POOLS)
      continue;

#ifdef NTOPNG_PRO
    if(stats && stats[_pool_id]) /* Duplicate existing statistics */
      new_stats[_pool_id] = new HostPoolStats(*stats[_pool_id]);
    else /* Brand new statistics */
      new_stats[_pool_id] = new HostPoolStats();
#endif

    snprintf(kname, sizeof(kname),
	     HOST_POOL_MEMBERS_KEY, iface->get_id(), pools[i]);

    /* Pool members are the elements of the list */
    if((num_members = redis->smembers(kname, &pool_members)) > 0) {

      for(int k = 0; k < num_members; k++) {
	member = pool_members[k];

	if(!member) continue;

	if((at = strchr(member, '@'))) {
	  vlan_id = atoi(at + 1);
	  *at = '\0';
	} else
	  vlan_id = 0;

	if(new_tree[vlan_id] || (new_tree[vlan_id] = new AddressTree())) {
	  bool rc;

	  if(!(rc = new_tree[vlan_id]->addAddress(member, _pool_id))
#ifdef HOST_POOLS_DEBUG
	     || true
#endif
	     )

	    ntop->getTrace()->traceEvent(TRACE_NORMAL,
					 "%s tree node for %s [vlan %i] [host pool: %s]",
					 rc ? "Successfully added" : "Unable to add",
					 member, vlan_id,
					 pools[i]);

	}

	free(member);
      }

      free(pool_members);
    }

    free(pools[i]);
  }

  if(pools)
    free(pools);

  /* Swap address trees */
  if(tree) {
    if(tree_shadow)
      delete []tree_shadow; /* Invokes the destructor */
    tree_shadow = tree;
  }
  tree = new_tree;

#ifdef NTOPNG_PRO
  /* Swap statistics */
  if(stats) {
    if(stats_shadow)
      delete []stats_shadow;
    stats_shadow = stats;
  }
  stats = new_stats;
#endif

  iface->refreshHostPools();
}

/* *************************************** */

u_int16_t HostPools::getPool(Host *h) {
  Mac *mac;
  IpAddress *ip;
  patricia_node_t *node;
#ifdef HOST_POOLS_DEBUG
  char buf[128];
  char *k;
#endif

  if(!h || !tree || !tree[h->get_vlan_id()])
    return NO_HOST_POOL_ID;

  if((mac = h->getMac()) && !mac->isSpecialMac()) {
    int16_t ret = mac->findAddress(tree[h->get_vlan_id()]);

    if(ret != -1) {
#ifdef HOST_POOLS_DEBUG
      k = mac->get_string_key(buf, sizeof(buf));
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Found pool for %s [pool id: %i]",
				   k, ret);
#endif

      return((u_int16_t)ret);
    }
  }

  if((ip = h->get_ip())) {
    node = (patricia_node_t*)ip->findAddress(tree[h->get_vlan_id()]);
    if(node) {
#ifdef HOST_POOLS_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Found pool for %s [pool id: %i]",
				   h->get_ip()->print(buf, sizeof(buf)), node->user_data);
#endif
      return node->user_data;
    }
  }

  return NO_HOST_POOL_ID;
}

/* *************************************** */

void HostPools::addToPool(u_int32_t client_ipv4 /* network byte order */,
			  u_int16_t user_pool_id,
			  bool permanentAuthorization) {
  char buf[64], host[128];

  snprintf(host, sizeof(host), "%s/32@0", 
	   Utils::intoaV4(ntohl(client_ipv4), buf, sizeof(buf)));

  addToPool(host, user_pool_id, permanentAuthorization);
}

/* *************************************** */

void HostPools::addToPool(char *host_or_mac,
			  u_int16_t user_pool_id,
			  bool permanentAuthorization) {
  char key[128], pool_buf[16];

  snprintf(pool_buf, sizeof(pool_buf), "%u", user_pool_id);
  snprintf(key, sizeof(key), HOST_POOL_MEMBERS_KEY, iface->get_id(), pool_buf);

  if(ntop->getRedis()->sadd(key, host_or_mac) /* New member added */) {
    if(!permanentAuthorization) {

      snprintf(key, sizeof(key), HOST_POOL_VOLATILE_MEMBERS_KEY, iface->get_id(), pool_buf);
      if(!ntop->getRedis()->sadd(key, host_or_mac)) {
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Unable to add %s as VOLATILE host pool member [pool id: %s]",
				     host_or_mac, pool_buf);
	return;
      }

      snprintf(key, sizeof(key), HOST_POOL_VOLATILE_MEMBER_EXPIRE, iface->get_id(), host_or_mac);
      if(ntop->getRedis()->set(key,
			       host_or_mac, /* Just a placeholder, we only care about the expire time */
			       3600 * 24 /* 1 Day, TODO: make it configurable */)) {
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Unable to set expire key for VOLATILE pool member %s [pool id: %s]",
				     host_or_mac, pool_buf);
	return;
      }
    }

    reloadPools();
  } else {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to add %s as PERMANENT host pool member [pool id: %s]",
				 host_or_mac, pool_buf);
  }
}

/* *************************************** */

void HostPools::purgeExpiredMembers() {
  char kname[CONST_MAX_LEN_REDIS_KEY], volatile_member[128];
  char **pools, **volatile_pool_members;
  int num_pools, num_volatile_members;
  bool purged = false;
  Redis *redis = ntop->getRedis();

  if(!iface || iface->get_id() == -1)
    return;

  snprintf(kname, sizeof(kname),
	   HOST_POOL_IDS_KEY, iface->get_id());

  if((num_pools = redis->smembers(kname, &pools)) <= 0) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "No host pools for interface %s", iface->get_name());
    return;
  }

  for(int i = 0; i < num_pools; i++) {
    if(!pools[i]) continue;

    /* Read VOLATILE pool members */
    snprintf(kname, sizeof(kname),
	     HOST_POOL_VOLATILE_MEMBERS_KEY, iface->get_id(), pools[i]);
    if((num_volatile_members = redis->smembers(kname, &volatile_pool_members)) > 0) {

      for(int k = 0; k < num_volatile_members; k++) {

	if(!volatile_pool_members[k]) continue;

	snprintf(kname, sizeof(kname),
		 HOST_POOL_VOLATILE_MEMBER_EXPIRE, iface->get_id(), volatile_pool_members[k]);

	if(redis->get(kname, volatile_member, sizeof(volatile_member), false) < 0
	   || strcmp(volatile_member, volatile_pool_members[k])) { /* The key is expired */
	  purged = true;
	  /* Delete both from the members and volatile members sets */
	  
	  snprintf(kname, sizeof(kname),
		   HOST_POOL_VOLATILE_MEMBERS_KEY, iface->get_id(), pools[i]);
	  redis->srem(kname, volatile_pool_members[k]);

	  snprintf(kname, sizeof(kname),
		   HOST_POOL_MEMBERS_KEY, iface->get_id(), pools[i]);
	  redis->srem(kname, volatile_pool_members[k]);

#ifdef HOST_POOLS_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL,
				       "Purged %s that was expired [host pool: %s]",
				       volatile_pool_members[k],
				       pools[i]);
#endif
	}

	free(volatile_pool_members[k]);
      }

      free(volatile_pool_members);
    }

    free(pools[i]);
  }

  if(pools)
    free(pools);

  if(purged)
    reloadPools();
}

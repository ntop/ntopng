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
  max_num_pools = MAX_NUM_HOST_POOLS;

  if((children_safe = (bool*)calloc(max_num_pools, sizeof(bool))) == NULL)
    throw 1;

#ifdef NTOPNG_PRO
  stats = stats_shadow = NULL;

  if((volatile_members = (volatile_members_t**)calloc(max_num_pools, sizeof(volatile_members_t))) == NULL
     || (volatile_members_lock = new Mutex*[max_num_pools]) == NULL
     || (enforce_quotas_per_pool_member = (bool*)calloc(max_num_pools, sizeof(bool))) == NULL)
    throw 1;

  for(int i = 0; i < max_num_pools; i++) {
    if((volatile_members_lock[i] = new Mutex()) == NULL)
      throw 2;
  }
#endif

  latest_swap = 0;
  if((swap_lock = new Mutex()) == NULL)
    throw 3;

  if(_iface)
    iface = _iface;

  reloadPools();

#ifdef NTOPNG_PRO
  loadFromRedis();
#endif

  assert(MAX_NUM_HOST_POOLS == max_num_pools);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Host Pools Available: %u", max_num_pools);
}

/* *************************************** */

HostPools::~HostPools() {
  if(tree_shadow)
    delete []tree_shadow;
  if(tree)
    delete []tree;
  if(children_safe)
    free(children_safe);

#ifdef NTOPNG_PRO
  dumpToRedis();

  if(enforce_quotas_per_pool_member)
    free(enforce_quotas_per_pool_member);
  
  if(stats)
    delete []stats;
  if(stats_shadow)
    delete []stats_shadow;

  if(volatile_members_lock)
    delete []volatile_members_lock;

  if(volatile_members) {
    for(int pool_id = 0; pool_id < max_num_pools; pool_id++) {
      volatile_members_t *current, *tmp;

      HASH_ITER(hh, volatile_members[pool_id], current, tmp) {
	HASH_DEL(volatile_members[pool_id], current);
	free(current->host_or_mac);
	free(current);
      }

      if(volatile_members[pool_id])
	free(volatile_members[pool_id]);
    }

    free(volatile_members);
  }

#endif
}

/* *************************************** */

#ifdef NTOPNG_PRO
void HostPools::swap(AddressTree **new_trees, HostPoolStats **new_stats) {
#else
void HostPools::swap(AddressTree **new_trees) {
#endif
  swap_lock->lock(__FILE__, __LINE__);
  while(time(NULL) - latest_swap < 1) {
    swap_lock->unlock(__FILE__, __LINE__);
    sleep(1); /* Force at least 1 sec. time between consecutive swaps */
    swap_lock->lock(__FILE__, __LINE__);
  }

#ifdef NTOPNG_PRO
  /* Swap statistics */
  if(new_stats) {
    if(stats) {
      if(stats_shadow)
	delete []stats_shadow;
      stats_shadow = stats;
    }
    stats = new_stats;
  }
#endif

  /* Swap address trees */
  if(new_trees) {
    if(tree) {
      if(tree_shadow)
	delete []tree_shadow; /* Invokes the destructor */
      tree_shadow = tree;
    }
    tree = new_trees;
  }

  latest_swap = time(NULL);
  swap_lock->unlock(__FILE__, __LINE__);
}

/* *************************************** */

#ifdef NTOPNG_PRO

void HostPools::reloadVolatileMembers(AddressTree **_trees) {
  volatile_members_t *current, *tmp;
  char *at, *member;
  bool rc;
  u_int16_t vlan_id;

  if(!_trees)
    return;

  for(int pool_id = 0; pool_id < max_num_pools; pool_id++) {

    if(!volatile_members[pool_id])
      continue;

    volatile_members_lock[pool_id]->lock(__FILE__, __LINE__);

    if(stats && stats[pool_id]) { /* The pool exists */
      HASH_ITER(hh, volatile_members[pool_id], current, tmp) {
	member = strdup(current->host_or_mac);

	if((at = strchr(member, '@'))) {
	  vlan_id = atoi(at + 1);
	  *at = '\0';
	} else
	  vlan_id = 0;

	if(_trees[vlan_id]  || (_trees[vlan_id] = new AddressTree())) {
	  if(!(rc = _trees[vlan_id]->addAddress(member, pool_id))
#ifdef HOST_POOLS_DEBUG
	     || true
#endif
	     )
	    ntop->getTrace()->traceEvent(TRACE_NORMAL,
					 "%s VOLATILE tree node for %s [vlan %i] [host pool: %i]",
					 rc ? "Successfully added" : "Unable to add",
					 member, vlan_id,
					 pool_id);

	}

	free(member);
      }
    } else { /* The pool no longer exists */
      HASH_ITER(hh, volatile_members[pool_id], current, tmp) {
	HASH_DEL(volatile_members[pool_id], current);
	free(current->host_or_mac);
	free(current);
      }
    }

    volatile_members_lock[pool_id]->unlock(__FILE__, __LINE__);

  }
};

void HostPools::addVolatileMember(char *host_or_mac, u_int16_t host_pool_id, time_t lifetime) {
  volatile_members_t *m;

  if(!host_or_mac || host_pool_id >= max_num_pools)
    return;

  volatile_members_lock[host_pool_id]->lock(__FILE__, __LINE__);

  HASH_FIND_STR(volatile_members[host_pool_id], host_or_mac, m);

  if(m == NULL) {
    m = (volatile_members_t*)calloc(1, sizeof(volatile_members_t));
    m->host_or_mac = strdup(host_or_mac);
    HASH_ADD_STR(volatile_members[host_pool_id], host_or_mac, m);
  }
  m->lifetime = time(NULL) + lifetime;

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
    "Adding %s VOLATILE MEMBER to the hash table [host pool: %i] [lifetime: %i]",
    host_or_mac, host_pool_id, lifetime);
#endif

  volatile_members_lock[host_pool_id]->unlock(__FILE__, __LINE__);
}

/* *************************************** */

void HostPools::dumpToRedis() {
  char key[128];
  char buf[32];
  Redis *redis = ntop->getRedis();

  if((!redis) || (! stats) || (! iface)) return;

  snprintf(key, sizeof(key), HOST_POOL_DUMP_KEY, iface->get_id());

  for(int i = 0; i<max_num_pools; i++) {
    if(stats[i]) {
      snprintf(buf, sizeof(buf), "%d", i);
      char *value = stats[i]->serialize(iface);
      if(value) {
	redis->hashSet(key, buf, value);
	free(value);
      }
    }
  }
}

/* *************************************** */

void HostPools::loadFromRedis() {
  char key[128], buf[32], *value;
  json_object *obj;
  enum json_tokener_error jerr = json_tokener_success;
  Redis *redis = ntop->getRedis();

  snprintf(key, sizeof(key), HOST_POOL_DUMP_KEY, iface->get_id());

  if((!redis) || (! stats) || (! iface)) return;
  if((value = (char *) malloc(POOL_MAX_SERIALIZED_LEN)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory to deserialize %s", key);
    return;
  }

  for(int i = 0; i<max_num_pools; i++) {
    if(stats[i]) {
      snprintf(buf, sizeof(buf), "%d", i);
      if(redis->hashGet(key, buf, value, POOL_MAX_SERIALIZED_LEN) == 0) {
	if((obj = json_tokener_parse_verbose(value, &jerr)) == NULL) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] key: %s: %s",
				       json_tokener_error_desc(jerr),
				       key, value);
	} else {
	  stats[i]->deserialize(iface, obj);
	  json_object_put(obj);
	}
      }
    }
  }

  free(value);
}
 
/* *************************************** */
 
void HostPools::incPoolStats(u_int32_t when, u_int16_t host_pool_id, u_int16_t ndpi_proto,
			     ndpi_protocol_category_t category_id, u_int64_t sent_packets, u_int64_t sent_bytes,
			     u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
  HostPoolStats *hps = getPoolStats(host_pool_id);
  
  if(!hps)
    return;
  
  /* Important to use the assigned hps as a swap can make stats[host_pool_id] NULL */
  hps->incStats(when, ndpi_proto, category_id, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
};
 
/* *************************************** */
 
void HostPools::updateStats(struct timeval *tv) {
  HostPoolStats *hps;

  if(stats && tv) {
    for(int i = 0; i < max_num_pools; i++)
      if((hps = stats[i]))
	hps->updateStats(tv); /* Use hps, stats[i] can become NULL after a swap */
  }
};

/* *************************************** */

void HostPools::luaStats(lua_State *vm) {
  HostPoolStats *hps;

  if(vm) {
    lua_newtable(vm);

    if(stats) {
      for(int i = 0; i < max_num_pools; i++) {
	if((hps = stats[i])) {
	  /* Must use the assigned hps as stats can be swapped
	     and accesses such as stats[i] could yield a NULL value */
	  hps->lua(vm, iface);
	  lua_rawseti(vm, -2, i);
	}
      }
    }
  }
};

/* *************************************** */

void HostPools::resetPoolsStats() {
    HostPoolStats *hps;

  if(stats) {
    for(int i = 0; i < max_num_pools; i++) {
      if((hps = stats[i])) {
        /* Must use the assigned hps as stats can be swapped
           and accesses such as stats[i] could yield a NULL value */
        hps->resetStats();
      }
    }
  }
}

/* *************************************** */

void HostPools::luaVolatileMembers(lua_State *vm) {
  volatile_members_t *current, *tmp;
  int i;
  time_t now = time(NULL);

  if(!vm)
    return;

  lua_newtable(vm);

  for(int pool_id = 0; pool_id < max_num_pools; pool_id++) {

    if(!volatile_members[pool_id])
      continue;

    volatile_members_lock[pool_id]->lock(__FILE__, __LINE__);

    if(stats && stats[pool_id]) { /* The pool exists */
      lua_newtable(vm);

      i = 0;
      HASH_ITER(hh, volatile_members[pool_id], current, tmp) {
	lua_newtable(vm);

	lua_push_str_table_entry(vm, "member", current->host_or_mac);
	lua_push_float_table_entry(vm, "residual_lifetime", current->lifetime - now);
	lua_push_bool_table_entry(vm, "expired", current->lifetime - now < 0);

	lua_rawseti(vm, -2, ++i);
      }

      lua_rawseti(vm, -2, pool_id);
    }

    volatile_members_lock[pool_id]->unlock(__FILE__, __LINE__);

  }
};

/* *************************************** */

void HostPools::addToPool(char *host_or_mac,
			  u_int16_t user_pool_id,
			  int32_t lifetime_secs) {
  char key[128], pool_buf[16];

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Adding %s as %s host pool member [pool id: %i]",
			       host_or_mac,
			       lifetime_secs <= 0 ? "PERMANENT" : "VOLATILE",
			       user_pool_id);
#endif

  if(lifetime_secs > 0)
    addVolatileMember(host_or_mac, user_pool_id, (u_int32_t)lifetime_secs);

  else {
    snprintf(pool_buf, sizeof(pool_buf), "%u", user_pool_id);
    snprintf(key, sizeof(key), HOST_POOL_MEMBERS_KEY, iface->get_id(), pool_buf);
    ntop->getRedis()->sadd(key, host_or_mac); /* New member added */
  }

  reloadPools();
}

/* *************************************** */

void HostPools::purgeExpiredVolatileMembers() {
  volatile_members_t *current, *tmp;
  bool purged = false;
  time_t now = time(NULL);

  for(int pool_id = 0; pool_id < max_num_pools; pool_id++) {
    volatile_members_lock[pool_id]->lock(__FILE__, __LINE__);

    HASH_ITER(hh, volatile_members[pool_id], current, tmp) {
#ifdef HOST_POOLS_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Checking VOLATILE MEMBER %s [pool id: %i] for expiration...",
				   current->host_or_mac,
				   pool_id);
#endif

      if(current->lifetime < now) {
	purged = true;

#ifdef HOST_POOLS_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Purging expired VOLATILE MEMBER %s [pool id: %i]",
				     current->host_or_mac,
				     pool_id);
#endif

	HASH_DEL(volatile_members[pool_id], current);
	free(current->host_or_mac);
	free(current);
      }
    }

    volatile_members_lock[pool_id]->unlock(__FILE__, __LINE__);
  }

  if(purged)
    reloadPools();
}

/* *************************************** */

void HostPools::removeVolatileMemberFromPool(char *host_or_mac, u_int16_t user_pool_id) {
  volatile_members_t *m;
  bool purged = false;

  if(user_pool_id == NO_HOST_POOL_ID || user_pool_id >= max_num_pools || !host_or_mac)
    return;

  volatile_members_lock[user_pool_id]->lock(__FILE__, __LINE__);

  HASH_FIND_STR(volatile_members[user_pool_id], host_or_mac, m);
  if(m) {
    HASH_DEL(volatile_members[user_pool_id], m);
    free(m->host_or_mac);
    free(m);
    purged = true;
  }

  volatile_members_lock[user_pool_id]->unlock(__FILE__, __LINE__);

  if(purged)
    reloadPools();
}

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
     || (new_stats = new HostPoolStats*[max_num_pools]) == NULL
#endif
     ) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Not enough memory");
    return;
  }
  for(u_int32_t i = 0; i < MAX_NUM_VLAN; i++)
    new_tree[i] = NULL;
#ifdef NTOPNG_PRO
  for(u_int32_t i = 0; i < max_num_pools; i++)
    new_stats[i] = NULL;
#endif

  snprintf(kname, sizeof(kname), HOST_POOL_IDS_KEY, iface->get_id());

#ifdef NTOPNG_PRO
  /* Always allocate defaul pool stats */
  if(stats && stats[0]) /* Duplicate existing statistics */
    new_stats[0] = new HostPoolStats(*stats[0]);
  else /* Brand new statistics */
    new_stats[0] = new HostPoolStats();
#endif

  /* Keys are pool ids */
  num_pools = redis->smembers(kname, &pools);

  for(int i = 0; i < num_pools; i++) {
    char rsp[8];

    if(!pools[i])
      continue;

    _pool_id = (u_int16_t)atoi(pools[i]);
    if(_pool_id >= max_num_pools)
      continue;

#ifdef NTOPNG_PRO
    if(_pool_id != 0) { /* Pool id 0 stats already updated */
      if(stats && stats[_pool_id]) /* Duplicate existing statistics */
        new_stats[_pool_id] = new HostPoolStats(*stats[_pool_id]);
      else /* Brand new statistics */
        new_stats[_pool_id] = new HostPoolStats();
    }
#endif

    snprintf(kname, sizeof(kname), HOST_POOL_DETAILS_KEY, iface->get_id(), i);
    rsp[0] = '\0';
    children_safe[i] = ((redis->hashGet(kname, (char*)"children_safe", rsp, sizeof(rsp)) != -1) && (!strcmp(rsp, "true")));

#ifdef NTOPNG_PRO
    enforce_quotas_per_pool_member[i] = ((redis->hashGet(kname, (char*)"enforce_quotas_per_pool_member", rsp, sizeof(rsp)) != -1) && (!strcmp(rsp, "true")));;

#ifdef HOST_POOLS_DEBUG
    redis->hashGet(kname, (char*)"name", rsp, sizeof(rsp));
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loading pool [name: %s] [children_safe: %i] [enforce_quotas_per_pool_member: %i]",
				 rsp, children_safe[i], enforce_quotas_per_pool_member[i]);    
#endif

#endif /* NTOPNG_PRO */

    snprintf(kname, sizeof(kname), HOST_POOL_MEMBERS_KEY, iface->get_id(), pools[i]);

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

#ifdef NTOPNG_PRO
  if(ntop->getPrefs()->isCaptivePortalEnabled())
    reloadVolatileMembers(new_tree /* Reload only on the new */);
  swap(new_tree, new_stats);
#else
  swap(new_tree);
#endif

  iface->refreshHostPools();
}

/* *************************************** */

bool HostPools::findMacPool(u_int8_t *mac, u_int16_t vlan_id, u_int16_t *found_pool) {
  AddressTree *cur_tree; /* must use this as tree can be swapped */

  if(!tree || !(cur_tree = tree[vlan_id]))
    return false;

  int16_t ret = cur_tree->findMac(mac);

  if(ret != -1) {
    *found_pool = (u_int16_t)ret;
    return true;
  }

  return false;
}

/* *************************************** */

bool HostPools::findMacPool(Mac *mac, u_int16_t *found_pool) {
  if (mac->isSpecialMac())
    return false;

  return findMacPool(mac->get_mac(), mac->get_vlan_id(), found_pool);
}

/* *************************************** */

bool HostPools::findIpPool(IpAddress *ip, u_int16_t vlan_id, u_int16_t *found_pool, patricia_node_t **found_node) {
  AddressTree *cur_tree; /* must use this as tree can be swapped */
#ifdef HOST_POOLS_DEBUG
  char buf[128];
#endif

  if(!tree || !(cur_tree = tree[vlan_id]))
    return false;

  *found_node = (patricia_node_t*)ip->findAddress(cur_tree);
  if(*found_node) {
#ifdef HOST_POOLS_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Found pool for %s [pool id: %i]",
				   ip->print(buf, sizeof(buf)), (*found_node)->user_data);
#endif
      *found_pool = (*found_node)->user_data;
      return true;
  }

  return false;
}


/* *************************************** */

u_int16_t HostPools::getPool(Host *h) {
  u_int16_t pool_id;
  patricia_node_t *node;
  bool found = false;

  if(h) {
    if(h->getMac())
      found = findMacPool(h->getMac(), &pool_id);
    if(!found && h->get_ip()) {
      found = findIpPool(h->get_ip(), h->get_vlan_id(), &pool_id, &node);
    }
  }

  if(!found)
    return NO_HOST_POOL_ID;

  return pool_id;
}

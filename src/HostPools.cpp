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

  if((volatile_members = (volatile_members_t**)calloc(MAX_NUM_HOST_POOLS, sizeof(volatile_members_t))) == NULL
     || (volatile_members_lock = new Mutex*[MAX_NUM_HOST_POOLS]) == NULL)
    throw 1;

  for(int i = 0; i < MAX_NUM_HOST_POOLS; i++) {
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
  
  for(int pool_id = 0; pool_id < MAX_NUM_HOST_POOLS; pool_id++) {

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

  if(!host_or_mac || host_pool_id >= MAX_NUM_HOST_POOLS)
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

void HostPools::incPoolStats(u_int16_t host_pool_id, u_int ndpi_proto,
			     u_int64_t sent_packets, u_int64_t sent_bytes,
			     u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
  if(host_pool_id == 0 || host_pool_id >= MAX_NUM_HOST_POOLS || !stats || !stats[host_pool_id])
    return;
  stats[host_pool_id]->incStats(ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
};

/* *************************************** */

void HostPools::updateStats(struct timeval *tv) {
  if(stats && tv) {
    for(int i = 1; i < MAX_NUM_HOST_POOLS; i++)
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

void HostPools::purgeExpiredVolatileMembers() {
  volatile_members_t *current, *tmp;
  bool purged = false;

  for(int pool_id = 0; pool_id < MAX_NUM_HOST_POOLS; pool_id++) {
    volatile_members_lock[pool_id]->lock(__FILE__, __LINE__);

    HASH_ITER(hh, volatile_members[pool_id], current, tmp) {
#ifdef HOST_POOLS_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Checking VOLATILE MEMBER %s [pool id: %i] for expiration...",
				   current->host_or_mac,
				   pool_id);
#endif

      if(current->lifetime < time(NULL)) {
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
    if(_pool_id == 0 || _pool_id >= MAX_NUM_HOST_POOLS)
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

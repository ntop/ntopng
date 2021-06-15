/*
 *
 * (C) 2015-21 - ntop.org
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

// #define HOST_POOLS_DEBUG 1

/* *************************************** */

HostPools::HostPools(NetworkInterface *_iface) {
  tree = tree_shadow = NULL;
#ifdef NTOPNG_PRO
  children_safe = forge_global_dns = NULL;
  routing_policy_id = NULL;

  if((children_safe = (bool*)calloc(MAX_NUM_HOST_POOLS, sizeof(bool))) == NULL)
    throw 1;

  if((forge_global_dns = (bool*)calloc(MAX_NUM_HOST_POOLS, sizeof(bool))) == NULL)
    throw 1;

  if((routing_policy_id = (u_int8_t*)calloc(MAX_NUM_HOST_POOLS, sizeof(u_int8_t))) == NULL)
    throw 1;

  for(int i = 0; i < MAX_NUM_HOST_POOLS; i++) routing_policy_id[i] = DEFAULT_ROUTING_TABLE_ID;

  if((pool_shaper = (u_int16_t*)calloc(MAX_NUM_HOST_POOLS, sizeof(u_int16_t))) == NULL
     || (schedule_bitmap = (u_int32_t*)calloc(MAX_NUM_HOST_POOLS, sizeof(u_int32_t))) == NULL
     || (enforce_quotas_per_pool_member   = (bool*)calloc(MAX_NUM_HOST_POOLS, sizeof(bool))) == NULL
     || (enforce_shapers_per_pool_member  = (bool*)calloc(MAX_NUM_HOST_POOLS, sizeof(bool))) == NULL)
    throw 1;
#endif

  stats = stats_shadow = NULL;

  if((num_active_hosts_inline          = (int32_t*)calloc(sizeof(int32_t), MAX_NUM_HOST_POOLS)) == NULL
     || (num_active_hosts_offline      = (int32_t*)calloc(sizeof(int32_t), MAX_NUM_HOST_POOLS)) == NULL
     || (num_active_l2_devices_inline  = (int32_t*)calloc(sizeof(int32_t), MAX_NUM_HOST_POOLS)) == NULL
     || (num_active_l2_devices_offline = (int32_t*)calloc(sizeof(int32_t), MAX_NUM_HOST_POOLS)) == NULL)
    throw 1;

  if(_iface)
    iface = _iface;

  reloadPools();

  loadFromRedis();

  max_num_pools = MAX_NUM_HOST_POOLS;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Host Pools Available: %u", MAX_NUM_HOST_POOLS);
}

/* *************************************** */

void HostPools::deleteStats(HostPoolStats ***hps) {
  if(hps) {
    if(*hps) {
      for(int i = 0; i < MAX_NUM_HOST_POOLS; i++)
	if((*hps)[i])
	  delete (*hps)[i];
      delete [] *hps;
      *hps = NULL;
    }
  }
}

/* *************************************** */

HostPools::~HostPools() {
  if(num_active_hosts_inline)
    free(num_active_hosts_inline);
  if(num_active_hosts_offline)
    free(num_active_hosts_offline);
  if(num_active_l2_devices_inline)
    free(num_active_l2_devices_inline);
  if(num_active_l2_devices_offline)
    free(num_active_l2_devices_offline);

  if(tree_shadow)   delete tree_shadow;
  if(tree)          delete tree;

  dumpToRedis();
  if(stats)        deleteStats(&stats);
  if(stats_shadow) deleteStats(&stats_shadow);

#ifdef NTOPNG_PRO
  if(children_safe)     free(children_safe);
  if(forge_global_dns)  free(forge_global_dns);
  if(routing_policy_id) free(routing_policy_id);
  if(pool_shaper)
    free(pool_shaper);
  if(schedule_bitmap)
    free(schedule_bitmap);
  if(enforce_quotas_per_pool_member)
    free(enforce_quotas_per_pool_member);
  if(enforce_shapers_per_pool_member)
    free(enforce_shapers_per_pool_member);

#endif
}

/* *************************************** */

void HostPools::swap(VLANAddressTree *new_trees, HostPoolStats **new_stats) {
  /* Swap statistics */
  if(new_stats) {
    if(stats) {
      if(stats_shadow) deleteStats(&stats_shadow);
      stats_shadow = stats;
    }

    stats = new_stats;
  }

  /* Swap address trees */
  if(new_trees) {
    if(tree) {
      if(tree_shadow) delete tree_shadow;
      tree_shadow = tree;
    }

    tree = new_trees;
  }
}

/* *************************************** */

void HostPools::dumpToRedis() {
  char key[128];
  char buf[32];
  Redis *redis = ntop->getRedis();

  if((!redis) || (! stats) || (! iface)) return;

  snprintf(key, sizeof(key), HOST_POOL_SERIALIZED_KEY, iface->get_id());

  for(int i = 0; i<MAX_NUM_HOST_POOLS; i++) {
    if(stats[i] && !stats[i]->needsReset()) {
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
  char key[CONST_MAX_LEN_REDIS_KEY], buf[32], *value;
  json_object *obj;
  enum json_tokener_error jerr = json_tokener_success;
  Redis *redis = ntop->getRedis();

  snprintf(key, sizeof(key), HOST_POOL_SERIALIZED_KEY, iface->get_id());

  if((!redis) || (!stats) || (!iface)) return;

  if((value = (char *) malloc(POOL_MAX_SERIALIZED_LEN)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory to deserialize %s", key);
    return;
  }

  for(int i = 0; i<MAX_NUM_HOST_POOLS; i++) {
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

void HostPools::luaStats(lua_State *vm) {
  if(vm) {
    lua_newtable(vm);

    for(int i = 0; i < MAX_NUM_HOST_POOLS; i++)
      luaStats(vm, i);
  }
};

/* *************************************** */

void HostPools::luaStats(lua_State *vm, u_int16_t pool_id) {
  HostPoolStats *hps;

  if(vm) {
    if(stats && pool_id < MAX_NUM_HOST_POOLS) {
      if((hps = stats[pool_id])) {
	/* Must use the assigned hps as stats can be swapped
	   and accesses such as stats[pool_id] could yield a NULL value */
	hps->lua(vm, iface);
	lua_push_uint64_table_entry(vm, "num_hosts", getNumPoolHosts(pool_id));
	lua_rawseti(vm, -2, pool_id);
      }
    }
  }
};

/* *************************************** */

void HostPools::updateStats(const struct timeval *tv) {
  HostPoolStats *hps;

  if(stats && tv) {
    for(int i = 0; i < MAX_NUM_HOST_POOLS; i++)
      if((hps = stats[i]))
	hps->updateStats(tv); /* Use hps, stats[i] can become NULL after a swap */
  }
};

/* *************************************** */

void HostPools::incPoolStats(u_int32_t when, u_int16_t host_pool_id, u_int16_t ndpi_proto,
			     ndpi_protocol_category_t category_id, u_int64_t sent_packets, u_int64_t sent_bytes,
			     u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
  HostPoolStats *hps = getPoolStats(host_pool_id);

  if(!hps) return;

  /* Important to use the assigned hps as a swap can make stats[host_pool_id] NULL */
  hps->incStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
  hps->incCategoryStats(when, category_id, sent_bytes, rcvd_bytes);
};

/* *************************************** */

#ifdef NTOPNG_PRO

void HostPools::incPoolNumDroppedFlows(u_int16_t pool_id) {
  HostPoolStats *hps = getPoolStats(pool_id);

  if(!hps) return;

  hps->incNumDroppedFlows();
}

/* *************************************** */

void HostPools::resetPoolsStats(u_int16_t pool_filter) {
  HostPoolStats *hps;

  if(stats) {
    if(pool_filter != (u_int16_t)-1) {
      if((hps = getPoolStats(pool_filter)))
	hps->resetStats();
    } else {
      for(int i = 0; i < MAX_NUM_HOST_POOLS; i++) {
	if((hps = stats[i])) {
	  /* Must use the assigned hps as stats can be swapped
	     and accesses such as stats[i] could yield a NULL value */
	  hps->resetStats();
	}
      }
    }
  }
}

/* *************************************** */

void HostPools::checkPoolsStatsReset() {
  HostPoolStats *hps;

  if(stats) {
    for(int i = 0; i < MAX_NUM_HOST_POOLS; i++) {
      if((hps = stats[i])) {
	/* Must use the assigned hps as stats can be swapped
	   and accesses such as stats[i] could yield a NULL value */
	hps->checkStatsReset();
      }
    }
  }
}

#endif

/* *************************************** */

void HostPools::lua(lua_State *vm) {
  u_int32_t hosts = 0, l2_devices = 0;
  u_int32_t cur_hosts = 0, cur_l2 = 0;
  u_int32_t active_pools = 0;
  char buf[8];

  lua_newtable(vm);

  for(int i = 0; i < MAX_NUM_HOST_POOLS; i++) {
    if((cur_hosts = getNumPoolHosts(i)))  hosts += cur_hosts;
    if((cur_l2 = getNumPoolL2Devices(i))) l2_devices += cur_l2;

    if(cur_hosts || cur_l2) {
      lua_newtable(vm);
      lua_push_uint64_table_entry(vm, "num_hosts", cur_hosts);
      lua_push_uint64_table_entry(vm, "num_l2_devices", cur_l2);
      snprintf(buf, sizeof(buf), "%d", i);

      lua_pushstring(vm, buf);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      active_pools++;
    }
  }

  lua_pushstring(vm, "num_members_per_pool");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "num_hosts", hosts);
  lua_push_uint64_table_entry(vm, "num_l2_devices", l2_devices);
  lua_push_uint64_table_entry(vm, "num_active_pools", active_pools);

  lua_pushstring(vm, "num_members");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void HostPools::reloadPools() {
  char kname[CONST_MAX_LEN_REDIS_KEY];
  char **pools, **pool_members, *at, *member;
  int num_pools, num_members, actual_num_members;
  u_int16_t _pool_id;
  VLANid vlan_id;
  VLANAddressTree *new_tree;
  HostPoolStats **new_stats;
  Redis *redis = ntop->getRedis();

  if(!iface || (iface->get_id() == -1))
    return;

  new_tree = new (std::nothrow) VLANAddressTree;
  new_stats = new (std::nothrow) HostPoolStats*[MAX_NUM_HOST_POOLS];
  for(u_int32_t i = 0; i < MAX_NUM_HOST_POOLS; i++)
    new_stats[i] = NULL;

  snprintf(kname, sizeof(kname), HOST_POOL_IDS_KEY);

  /* Always allocate default pool stats */
  if(stats && stats[0]) /* Duplicate existing statistics */
    new_stats[0] = new (std::nothrow) HostPoolStats(*stats[0]);
  else /* Brand new statistics */
    new_stats[0] = new (std::nothrow) HostPoolStats(iface);

  /* Set the default pool name into the stats */
  if(new_stats[0]) new_stats[0]->updateName(DEFAULT_POOL_NAME);

  /* Keys are pool ids */
  if((num_pools = redis->smembers(kname, &pools)) == -1)
    return; /* Something went wrong with redis? */
  
  for(int i = 0; i < num_pools; i++) {
    if(!pools[i])
      continue;

    _pool_id = (u_int16_t)atoi(pools[i]);
    if(_pool_id >= MAX_NUM_HOST_POOLS) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Ignoring pool [pool id: %2d]. "
				   "Maximum number of host pools for this license is %u, inclusive of the Not Assigned pool.",
				   _pool_id, MAX_NUM_HOST_POOLS);

      free(pools[i]);
      continue;
    }

    snprintf(kname, sizeof(kname), HOST_POOL_DETAILS_KEY, _pool_id);

    if(_pool_id != 0) { /* Pool id 0 stats already updated */
      if(stats && stats[_pool_id]) /* Duplicate existing statistics */
	new_stats[_pool_id] = new (std::nothrow) HostPoolStats(*stats[_pool_id]);
      else /* Brand new statistics */
	new_stats[_pool_id] = new (std::nothrow) HostPoolStats(iface);
    }

    /* Initialize the name */
    if(new_stats[_pool_id]) {
      char name_rsp[POOL_MAX_NAME_LEN];
      redis->hashGet(kname, (char*)"name", name_rsp, sizeof(name_rsp));
      new_stats[_pool_id]->updateName(name_rsp);
    }

#ifdef NTOPNG_PRO
    char rsp[16] = { 0 };

    children_safe[_pool_id] = ((redis->hashGet(kname, (char*)CONST_CHILDREN_SAFE, rsp, sizeof(rsp)) != -1)
			&& (!strcmp(rsp, "true")));

    forge_global_dns[_pool_id] = ((redis->hashGet(kname, (char*)CONST_FORGE_GLOBAL_DNS, rsp, sizeof(rsp)) != -1)
    			&& (!strcmp(rsp, "true")));

    routing_policy_id[_pool_id] = (redis->hashGet(kname, (char*)CONST_ROUTING_POLICY_ID, rsp, sizeof(rsp)) != -1) ? atoi(rsp) : DEFAULT_ROUTING_TABLE_ID;
    pool_shaper[_pool_id] = (redis->hashGet(kname, (char*)CONST_POOL_SHAPER_ID, rsp, sizeof(rsp)) != -1) ? atoi(rsp) : DEFAULT_SHAPER_ID;
    schedule_bitmap[_pool_id] = (redis->hashGet(kname, (char*)CONST_SCHEDULE_BITMAP, rsp, sizeof(rsp)) != -1) ? strtol(rsp, NULL, 16) : DEFAULT_TIME_SCHEDULE;

    enforce_quotas_per_pool_member[_pool_id]   = ((redis->hashGet(kname, (char*)CONST_ENFORCE_QUOTAS_PER_POOL_MEMBER, rsp, sizeof(rsp)) != -1)
					 && (!strcmp(rsp, "true")));;
    enforce_shapers_per_pool_member[_pool_id]   = ((redis->hashGet(kname, (char*)CONST_ENFORCE_SHAPERS_PER_POOL_MEMBER, rsp, sizeof(rsp)) != -1)
					 && (!strcmp(rsp, "true")));;

#ifdef HOST_POOLS_DEBUG
    redis->hashGet(kname, (char*)"name", rsp, sizeof(rsp));
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loading pool [%s][iteration: %u][pool_id: %u][name: %s]"
				 "[children_safe: %i]"
				 "[forge_global_dns: %i]"
				 "[pool_shaper: %i]"
				 "[schedule_bitmap: %i]"
				 "[enforce_quotas_per_pool_member: %i]"
				 "[enforce_shapers_per_pool_member: %i]",
				 iface->get_name(),
				 i, _pool_id,
				 rsp, children_safe[_pool_id], forge_global_dns[_pool_id],
				 pool_shaper[_pool_id], schedule_bitmap[_pool_id],
				 enforce_quotas_per_pool_member[_pool_id],
				 enforce_shapers_per_pool_member[_pool_id]);
#endif

#endif /* NTOPNG_PRO */

    snprintf(kname, sizeof(kname), HOST_POOL_MEMBERS_KEY, pools[i]);

    /* Pool members are the elements of the list */
    if((num_members = redis->smembers(kname, &pool_members)) > 0) {
      // NOTE: the auto-assigned host_pool must not be limited as it receives devices assigments automatically
      actual_num_members = min_val((u_int32_t)num_members, ((_pool_id == ntop->getPrefs()->get_auto_assigned_pool_id()) ? MAX_NUM_INTERFACE_HOSTS : MAX_NUM_POOL_MEMBERS));

      if(actual_num_members < num_members) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many members [pool id: %2d][pool members: %d]. "
				     "Maximum number of pool members for this license is %u, so %u pool members will be ignored.",
				     _pool_id, num_members, actual_num_members, num_members - actual_num_members, actual_num_members);
      }

      for(int k = 0; k < actual_num_members; k++) {
	member = pool_members[k];

	if(!member) continue;

	if((at = strchr(member, '@'))) {
	  vlan_id = atoi(at + 1);
	  *at = '\0';
	} else
	  vlan_id = 0;

	bool rc;

	if(!(rc = new_tree->addAddress(vlan_id, member, _pool_id))
#ifdef HOST_POOLS_DEBUG
	    || true
#endif
	     )

	  ntop->getTrace()->traceEvent(TRACE_NORMAL,
				       "%s tree node for %s [vlan %i] [host pool: %s]",
				       rc ? "Successfully added" : "Unable to add",
				       member, vlan_id,
				       pools[i]);

	free(member);
      }

      free(pool_members);
    }

    free(pools[i]);
  }

  if(pools) free(pools);

  swap(new_tree, new_stats);

  iface->refreshHostPools();
}

/* *************************************** */

bool HostPools::findMacPool(const u_int8_t * const mac, u_int16_t *found_pool) {
  VLANAddressTree *cur_tree; /* must use this as tree can be swapped */
  int16_t ret;

  if(!tree || !(cur_tree = tree))
    return(false);

  ret = cur_tree->findMac(0, mac);

  if(ret != -1) {
    *found_pool = (u_int16_t)ret;
    return(true);
  }

  return(false);
}

/* *************************************** */

bool HostPools::findMacPool(Mac *mac, u_int16_t *found_pool) {
  if(mac->isSpecialMac())
    return(false);

  return findMacPool(mac->get_mac(), found_pool);
}

/* *************************************** */

bool HostPools::findIpPool(IpAddress *ip, VLANid vlan_id,
			   u_int16_t *found_pool, ndpi_patricia_node_t **found_node) {
  VLANAddressTree *cur_tree; /* must use this as tree can be swapped */
#ifdef HOST_POOLS_DEBUG
  char buf[128];
#endif

  if(!tree || !(cur_tree = tree))
    return(false);

  *found_node = (ndpi_patricia_node_t*)ip->findAddress(cur_tree->getAddressTree(vlan_id));

  if(*found_node) {
#ifdef HOST_POOLS_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Found pool for %s [pool id: %i]",
				   ip->print(buf, sizeof(buf)), ndpi_patricia_get_node_u64(*found_node));
#endif
      *found_pool = ndpi_patricia_get_node_u64(*found_node);
      return(true);
  }

  return(false);
}

/* *************************************** */

u_int16_t HostPools::getPool(Host *h) {
  u_int16_t pool_id;
  ndpi_patricia_node_t *node;
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

/* *************************************** */

 u_int16_t HostPools::getPool(Mac *m) {
  u_int16_t pool_id;
  bool found = false;

  if(m)
    found = findMacPool(m, &pool_id);

  if(!found)
    return NO_HOST_POOL_ID;

  return pool_id;
}

/* *************************************** */

/* Returns a pool id, given a pool name. When no pool id is found, the default pool id is returned */
u_int16_t HostPools::getPoolByName(const char * const pool_name) {
  HostPoolStats *hps;

  for(int i = 0; i < MAX_NUM_HOST_POOLS; i++) {
    if((hps = getPoolStats(i)) && hps->getName().compare(pool_name) == 0)
      return i;
  }

  return NO_HOST_POOL_ID;
}

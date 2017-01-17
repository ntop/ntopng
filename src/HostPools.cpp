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

/* *************************************** */

HostPools::HostPools(NetworkInterface *_iface) {
  ptree = ptree_shadow = NULL;
  if(_iface)
    iface = _iface;

  reloadPools(0);
}

void HostPools::reloadPools(u_int16_t pool_id) {
  char kname[CONST_MAX_LEN_REDIS_KEY];
  char **pools, **pool_members, *at, *member;
  int num_pools, num_members;
  u_int16_t _pool_id, vlan_id;
  AddressTree **new_ptree;
  patricia_node_t *node;
  Redis *redis = ntop->getRedis();

  if(!iface || iface->get_id() == -1)
    return;

  if((new_ptree = new AddressTree*[MAX_NUM_VLAN]) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Not enough memory");
    return;
  }
  for(u_int32_t i = 0; i < MAX_NUM_VLAN; i++)
    new_ptree[i] = NULL;

  snprintf(kname, sizeof(kname),
	   "ntopng.prefs.%u.host_pools.pool_ids", iface->get_id());

  /* Keys are pool ids */
  if((num_pools = redis->smembers(kname, &pools)) <= 0) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "No host pools for interface %s", iface->get_name());
    delete new_ptree; /* No need to invoke destructors here as elements are empty */
    return;
  }

  for(int i = 0; i < num_pools; i++) {
    if(!pools[i]) continue;

    snprintf(kname, sizeof(kname),
	     "ntopng.prefs.%u.host_pools.members.%s", iface->get_id(), pools[i]);

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

	if(new_ptree[vlan_id] || (new_ptree[vlan_id] = new AddressTree())) {
	  _pool_id = (u_int16_t)atoi(pools[i]);
	  node = new_ptree[vlan_id]->addAddress(member, &_pool_id);

#ifdef HOST_POOLS_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s ptree node for %s [vlan %i] [host pool: %s]",
				       node ? "Successfully added" : "Unable to add",
				       member, vlan_id,
				       pools[i]);
#endif
	}

	free(member);
      }

      free(pool_members);
    }

    free(pools[i]);
  }

  if(pools)
    free(pools);


  if(ptree) {
    if(ptree_shadow)
      delete []ptree_shadow; /* Invokes the destructor */
    ptree_shadow = ptree;
  }

  ptree = new_ptree;

  iface->refreshHostPools(&pool_id);
}

u_int16_t HostPools::getPool(Host *h) {
  Mac *mac;
  IpAddress *ip;
  patricia_node_t *node;
#ifdef HOST_POOLS_DEBUG
  char buf[128];
  char *k;
#endif

  if(!h || !ptree || !ptree[h->get_vlan_id()])
    return NO_HOST_POOL_ID;

  if((mac = h->getMac()) && !mac->isSpecialMac()) {
    node = (patricia_node_t*)mac->findAddress(ptree[h->get_vlan_id()]);
    if(node) {
#ifdef HOST_POOLS_DEBUG
      k = mac->get_string_key(buf, sizeof(buf));
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Found pool for %s [pool id: %i]",
				   k, node->user_data);
#endif
      return node->user_data;
    }
  }

  if((ip = h->get_ip())) {
    node = (patricia_node_t*)ip->findAddress(ptree[h->get_vlan_id()]);
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


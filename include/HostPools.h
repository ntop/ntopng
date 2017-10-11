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

#ifndef _HOST_POOLS_H_
#define _HOST_POOLS_H_

#include "ntop_includes.h"

class NetworkInterface;
class Host;
class Mac;

class HostPools {
 private:
  Mutex *swap_lock;
  volatile time_t latest_swap;
  AddressTree **tree, **tree_shadow;
  NetworkInterface *iface;
  u_int16_t max_num_pools;
  int32_t *num_active_pool_members_inline, *num_active_pool_members_offline;
#ifdef NTOPNG_PRO
  bool *children_safe;
  u_int8_t *routing_policy_id;
  bool *enforce_quotas_per_pool_member; /* quotas can be pool-wide or per pool member */
  HostPoolStats **stats, **stats_shadow;
  volatile_members_t **volatile_members;
  Mutex **volatile_members_lock;

  void reloadVolatileMembers(AddressTree **_trees);
  void addVolatileMember(char *host_or_mac, u_int16_t user_pool_id, time_t lifetime);
  void swap(AddressTree **new_trees, HostPoolStats **new_stats);

  inline HostPoolStats* getPoolStats(u_int16_t host_pool_id) {
    if((host_pool_id >= max_num_pools) || (!stats))
      return NULL;
    return stats[host_pool_id];
  }
  void reloadPoolStats();
  static void deleteStats(HostPoolStats ***hps);
#else
  void swap(AddressTree **new_trees);
#endif
  static void deleteTree(AddressTree ***at);

  void loadFromRedis();
  void dumpToRedis();

public:
  HostPools(NetworkInterface *_iface);
  virtual ~HostPools();

  void reloadPools();
  u_int16_t getPool(Host *h);

  bool findIpPool(IpAddress *ip, u_int16_t vlan_id, u_int16_t *found_pool, patricia_node_t **found_node);
  bool findMacPool(u_int8_t *mac, u_int16_t vlan_id, u_int16_t *found_pool);
  bool findMacPool(Mac *mac, u_int16_t *found_pool);
  void lua(lua_State *vm);
  
  inline int32_t numPoolMembers(u_int16_t pool_id) {
    return(num_active_pool_members_inline[pool_id] + num_active_pool_members_offline[pool_id]);
  }
  
  inline void incPoolNumMembers(u_int16_t pool_id, bool isInlineCall) {
    if((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) {
      if(isInlineCall)
	num_active_pool_members_inline[pool_id]++;
      else
	num_active_pool_members_offline[pool_id]++;
    }
  }

  inline void decPoolNumMembers(u_int16_t pool_id, bool isInlineCall) {
    if((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) {
      if(isInlineCall)
	num_active_pool_members_inline[pool_id]--;
      else
	num_active_pool_members_offline[pool_id]--;
    }
  }
 
#ifdef NTOPNG_PRO
  void incPoolNumDroppedFlows(u_int16_t pool_id);
  void incPoolStats(u_int32_t when, u_int16_t host_pool_id, u_int16_t ndpi_proto,
		    ndpi_protocol_category_t category_id, u_int64_t sent_packets, u_int64_t sent_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes);
  void updateStats(struct timeval *tv);
  void luaStats(lua_State *vm);

  inline bool getProtoStats(u_int16_t host_pool_id, u_int16_t ndpi_proto, u_int64_t *bytes, u_int32_t *duration) {
    HostPoolStats *hps;
    if (!(hps = getPoolStats(host_pool_id))) return false;

    hps->getProtoStats(ndpi_proto, bytes, duration);
    return true;
  }

  inline bool getCategoryStats(u_int16_t host_pool_id, ndpi_protocol_category_t category_id, u_int64_t *bytes, u_int32_t *duration) {
    HostPoolStats *hps;
    if (!(hps = getPoolStats(host_pool_id))) return false;

    hps->getCategoryStats(category_id, bytes, duration);
    return true;
  }

  void resetPoolsStats();

  inline bool enforceQuotasPerPoolMember(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? enforce_quotas_per_pool_member[pool_id] : false);
  }
  void luaVolatileMembers(lua_State *vm);
  void addToPool(char *host_or_mac, u_int16_t user_pool_id, int32_t lifetime_secs);
  void removeVolatileMemberFromPool(char *host_or_mac, u_int16_t user_pool_id);
  void purgeExpiredVolatileMembers();

  inline bool isChildrenSafePool(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? children_safe[pool_id] : false);
  }
  
  inline u_int8_t getRoutingPolicy(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? routing_policy_id[pool_id] : 0);
  }
#endif
};

#endif /* _HOST_POOLS_H_ */

/*
 *
 * (C) 2015-18 - ntop.org
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
  VlanAddressTree *tree, *tree_shadow;
  NetworkInterface *iface;
  u_int16_t max_num_pools;
  int32_t *num_active_hosts_inline, *num_active_hosts_offline;
  int32_t *num_active_l2_devices_inline, *num_active_l2_devices_offline;
#ifdef NTOPNG_PRO
  bool *children_safe;
  bool *forge_global_dns;
  u_int8_t *routing_policy_id;
  u_int16_t *pool_shaper;
  u_int32_t *schedule_bitmap;
  bool *enforce_quotas_per_pool_member;   /* quotas can be pool-wide or per pool member */
  bool *enforce_shapers_per_pool_member;
  HostPoolStats **stats, **stats_shadow;
  volatile_members_t **volatile_members;
  Mutex **volatile_members_lock;

  void reloadVolatileMembers(VlanAddressTree *_trees);
  void addVolatileMember(char *host_or_mac, u_int16_t user_pool_id, time_t lifetime);
  void swap(VlanAddressTree *new_trees, HostPoolStats **new_stats);

  inline HostPoolStats* getPoolStats(u_int16_t host_pool_id) {
    if((host_pool_id >= max_num_pools) || (!stats))
      return NULL;
    return stats[host_pool_id];
  }
  void reloadPoolStats();
  static void deleteStats(HostPoolStats ***hps);
#else
  void swap(VlanAddressTree *new_trees);
#endif

  void loadFromRedis();

  inline void incNumMembers(u_int16_t pool_id, int32_t *ctr) const {
    if(ctr && pool_id < max_num_pools)
      ctr[pool_id]++;
  };
  inline void decNumMembers(u_int16_t pool_id, int32_t *ctr) const {
    if(ctr && pool_id < max_num_pools)
      ctr[pool_id]--;
  };

 public:
  HostPools(NetworkInterface *_iface);
  virtual ~HostPools();

  void dumpToRedis();
  void reloadPools();
  u_int16_t getPool(Host *h);
  u_int16_t getPool(Mac *m);

  bool findIpPool(IpAddress *ip, u_int16_t vlan_id, u_int16_t *found_pool, patricia_node_t **found_node);
  bool findMacPool(u_int8_t *mac, u_int16_t *found_pool);
  bool findMacPool(Mac *mac, u_int16_t *found_pool);
  void lua(lua_State *vm);

  inline int32_t getNumPoolHosts(u_int16_t pool_id) {
    if(pool_id >= max_num_pools)
      return 0;
    return num_active_hosts_inline[pool_id] + num_active_hosts_offline[pool_id];
  }

  inline int32_t getNumPoolL2Devices(u_int16_t pool_id) {
    if(pool_id >= max_num_pools)
      return 0;

    return num_active_l2_devices_inline[pool_id] + num_active_l2_devices_offline[pool_id];
  }

  inline void incNumHosts(u_int16_t pool_id, bool isInlineCall) {
    incNumMembers(pool_id, isInlineCall ? num_active_hosts_inline : num_active_hosts_offline);
  };
  inline void decNumHosts(u_int16_t pool_id, bool isInlineCall) {
    decNumMembers(pool_id, isInlineCall ? num_active_hosts_inline : num_active_hosts_offline);
  };
  inline void incNumL2Devices(u_int16_t pool_id, bool isInlineCall) {
    incNumMembers(pool_id, isInlineCall ? num_active_l2_devices_inline : num_active_l2_devices_offline);
  };
  inline void decNumL2Devices(u_int16_t pool_id, bool isInlineCall) {
    decNumMembers(pool_id, isInlineCall ? num_active_l2_devices_inline : num_active_l2_devices_offline);
  };


#ifdef NTOPNG_PRO
  void incPoolNumDroppedFlows(u_int16_t pool_id);
  void incPoolStats(u_int32_t when, u_int16_t host_pool_id, u_int16_t ndpi_proto,
		    ndpi_protocol_category_t category_id, u_int64_t sent_packets, u_int64_t sent_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes);
  void updateStats(struct timeval *tv);
  void luaStats(lua_State *vm);

  /* To be called on the same thread as incPoolStats */
  void checkPoolsStatsReset();

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

  inline bool getStats(u_int16_t host_pool_id, u_int64_t *bytes, u_int32_t *duration) {
    HostPoolStats *hps;
    if (!(hps = getPoolStats(host_pool_id))) return false;

    hps->getStats(bytes, duration);
    return true;
  }

  void resetPoolsStats(u_int16_t pool_filter);

  inline bool enforceQuotasPerPoolMember(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? enforce_quotas_per_pool_member[pool_id] : false);
  }
  inline bool enforceShapersPerPoolMember(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? enforce_shapers_per_pool_member[pool_id] : false);
  }
  inline u_int16_t getPoolShaper(u_int16_t pool_id) {
    return((pool_id < max_num_pools) ? pool_shaper[pool_id] : DEFAULT_SHAPER_ID);
  }
  inline u_int32_t getPoolSchedule(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? schedule_bitmap[pool_id] : DEFAULT_TIME_SCHEDULE);
  }
  void luaVolatileMembers(lua_State *vm);
  void addToPool(char *host_or_mac, u_int16_t user_pool_id, int32_t lifetime_secs);
  void removeVolatileMemberFromPool(char *host_or_mac, u_int16_t user_pool_id);
  void purgeExpiredVolatileMembers();

  inline bool isChildrenSafePool(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? children_safe[pool_id] : false);
  }

  inline bool forgeGlobalDns(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? forge_global_dns[pool_id] : false);
  }

  inline u_int8_t getRoutingPolicy(u_int16_t pool_id) {
    return(((pool_id != NO_HOST_POOL_ID) && (pool_id < max_num_pools)) ? routing_policy_id[pool_id] : DEFAULT_ROUTING_TABLE_ID);
  }
#endif
};

#endif /* _HOST_POOLS_H_ */

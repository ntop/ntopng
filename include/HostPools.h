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
#ifdef NTOPNG_PRO
  HostPoolStats **stats, **stats_shadow;
  volatile_members_t **volatile_members;
  Mutex **volatile_members_lock;

  void reloadVolatileMembers(AddressTree **_trees);
  void addVolatileMember(char *host_or_mac, u_int16_t user_pool_id, time_t lifetime);
#endif

#ifdef NTOPNG_PRO
  void swap(AddressTree **new_trees, HostPoolStats **new_stats);

  inline HostPoolStats* getPoolStats(u_int16_t host_pool_id) {
    if((host_pool_id >= MAX_NUM_HOST_POOLS) || (!stats))
      return NULL;
    return stats[host_pool_id];
  }

  void reloadPoolStats();
#else
  void swap(AddressTree **new_trees);
#endif

  Mutex *swap_lock;
  volatile time_t latest_swap;
  AddressTree **tree, **tree_shadow;
  NetworkInterface *iface;
  bool children_safe[MAX_NUM_HOST_POOLS];

  void loadFromRedis();
  void dumpToRedis();

public:
  HostPools(NetworkInterface *_iface);
  virtual ~HostPools();
  void reloadPools();
  u_int16_t getPool(Host *h);

  bool findIpPool(IpAddress *ip, u_int16_t vlan_id, u_int16_t *found_pool, patricia_node_t **found_node);
  bool findMacPool(Mac *mac, u_int16_t *found_pool);

#ifdef NTOPNG_PRO
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

  void luaVolatileMembers(lua_State *vm);
  void addToPool(char *host_or_mac, u_int16_t user_pool_id, int32_t lifetime_secs);
  void removeVolatileMemberFromPool(char *host_or_mac, u_int16_t user_pool_id);
  void purgeExpiredVolatileMembers();
#endif
};

#endif /* _HOST_POOLS_H_ */

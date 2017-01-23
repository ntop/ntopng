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
#ifdef NTOPNG_PRO
class HostPoolStats;
#endif

#define NO_HOST_POOL_ID 0

class HostPools {
 private:
#ifdef NTOPNG_PRO
  HostPoolStats **stats, **stats_shadow;
#endif
  AddressTree **tree, **tree_shadow;
  NetworkInterface *iface;
  void reloadPoolStats();

public:
  HostPools(NetworkInterface *_iface);
  void reloadPools();
  u_int16_t getPool(Host *h);
#ifdef NTOPNG_PRO
  void incPoolStats(u_int16_t host_pool_id, u_int ndpi_proto,
		    u_int64_t sent_packets, u_int64_t sent_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes);
  void updateStats(struct timeval *tv);
  void lua(lua_State *vm);
#endif
  void addToPool(u_int32_t client_ipv4, u_int16_t user_pool_id, bool permanentAuthorization);
  void addToPool(char *host_or_mac, u_int16_t user_pool_id, bool permanentAuthorization);
  void purgeExpiredMembers();
};

#endif /* _HOST_POOLS_H_ */

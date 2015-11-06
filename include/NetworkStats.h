/*
 *
 * (C) 2015 - ntop.org
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

#ifndef _NETWORK_STATS_H_
#define _NETWORK_STATS_H_

#include "ntop_includes.h"

class NetworkStats {
 private:
  u_int64_t ingress; /* outside -> network */
  u_int64_t egress;  /* network -> outside */
  u_int64_t inner;   /* network -> network (local traffic) */

 public:
  NetworkStats();

  inline bool trafficSeen(){return ingress || egress || inner;};
  inline void incIngress(u_int64_t num_bytes) { ingress += num_bytes; };
  inline void incEgress(u_int64_t num_bytes)  { egress  += num_bytes; };
  inline void incInner(u_int64_t num_bytes)   { inner   += num_bytes; };

  void lua(lua_State* vm);
};

#endif /* _NETWORK_STATS_H_ */

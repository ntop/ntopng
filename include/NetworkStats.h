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

#ifndef _NETWORK_STATS_H_
#define _NETWORK_STATS_H_

#include "ntop_includes.h"

class NetworkStats: public Checkpointable {
 private:
  TrafficStats ingress, ingress_broadcast; /* outside -> network */
  TrafficStats egress, egress_broadcast;   /* network -> outside */
  TrafficStats inner, inner_broadcast;     /* network -> network (local traffic) */

 public:
  NetworkStats();

  inline bool trafficSeen(){
    return ingress.getNumPkts() || egress.getNumPkts() || inner.getNumPkts();
  };
  inline void incIngress(u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    ingress.incStats(num_pkts, num_bytes);
    if(broadcast) ingress_broadcast.incStats(num_pkts, num_bytes);
  };
  inline void incEgress(u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    egress.incStats(num_pkts, num_bytes);
    if(broadcast) egress_broadcast.incStats(num_pkts, num_bytes);
  };
  inline void incInner(u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    inner.incStats(num_pkts, num_bytes);
    if(broadcast) inner_broadcast.incStats(num_pkts, num_bytes);
  };

  void lua(lua_State* vm);
  bool serializeCheckpoint(json_object *my_object, DetailsLevel details_level);
};

#endif /* _NETWORK_STATS_H_ */

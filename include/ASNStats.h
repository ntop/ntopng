/*
 *
 * (C) 2019-26 - ntop.org
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

#ifndef _ASN_STATS_H_
#define _ASN_STATS_H_

#include "ntop_includes.h"

class Flow; /* Forward */

/* *************************************** */

/* This class is used to collect information from live flows and
 * store those info here, in order to do any kind of computation
 * with ASN and be more "free" to just get ASN stats instead of all
 * the stats if interested in the live info.
 * Also this class is used by FlowStats.cpp for the same reason (but that is
 * used to get all the info from the flows)
 */
typedef struct {
  u_int64_t bytes_sent, bytes_rcvd;  
  /* other_bytes = (bytes_sent+bytes_rcvd) - (transit_bytes+peering_bytes+ix_bytes) */
  u_int64_t transit_bytes, peering_bytes, ix_bytes;
} ASNTrafficStats;

class ASNStats {
 private:
  std::set<u_int32_t> transit_asn;
  std::map<u_int32_t, ASNTrafficStats> src_asn, dst_asn;

 public:
  ASNStats();
  ~ASNStats();

  void incStats(Flow* flow);

  void lua(lua_State* vm, bool show_all_stats = false);

  void resetStats();
};

#endif /* _ASN_STATS_H_ */

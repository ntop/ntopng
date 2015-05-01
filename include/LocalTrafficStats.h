/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _LOCAL_TRAFFIC_STATS_H_
#define _LOCAL_TRAFFIC_STATS_H_

#include "ntop_includes.h"

typedef struct localStats {
  u_int64_t local2remote, remote2local, local2local, remote2remote;
} LocalStats;

class LocalTrafficStats {
 private:
  LocalStats packets, bytes;

 public:
  LocalTrafficStats();
  
  void incStats(u_int num_pkts, u_int pkt_len, bool localsender, bool localreceiver);  
  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();
  void lua(lua_State* vm);
};

#endif /* _LOCAL_TRAFFIC_STATS_H_ */

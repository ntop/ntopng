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

#ifndef _GROUPER_H_
#define _GROUPER_H_

#include "ntop_includes.h"

class Host;

struct groupStats{
  u_int32_t num_hosts;
  u_int32_t num_flows, num_dropped_flows;
  u_int64_t bytes_sent;
  u_int64_t bytes_rcvd;
  time_t first_seen;
  time_t last_seen;
  u_int32_t num_alerts;
  float throughput_bps;
  float throughput_pps;
  float throughput_trend_bps_diff;
  char country[3];
};

class Grouper {
 private:
  sortField sorter;

  int table_index;
  int64_t group_id_i;
  bool group_id_set;
  char *group_id_s;
  char *group_label;
  groupStats stats;

 public:
  Grouper(sortField sf);
  ~Grouper();

  inline u_int32_t getNumEntries(){return stats.num_hosts;}

  bool inGroup(Host *h);
  int8_t incStats(Host *h);
  int8_t newGroup(Host *h);

  void lua(lua_State* vm);
};

#endif /* _GROUPER_H_ */

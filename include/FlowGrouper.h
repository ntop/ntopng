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

#ifndef _FLOW_GROUPER_H_
#define _FLOW_GROUPER_H_

#include "ntop_includes.h"

class Flow;

struct flowGroupStats {
  u_int64_t bytes;
  u_int32_t num_flows;
  u_int32_t num_blocked_flows;
  time_t first_seen;
  time_t last_seen;
  float bytes_thpt;
};

class FlowGrouper {
  private:
    sortField sorter;
    flowGroupStats stats;
    int table_index;

    /* group id */
    u_int16_t app_protocol;

  public:
    FlowGrouper(sortField sf);
    ~FlowGrouper();

  inline u_int32_t getNumEntries(){return stats.num_flows;}

  bool inGroup(Flow *flow);
  int incStats(Flow *flow);
  int newGroup(Flow *flow);

  void lua(lua_State* vm);
};

#endif /* _FLOW_GROUPER_H_ */

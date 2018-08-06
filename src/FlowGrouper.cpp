/*
 *
 * (C) 2017-18 - ntop.org
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

#include "ntop_includes.h"

/* *************************************** */

FlowGrouper::FlowGrouper(sortField sf){
  sorter = sf;
  app_protocol = 0;
  table_index = 1;

  memset(&stats, 0, sizeof(stats));
}

/* *************************************** */

FlowGrouper::~FlowGrouper() {}

/* *************************************** */

bool FlowGrouper::inGroup(Flow *flow) {
  switch(sorter) {
    case column_ndpi:
      return (flow->get_detected_protocol().app_protocol == app_protocol);
    default:
      return false;
  }
}

/* *************************************** */

int FlowGrouper::newGroup(Flow *flow) {
  if(flow == NULL)
    return -1;

  memset(&stats, 0, sizeof(stats));

  switch(sorter) {
    case column_ndpi:
      app_protocol = flow->get_detected_protocol().app_protocol;
      break;
    default:
      return -1;
  }

  return 0;
}

/* *************************************** */

int FlowGrouper::incStats(Flow *flow) {
  if(flow == NULL || !inGroup(flow))
    return -1;

  stats.bytes += flow->get_bytes();
  stats.bytes_thpt += flow->get_bytes_thpt();

  if(stats.first_seen == 0 || flow->get_first_seen() < stats.first_seen)
    stats.first_seen = flow->get_first_seen();
  if(flow->get_last_seen() > stats.last_seen)
    stats.last_seen = flow->get_last_seen();

#ifdef HAVE_NEDGE
  if(!flow->isPassVerdict())
#endif
    stats.num_blocked_flows++;

  stats.num_flows++;
  return 0;
}

/* *************************************** */

void FlowGrouper::lua(lua_State* vm) {
  lua_newtable(vm);

  lua_push_int_table_entry(vm, "proto", app_protocol);

  lua_push_int_table_entry(vm, "bytes", stats.bytes);
  lua_push_int_table_entry(vm, "seen.first", stats.first_seen);
  lua_push_int_table_entry(vm, "seen.last", stats.last_seen);
  lua_push_int_table_entry(vm, "num_flows", stats.num_flows);
  lua_push_int_table_entry(vm, "num_blocked_flows", stats.num_blocked_flows);
  lua_push_float_table_entry(vm, "throughput_bps", max_val(stats.bytes_thpt, 0));

  lua_rawseti(vm, -2, table_index++);
}

/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _OBSERVATION_POINT_ID_TRAFFI_CSTATS_H_
#define _OBSERVATION_POINT_ID_TRAFFI_CSTATS_H_

#include "ntop_includes.h"

class ObservationPointIdTrafficStats {
private:
  u_int32_t num_collected_flows;
  u_int64_t total_flow_bytes;

public:
  ObservationPointIdTrafficStats(u_int32_t num_flows = 0, u_int32_t num_bytes = 0) { num_collected_flows = num_flows, total_flow_bytes = num_bytes; }

  inline void inc(u_int32_t num_bytes) {
    num_collected_flows++, total_flow_bytes += num_bytes;
  }

  inline void set(u_int32_t num_flows, u_int32_t num_bytes) {
    num_collected_flows = num_flows, total_flow_bytes = num_bytes;
  }

  inline u_int32_t get_num_collected_flows() { return(num_collected_flows); }
  inline u_int64_t get_total_flow_bytes()    { return(total_flow_bytes);    }

  inline void lua(lua_State* vm) {
    lua_push_uint32_table_entry(vm, "num_collected_flows", num_collected_flows);
    lua_push_uint64_table_entry(vm, "total_flow_bytes",    total_flow_bytes);
  }
};

#endif /* _OBSERVATION_POINT_ID_TRAFFI_CSTATS_H_ */

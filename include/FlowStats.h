/*
 *
 * (C) 2019 - ntop.org
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

#ifndef _FLOW_STATUS_STATS_H_
#define _FLOW_STATUS_STATS_H_

#include "ntop_includes.h"

/* *************************************** */

class FlowStats {
 private:
  u_int32_t counters[BITMAP_NUM_BITS];
  u_int32_t protocols[0x100];
  u_int32_t alert_levels[ALERT_LEVEL_MAX_LEVEL];
  u_int32_t dscps[64]; // 64 values available for dscp

 public:
  FlowStats();
  ~FlowStats();

  void incStats(Bitmap alert_bitmap, u_int8_t l4_protocol, AlertLevel alert_level, 
                  u_int8_t dscp_cli2srv, u_int8_t dscp_srv2cli);

  void lua(lua_State* vm);

  void resetStats();
};

#endif /* _FLOW_STATUS_STATS_H_ */

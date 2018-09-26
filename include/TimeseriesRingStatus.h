/*
 *
 * (C) 2018 - ntop.org
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

#ifndef _TIMESERIES_RING_STATUS_H_
#define _TIMESERIES_RING_STATUS_H_

#include "ntop_includes.h"


class TimeseriesRingStatus {
 public:
  TimeseriesPoint **ts_points;
  u_int8_t max_points, available_points, point_idx;
  u_int8_t num_steps, cur_steps;

  TimeseriesRingStatus(u_int8_t, u_int8_t);
  ~TimeseriesRingStatus();

  void insert(TimeseriesPoint *pt, time_t when);
  void lua(lua_State* vm, NetworkInterface *iface);
  inline bool isTimeToInsert() { return(++cur_steps >= num_steps); }
};

#endif /* _TIMESERIES_RING_STATUS_H_ */

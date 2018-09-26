/*
 *
 * (C) 2013-18 - ntop.org
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

TimeseriesRingStatus::TimeseriesRingStatus(u_int8_t max_points, u_int8_t num_steps) {
  point_idx = available_points = 0;
  cur_steps = 0;

  this->max_points = max_points;
  this->ts_points = new TimeseriesPoint*[max_points]();
  this->num_steps = num_steps;
}

/* *************************************** */

TimeseriesRingStatus::~TimeseriesRingStatus() {
  for(int i=0; i<max_points; i++)
    if(ts_points[i])
      delete ts_points[i];
  
  delete[] ts_points;
}

/* *************************************** */

void TimeseriesRingStatus::insert(TimeseriesPoint *pt, time_t when) {
  if(ts_points[point_idx])
    delete ts_points[point_idx];

  pt->timestamp = when;
  ts_points[point_idx] = pt;

  point_idx = (point_idx + 1) % max_points;
  cur_steps = 0;

  /* -1 because 1 point is for buffering */
  available_points = min(available_points + 1, max_points - 1);
}

/* *************************************** */

void TimeseriesRingStatus::lua(lua_State* vm, NetworkInterface *iface) {
  int idx = point_idx - available_points;

  if(idx < 0)
    idx += max_points;

  lua_newtable(vm);

  for(int i=0; i < available_points; i++) {
    TimeseriesPoint *pt = ts_points[idx];

    if(pt) {
      lua_newtable(vm);

      /* Process Point */
      lua_push_int_table_entry(vm, "instant", pt->timestamp);
      pt->lua(vm, iface);

      lua_rawseti(vm, -2, i + 1);
    }

    idx = (idx + 1) % max_points;
  }
}

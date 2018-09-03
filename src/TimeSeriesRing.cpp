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

class TsRingStatus {
 public:
  TimeseriesPoint **ts_points;
  u_int8_t max_points, available_points, point_idx;
  u_int8_t num_steps, cur_steps;

  TsRingStatus(u_int8_t, u_int8_t);
  ~TsRingStatus();

  void insert(TimeseriesPoint *pt, time_t when);
  void lua(lua_State* vm, NetworkInterface *iface);
  inline bool isTimeToInsert() { return(++cur_steps >= num_steps); }
};

/* *************************************** */

TsRingStatus::TsRingStatus(u_int8_t max_points, u_int8_t num_steps) {
  point_idx = available_points = 0;
  cur_steps = 0;

  this->max_points = max_points;
  this->ts_points = new TimeseriesPoint*[max_points]();
  this->num_steps = num_steps;
}

/* *************************************** */

TsRingStatus::~TsRingStatus() {
  delete[] ts_points;
}

/* *************************************** */

void TsRingStatus::insert(TimeseriesPoint *pt, time_t when) {
  TimeseriesPoint *target = ts_points[point_idx];

  if(target) delete target;
  target = pt;
  target->timestamp = when;
  ts_points[point_idx] = target;

  point_idx = (point_idx + 1) % max_points;
  cur_steps = 0;

  /* -1 because 1 point is for buffering */
  available_points = min(available_points + 1, max_points - 1);
}

/* *************************************** */

void TsRingStatus::lua(lua_State* vm, NetworkInterface *iface) {
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

/* *************************************** */

TimeSeriesRing::TimeSeriesRing(NetworkInterface *iface) {
  this->iface = iface;
  status = status_shadow = NULL;

  u_int8_t num_slots = ntop->getPrefs()->getNumTsSlots();

  if(num_slots > 0)
    status = new TsRingStatus(num_slots, ntop->getPrefs()->getNumTsSteps());
}

/* *************************************** */

TimeSeriesRing::~TimeSeriesRing() {
  if(status) delete status;
  if(status_shadow) delete status_shadow;
}

/* *************************************** */

bool TimeSeriesRing::isTimeToInsert() {
  u_int8_t num_slots = ntop->getPrefs()->getNumTsSlots();

  if(status_shadow) {
    delete status_shadow;
    status_shadow = NULL;
  }

  /* Number of slots can change at runtime due via user gui */
  if((!status && (num_slots > 0)) || (status && (num_slots != status->max_points))) {
    TsRingStatus *new_status = NULL;

    if(num_slots > 0)
     new_status = new TsRingStatus(num_slots, ntop->getPrefs()->getNumTsSteps());

    status_shadow = status;
    status = new_status;
  }

  if(status)
    return status->isTimeToInsert();

  return false;
}

/* *************************************** */

void TimeSeriesRing::insert(TimeseriesPoint *pt, time_t when) {
  if(status)
    status->insert(pt, when);
}

/* *************************************** */

void TimeSeriesRing::lua(lua_State* vm) {
  if(!status)
    lua_pushnil(vm);
  else
    status->lua(vm, iface);
}

/* *************************************** */

/* NOTE: same format as TsRingStatus::lua */
void TimeSeriesRing::luaSinglePoint(lua_State* vm, NetworkInterface *iface, TimeseriesPoint *pt) {
  lua_newtable(vm);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "instant", time(0));
  pt->lua(vm, iface);
  lua_rawseti(vm, -2, 1);
}

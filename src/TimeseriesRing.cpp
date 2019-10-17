/*
 *
 * (C) 2013-19 - ntop.org
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

TimeseriesRing::TimeseriesRing(NetworkInterface *iface) {
  this->iface = iface;
  status = status_shadow = NULL;

  u_int8_t num_slots = ntop->getPrefs()->getNumTsSlots();

  if(num_slots > 0)
    status = new TimeseriesRingStatus(num_slots, ntop->getPrefs()->getNumTsSteps());
}

/* *************************************** */

TimeseriesRing::~TimeseriesRing() {
  if(status) delete status;
  if(status_shadow) delete status_shadow;
}

/* *************************************** */

bool TimeseriesRing::isTimeToInsert() {
  u_int8_t num_slots = ntop->getPrefs()->getNumTsSlots();

  if(status_shadow) {
    delete status_shadow;
    status_shadow = NULL;
  }

  /* Number of slots can change at runtime due via user gui */
  if((!status && (num_slots > 0)) || (status && (num_slots != status->max_points))) {
    TimeseriesRingStatus *new_status = NULL;

    if(num_slots > 0)
     new_status = new TimeseriesRingStatus(num_slots, ntop->getPrefs()->getNumTsSteps());

    status_shadow = status;
    status = new_status;
  }

  if(status)
    return status->isTimeToInsert();

  return false;
}

/* *************************************** */

void TimeseriesRing::insert(TimeseriesPoint *pt, time_t when) {
  if(status)
    status->insert(pt, when);
  else
    delete pt;
}

/* *************************************** */

void TimeseriesRing::lua(lua_State* vm) {
  if(!status)
    lua_pushnil(vm);
  else
    status->lua(vm, iface);
}

/* *************************************** */

bool TimeseriesRing::isRingEnabled(const NetworkInterface *_iface) {
  if(!_iface || !_iface->isPacketInterface())
    return false; /* Only for packet interfaces */

  if(!ntop->getPrefs())
    return false; /* Preferences not instantiated (-h?) */

  return ntop->getPrefs()->getNumTsSlots() > 0;
}

/* *************************************** */

/* NOTE: same format as TimeseriesRingStatus::lua */
void TimeseriesRing::luaSinglePoint(lua_State* vm, NetworkInterface *iface,
				    TimeseriesPoint *pt) {
  lua_newtable(vm);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "instant", time(0));
  pt->lua(vm, iface);
  lua_rawseti(vm, -2, 1);
}

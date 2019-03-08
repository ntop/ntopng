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

HostTimeseriesPoint::HostTimeseriesPoint(const TimeseriesStats * const hs) : TimeseriesPoint() {
  host_stats = hs ? new (std::nothrow) TimeseriesStats(*hs) : NULL;
}

HostTimeseriesPoint::~HostTimeseriesPoint() {
  if(host_stats) delete host_stats;
}

/* *************************************** */

void HostTimeseriesPoint::lua(lua_State* vm, NetworkInterface *iface) {
  if(host_stats)
    host_stats->lua(vm, iface, true /* host details */, true /* verbose */, true /* tsLua */);
}

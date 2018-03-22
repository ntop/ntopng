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

#ifndef _INTERFACE_STATS_HASH_H_
#define _INTERFACE_STATS_HASH_H_

#include "ntop_includes.h"
 
class InterfaceStatsHash {
 private:
  Mutex m;
  u_int max_hash_size;
  sFlowInterfaceStats **buckets;

 public:
  InterfaceStatsHash(u_int _max_hash_size);
  ~InterfaceStatsHash();

  bool set(u_int32_t deviceIP, u_int32_t ifIndex, sFlowInterfaceStats *stats);
  bool get(u_int32_t deviceIP, u_int32_t ifIndex, sFlowInterfaceStats *stats);

  void luaDeviceList(lua_State *vm);
  void luaDeviceInfo(lua_State *vm, u_int32_t deviceIP);
};

#endif /* _INTERFACE_STATS_HASH_H_ */

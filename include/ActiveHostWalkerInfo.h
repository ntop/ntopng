/*
 *
 * (C) 2013-22 - ntop.org
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

#ifndef __ACTIVE_HOST_WALKER_INFO__
#define __ACTIVE_HOST_WALKER_INFO__

#include "ntop_includes.h"

class ActiveHostWalkerInfo {
private:
  std::string name, label;
  int64_t x, y;
  
  u_int64_t z;

public:
  ActiveHostWalkerInfo(char* _name, char* _label,
		       int64_t _x, int64_t _y,
		       u_int64_t _z) {
    name.assign(_name), label.assign(_label), x = _x, y = _y, z = _z;    
  }

  inline u_int64_t getZ() const { return(z); }
  
  void lua(lua_State* vm, bool treeMapMode);
};
  
#endif /* __ACTIVE_HOST_WALKER_INFO__ */

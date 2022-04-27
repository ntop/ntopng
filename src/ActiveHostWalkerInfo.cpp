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

#include "ntop_includes.h"
  
void ActiveHostWalkerInfo::lua(lua_State* vm) {
  char buf[64];
    
  lua_newtable(vm);

  /* meta */
  lua_newtable(vm);
  lua_push_str_table_entry(vm, "label", label.c_str());
  snprintf(buf, sizeof(buf), "host=%s", name.c_str());
  lua_push_str_table_entry(vm, "url_query", buf);
    
  lua_pushstring(vm, "meta");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* ********** */
  
  lua_push_uint32_table_entry(vm, "x", x);
  lua_push_uint32_table_entry(vm, "y", y);
  lua_push_uint64_table_entry(vm, "z", z);
}  

/*
 *
 * (C) 2019-22 - ntop.org
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

/* *************************************************** */

void BlacklistStats::incHits(std::string name) {
  std::unordered_map<std::string, BlacklistUsageStats>::iterator it = stats.find(name);

  if(it == stats.end()) {
    BlacklistUsageStats l;

    stats[name] = l;
  } else
    it->second.incHits();
}

/* *************************************************** */

u_int32_t BlacklistStats::getNumHits(std::string name) {
  std::unordered_map<std::string, BlacklistUsageStats>::iterator it = stats.find(name);

  if(it == stats.end())
    return(0);
  else
    return(it->second.getNumHits());
}

/* *************************************************** */

void BlacklistStats::lua(lua_State* vm) {
  lua_newtable(vm);

  for(std::unordered_map<std::string, BlacklistUsageStats>::iterator it = stats.begin(); it != stats.end(); ++it)
    lua_push_int32_table_entry(vm, it->first.c_str(), it->second.getNumHits());
}

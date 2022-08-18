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

#ifndef _DOHDOT_STATS_H
#define _DOHDOT_STATS_H

#include "ntop_includes.h"

class DoHDoTStats {
private:
  IpAddress ip;
  VLANid vlan_id;
  u_int32_t num_uses;
  
public:
  DoHDoTStats(IpAddress i, VLANid id) { ip = i, vlan_id = id, num_uses = 0; }

  inline void incUses() { num_uses++; }

  void lua(lua_State *vm) {
    char buf[64];
    
    lua_push_str_table_entry(vm, "ip", ip.print(buf, sizeof(buf)));
    lua_push_uint32_table_entry(vm, "vlan_id", vlan_id);
    lua_push_uint32_table_entry(vm, "num_uses", num_uses);
  }
};

#endif /* _DOHDOT_STATS_H */

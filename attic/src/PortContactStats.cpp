/*
 *
 * (C) 2013-20 - ntop.org
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

/* ************************************************************** */

PortContactStats::PortContactStats(u_int16_t _l7_proto, Host *peer,
				   const char *_info, time_t when) {
  l7_proto = _l7_proto;
  update(peer, _info, when);
}

/* ************************************************************** */

void PortContactStats::update(Host *peer, const char *_info, time_t when) {
  char buf[64] = { '\0' };
  
  last_seen = when;
  last_peer = std::string(peer->get_ip()->print(buf, sizeof(buf)));

  if(_info || info.empty())
    info = std::string(_info ? _info : "");
}

/* ************************************************************** */

void PortContactStats::lua(lua_State* vm, NetworkInterface *iface) {
  lua_push_str_table_entry(vm, "proto", iface->get_ndpi_proto_name(l7_proto));
  lua_push_str_table_entry(vm, "peer", last_peer.c_str());
  lua_push_str_table_entry(vm, "info", info.c_str());
  lua_push_int32_table_entry(vm, "last_seen", (u_int32_t)last_seen);
};


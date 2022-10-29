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

/* *************************************** */

HostPorts::HostPorts() {
  ;
}

/* *************************************** */

HostPorts::~HostPorts() {
  ;
}

/* *************************************** */

void HostPorts::reset() {
  udp_host_server_ports.clear(), tcp_host_server_ports.clear();
  udp_client_contacted_ports.clear(), tcp_client_contacted_ports.clear();
}

/* *************************************** */

void HostPorts::setLuaArray(lua_State *vm, NetworkInterface *iface,
			    bool isTCP, std::unordered_map<u_int16_t, ndpi_protocol> *ports) {
  if(ports) {
    std::unordered_map<u_int16_t, ndpi_protocol>::iterator it;
    
    for(it = ports->begin(); it != ports->end(); ++it) {
      char str[32], buf[64];
      
      snprintf(str, sizeof(str), "%s:%u", isTCP ? "tcp" : "udp", it->first);
      lua_push_str_table_entry(vm, str, ndpi_protocol2name(iface->get_ndpi_struct(), it->second, buf, sizeof(buf)));
    }
  }
}

/* *************************************** */

void HostPorts::lua(lua_State *vm, NetworkInterface *iface) {
  lua_newtable(vm);

  lua_newtable(vm);

  /* ***************************** */

  setLuaArray(vm, iface, true,  &tcp_host_server_ports);
  setLuaArray(vm, iface, false, &udp_host_server_ports);

  lua_pushstring(vm, "local_server_ports");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* ***************************** */

  lua_newtable(vm);

  setLuaArray(vm, iface, true,  &tcp_client_contacted_ports);
  setLuaArray(vm, iface, false, &udp_client_contacted_ports);

  lua_pushstring(vm, "remote_contacted_ports");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* ***************************** */

  lua_pushstring(vm, "used_ports");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void HostPorts::setServerPort(bool isTCP, u_int16_t port, ndpi_protocol *proto) {
  if(isTCP)
    tcp_host_server_ports[port] = *proto;
  else
    udp_host_server_ports[port] = *proto;
}

/* *************************************** */

void HostPorts::setContactedPort(bool isTCP, u_int16_t port, ndpi_protocol *proto) {
  if(isTCP)
    tcp_client_contacted_ports[port] = *proto;
  else
    udp_client_contacted_ports[port] = *proto;
}

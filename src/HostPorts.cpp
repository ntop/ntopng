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
  host_server_ports = ndpi_bitmap_alloc(), contacted_ports = ndpi_bitmap_alloc();
}

/* *************************************** */

HostPorts::~HostPorts() {
  if(host_server_ports) ndpi_bitmap_free(host_server_ports);
  if(contacted_ports)   ndpi_bitmap_free(contacted_ports);
}

/* *************************************** */

void HostPorts::reset() {
  if(host_server_ports) ndpi_bitmap_clear(host_server_ports);
  if(contacted_ports)   ndpi_bitmap_clear(contacted_ports);
}

/* *************************************** */

void HostPorts::setLuaArray(lua_State *vm, ndpi_bitmap *ports, const char *label) {
  if(ports) {
    ndpi_bitmap_iterator *i = ndpi_bitmap_iterator_alloc(ports);

    if(i) {
      u_int32_t port, index = 1;
      
      lua_createtable(vm, ndpi_bitmap_cardinality(ports), 0);

      while(ndpi_bitmap_iterator_next(i, &port)) {
	lua_pushinteger(vm, port);
	lua_rawseti(vm, -2, index++);
      }
      
      ndpi_bitmap_iterator_free(i);
				
      lua_pushstring(vm, label);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }
}

/* *************************************** */

void HostPorts::lua(lua_State *vm) {
  lua_newtable(vm);

  setLuaArray(vm, host_server_ports, "local_server_ports");
  setLuaArray(vm, contacted_ports, "remote_contacted_ports");
  
  lua_pushstring(vm, "used_ports");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void HostPorts::setServerPort(bool isTCP /* ignored */, u_int16_t port) {
  if(host_server_ports) ndpi_bitmap_set(host_server_ports, port);
}

/* *************************************** */

void HostPorts::setContactedPort(bool isTCP /* ignored */, u_int16_t port) {
  if(contacted_ports) ndpi_bitmap_set(contacted_ports, port);
}

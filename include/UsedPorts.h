/*
 *
 * (C) 2013-24 - ntop.org
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

#ifndef _USED_PORTS_H_
#define _USED_PORTS_H_

#include "ntop_includes.h"

class UsedPorts {
 private:
  Host* h;
  /* Used for both TCP and UDP */
  std::unordered_map<u_int16_t, ndpi_protocol> udp_server_ports, tcp_server_ports;
  std::unordered_map<u_int16_t, ndpi_protocol> udp_client_contacted_ports, tcp_client_contacted_ports;

  ServerPortsBitmap *bitmap_server_ports;
  
  void setLuaArray(lua_State *vm, NetworkInterface *iface, bool isTCP,
                   std::unordered_map<u_int16_t, ndpi_protocol> *ports);
  char* getRedisKey(char *redis_key, size_t key_len);
  void restore();
  
 public:
  UsedPorts(Host* h);
  UsedPorts();
  ~UsedPorts();

  void reset();

  void lua(lua_State *vm, NetworkInterface *iface);

  inline std::unordered_map<u_int16_t, ndpi_protocol> getUDPServerPorts() { return(udp_server_ports); };
  inline std::unordered_map<u_int16_t, ndpi_protocol> getTCPServerPorts() { return(tcp_server_ports); };


  bool setServerPort(bool isTCP, u_int16_t port, ndpi_protocol *proto);
  void setContactedPort(bool isTCP, u_int16_t port, ndpi_protocol *proto);
  void setLuaArrayUDPServerPorts(lua_State *vm, NetworkInterface *iface) {setLuaArray(vm, iface, false, &udp_server_ports);};
  void setLuaArrayTCPServerPorts(lua_State *vm, NetworkInterface *iface) {setLuaArray(vm, iface, true, &tcp_server_ports);};

  std::unordered_map<u_int16_t, ndpi_protocol> *getServerPorts(bool isTCP) {
    return (isTCP ? &tcp_server_ports : &udp_server_ports);
  }
};

#endif /* _USED_PORTS_H_ */

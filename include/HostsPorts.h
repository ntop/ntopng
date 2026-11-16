/*
 *
 * (C) 2019-26 - ntop.org
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

#ifndef _HOSTS_PORTS_H_
#define _HOSTS_PORTS_H_

#include "ntop_includes.h"

class HostsPorts {
 private:
  /* <srv_port, app_proto, master_proto> -> (<srv_host, vlan_id> -> 1)*/
  std::unordered_map<u_int64_t, PortDetails*> srv_ports;
  u_int8_t protocol = 0;
  u_int16_t vlan_id = (u_int16_t)-1;
  /* Restrictions of the requesting user (NULL = unrestricted) */
  AddressTree* allowed_nets = NULL;
  Bitmap4096* allowed_pools = NULL;

 public:
  HostsPorts() {};
  ~HostsPorts() {};

  /* Getters */
  inline std::unordered_map<u_int64_t, PortDetails*> get_srv_ports() {
    return (srv_ports);
  };
  inline u_int8_t get_protocol() { return (protocol); };
  inline u_int16_t get_vlan_id() { return (vlan_id); };
  inline AddressTree* get_allowed_nets() { return (allowed_nets); };
  inline Bitmap4096* get_allowed_pools() { return (allowed_pools); };

  /* Setters */
  void set_protocol(u_int8_t _protocol) { protocol = _protocol; };
  void set_vlan_id(u_int16_t _vlan_id) { vlan_id = _vlan_id; };
  void set_user_restrictions(AddressTree* _allowed_nets, Bitmap4096* _allowed_pools) {
    allowed_nets = _allowed_nets, allowed_pools = _allowed_pools;
  };
  void add_srv_port(u_int64_t key, u_int64_t host_key);
};

#endif /* _HOSTS_PORTS_H_ */

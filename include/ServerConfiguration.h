/*
 *
 * (C) 2013-26 - ntop.org
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

#ifndef _SERVER_CONFIGURATION_H
#define _SERVER_CONFIGURATION_H

#include "ntop_includes.h"

class ServerConfiguration {
 private:
  class ServersTree {
   public:
   /* All services are stored in a single VLANAddressTree, each node has a bitmap of server types (HostService).
    * Note: servers are configured by (exact) IP addresses (and VLAN). */
    VLANAddressTree tree;
    u_int32_t num_servers[HOST_SERVICE_MAX];

    ServersTree() { memset(num_servers, 0, sizeof(num_servers)); }
  };

  ServersTree *servers, *servers_shadow;

  void loadConfiguration(ServersTree* st, HostService type);
  void addServer(ServersTree* st, HostService type, u_int16_t vlan_id,
                 const char* net);

 public:
  ServerConfiguration();
  ~ServerConfiguration();

  void reloadServersConfiguration();

  inline bool isEmptyConfiguration(HostService type) {
    ServersTree* cur = servers;
    return ((cur == NULL) || (cur->num_servers[type] == 0));
  }

  u_int32_t getServerTypes(IpAddress* ip, u_int16_t vlan_id);

  inline bool isServer(HostService type, IpAddress* ip, u_int16_t vlan_id) {
    return ((getServerTypes(ip, vlan_id) & (1 << type)) != 0);
  }
};

#endif /* _SERVER_CONFIGURATION_H */

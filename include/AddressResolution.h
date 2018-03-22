/*
 *
 * (C) 2013-18 - ntop.org
 *
 *
 * This program is free software; you can addresstribute it and/or modify
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

#ifndef _ADDRESS_RESOLUTION_H_
#define _ADDRESS_RESOLUTION_H_

#include "ntop_includes.h"

class AddressResolution {
  AddressList localNetworks;
  int num_resolvers;
  u_int32_t num_resolved_addresses, num_resolved_fails;
  pthread_t *resolveThreadLoop;
  Mutex m;

 public:
  AddressResolution();
  ~AddressResolution();

  void startResolveAddressLoop();
  void resolveHostName(char *numeric_ip, char *rsp = NULL, u_int rsp_len = 0);

  inline u_int8_t getNumLocalNetworks()       { return localNetworks.getNumAddresses();    };
  inline char *get_local_network(u_int8_t id) { return localNetworks.getAddressString(id); };
  bool setLocalNetworks(char *rule);
  int16_t findAddress(int family, void *addr, u_int8_t *network_mask_bits = NULL);
  void setLocalNetwork(char *net)             { localNetworks.addAddresses(net);           };
  void getLocalNetworks(lua_State* vm);
  inline void dump()                          { localNetworks.dump(); }
};

#endif /* _ADDRESS_RESOLUTION_H_ */

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

#ifndef _ADDRESS_LIST_H_
#define _ADDRESS_LIST_H_

#include "ntop_includes.h"

class AddressList {
  char *addressString[CONST_MAX_NUM_NETWORKS];
  AddressTree tree;

  bool addAddress(char *_net);
  
 public:
  AddressList();
  ~AddressList();

  inline u_int8_t getNumAddresses() { return(tree.getNumAddresses()); }
  bool addAddresses(char *net);
  
  int16_t findAddress(int family, void *addr, u_int8_t *network_mask_bits = NULL) {
    return(tree.findAddress(family, addr, network_mask_bits));
  };
  void getAddresses(lua_State* vm)            { return(tree.getAddresses(vm));                               };
  inline char *getAddressString(u_int8_t id)  { return((id < getNumAddresses()) ? addressString[id] : NULL); };
  inline void dump()                          { tree.dump(); }
};

#endif /* _ADDRESS_LIST_H_ */

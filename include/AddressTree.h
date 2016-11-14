/*
 *
 * (C) 2013-16 - ntop.org
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

#ifndef _ADDRESS_TREE_H_
#define _ADDRESS_TREE_H_

#include "ntop_includes.h"

class AddressTree {
  u_int8_t numAddresses;
  char *addressString[CONST_MAX_NUM_NETWORKS];
  patricia_tree_t *ptree;
  
 public:
  AddressTree();
  ~AddressTree();

  u_int8_t getNumAddresses();
  /*
   Returns the id of the network added. A negative number is returned on error.
   */
  int16_t addAddress(char *_net);
  bool addAddresses(char *net);
  bool removeAddress(char *net);
  int16_t findAddress(int family, void *addr); /* if(rc > 0) networdId else notfound */
  void getAddresses(lua_State* vm);
  inline char *getAddressString(u_int8_t id) { return((id < numAddresses) ? addressString[id] : NULL); };
};

#endif /* _ADDRESS_TREE_H_ */

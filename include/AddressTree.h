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
  u_int16_t numAddresses;
  patricia_tree_t *ptree_v4, *ptree_v6;
   
 public:
  AddressTree();
  ~AddressTree();

  inline u_int16_t getNumAddresses() { return(numAddresses); }
  bool removeAddress(char *net);
  inline patricia_tree_t* getTree(bool isV4) { return(isV4 ? ptree_v4 : ptree_v6); }
  patricia_node_t* addAddress(char *_net);
  bool addAddresses(char *net);
  void getAddresses(lua_State* vm);
  int16_t findAddress(int family, void *addr);
  void dump();
};

#endif /* _ADDRESS_TREE_H_ */

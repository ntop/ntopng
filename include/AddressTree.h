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

#ifndef _ADDRESS_TREE_H_
#define _ADDRESS_TREE_H_

#include "ntop_includes.h"

typedef struct {
  u_int8_t mac[6];
  int16_t value;
  UT_hash_handle hh; /* makes this structure hashable */
} MacKey_t;

class AddressTree {
 private:
  u_int16_t numAddresses;
  patricia_tree_t *ptree_v4, *ptree_v6;
  MacKey_t *macs;
  
  patricia_tree_t* getPatricia(char* what);
  
 public:
  AddressTree();
  AddressTree(const AddressTree &at);
  ~AddressTree();

  void init();
  void cleanup();

  inline u_int16_t getNumAddresses() { return(numAddresses); }

  inline patricia_tree_t* getTree(bool isV4) { return(isV4 ? ptree_v4 : ptree_v6); }
  bool addAddress(char *_net, const int16_t user_data = -1);
  bool addAddresses(char *net, const int16_t user_data = -1);
  void getAddresses(lua_State* vm);
  int16_t findAddress(int family, void *addr, u_int8_t *network_mask_bits = NULL);
  int16_t findMac(u_int8_t addr[]);
  void dump();
};

#endif /* _ADDRESS_TREE_H_ */

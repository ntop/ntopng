/*
 *
 * (C) 2013-19 - ntop.org
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

class IpAddress;

class AddressTree {
 private:
  u_int16_t numAddresses;
  patricia_tree_t *ptree_v4, *ptree_v6;
  std::map<u_int64_t, int16_t> macs;
  
  patricia_tree_t* getPatricia(char* what);
  
 public:
  AddressTree(bool handleIPv6 = true);
  AddressTree(const AddressTree &at);
  ~AddressTree();

  void init(bool handleIPv6);
  void cleanup();

  inline u_int16_t getNumAddresses() { return(numAddresses); }

  inline const patricia_tree_t * getTree(bool isV4) const { return(isV4 ? ptree_v4 : ptree_v6); }
  bool addAddress(const char * const _net, const int16_t user_data = -1);
  patricia_node_t* addAddress(const IpAddress * const ipa);
  patricia_node_t* addAddress(const IpAddress * const ipa, int network_bits, bool compact_after_add);
  bool addAddresses(char *net, const int16_t user_data = -1);
  void getAddresses(lua_State* vm) const;
  int16_t findAddress(int family, void *addr, u_int8_t *network_mask_bits = NULL);
  int16_t findMac(const u_int8_t addr[]);
  bool match(char *addr);
  bool match(const IpAddress * const ipa, int network_bits) const;
  void dump();
  void walk(void_fn3_t func, void * const user_data) const;
};

#endif /* _ADDRESS_TREE_H_ */

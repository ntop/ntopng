/*
 *
 * (C) 2013-20 - ntop.org
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
 protected:
  u_int16_t numAddresses, numAddressesIPv4, numAddressesIPv6;
  patricia_tree_t* getPatricia(char* what);
  patricia_tree_t *ptree_v4, *ptree_v6;
  std::map<u_int64_t, int16_t> macs;
  void removePrefix(bool isV4, prefix_t* prefix);
  static void walk(const patricia_tree_t *ptree, void_fn3_t func, void * const user_data);
  static bool removePrefix(patricia_tree_t *ptree, prefix_t* prefix);

 public:
  AddressTree(bool handleIPv6 = true);
  AddressTree(const AddressTree &at);
  virtual ~AddressTree();

  void init(bool handleIPv6);
  void cleanup();

  inline u_int16_t getNumAddresses()     const { return(numAddresses);     }
  inline u_int16_t getNumAddressesIPv4() const { return(numAddressesIPv4); }
  inline u_int16_t getNumAddressesIPv6() const { return(numAddressesIPv6); }

  inline patricia_tree_t * getTree(bool isV4) const { return(isV4 ? ptree_v4 : ptree_v6); }
  bool addAddress(const char * const _net, const int16_t user_data = -1);
  bool addAddressAndData(const char * const _what, void *user_data);
  patricia_node_t* addAddress(const IpAddress * const ipa);
  patricia_node_t* addAddress(const IpAddress * const ipa, int network_bits, bool compact_after_add);
  bool addAddresses(const char *net, const int16_t user_data = -1);
  void getAddresses(lua_State* vm) const;
  int16_t findAddress(int family, void *addr, u_int8_t *network_mask_bits = NULL);
  int16_t findMac(const u_int8_t addr[]);
  int16_t find(const char *addr, u_int8_t *network_mask_bits = NULL);
  bool match(char *addr);
  patricia_node_t* match(const IpAddress * const ipa, int network_bits) const;
  void dump();
  void walk(void_fn3_t func, void * const user_data) const;
};

#endif /* _ADDRESS_TREE_H_ */

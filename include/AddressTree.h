/*
 *
 * (C) 2013-23 - ntop.org
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
  u_int32_t numAddresses, numAddressesIPv4, numAddressesIPv6;
  ndpi_patricia_tree_t *getPatricia(char *what);
  ndpi_patricia_tree_t *ptree_v4, *ptree_v6;
  std::map<u_int64_t, int16_t> macs;
  ndpi_void_fn_t free_func;

  void removePrefix(bool isV4, ndpi_prefix_t *prefix);
  static void walk(ndpi_patricia_tree_t *ptree, ndpi_void_fn3_t func,
                   void *const user_data);
  static bool removePrefix(ndpi_patricia_tree_t *ptree, ndpi_prefix_t *prefix);
  void cleanup(ndpi_void_fn_t free_func);

 public:
  AddressTree(bool handleIPv6 = true, ndpi_void_fn_t data_free_func = NULL);
  AddressTree(const AddressTree &at, ndpi_void_fn_t data_free_func = NULL);
  virtual ~AddressTree();

  void init(bool handleIPv6);
  void cleanup();

  inline u_int32_t getNumAddresses() const { return (numAddresses); }
  inline u_int32_t getNumAddressesIPv4() const { return (numAddressesIPv4); }
  inline u_int32_t getNumAddressesIPv6() const { return (numAddressesIPv6); }

  inline ndpi_patricia_tree_t *getTree(bool isV4) const {
    return (isV4 ? ptree_v4 : ptree_v6);
  }

  bool addAddress(const char *_net, const int16_t user_data = -1);
  bool addAddressAndData(const char *_what, void *user_data);
  ndpi_patricia_node_t *addAddress(const IpAddress *const ipa);
  ndpi_patricia_node_t *addAddress(const IpAddress *const ipa, int network_bits,
                                   bool compact_after_add);
  bool addAddresses(const char *net, const int16_t user_data = -1);

  void getAddresses(lua_State *vm) const;

  int16_t findAddress(int family, void *addr,
                      u_int8_t *network_mask_bits = NULL);
  int16_t findMac(const u_int8_t addr[]);
  int16_t find(const char *addr, u_int8_t *network_mask_bits = NULL);

  /* Return true on match, false otherwise */
  bool match(char *addr);
  /* Return user data on success, NULL otherwise */
  void *matchAndGetData(const char *addr);
  /* Return node on success, NULL otherwise */
  ndpi_patricia_node_t *matchAndGetNode(const char *addr);

  ndpi_patricia_node_t *match(const IpAddress *const ipa,
                              int network_bits) const;
  void *matchAndGetData(const IpAddress *const ipa) const;

  void dump();
  void walk(ndpi_void_fn3_t func, void *const user_data) const;
};

#endif /* _ADDRESS_TREE_H_ */

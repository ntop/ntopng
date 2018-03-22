/*
 *
 * (C) 2017-18 - ntop.org
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

#ifndef _VLAN_ADDRESS_TREE_H_
#define _VLAN_ADDRESS_TREE_H_

class AddressTree;

class VlanAddressTree {
 protected:
  AddressTree **tree;

 public:
  VlanAddressTree();
  ~VlanAddressTree();

  bool addAddress(u_int16_t vlan_id, char *_net, const int16_t user_data = -1);
  bool addAddresses(u_int16_t vlan_id, char *net, const int16_t user_data = -1);

  int16_t findAddress(u_int16_t vlan_id, int family, void *addr, u_int8_t *network_mask_bits = NULL);
  int16_t findMac(u_int16_t vlan_id, u_int8_t addr[]);

  inline AddressTree *getAddressTree(u_int16_t vlan_id) { return tree[vlan_id]; };
};

#endif

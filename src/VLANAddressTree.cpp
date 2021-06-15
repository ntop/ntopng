/*
 *
 * (C) 2017-21 - ntop.org
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

#include "ntop_includes.h"

/* **************************************** */

VLANAddressTree::VLANAddressTree() {
  tree = new (std::nothrow) AddressTree*[MAX_NUM_VLAN];
  memset(tree, 0, sizeof(AddressTree*) * MAX_NUM_VLAN);
}

/* **************************************** */

VLANAddressTree::~VLANAddressTree() {
  for(int i = 0; i < MAX_NUM_VLAN; i++)
    if(tree[i])
      delete tree[i];

  delete [] tree;
}

/* **************************************** */

bool VLANAddressTree::addAddress(VLANid vlan_id, char *_net, const int16_t user_data) {
  if(tree[vlan_id] || (tree[vlan_id] = new (std::nothrow) AddressTree()))
    return tree[vlan_id]->addAddress(_net, user_data);

  return false;
}

/* **************************************** */

bool VLANAddressTree::addAddresses(VLANid vlan_id, char *net, const int16_t user_data) {
  if(tree[vlan_id] || (tree[vlan_id] = new (std::nothrow) AddressTree()))
    return tree[vlan_id]->addAddresses(net, user_data);

  return false;
}

/* **************************************** */

int16_t VLANAddressTree::findAddress(VLANid vlan_id, int family, void *addr, u_int8_t *network_mask_bits) {
  if(! tree[vlan_id]) return -1;
  return tree[vlan_id]->findAddress(family, addr, network_mask_bits);
}

/* **************************************** */

int16_t VLANAddressTree::findMac(VLANid vlan_id, const u_int8_t addr[]) {
  if(! tree[vlan_id]) return -1;
  return tree[vlan_id]->findMac(addr);
}

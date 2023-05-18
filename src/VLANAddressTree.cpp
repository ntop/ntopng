/*
 *
 * (C) 2017-23 - ntop.org
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

VLANAddressTree::VLANAddressTree(ndpi_void_fn_t data_free_func) {
  free_func = data_free_func;
  tree = new (std::nothrow) AddressTree *[MAX_NUM_VLAN];
  memset(tree, 0, sizeof(AddressTree *) * MAX_NUM_VLAN);
}

/* **************************************** */

VLANAddressTree::~VLANAddressTree() {
  for (int i = 0; i < MAX_NUM_VLAN; i++)
    if (tree[i]) delete tree[i];

  delete[] tree;
}

/* **************************************** */

bool VLANAddressTree::addAddress(u_int16_t vlan_id, char *_net,
                                 const int16_t user_data) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (tree[vlan_id] ||
      (tree[vlan_id] = new (std::nothrow) AddressTree(true, free_func)))
    return tree[vlan_id]->addAddress(_net, user_data);

  return false;
}

/* **************************************** */

bool VLANAddressTree::addVLANAddressAndData(u_int16_t vlan_id,
                                            const char *_what,
                                            void *user_data) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (tree[vlan_id] ||
      (tree[vlan_id] = new (std::nothrow) AddressTree(true, free_func)))
    return tree[vlan_id]->addAddressAndData(_what, user_data);

  return false;
}

/* **************************************** */

bool VLANAddressTree::addAddresses(u_int16_t vlan_id, char *net,
                                   const int16_t user_data) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (tree[vlan_id] ||
      (tree[vlan_id] = new (std::nothrow) AddressTree(true, free_func)))
    return tree[vlan_id]->addAddresses(net, user_data);

  return false;
}

/* **************************************** */

int16_t VLANAddressTree::findAddress(u_int16_t vlan_id, int family, void *addr,
                                     u_int8_t *network_mask_bits) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (!tree[vlan_id]) return -1;
  return tree[vlan_id]->findAddress(family, addr, network_mask_bits);
}

/* **************************************** */

int16_t VLANAddressTree::findMac(u_int16_t vlan_id, const u_int8_t addr[]) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (!tree[vlan_id]) return -1;
  return tree[vlan_id]->findMac(addr);
}

/* **************************************** */

void *VLANAddressTree::findAndGetData(u_int16_t vlan_id,
                                      const IpAddress *const ipa) const {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (!tree[vlan_id]) return NULL;
  return tree[vlan_id]->matchAndGetData(ipa);
}

/* **************************************** */

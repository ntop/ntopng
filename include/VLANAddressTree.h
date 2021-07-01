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

#ifndef _VLAN_ADDRESS_TREE_H_
#define _VLAN_ADDRESS_TREE_H_

class AddressTree;

/*
typedef struct {
  // u_int32_t vlan_id:16, observation_point_id:16;
} VLANid; 
*/

/*
  VLANId is 12 bits but in order to avoid breaking bytes
  boundaries we assign 16 bits each
*/
typedef u_int16_t VLANid;

/* Make sure we won't exceed 12 bites for vlanId */
inline u_int16_t filterVLANid(VLANid id)             { return((u_int16_t)(id & 0xFFF)); }

class VLANAddressTree {
 protected:
  AddressTree **tree;

 public:
  VLANAddressTree();
  ~VLANAddressTree();

  bool addAddress(VLANid vlan_id, char *_net, const int16_t user_data = -1);
  bool addAddresses(VLANid vlan_id, char *net, const int16_t user_data = -1);

  int16_t findAddress(VLANid vlan_id, int family, void *addr, u_int8_t *network_mask_bits = NULL);
  int16_t findMac(VLANid vlan_id, const u_int8_t addr[]);

  inline AddressTree *getAddressTree(VLANid vlan_id) { return tree[vlan_id]; };
};

#endif

/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _FLOW_HASH_H_
#define _FLOW_HASH_H_

#include "ntop_includes.h"
 
class FlowHash : public GenericHash {
 public:
  FlowHash(NetworkInterface *iface, u_int _num_hashes, u_int _max_hash_size);

  Flow* find(IpAddress *src_ip, IpAddress *dst_ip,
	     u_int16_t src_port, u_int16_t dst_port,
	     VLANid vlanId, u_int16_t observation_domain_id,
	     u_int8_t protocol,
	     const ICMPinfo * const icmp_info,
	     bool *src2dst_direction,
	     bool is_inline_call);
  /**
   * @brief Find an entry by key value and hash entry id.
   *
   * @param key Key value of the flow
   * @param hash_id The unique identifier of the flow in the hash table
   * @return Pointer of entry that matches with the key parameter, NULL if there isn't entry with the key parameter or if the hash is empty.
   */
  Flow* findByKeyAndHashId(u_int32_t key, u_int hash_id);
};

#endif /* _FLOW_HASH_H_ */

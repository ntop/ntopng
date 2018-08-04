/*
 *
 * (C) 2013-18 - ntop.org
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

/* ************************************ */

FlowHash::FlowHash(NetworkInterface *_iface, u_int _num_hashes, u_int _max_hash_size) 
  : GenericHash(_iface, _num_hashes, _max_hash_size, "FlowHash") {
  ;
};

/* ************************************ */

static u_int16_t max_num_loops = 0;

Flow* FlowHash::find(IpAddress *src_ip, IpAddress *dst_ip,
		     u_int16_t src_port, u_int16_t dst_port, 
		     u_int16_t vlanId, u_int8_t protocol,
		     bool *src2dst_direction) {

  u_int32_t hash = ((src_ip->key()+dst_ip->key()+src_port+dst_port+vlanId+protocol) % num_hashes);
  Flow *head = (Flow*)table[hash];
  u_int16_t num_loops = 0;
  
  while(head) {
    if((!head->idle() && !head->is_ready_to_be_purged())
       && head->equal(src_ip, dst_ip, src_port, dst_port, vlanId, protocol, src2dst_direction)) {
      if(num_loops > max_num_loops) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "DEBUG: [Num loops: %u][hashId: %u]", num_loops, hash);
	max_num_loops = num_loops;
      }
      return(head);
    } else
      head = (Flow*)head->next(), num_loops++;
  }

  if(num_loops > max_num_loops) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "DEBUG: [Num loops: %u][hashId: %u]", num_loops, hash);
    max_num_loops = num_loops;
  }

  return(NULL);
}

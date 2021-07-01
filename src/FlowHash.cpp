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
		     VLANid vlanId, u_int16_t observation_point_id,
		     u_int8_t protocol,
		     const ICMPinfo * const icmp_info,
		     bool *src2dst_direction,
		     bool is_inline_call) {
  u_int32_t hash = ((src_ip->key() + dst_ip->key()
		     + (icmp_info ? icmp_info->key() : 0)
		     + src_port + dst_port + vlanId + protocol) % num_hashes);
  Flow *head = (Flow*)table[hash];
  u_int16_t num_loops = 0;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u:%u / %u:%u [icmp: %u][key: %u][icmp info key: %u][head: 0x%x]", src_ip->key(), src_port, dst_ip->key(), dst_port, icmp_info ? 1 : 0, hash, icmp_info ? icmp_info->key() : 0, head);

  if(!head)
    return(NULL);

  if(!is_inline_call)
    locks[hash]->rdlock(__FILE__, __LINE__);

  while(head) {
    if(!head->idle()
       && !head->is_swap_done() /* Do NOT return flows for which swap has been done. Leave them so they will be marked as idle and disappear */
       && head->equal(src_ip, dst_ip, src_port, dst_port, vlanId, observation_point_id,
		      protocol, icmp_info, src2dst_direction)) {
      if(num_loops > max_num_loops) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "DEBUG: [Num loops: %u][hashId: %u]", num_loops, hash);
	max_num_loops = num_loops;
      }

      break;
    } else
      head = (Flow*)head->next(), num_loops++;
  }

  if(num_loops > max_num_loops) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "DEBUG: [Num loops: %u][hashId: %u]", num_loops, hash);
    max_num_loops = num_loops;
  }

  if(!is_inline_call)
    locks[hash]->unlock(__FILE__, __LINE__);

  return(head);
}

/* ************************************ */

Flow* FlowHash::findByKeyAndHashId(u_int32_t key, u_int hash_id) {
  u_int32_t hash = key % num_hashes;
  Flow *head = (Flow*)table[hash];

  if(head == NULL) return(NULL);

  locks[hash]->rdlock(__FILE__, __LINE__);

  while(head) {
    if(!head->idle() && head->get_hash_entry_id() == hash_id)
      break;
    else
      head = (Flow*)head->next();
  }

  locks[hash]->unlock(__FILE__, __LINE__);

  return((Flow*)head);
}


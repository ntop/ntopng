/*
 *
 * (C) 2013-26 - ntop.org
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

FlowHash::FlowHash(NetworkInterface* _iface, u_int _num_hashes,
                   u_int _max_hash_size)
    : GenericHash(_iface, _num_hashes, _max_hash_size, "FlowHash") {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
};

/* ************************************ */

static u_int16_t max_num_loops = 0;

/* NOTE: when is_inline_call is false, the flow returned has its reference
   counter increased: the caller must call decUses() when done with it */
Flow* FlowHash::find(Mac* src_mac, Mac* dst_mac, IpAddress* src_ip,
                     IpAddress* dst_ip, u_int16_t src_port, u_int16_t dst_port,
                     u_int16_t vlanId, u_int16_t observation_point_id,
                     u_int32_t private_flow_id, u_int8_t protocol,
                     const ICMPinfo* const icmp_info, bool* src2dst_direction,
                     bool is_inline_call, Flow** unswapped_flow) {
  u_int32_t hash;
  Flow* head;
  u_int16_t num_loops = 0;

  hash = src_ip->key() + dst_ip->key() + (icmp_info ? icmp_info->key() : 0) +
         private_flow_id + src_port + dst_port + vlanId + protocol;

#ifdef USE_MAC_IN_KEY_WITH_DHCP
  if ((src_ip->key() == 0) && (dst_ip->key() == 0xFFFFFFFF)) {
    /* Add the MAC address of the source host (dst_mac is not necessary as it's
     * FF:FF:FF:FF:FF:FF) */
    if (src_mac != NULL) hash += src_mac->key();
  }
#endif

  hash %= num_hashes;

  head = (Flow*)table[hash];

  *unswapped_flow = NULL;

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] %u:%u / %u:%u [icmp key: %u]"
			       "[priv flow id: %u][vlan: %u][protocol: %u]"
			       "[hash: %u][head: 0x%x]",
			       iface->get_name(),
			       src_ip->key(), ntohs(src_port), dst_ip->key(), ntohs(dst_port),
			       icmp_info ? icmp_info->key() : 0,
			       private_flow_id, vlanId, protocol, hash, head);
#endif

  if (!head) return (NULL);

  if (!is_inline_call) {
    locks[hash]->rdlock(__FILE__, __LINE__);
    head = (Flow*)table[hash]; /* Read it again now that the lock is held */
  }

  while (head) {
    if (!head->idle() &&
        head->equal(src_mac, dst_mac, src_ip, dst_ip, src_port, dst_port,
                    vlanId, observation_point_id, private_flow_id, protocol,
                    icmp_info, src2dst_direction)) {
      if (num_loops > max_num_loops) {
        ntop->getTrace()->traceEvent(
            TRACE_DEBUG, "DEBUG: [Num loops: %u][hashId: %u]", num_loops, hash);
        max_num_loops = num_loops;
      }

#ifdef HAVE_NEDGE
      if (head->is_swap_requested()) {
        /*
          This is a good flow but in the wrong direction
          hence we remember the flow unswapped but merge
          data with the flow with the correct direction
          (the flows are swapped at once on the other builds, see
          Flow::swapNow())
         */
        *unswapped_flow = head;
        head = NULL;
      }
#endif

      break;
    } else
      head = (Flow*)head->next(), num_loops++;
  }

  if (num_loops > max_num_loops) {
    ntop->getTrace()->traceEvent(
        TRACE_DEBUG, "DEBUG: [Num loops: %u][hashId: %u]", num_loops, hash);
    max_num_loops = num_loops;
  }

  if (!is_inline_call) {
    /*
      The caller is not the thread that purges the hash: take a reference
      before releasing the lock, or the flow can be freed while in use
      (see GenericHash::purgeQueuedIdleEntries)
    */
    if (head) head->incUses();
    locks[hash]->unlock(__FILE__, __LINE__);
  }

  return (head);
}

/* ************************************ */

/* NOTE: the flow returned has its reference counter increased: the caller
   must call decUses() when done with it */
Flow* FlowHash::findByKeyAndHashId(u_int32_t key, u_int32_t hash_id) {
  u_int32_t hash = key % num_hashes;
  Flow* head;

  if (table[hash] == NULL) return (NULL);

  locks[hash]->rdlock(__FILE__, __LINE__);
  head = (Flow*)table[hash];

  while (head) {
    if ((!head->idle()) && (head->get_hash_entry_id() == hash_id))
      break;
    else
      head = (Flow*)head->next();
  }

  /*
    Take a reference before releasing the lock, or the flow can be freed
    while in use (see GenericHash::purgeQueuedIdleEntries)
  */
  if (head) head->incUses();

  locks[hash]->unlock(__FILE__, __LINE__);

  return ((Flow*)head);
}

/* **************************************************** */

#ifdef HAVE_NEDGE

u_int32_t FlowHash::dropHostTraffic(IpAddress* host_ip,
                                    AddressTree* allowed_nets) {
  u_int32_t num_matched_flows = 0;

  for (u_int32_t i = 0; i < num_hashes; i++) {
    u_int32_t hash = i % num_hashes;
    Flow* head = (Flow*)table[hash];

    if (head != NULL) {
      locks[hash]->rdlock(__FILE__, __LINE__);

      while (head) {
        if (!head->idle()) {
          if ((head->get_cli_ip_addr()->equal(host_ip)) ||
              (head->get_srv_ip_addr()->equal(host_ip))) {
            if (head->match(allowed_nets)) {
              head->setDropVerdict(DROP_REASON_USER_ACTION);
              num_matched_flows++;
            }
          }
        }

        head = (Flow*)head->next();
      } /* while */

      locks[hash]->unlock(__FILE__, __LINE__);
    } /* if */
  } /* while */

  return (num_matched_flows);
}

#endif

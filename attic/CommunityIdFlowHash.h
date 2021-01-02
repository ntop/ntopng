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

#ifndef _COMMUNITY_ID_FLOW_HASH_H_
#define _COMMUNITY_ID_FLOW_HASH_H_

#include "ntop_includes.h"

// #define TEST_COMMUNITY_ID_FLOW_HASH 1

/* ******************************* */

class CommunityIdFlowHash {
 private:
  static u_int8_t icmp_type_to_code_v4(u_int8_t icmp_type, u_int8_t icmp_code, bool * const is_one_way);
  static u_int8_t icmp_type_to_code_v6(u_int8_t icmp_type, u_int8_t icmp_code, bool * const is_one_way);
  static ssize_t buf_copy(u_int8_t * const dst, const void * const src, ssize_t len);
  static bool is_less_than(const IpAddress * const ip1, const IpAddress * const ip2, u_int16_t p1 = 0, u_int16_t p2 = 0);
  static void check_peers(IpAddress ** const ip1, IpAddress ** const ip2, u_int16_t * const p1, u_int16_t * const p2, bool is_icmp_one_way);

 public:
  static char * get_community_id_flow_hash(Flow * const f);
};

#endif /* _COMMUNITY_ID_FLOW_HASH_H_ */

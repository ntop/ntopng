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


#ifndef _ARP_STATS_MATRIX_ELEMENT_H_
#define _ARP_STATS_MATRIX_ELEMENT_H_

#include "ntop_includes.h"

class ArpStatsMatrixElement : public GenericHashEntry {
 private:
  struct {
    struct {
      u_int32_t requests, replies;
    } src2dst, dst2src;
  } stats;

  u_int8_t src_mac[6], dst_mac[6];
  u_int32_t src_ip, dst_ip;

 public:
  ArpStatsMatrixElement(NetworkInterface *_iface,
			const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6], 
			const u_int32_t _src_ip, const u_int32_t _dst_ip);
  ~ArpStatsMatrixElement();

  inline void incArpReplies(bool src2dst) {
    src2dst ? stats.src2dst.replies++ : stats.dst2src.replies++;
    updateSeen();
  }

  inline void incArpRequests(bool src2dst) {
    src2dst ? stats.src2dst.requests++ : stats.dst2src.requests++;
    updateSeen();
  }

  bool equal(const u_int8_t _src_mac[6],
	    const u_int32_t _src_ip, const u_int32_t _dst_ip,
      bool * const src2dst);
  u_int32_t key();
  void lua(lua_State* vm);
  void print(char *msg) const;
};

#endif /* _ARP_STATS_MATRIX_ELEMENT_H_ */


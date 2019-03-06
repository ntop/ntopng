/*
 *
 * (C) 2013-19 - ntop.org
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
    } sent, rcvd;
  } stats;

  u_int8_t src_mac[6];
  u_int8_t dst_mac[6];

 public:
  ArpStatsMatrixElement(NetworkInterface *_iface, const u_int8_t _src_mac[6],
			const u_int8_t _dst_mac[6] );
  ~ArpStatsMatrixElement();

  void setStats(u_int32_t sent_req, u_int32_t sent_res, u_int32_t rcv_req, u_int32_t rcv_res){
    stats.sent.replies = sent_res;
    stats.sent.requests = sent_req;
    stats.rcvd.replies = rcv_res;
    stats.rcvd.requests = rcv_req;
  }

  inline u_int32_t incSentArpReplies()        { return ++stats.sent.replies;  }
  inline u_int32_t incSentArpRequests()       { return ++stats.sent.requests; }

  bool equal(const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6]) const;
  bool idle();
  u_int32_t key();
  void lua(lua_State* vm);
};

#endif /* _ARP_STATS_MATRIX_ELEMENT_H_ */


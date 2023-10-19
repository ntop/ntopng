/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _TCP_PACKET_STATS_H_
#define _TCP_PACKET_STATS_H_

#include "ntop_includes.h"

class TcpPacketStats {
 private:
  u_int64_t pktRetr, pktOOO, pktLost, pktKeepAlive;

 public:
  TcpPacketStats();

  /* TCP Retransmissions */
  inline void incRetr(u_int32_t num) { pktRetr += num; }

  /* Out-of-Order */
  inline void incOOO(u_int32_t num) { pktOOO += num; }

  /* TCP Segments Lost */
  inline void incLost(u_int32_t num) { pktLost += num; }

  /* TCP Keep-Alive */
  inline void incKeepAlive(u_int32_t num) { pktKeepAlive += num; }

  json_object* getJSONObject();
  inline bool seqIssues() const {
    return (pktRetr || pktOOO || pktLost || pktKeepAlive);
  }
  void lua(lua_State* vm, const char* label);

  char* serialize();
  inline void sum(TcpPacketStats* s) const {
    s->pktRetr += pktRetr, s->pktOOO += pktOOO, s->pktLost += pktLost,
        s->pktKeepAlive += pktKeepAlive;
  }

  inline u_int64_t get_retr() const { return pktRetr; };
};

#endif /* _TCP_PACKET_STATS_H_ */

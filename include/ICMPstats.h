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

#ifndef _ICMP_STATS_H_
#define _ICMP_STATS_H_

#include "ntop_includes.h"


typedef struct {
  int type_code; /* too big but that's all UThash offers */
  u_int16_t pkt_sent, pkt_rcvd;
  char *last_host_sent_peer, *last_host_rcvd_peer;
  UT_hash_handle hh; /* makes this structure hashable */  
} ICMPstats_t;
  
class ICMPstats {
 private:
  ICMPstats_t *stats;
  Mutex m;

  void addToTable(const char *label, lua_State *vm, ICMPstats_t *curr);
  inline int  get_typecode(u_int8_t icmp_type, u_int8_t icmp_code) { return((icmp_type << 8) + icmp_code); }
  inline void to_typecode(int type_code, u_int8_t *icmp_type, u_int8_t *icmp_code) { *icmp_type = (type_code >> 8) & 0xFF, *icmp_code = type_code & 0xFF; }
  
 public:
  ICMPstats();
  ~ICMPstats();

  void incStats(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer);
  void lua(bool isV4, lua_State *vm);  
  void sum(ICMPstats *e);
};

#endif /* _ICMP_STATS_H_ */

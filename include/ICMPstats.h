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

#ifndef _ICMP_STATS_H_
#define _ICMP_STATS_H_

#include "ntop_includes.h"


typedef struct {
  u_int16_t pkt_sent, pkt_rcvd;
  char *last_host_sent_peer, *last_host_rcvd_peer;
} ICMPstats_t;
  
class ICMPstats {
 private:
  std::map<u_int16_t, ICMPstats_t> stats;
  Mutex m;
  MonitoredCounter<u_int32_t> num_destination_unreachable;

  void addToTable(const char *label, lua_State *vm, const ICMPstats_t *curr, bool verbose);
  inline u_int16_t get_typecode(u_int8_t icmp_type, u_int8_t icmp_code) { return((icmp_type << 8) + icmp_code); }
  inline void to_typecode(int type_code, u_int8_t *icmp_type, u_int8_t *icmp_code) { *icmp_type = (type_code >> 8) & 0xFF, *icmp_code = type_code & 0xFF; }
  
 public:
  ICMPstats();
  ~ICMPstats();

  void incStats(u_int32_t num_pkts, u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer);
  void updateStats(const struct timeval *tv);
  void lua(bool isV4, lua_State *vm, bool verbose = true);
  bool hasAnomalies(time_t when);
  void luaAnomalies(lua_State* vm, time_t when);
  void sum(ICMPstats *e);
  void getTsStats(ts_icmp_stats *s);
};

#endif /* _ICMP_STATS_H_ */

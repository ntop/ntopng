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

#ifndef _DNS_STATS_H_
#define _DNS_STATS_H_

#include "ntop_includes.h"

struct queries_breakdown {
  u_int32_t num_a, num_ns, num_cname, num_soa,
    num_ptr, num_mx, num_txt, num_aaaa,
    num_any, num_other;
};

struct dns_stats {
  u_int32_t num_queries, num_replies_ok, num_replies_error;
  struct queries_breakdown breakdown;
};

class DnsStats {
 private:
  struct dns_stats sent, rcvd;

  void incQueryBreakdown(struct queries_breakdown *bd, u_int16_t query_type);
  void deserializeStats(json_object *o, struct dns_stats *stats);
  json_object* getStatsJSONObject(struct dns_stats *stats);
  void luaStats(lua_State *vm, struct dns_stats *stats, const char *label);
  void incNumDNSQueries(u_int16_t query_type, struct dns_stats *s);

 public:
  DnsStats();

  inline void incNumDNSQueriesSent(u_int16_t query_type) { incNumDNSQueries(query_type, &sent); };
  inline void incNumDNSQueriesRcvd(u_int16_t query_type) { incNumDNSQueries(query_type, &rcvd); };
  inline void incNumDNSResponsesSent(u_int8_t ret_code)  { if(ret_code == 0) sent.num_replies_ok++; else sent.num_replies_error++; };
  inline void incNumDNSResponsesRcvd(u_int8_t ret_code)  { if(ret_code == 0) rcvd.num_replies_ok++; else rcvd.num_replies_error++; };

  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();
  void lua(lua_State *vm);
};

#endif /* _STATS_H_ */

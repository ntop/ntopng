/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _EPP_STATS_H_
#define _EPP_STATS_H_

#include "ntop_includes.h"

class EppStats {
 private:
  struct epp_stats sent, rcvd;

  void deserializeStats(json_object *o, struct epp_stats *stats);
  json_object* getStatsJSONObject(struct epp_stats *stats);
  void luaStats(lua_State *vm, struct epp_stats *stats, const char *label);
  void incNumEPPQueries(u_int16_t query_type, struct epp_stats *what);

 public:
  EppStats();

  void incNumEPPQueriesSent(u_int16_t query_type)        { incNumEPPQueries(query_type, &sent); };
  inline void incNumEPPQueriesRcvd(u_int16_t query_type) { incNumEPPQueries(query_type, &rcvd); };
  inline void incNumEPPResponsesSent(u_int32_t ret_code) { if((ret_code >= 1000) && (ret_code < 2000)) sent.num_replies_ok++; else sent.num_replies_error++; };
  inline void incNumEPPResponsesRcvd(u_int32_t ret_code) { if((ret_code >= 1000) && (ret_code < 2000)) rcvd.num_replies_ok++; else rcvd.num_replies_error++; };

  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();
  void lua(lua_State *vm);
};

#endif /* _STATS_H_ */

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

#ifndef _NDPI_STATS_H_
#define _NDPI_STATS_H_

#include "ntop_includes.h"

class NetworkInterface;
class ThroughputStats;

/* *************************************** */

class nDPIStats {
 private:
  bool enable_throughput_stats, enable_behavior_stats;
  time_t nextMinPeriodicUpdate;
  std::unordered_map<u_int16_t, ProtoCounter*> counters;
  std::unordered_map<u_int16_t, CategoryCounter> cat_counters;
  
 public:
  nDPIStats(bool enable_throughput_stats = false, bool enable_behavior_stats = false);
  nDPIStats(nDPIStats &stats);
  ~nDPIStats();

  void updateStats(const struct timeval *tv);

  void incStats(u_int32_t when, u_int16_t proto_id, u_int64_t sent_packets,
                u_int64_t sent_bytes, u_int64_t rcvd_packets,
                u_int64_t rcvd_bytes);

  void incCategoryStats(u_int32_t when, ndpi_protocol_category_t category_id,
                        u_int64_t sent_bytes, u_int64_t rcvd_bytes);

  void incFlowsStats(u_int16_t proto_id);
  void lua(NetworkInterface *iface, lua_State* vm,
	   bool with_categories = false, bool tsLua = false, bool diff = false);
  json_object* getJSONObject(NetworkInterface *iface);
  void sum(nDPIStats *s);

  inline u_int64_t getProtoBytes(u_int16_t proto_id) {
    std::unordered_map<u_int16_t, ProtoCounter *>::iterator pi = counters.find(proto_id);

    if(pi != counters.end()) {
      TrafficCounter tc = pi->second->get_bytes();

      return(tc.getTotal());
    } else 
      return(0); 
  }

  inline u_int32_t getProtoDuration(u_int16_t proto_id) {
    std::unordered_map<u_int16_t, ProtoCounter *>::iterator pi = counters.find(proto_id);

    if(pi != counters.end())
      return(pi->second->get_duration());
    else
      return (0);
  }

  inline u_int64_t getCategoryBytes(ndpi_protocol_category_t category_id) {
    std::unordered_map<u_int16_t, CategoryCounter>::iterator cc = cat_counters.find(category_id);

    if(cc != cat_counters.end())
      return(cc->second.getTotalBytes());
    else
      return (0);
  }

  inline u_int32_t getCategoryDuration(ndpi_protocol_category_t category_id) {
    std::unordered_map<u_int16_t, CategoryCounter>::iterator cc = cat_counters.find(category_id);

    if(cc != cat_counters.end())
      return(cc->second.getDuration());
    else
      return (0);
  }

  void resetStats();
  char* serialize(NetworkInterface *iface);
  void  deserialize(NetworkInterface *iface, json_object *o);
};

#endif /* _NDPI_STATS_H_ */

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

#ifndef _PROTO_COUNTER_H_
#define _PROTO_COUNTER_H_

#include "ntop_includes.h"

class ProtoCounter {
 private:
  u_int16_t proto_id;
#ifdef NTOPNG_PRO
  BehaviorAnalysis *behavior_bytes_traffic;
#endif
  ThroughputStats *bytes_thpt;
  TrafficCounter packets, bytes;
  u_int32_t duration /* sec */,
      last_epoch_update; /* useful to avoid multiple updates */
  u_int32_t total_flows;

 public:
  ProtoCounter(u_int16_t _proto_id, bool enable_throughput_stats,
               bool enable_behavior_stats);
  ~ProtoCounter();

  void set(ProtoCounter *p);
  void sum(ProtoCounter *p);
  void print(u_int16_t proto_id, NetworkInterface *iface);
  void lua(lua_State *vm, NetworkInterface *iface, bool tsLua, bool diff);

  inline bool has_throughput_stats() {
    return (
#ifdef NTOPNG_PRO
        behavior_bytes_traffic ? true : false
#else
        false
#endif
    );
  }
  inline bool has_behavior_stats() {
#ifdef NTOPNG_PRO
    return (behavior_bytes_traffic ? true : false);
#else
    return (false);
#endif
  }

  void updateStats(const struct timeval *tv, time_t nextMinPeriodicUpdate);
  void incStats(u_int32_t when, u_int64_t sent_packets, u_int64_t sent_bytes,
                u_int64_t rcvd_packets, u_int64_t rcvd_bytes);
  inline TrafficCounter get_packets() { return (packets); }
  inline TrafficCounter get_bytes() { return (bytes); }
  inline u_int32_t get_duration() { return (duration); }
  inline u_int32_t get_total_flows() { return (total_flows); }
  inline void inc_total_flows() { total_flows++; }
  void addProtoJson(json_object *my_object, NetworkInterface *iface);
  void resetStats();
};

#endif /* _PROTO_COUNTER_H_ */

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

#ifndef _GENRIC_TRAFFIC_ELEMENT_H_
#define _GENRIC_TRAFFIC_ELEMENT_H_

#include "ntop_includes.h"

class GenericTrafficElement {
 protected:
  u_int16_t vlan_id;
  TrafficStats sent, rcvd;
  nDPIStats *ndpiStats;
  u_int32_t total_num_dropped_flows;

  float bytes_thpt, pkts_thpt;
  float last_bytes_thpt, last_pkts_thpt;
  ValueTrend bytes_thpt_trend, pkts_thpt_trend;
  float bytes_thpt_diff;
  u_int64_t last_bytes, last_packets;
  struct timeval last_update_time;

  u_int16_t host_pool_id;

 public:
  GenericTrafficElement();
  GenericTrafficElement(const GenericTrafficElement &gte);

  virtual ~GenericTrafficElement() {
    if(ndpiStats) delete ndpiStats;
  };
  inline u_int16_t get_host_pool()         { return(host_pool_id);   };
  inline u_int16_t get_vlan_id()           { return(vlan_id);        };
  inline void incNumDroppedFlows()         { total_num_dropped_flows++;      };
  inline u_int32_t getNumDroppedFlows()    { return total_num_dropped_flows; };
  virtual void updateStats(struct timeval *tv);
  void lua(lua_State* vm, bool host_details);

  inline u_int64_t getNumBytes()      { return(sent.getNumBytes()+rcvd.getNumBytes()); };
  inline u_int64_t getNumBytesSent()  { return(sent.getNumBytes());                    };
  inline u_int64_t getNumBytesRcvd()  { return(rcvd.getNumBytes());                    };

  inline ValueTrend getThptTrend()    { return(bytes_thpt_trend);          };
  inline float getThptTrendDiff()     { return(bytes_thpt_diff);           };
  inline float getBytesThpt()         { return(bytes_thpt);                };
  inline float getPacketsThpt()       { return(pkts_thpt);                 };
  void resetStats();
};

#endif /* _GENRIC_TRAFFIC_ELEMENT_H_ */

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

#ifndef _GENRIC_TRAFFIC_ELEMENT_H_
#define _GENRIC_TRAFFIC_ELEMENT_H_

#include "ntop_includes.h"

class GenericTrafficElement {
 protected:
  TrafficStats sent, rcvd;
  nDPIStats *ndpiStats;
#ifdef NTOPNG_PRO
  CustomAppStats *custom_app_stats;
#endif
  u_int32_t total_num_dropped_flows;

  float bytes_thpt, pkts_thpt;
  float last_bytes_thpt, last_pkts_thpt;
  ValueTrend bytes_thpt_trend, pkts_thpt_trend;
  float bytes_thpt_diff;
  u_int64_t last_bytes, last_packets;
  struct timeval last_update_time;

 public:
  GenericTrafficElement();
  GenericTrafficElement(const GenericTrafficElement &gte);

  virtual ~GenericTrafficElement() {
    if(ndpiStats) delete ndpiStats;
#ifdef NTOPNG_PRO
    if(custom_app_stats) delete custom_app_stats;
#endif
  };
  inline void incNumDroppedFlows()         { total_num_dropped_flows++;      };
  virtual void updateStats(struct timeval *tv);
  void lua(lua_State* vm, bool host_details);

  inline nDPIStats* getnDPIStats()                          { return(ndpiStats); };
  inline u_int32_t getNumDroppedFlows() const { return total_num_dropped_flows;                };
  inline u_int64_t getNumBytes()        const { return(sent.getNumBytes()+rcvd.getNumBytes()); };
  inline u_int64_t getNumBytesSent()    const { return(sent.getNumBytes());                    };
  inline u_int64_t getNumBytesRcvd()    const { return(rcvd.getNumBytes());                    };

  inline ValueTrend getThptTrend()   const  { return(bytes_thpt_trend);          };
  inline float getThptTrendDiff()    const  { return(bytes_thpt_diff);           };
  inline float getBytesThpt()        const  { return(bytes_thpt);                };
  inline float getPacketsThpt()      const  { return(pkts_thpt);                 };
  void resetStats();
};

#endif /* _GENRIC_TRAFFIC_ELEMENT_H_ */

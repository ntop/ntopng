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

#ifndef _GENRIC_TRAFFIC_ELEMENT_H_
#define _GENRIC_TRAFFIC_ELEMENT_H_

#include "ntop_includes.h"

class GenericTrafficElement {
 protected:
  TrafficStats sent, rcvd;
  ThroughputStats bytes_thpt, pkts_thpt;
  nDPIStats *ndpiStats;
#ifdef NTOPNG_PRO
  CustomAppStats *custom_app_stats;
#endif
  DSCPStats *dscpStats;
  u_int32_t total_num_dropped_flows;
  TcpPacketStats tcp_packet_stats_sent, tcp_packet_stats_rcvd;

  float bytes_thpt_diff;

  inline void incRetx(TcpPacketStats * const tps, u_int32_t num)      { tps->incRetr(num);      };
  inline void incOOO(TcpPacketStats * const tps, u_int32_t num)       { tps->incOOO(num);       };
  inline void incLost(TcpPacketStats * const tps, u_int32_t num)      { tps->incLost(num);;     };
  inline void incKeepAlive(TcpPacketStats * const tps, u_int32_t num) { tps->incKeepAlive(num); };

 public:
  GenericTrafficElement();
  GenericTrafficElement(const GenericTrafficElement &gte);

  virtual ~GenericTrafficElement() {
    if(ndpiStats) delete ndpiStats;
#ifdef NTOPNG_PRO
    if(custom_app_stats) delete custom_app_stats;
#endif
    if(dscpStats) delete dscpStats;
  };
  inline void incNumDroppedFlows()         { total_num_dropped_flows++;      };

  inline TcpPacketStats* getTcpPacketSentStats() { return(&tcp_packet_stats_sent); }
  inline TcpPacketStats* getTcpPacketRcvdStats() { return(&tcp_packet_stats_rcvd); }
  inline void incSentTcp(u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    if(ooo_pkts)        incOOO(&tcp_packet_stats_sent, ooo_pkts);
    if(retr_pkts)       incRetx(&tcp_packet_stats_sent, retr_pkts);
    if(lost_pkts)       incLost(&tcp_packet_stats_sent, lost_pkts);
    if(keep_alive_pkts) incKeepAlive(&tcp_packet_stats_sent, keep_alive_pkts);
  }

  inline void incRcvdTcp(u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    if(ooo_pkts)        incOOO(&tcp_packet_stats_rcvd, ooo_pkts);
    if(retr_pkts)       incRetx(&tcp_packet_stats_rcvd, retr_pkts);
    if(lost_pkts)       incLost(&tcp_packet_stats_rcvd, lost_pkts);
    if(keep_alive_pkts) incKeepAlive(&tcp_packet_stats_rcvd, keep_alive_pkts);
  }
  
  inline void incRetxSent(u_int32_t num)       { incRetx(&tcp_packet_stats_sent, num);      };
  inline void incOOOSent(u_int32_t num)        { incOOO(&tcp_packet_stats_sent, num);       };
  inline void incLostSent(u_int32_t num)       { incLost(&tcp_packet_stats_sent, num);      };
  inline void incKeepAliveSent(u_int32_t num)  { incKeepAlive(&tcp_packet_stats_sent, num); };

  inline void incRetxRcvd(u_int32_t num)       { incRetx(&tcp_packet_stats_rcvd, num);      };
  inline void incOOORcvd(u_int32_t num)        { incOOO(&tcp_packet_stats_rcvd, num);       };
  inline void incLostRcvd(u_int32_t num)       { incLost(&tcp_packet_stats_rcvd, num);      };
  inline void incKeepAliveRcvd(u_int32_t num)  { incKeepAlive(&tcp_packet_stats_rcvd, num); };

  virtual void updateStats(const struct timeval *tv);
  void lua(lua_State* vm, bool host_details);
  void getJSONObject(json_object *my_object, NetworkInterface *iface);
  void deserialize(json_object *obj, NetworkInterface *iface);

  inline nDPIStats* getnDPIStats()                          { return(ndpiStats); };
  inline DSCPStats* getDSCPStats()                          { return(dscpStats); };
  inline u_int32_t getNumDroppedFlows() const { return total_num_dropped_flows;                };
  inline u_int64_t getNumBytes()        const { return(sent.getNumBytes()+rcvd.getNumBytes()); };
  inline u_int64_t getNumBytesSent()    const { return(sent.getNumBytes());                    };
  inline u_int64_t getNumBytesRcvd()    const { return(rcvd.getNumBytes());                    };
  inline u_int64_t getNumPktsSent()     const { return(sent.getNumPkts());                     };
  inline u_int64_t getNumPktsRcvd()     const { return(rcvd.getNumPkts());                     };

  inline float getBytesThpt()           const { return(bytes_thpt.getThpt());                  };
  inline float getPacketsThpt()         const { return(pkts_thpt.getThpt());                   };
  void resetStats();
};

#endif /* _GENRIC_TRAFFIC_ELEMENT_H_ */

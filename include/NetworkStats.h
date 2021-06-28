/*
 *
 * (C) 2015-21 - ntop.org
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

#ifndef _NETWORK_STATS_H_
#define _NETWORK_STATS_H_

#include "ntop_includes.h"

class NetworkStats : public NetworkStatsAlertableEntity, public GenericTrafficElement, public Score {
 private:
  u_int8_t network_id;
  u_int32_t numHosts;
  TrafficStats ingress, ingress_broadcast; /* outside -> network */
  TrafficStats egress, egress_broadcast;   /* network -> outside */
  TrafficStats inner, inner_broadcast;     /* network -> network (local traffic) */
  TcpPacketStats tcp_packet_stats_ingress, tcp_packet_stats_egress, tcp_packet_stats_inner;
  AlertCounter syn_flood_victim_alert;
  AlertCounter flow_flood_victim_alert;
  u_int32_t syn_recvd_last_min, synack_sent_last_min; /* syn scan counters (victim) */

#if defined(NTOPNG_PRO)
  time_t nextMinPeriodicUpdate;
  /* Behavioural analysis regarding the interface */
  AnalysisBehavior *score_behavior, *traffic_tx_behavior, *traffic_rx_behavior;  
#endif

  static inline void incTcp(TcpPacketStats *tps, u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    if(ooo_pkts)        tps->incOOO(ooo_pkts);
    if(retr_pkts)       tps->incRetr(retr_pkts);
    if(lost_pkts)       tps->incLost(lost_pkts);
    if(keep_alive_pkts) tps->incKeepAlive(keep_alive_pkts);
  }

#ifdef NTOPNG_PRO
  void updateBehaviorStats(const struct timeval *tv);
#endif

 public:
  NetworkStats(NetworkInterface *iface, u_int8_t _network_id);
  virtual ~NetworkStats();

  inline bool trafficSeen(){
    return ingress.getNumPkts() || egress.getNumPkts() || inner.getNumPkts();
  };
  
  inline void incIngress(time_t t, u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    rcvd.incStats(t, num_pkts, num_bytes);
    ingress.incStats(t, num_pkts, num_bytes);
    if(broadcast) ingress_broadcast.incStats(t, num_pkts, num_bytes);
  };
  
  inline void incEgress(time_t t, u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    sent.incStats(t, num_pkts, num_bytes);
    egress.incStats(t, num_pkts, num_bytes);
    if(broadcast) egress_broadcast.incStats(t, num_pkts, num_bytes);
  };
  
  inline void incInner(time_t t, u_int64_t num_pkts, u_int64_t num_bytes, bool broadcast) {
    sent.incStats(t, num_pkts, num_bytes);
    inner.incStats(t, num_pkts, num_bytes);
    if(broadcast) inner_broadcast.incStats(t, num_pkts, num_bytes);
  };

  inline void incIngressTcp(u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    incTcp(&tcp_packet_stats_ingress, ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
  };

  inline void incEgressTcp(u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    incTcp(&tcp_packet_stats_egress, ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
  };

  inline void incInnerTcp(u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    incTcp(&tcp_packet_stats_inner, ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
  };

  inline void incNumHosts() { numHosts++; };
  inline void decNumHosts() { numHosts--; };
  inline u_int32_t getNumHosts() const { return numHosts; };

  void setNetworkId(u_int8_t id);
  bool match(const AddressTree * const tree) const;
  void lua(lua_State* vm, bool diff = false);
  bool serialize(json_object *my_object);
  void deserialize(json_object *obj);
  void housekeepAlerts(ScriptPeriodicity p);

  virtual void updateStats(const struct timeval *tv);

  void updateSynAlertsCounter(time_t when, bool syn_sent);
  void updateSynAckAlertsCounter(time_t when, bool synack_sent);
  void incNumFlows(time_t t, bool as_client);
};

#endif /* _NETWORK_STATS_H_ */

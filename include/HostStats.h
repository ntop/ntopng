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

#ifndef _HOST_STATS_H_
#define _HOST_STATS_H_

class Host;

class HostStats: public Checkpointable, public TimeseriesStats {
 protected:
  NetworkInterface *iface;

  /* Written by NetworkInterface::periodicStatsUpdate thread */
  // NOTE: GenericTrafficElement inherited data is updated periodically too
  u_int32_t total_activity_time /* sec */;
  u_int32_t last_epoch_update; /* useful to avoid multiple updates */

#ifdef NTOPNG_PRO
  HostPoolStats *quota_enforcement_stats, *quota_enforcement_stats_shadow;
#endif

  /* Written by NetworkInterface::processPacket thread */
  PacketStats sent_stats, recv_stats;
  u_int32_t total_num_flows_as_client, total_num_flows_as_server;

  /* Written by minute activity thread */
  u_int64_t checkpoint_sent_bytes, checkpoint_rcvd_bytes;
  bool checkpoint_set;

 public:
  HostStats(Host *_host);
  virtual ~HostStats();

  void checkPointHostTalker(lua_State *vm, bool saveCheckpoint);
  bool serializeCheckpoint(json_object *my_object, DetailsLevel details_level);
  virtual void incStats(time_t when, u_int8_t l4_proto, u_int ndpi_proto,
		custom_app_t custom_app,
		u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
		bool peer_is_unicast);
  virtual void getJSONObject(json_object *my_object, DetailsLevel details_level);
  inline void incFlagStats(bool as_client, u_int8_t flags)  { if (as_client) sent_stats.incFlagStats(flags); else recv_stats.incFlagStats(flags); };

  virtual void computeAnomalyIndex(time_t when) {};

  inline void incSentStats(u_int pkt_len)           { sent_stats.incStats(pkt_len);       };
  inline void incRecvStats(u_int pkt_len)           { recv_stats.incStats(pkt_len);       };
  inline void incnDPIFlows(u_int16_t l7_protocol)   { if(ndpiStats) ndpiStats->incFlowsStats(l7_protocol); };
  inline u_int32_t getTotalNumFlowsAsClient() const { return(total_num_flows_as_client);  };
  inline u_int32_t getTotalNumFlowsAsServer() const { return(total_num_flows_as_server);  };
  virtual void deserialize(json_object *obj)        {}
  virtual void incNumFlows(bool as_client, Host *peer) { if(as_client) total_num_flows_as_client++; else total_num_flows_as_server++; } ;
  virtual void decNumFlows(bool as_client, Host *peer) {};
  virtual bool hasAnomalies(time_t when) { return false; };
  virtual void luaAnomalies(lua_State* vm, time_t when) {};
  virtual void lua(lua_State* vm, bool mask_host, DetailsLevel details_level, bool tsLua = false);

#ifdef NTOPNG_PRO
  inline void incQuotaEnforcementStats(time_t when, u_int16_t ndpi_proto,
				       u_int64_t sent_packets, u_int64_t sent_bytes,
				       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    if(quota_enforcement_stats)
      quota_enforcement_stats->incStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
  };
  inline void incQuotaEnforcementCategoryStats(time_t when,
					       ndpi_protocol_category_t category_id,
					       u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
    if(quota_enforcement_stats)
      quota_enforcement_stats->incCategoryStats(when, category_id, sent_bytes, rcvd_bytes);
  }
  inline void resetQuotaStats() { if(quota_enforcement_stats) quota_enforcement_stats->resetStats(); };

  void allocateQuotaEnforcementStats();
  void deleteQuotaEnforcementStats();
  inline HostPoolStats* getQuotaEnforcementStats() { return(quota_enforcement_stats); }
#endif

  virtual void incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {}
  virtual void incNumDNSQueriesSent(u_int16_t query_type) {}
  virtual void incNumDNSQueriesRcvd(u_int16_t query_type) {}
  virtual void incNumDNSResponsesSent(u_int32_t ret_code) {}
  virtual void incNumDNSResponsesRcvd(u_int32_t ret_code) {}
  virtual void luaDNS(lua_State *vm, bool verbose) const  {}
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose) const  {}
  virtual void incrVisitedWebSite(char *hostname) {}
  virtual void tsLua(lua_State* vm) {}
  virtual HTTPstats* getHTTPstats() { return(NULL); }
};

#endif

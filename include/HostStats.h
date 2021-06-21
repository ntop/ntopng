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

#ifndef _HOST_STATS_H_
#define _HOST_STATS_H_

class Host;

class HostStats: public GenericTrafficElement {
 protected:
  NetworkInterface *iface;
  Host *host;

  u_int8_t client_flows_anomaly:1, server_flows_anomaly:1, client_score_anomaly:1, server_score_anomaly:1, _notused:4;
  u_int32_t total_alerts;
  u_int32_t unreachable_flows_as_client, unreachable_flows_as_server;
  /* Used concurrently in view interfaces, possibly removed after https://github.com/ntop/ntopng/issues/4596 */
  u_int32_t alerted_flows_as_client, alerted_flows_as_server;
  u_int32_t host_unreachable_flows_as_client, host_unreachable_flows_as_server;
  u_int32_t total_num_flows_as_client, total_num_flows_as_server;
  u_int32_t num_flow_alerts;
  u_int64_t udp_sent_unicast, udp_sent_non_unicast;
  L4Stats l4stats;
  
  u_int8_t consecutive_high_score;
  time_t periodicUpdate;

  /* *************************************** */
  /* Behavioural analysis regarding the host */
  DESCounter active_flows_srv, active_flows_cli, score_cli, score_srv;

  /* **************************************** */
  
  /* Written by NetworkInterface::periodicStatsUpdate thread */
  // NOTE: GenericTrafficElement inherited data is updated periodically too
  u_int32_t total_activity_time /* sec */;
  u_int32_t last_epoch_update; /* useful to avoid multiple updates */

#ifdef NTOPNG_PRO
  HostPoolStats *quota_enforcement_stats, *quota_enforcement_stats_shadow;
#endif

  /* Written by NetworkInterface::processPacket thread */
  PacketStats sent_stats, recv_stats;

  /* Used to store checkpoint data to build top talkers stats */
  struct {
    u_int64_t sent_bytes;
    u_int64_t rcvd_bytes;
  } checkpoints;

 public:
  HostStats(Host *_host);
  virtual ~HostStats();

  virtual void incStats(time_t when, u_int8_t l4_proto,
			u_int ndpi_proto, ndpi_protocol_category_t ndpi_category,
			custom_app_t custom_app,
			u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
			u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
			bool peer_is_unicast);
  void checkpoint(lua_State* vm);
  virtual void getJSONObject(json_object *my_object, DetailsLevel details_level);
  inline void incFlagStats(bool as_client, u_int8_t flags, bool cumulative_flags)  {
    if (as_client)
      sent_stats.incFlagStats(flags, cumulative_flags);
    else
      recv_stats.incFlagStats(flags, cumulative_flags);
  };
  
  virtual void computeAnomalyIndex(time_t when) {};

  inline Host* getHost() const { return(host); }
  inline void incNumAlertedFlows(bool as_client)   { if(as_client) alerted_flows_as_client++; else alerted_flows_as_server++; };
  inline void incNumUnreachableFlows(bool as_server) { if(as_server) unreachable_flows_as_server++; else unreachable_flows_as_client++; }
  inline void incNumHostUnreachableFlows(bool as_server) { if(as_server) host_unreachable_flows_as_server++; else host_unreachable_flows_as_client++; };
  inline void incNumFlowAlerts()                     { num_flow_alerts++; };
  inline void incTotalAlerts()                       { total_alerts++;    };
  inline u_int32_t getTotalAlertedNumFlowsAsClient() const { return(alerted_flows_as_client);  };
  inline u_int32_t getTotalAlertedNumFlowsAsServer() const { return(alerted_flows_as_server);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsClient() const { return(unreachable_flows_as_client);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsServer() const { return(unreachable_flows_as_server);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsClient() const { return(host_unreachable_flows_as_client);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsServer() const { return(host_unreachable_flows_as_server);  };
  u_int32_t getTotalAlerts() const;
  inline u_int32_t getNumFlowAlerts() const { return(num_flow_alerts); };
  void luaNdpiStats(lua_State *vm);
  void luaActiveFlowsBehaviour(lua_State *vm);
  void luaScoreBehaviour(lua_State *vm);
  void luaStats(lua_State* vm, NetworkInterface *iface, bool host_details, bool verbose, bool tsLua = false);
  virtual u_int16_t getNumActiveContactsAsClient() { return 0; }
  virtual u_int16_t getNumActiveContactsAsServer() { return 0; }
  virtual void resetTopSitesData() {};
  
  inline void incSentStats(u_int num_pkts, u_int pkt_len) { sent_stats.incStats(num_pkts, pkt_len); };
  inline void incRecvStats(u_int num_pkts, u_int pkt_len) { recv_stats.incStats(num_pkts, pkt_len); };
  inline void incnDPIFlows(u_int16_t l7_protocol)   { if(ndpiStats) ndpiStats->incFlowsStats(l7_protocol); };
  inline void incrConsecutiveHighScore()            { consecutive_high_score++; };
  inline void resetConsecutiveHighScore()           { consecutive_high_score = 0; };
  inline u_int8_t getConsecutiveHighScore()         { return(consecutive_high_score); };
  inline u_int32_t getTotalNumFlowsAsClient() const { return(total_num_flows_as_client);  };
  inline u_int32_t getTotalNumFlowsAsServer() const { return(total_num_flows_as_server);  };
  inline u_int32_t getTotalActivityTime()     const { return(total_activity_time);        };
  virtual void deserialize(json_object *obj)        {}
  virtual void incNumFlows(bool as_client) { if(as_client) total_num_flows_as_client++; else total_num_flows_as_server++; } ;
  virtual bool hasAnomalies(time_t when) { return false; };
  virtual void luaAnomalies(lua_State* vm, time_t when) {};
  virtual void luaPeers(lua_State *vm) 			{};
  virtual void lua(lua_State* vm, bool mask_host, DetailsLevel details_level);
  void updateStats(const struct timeval *tv);
  virtual void luaHostBehaviour(lua_State* vm);
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
  
  virtual void luaHTTP(lua_State *vm) {}
  virtual void luaDNS(lua_State *vm, bool verbose)  {}
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose)  {}
  virtual void incrVisitedWebSite(char *hostname) {}
  virtual HTTPstats* getHTTPstats()  { return(NULL); }
  virtual DnsStats*  getDNSstats()   { return(NULL); }
  virtual ICMPstats* getICMPstats()  { return(NULL); }

  virtual void incCliContactedPorts(u_int16_t port)  { ; }
  virtual void incSrvPortsContacts(u_int16_t port)   { ; }
  virtual void incContactedService(char *name)       { ; }
  virtual void incCliContactedHosts(IpAddress *peer) { ; }
  virtual void incSrvHostContacts(IpAddress *peer)   { ; }

  virtual u_int32_t getNTPContactCardinality()  { return((u_int32_t)-1); }
  virtual u_int32_t getDNSContactCardinality()  { return((u_int32_t)-1); }
  virtual u_int32_t getSMTPContactCardinality() { return((u_int32_t)-1); }
  virtual void incNTPContactCardinality(Host *h)  { ; }
  virtual void incDNSContactCardinality(Host *h)  { ; }
  virtual void incSMTPContactCardinality(Host *h) { ; }

  inline bool has_flows_anomaly(bool as_client) { return(as_client ? client_flows_anomaly : server_flows_anomaly); }
  inline u_int64_t value_flows_anomaly(bool as_client) { return(as_client ? active_flows_cli.getLastValue() : active_flows_srv.getLastValue()); }
  inline u_int64_t lower_bound_flows_anomaly(bool as_client) { return(as_client ? active_flows_cli.getLastLowerBound() : active_flows_srv.getLastLowerBound()); }
  inline u_int64_t upper_bound_flows_anomaly(bool as_client) { return(as_client ? active_flows_cli.getLastUpperBound() : active_flows_srv.getLastUpperBound()); }

  inline bool has_score_anomaly(bool as_client) { return(as_client ? client_score_anomaly : server_score_anomaly); }
  inline u_int64_t value_score_anomaly(bool as_client) { return(as_client ? score_cli.getLastValue() : score_srv.getLastValue()); }
  inline u_int64_t lower_bound_score_anomaly(bool as_client) { return(as_client ? score_cli.getLastLowerBound() : score_srv.getLastLowerBound()); }
  inline u_int64_t upper_bound_score_anomaly(bool as_client) { return(as_client ? score_cli.getLastUpperBound() : score_srv.getLastUpperBound()); }
};

#endif

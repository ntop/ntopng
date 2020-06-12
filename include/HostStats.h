/*
 *
 * (C) 2013-20 - ntop.org
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

  std::map<AlertType,u_int32_t> total_alerts;
  u_int32_t unreachable_flows_as_client, unreachable_flows_as_server;
  u_int32_t misbehaving_flows_as_client, misbehaving_flows_as_server;
  u_int32_t host_unreachable_flows_as_client, host_unreachable_flows_as_server;
  u_int32_t total_num_flows_as_client, total_num_flows_as_server;
  u_int32_t num_flow_alerts;
  u_int64_t udp_sent_unicast, udp_sent_non_unicast;
  L4Stats l4stats;

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
  inline void incNumMisbehavingFlows(bool as_client)   { if(as_client) misbehaving_flows_as_client++; else misbehaving_flows_as_server++; };
  inline void incNumUnreachableFlows(bool as_server) { if(as_server) unreachable_flows_as_server++; else unreachable_flows_as_client++; }
  inline void incNumHostUnreachableFlows(bool as_server) { if(as_server) host_unreachable_flows_as_server++; else host_unreachable_flows_as_client++; };
  inline void incNumFlowAlerts()                     { num_flow_alerts++; }
  inline void incTotalAlerts(AlertType alert_type)   { total_alerts[alert_type]++; };

  inline u_int32_t getTotalMisbehavingNumFlowsAsClient() const { return(misbehaving_flows_as_client);  };
  inline u_int32_t getTotalMisbehavingNumFlowsAsServer() const { return(misbehaving_flows_as_server);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsClient() const { return(unreachable_flows_as_client);  };
  inline u_int32_t getTotalUnreachableNumFlowsAsServer() const { return(unreachable_flows_as_server);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsClient() const { return(host_unreachable_flows_as_client);  };
  inline u_int32_t getTotalHostUnreachableNumFlowsAsServer() const { return(host_unreachable_flows_as_server);  };
  u_int32_t getTotalAlerts() const;
  inline u_int32_t getNumFlowAlerts() const { return(num_flow_alerts); };
  void luaStats(lua_State* vm, NetworkInterface *iface, bool host_details, bool verbose, bool tsLua = false);
  virtual u_int16_t getNumActiveContactsAsClient() { return 0; }
  virtual u_int16_t getNumActiveContactsAsServer() { return 0; }

  inline void incSentStats(u_int num_pkts, u_int pkt_len) { sent_stats.incStats(num_pkts, pkt_len); };
  inline void incRecvStats(u_int num_pkts, u_int pkt_len) { recv_stats.incStats(num_pkts, pkt_len); };
  inline void incnDPIFlows(u_int16_t l7_protocol)   { if(ndpiStats) ndpiStats->incFlowsStats(l7_protocol); };
  inline u_int32_t getTotalNumFlowsAsClient() const { return(total_num_flows_as_client);  };
  inline u_int32_t getTotalNumFlowsAsServer() const { return(total_num_flows_as_server);  };
  inline u_int32_t getTotalActivityTime()     const { return(total_activity_time);        };
  virtual void deserialize(json_object *obj)        {}
  virtual void incNumFlows(bool as_client, Host *peer) { if(as_client) total_num_flows_as_client++; else total_num_flows_as_server++; } ;
  virtual void decNumFlows(bool as_client, Host *peer) {};
  virtual bool hasAnomalies(time_t when) { return false; };
  virtual void luaAnomalies(lua_State* vm, time_t when) {};
  virtual void lua(lua_State* vm, bool mask_host, DetailsLevel details_level);

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

  virtual void luaHTTP(lua_State *vm) const {}
  virtual void luaDNS(lua_State *vm, bool verbose) const  {}
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose) const  {}
  virtual void incrVisitedWebSite(char *hostname) {}
  virtual HTTPstats* getHTTPstats()  const { return(NULL); }
  virtual DnsStats*  getDNSstats()   const { return(NULL); }
  virtual ICMPstats* getICMPstats()  const { return(NULL); }

  virtual void incCliContactedPorts(u_int16_t port)  { ; }
  virtual void incSrvPortsContacts(u_int16_t port)   { ; }
  virtual void incServicesContacted(char *name)      { ; }
  virtual void incCliContactedHosts(IpAddress *peer) { ; }
  virtual void incSrvHostContacts(IpAddress *peer)   { ; }
};

#endif

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

#ifndef _HOST_H_
#define _HOST_H_

#include "ntop_includes.h"

class Host : public GenericHashEntry, public AlertableEntity {
 protected:
  IpAddress ip;
  Mac *mac;
  char *asname;

  struct {
    Fingerprint ja3;
    Fingerprint hassh;
  } fingerprints;
  
  bool stats_reset_requested, name_reset_requested, data_delete_requested;
  u_int16_t vlan_id, host_pool_id, host_services_bitmap;
  HostStats *stats, *stats_shadow;
  HostScore score;
  time_t last_stats_reset;
  std::atomic<u_int32_t> active_alerted_flows;
  
  /* Host data: update Host::deleteHostData when adding new fields */
  struct {
    char *mdns /* name from a MDNS reply of any type */,
    *mdns_txt /* name from a TXT MDNS reply after "nm=" field (most accurate) */,
    *mdns_info /* name from a TXT MDNS reply */;
    char *resolved; /* The name as resolved by ntopng DNS requests */
    char *netbios; /* The Netbios name */
  } names;

  char *ssdpLocation;
  bool prefs_loaded;
  MudRecording mud_pref;
  /* END Host data: */

  AlertCounter *syn_flood_attacker_alert, *syn_flood_victim_alert;
  AlertCounter *flow_flood_attacker_alert, *flow_flood_victim_alert;
  u_int32_t syn_sent_last_min, synack_recvd_last_min; /* syn scan counters (attacker) */
  u_int32_t syn_recvd_last_min, synack_sent_last_min; /* syn scan counters (victim) */
  std::atomic<u_int32_t> num_active_flows_as_client, num_active_flows_as_server; /* Need atomic as inc/dec done on different threads */
  u_int32_t asn;
  AutonomousSystem *as;
  Country *country;
  Vlan *vlan;

  OperatingSystem *os; /* Pointer to an instance of operating system, used internally to handle operating system statistics    */
  OSType os_type;      /* Operating system type, equivalent to os->get_os_type(), used by operating system setters and getters */

  Mutex m;
  u_int32_t mac_last_seen;
  u_int8_t num_resolve_attempts;
  time_t nextResolveAttempt;

#ifdef NTOPNG_PRO
  TrafficShaper **host_traffic_shapers;
  bool has_blocking_quota, has_blocking_shaper;
#endif
  bool hidden_from_top;
  bool is_in_broadcast_domain;
  bool is_dhcp_host;

  void initialize(Mac *_mac, u_int16_t _vlan_id);
  void inlineSetOS(OSType _os);
  bool statsResetRequested();
  void checkStatsReset();
#ifdef NTOPNG_PRO
  TrafficShaper *get_shaper(ndpi_protocol ndpiProtocol, bool isIngress);
  void get_quota(u_int16_t protocol, u_int64_t *bytes_quota, u_int32_t *secs_quota, u_int32_t *schedule_bitmap, bool *is_category);
#endif
  void lua_get_names(lua_State * const vm, char * const buf, ssize_t buf_size);
  void luaStrTableEntryLocked(lua_State * const vm, const char * const entry_name, const char * const entry);
  char* printMask(char *str, u_int str_len) { return ip.printMask(str, str_len, isLocalHost()); };
  void freeHostNames();
  void resetHostNames();
  virtual void deleteHostData();
  char* get_mac_based_tskey(Mac *mac, char *buf, size_t bufsize);
  
 public:
  Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  Host(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip);

  virtual ~Host();

  virtual bool isLocalHost()  const = 0;
  virtual bool isSystemHost() const = 0;
  inline  bool isBroadcastDomainHost() const { return(is_in_broadcast_domain); };
  inline  bool serializeByMac()        const { return(isLocalHost() && iface->serializeLbdHostsAsMacs()); }
  inline  bool isDhcpHost()            const { return(is_dhcp_host); };
  inline  void setBroadcastDomainHost()      { is_in_broadcast_domain = true;  };
  inline  void setSystemHost()               { /* TODO: remove */              };

  inline  bool isDhcpServer()          const { return(host_services_bitmap & (1 << HOST_IS_DHCP_SERVER)); }
  inline  void setDhcpServer()               { host_services_bitmap |= 1 << HOST_IS_DHCP_SERVER;          }
  inline  bool isDnsServer()          const  { return(host_services_bitmap & (1 << HOST_IS_DNS_SERVER));  }
  inline  void setDnsServer()                { host_services_bitmap |= 1 << HOST_IS_DNS_SERVER;           }
  inline  bool isSmtpServer()          const { return(host_services_bitmap & (1 << HOST_IS_SMTP_SERVER)); }
  inline  void setSmtpServer()               { host_services_bitmap |= 1 << HOST_IS_SMTP_SERVER;          }
  inline  bool isNtpServer()          const  { return(host_services_bitmap & (1 << HOST_IS_NTP_SERVER));  }
  inline  void setNtpServer()                { host_services_bitmap |= 1 << HOST_IS_NTP_SERVER;           }
  inline  u_int16_t getServicesMap()         { return(host_services_bitmap);                              }
  /*
    NOTE: update the fucntion below when a new isXXXServer is added 
    Return true if this host is a server for known protocols 
  */
  inline bool  isProtocolServer()     const  { return(isDhcpServer() || isDnsServer() || isSmtpServer() || isNtpServer()); }
						      
  bool isBroadcastHost()              const  { return(ip.isBroadcastAddress() || (mac && mac->isBroadcast())); }
  bool isMulticastHost()              const  { return(ip.isMulticastAddress()); }

  inline nDPIStats* get_ndpi_stats()   const { return(stats->getnDPIStats()); };

  inline bool isChildSafe() const {
#ifdef NTOPNG_PRO
    return(iface->getHostPools()->isChildrenSafePool(host_pool_id));
#else
    return(false);
#endif
  };

  inline bool forgeGlobalDns() {
#ifdef NTOPNG_PRO
    return(iface->getHostPools()->forgeGlobalDns(host_pool_id));
#else
    return(false);
#endif
  };

  virtual HostStats* allocateStats()                { return(new HostStats(this)); };
  void updateStats(periodic_stats_update_user_data_t *periodic_stats_update_user_data);
  void incLowGoodputFlows(time_t t, bool asClient);
  void decLowGoodputFlows(time_t t, bool asClient);
  inline u_int16_t get_host_pool()    const { return(host_pool_id);   };
  inline u_int16_t get_vlan_id()      const { return(vlan_id);        };
  char* get_name(char *buf, u_int buf_len, bool force_resolution_if_not_found);

  inline void incSentTcp(u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    if(ooo_pkts)        stats->incOOOSent(ooo_pkts);
    if(retr_pkts)       stats->incRetxSent(retr_pkts);
    if(lost_pkts)       stats->incLostSent(lost_pkts);
    if(keep_alive_pkts) stats->incKeepAliveSent(keep_alive_pkts);
  }

  inline void incRcvdTcp(u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts, u_int32_t keep_alive_pkts) {
    if(ooo_pkts)        stats->incOOORcvd(ooo_pkts);
    if(retr_pkts)       stats->incRetxRcvd(retr_pkts);
    if(lost_pkts)       stats->incLostRcvd(lost_pkts);
    if(keep_alive_pkts) stats->incKeepAliveRcvd(keep_alive_pkts);
  }

  inline void incSentStats(u_int num_pkts, u_int pkt_len)  { stats->incSentStats(num_pkts, pkt_len); };
  inline void incRecvStats(u_int num_pkts, u_int pkt_len)  { stats->incRecvStats(num_pkts, pkt_len); };

  inline void incDSCPStats(u_int8_t ds, u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t rcvd_packets, u_int64_t rcvd_bytes) { 
    stats->getDSCPStats()->incStats(ds, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes); 
  }
  
  virtual int16_t get_local_network_id() const = 0;
  virtual HTTPstats* getHTTPstats()           { return(NULL);                  };
  virtual DnsStats*  getDNSstats()            { return(NULL);                  };
  virtual ICMPstats* getICMPstats()           { return(NULL);                  };
  inline void set_ipv4(u_int32_t _ipv4)             { ip.set(_ipv4);                 };
  inline void set_ipv6(struct ndpi_in6_addr *_ipv6) { ip.set(_ipv6);                 };
  inline u_int32_t key()                            { return(ip.key());              };
  inline IpAddress* get_ip()                        { return(&ip);                   };
  inline bool isIPv4()                        const { return ip.isIPv4();            };
  inline bool isIPv6()                        const { return ip.isIPv6();            };
  void set_mac(Mac  *m);
  inline bool isBlacklisted()                 const { return(ip.isBlacklistedAddress()); };
  void reloadHostBlacklist();
  inline const u_int8_t* const get_mac() const { return(mac ? mac->get_mac() : NULL);}
  inline Mac* getMac() const                   { return(mac);              }
  inline DeviceType getDeviceType()      const { Mac *m = mac; return(isBroadcastDomainHost() && m ? m->getDeviceType() : device_unknown); }
  char * getResolvedName(char * const buf, ssize_t buf_len);
  char * getMDNSName(char * const buf, ssize_t buf_len);
  char * getMDNSTXTName(char * const buf, ssize_t buf_len);
  char * getMDNSInfo(char * const buf, ssize_t buf_len);
  char * getNetbiosName(char * const buf, ssize_t buf_len);
#ifdef NTOPNG_PRO
  inline TrafficShaper *get_ingress_shaper(ndpi_protocol ndpiProtocol) { return(get_shaper(ndpiProtocol, true)); }
  inline TrafficShaper *get_egress_shaper(ndpi_protocol ndpiProtocol)  { return(get_shaper(ndpiProtocol, false)); }
  inline void resetQuotaStats()                                        { stats->resetQuotaStats(); }
  bool checkQuota(ndpi_protocol ndpiProtocol, L7PolicySource_t *quota_source, const struct tm *now);
  inline bool hasBlockedTraffic() { return has_blocking_quota || has_blocking_shaper; };
  inline void resetBlockedTrafficStatus(){ has_blocking_quota = has_blocking_shaper = false; };
  void luaUsedQuotas(lua_State* vm);

  inline void incQuotaEnforcementStats(u_int32_t when, u_int16_t ndpi_proto,
				       u_int64_t sent_packets, u_int64_t sent_bytes,
				       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    stats->incQuotaEnforcementStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
  }

  inline void incQuotaEnforcementCategoryStats(u_int32_t when,
				       ndpi_protocol_category_t category_id,
				       u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
    stats->incQuotaEnforcementCategoryStats(when, category_id, sent_bytes, rcvd_bytes);
  }
#endif

  inline u_int64_t getNumBytesSent()     const { return(stats->getNumBytesSent());   }
  inline u_int64_t getNumBytesRcvd()     const { return(stats->getNumBytesRcvd());   }
  inline u_int64_t getNumPktsSent()      const { return(stats->getNumPktsSent());    }
  inline u_int64_t getNumPktsRcvd()      const { return(stats->getNumPktsRcvd());    }
  inline u_int64_t getNumDroppedFlows()        { return(stats->getNumDroppedFlows());}
  inline u_int64_t getNumBytes()               { return(stats->getNumBytes());}
  inline float getBytesThpt()                  { return(stats->getBytesThpt());      }
  inline float getPacketsThpt()                { return(stats->getPacketsThpt());    }
  inline void incNumDroppedFlows()             { stats->incNumDroppedFlows();        }

  inline u_int32_t get_asn()             const { return(asn);              }
  inline char*     get_asname()          const { return(asname);           }
  inline AutonomousSystem* get_as()      const { return(as);               }

  inline bool isPrivateHost()            const { return(ip.isPrivateAddress()); }
  bool isLocalInterfaceAddress();
  char* get_visual_name(char *buf, u_int buf_len);
  virtual char* get_string_key(char *buf, u_int buf_len) const { return(ip.print(buf, buf_len)); };
  char* get_hostkey(char *buf, u_int buf_len, bool force_vlan=false);
  char* get_tskey(char *buf, size_t bufsize);

  bool is_hash_entry_state_idle_transition_ready() const;
  void periodic_stats_update(const struct timeval *tv);
  virtual void custom_periodic_stats_update(const struct timeval *tv) { ; }
  
  virtual void lua(lua_State* vm, AddressTree * ptree, bool host_details,
	   bool verbose, bool returnHost, bool asListElement);

  void lua_get_bins(lua_State* vm)            const;
  void lua_get_ip(lua_State* vm)              const;
  void lua_get_localhost_info(lua_State* vm)  const;
  void lua_get_mac(lua_State* vm)             const;
  void lua_get_host_pool(lua_State* vm)       const;
  void lua_get_as(lua_State* vm)              const;
  void lua_get_bytes(lua_State* vm)           const;
  void lua_get_app_bytes(lua_State *vm, u_int app_id) const;
  void lua_get_cat_bytes(lua_State *vm, ndpi_protocol_category_t category_id) const;
  void lua_get_packets(lua_State* vm)       const;
  void lua_get_time(lua_State* vm)          const;
  void lua_get_syn_flood(lua_State* vm)     const;
  void lua_get_flow_flood(lua_State*vm)     const;
  void lua_get_services(lua_State *vm)      const;
  void lua_get_syn_scan(lua_State* vm)      const;
  void lua_get_anomalies(lua_State* vm)     const;
  void lua_get_num_alerts(lua_State* vm)    const;
  void lua_get_num_total_flows(lua_State* vm) const;
  void lua_get_num_flows(lua_State* vm)     const;
  void lua_get_min_info(lua_State* vm);
  void lua_get_num_contacts(lua_State* vm);
  void lua_get_num_http_hosts(lua_State*vm);
  void lua_get_score(lua_State* vm);
  void lua_get_score_breakdown(lua_State* vm);
  void lua_get_os(lua_State* vm);
  void lua_get_fingerprints(lua_State *vm);
  void lua_get_geoloc(lua_State *vm);
  
  void resolveHostName();
  char *get_host_label(char * const buf, ssize_t buf_size);
  inline int compare(Host *h) { return(ip.compare(&h->ip)); };
  inline bool equal(IpAddress *_ip)  { return(_ip && ip.equal(_ip)); };
  void incStats(u_int32_t when, u_int8_t l4_proto,
		u_int ndpi_proto, ndpi_protocol_category_t ndpi_category,
		custom_app_t custom_app,
		u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
    bool peer_is_unicast);
  inline void checkpoint(lua_State* vm) { if(stats) return stats->checkpoint(vm); };
  void incHitter(Host *peer, u_int64_t sent_bytes, u_int64_t rcvd_bytes);
  virtual void updateHostTrafficPolicy(char *key) {};
  bool addIfMatching(lua_State* vm, AddressTree * ptree, char *key);
  bool addIfMatching(lua_State* vm, u_int8_t *mac);
  void updateSynAlertsCounter(time_t when, bool syn_sent);
  void updateSynAckAlertsCounter(time_t when, bool synack_sent);
  inline void updateRoundTripTime(u_int32_t rtt_msecs) {
    if(as) as->updateRoundTripTime(rtt_msecs);
  }

  void incNumFlows(time_t t, bool as_client);
  void decNumFlows(time_t t, bool as_client);
  inline void incNumAlertedFlows(bool as_client) { active_alerted_flows++; if(stats) stats->incNumAlertedFlows(as_client); }
  inline void decNumAlertedFlows(bool as_client) { active_alerted_flows--; }
  inline u_int32_t getNumAlertedFlows() const { return(active_alerted_flows); }
  inline void incNumUnreachableFlows(bool as_server) { if(stats) stats->incNumUnreachableFlows(as_server); }
  inline void incNumHostUnreachableFlows(bool as_server) { if(stats) stats->incNumHostUnreachableFlows(as_server); };
  inline void incnDPIFlows(u_int16_t l7_protocol)    { if(stats) stats->incnDPIFlows(l7_protocol); }
  inline void incFlagStats(bool as_client, u_int8_t flags, bool cumulative_flags)  {
    stats->incFlagStats(as_client, flags, cumulative_flags);
  };
  virtual void luaHTTP(lua_State *vm)              { };
  virtual void luaDNS(lua_State *vm, bool verbose) { };
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose)    { };
  virtual void luaTCP(lua_State *vm) { };
  virtual u_int16_t getNumActiveContactsAsClient()  { return 0; };
  virtual u_int16_t getNumActiveContactsAsServer()  { return 0; };
  inline TcpPacketStats* getTcpPacketSentStats() { return(stats->getTcpPacketSentStats()); }
  inline TcpPacketStats* getTcpPacketRcvdStats() { return(stats->getTcpPacketRcvdStats()); }

  virtual NetworkStats* getNetworkStats(int16_t networkId) { return(NULL);   };
  inline Country* getCountryStats()                        { return country; };

  bool match(const AddressTree * const tree) const { return ip.match(tree); };
  void updateHostPool(bool isInlineCall, bool firstUpdate = false);
  virtual bool dropAllTraffic() const { return(false); };
  virtual bool setRemoteToRemoteAlerts() { return(false); };
  virtual void incrVisitedWebSite(char *hostname) {};
  inline void incTotalAlerts(AlertType alert_type) { stats->incTotalAlerts(alert_type); }
  inline u_int32_t getTotalAlerts()       { return(stats->getTotalAlerts()); }
  virtual u_int32_t getActiveHTTPHosts()  { return(0); };
  inline u_int32_t getNumOutgoingFlows()  const { return(num_active_flows_as_client); }
  inline u_int32_t getNumIncomingFlows()  const { return(num_active_flows_as_server); }
  inline u_int32_t getNumActiveFlows()    const { return(getNumOutgoingFlows()+getNumIncomingFlows()); }
  inline u_int32_t getTotalNumFlowsAsClient() const { return(stats->getTotalNumFlowsAsClient());  };
  inline u_int32_t getTotalNumFlowsAsServer() const { return(stats->getTotalNumFlowsAsServer());  };
  inline u_int32_t getTotalNumAlertedOutgoingFlows() const { return stats->getTotalAlertedNumFlowsAsClient(); };
  inline u_int32_t getTotalNumAlertedIncomingFlows() const { return stats->getTotalAlertedNumFlowsAsServer(); };
  inline u_int32_t getTotalNumUnreachableOutgoingFlows() const { return stats->getTotalUnreachableNumFlowsAsClient(); };
  inline u_int32_t getTotalNumUnreachableIncomingFlows() const { return stats->getTotalUnreachableNumFlowsAsServer(); };
  inline u_int32_t getTotalNumHostUnreachableOutgoingFlows() const { return stats->getTotalHostUnreachableNumFlowsAsClient(); };
  inline u_int32_t getTotalNumHostUnreachableIncomingFlows() const { return stats->getTotalHostUnreachableNumFlowsAsServer(); };
  void splitHostVlan(const char *at_sign_str, char *buf, int bufsize, u_int16_t *vlan_id);
  char* get_country(char *buf, u_int buf_len);
  char* get_city(char *buf, u_int buf_len);
  void get_geocoordinates(float *latitude, float *longitude);
  void serialize_geocoordinates(ndpi_serializer *s, const char *prefix);
  inline void reloadHideFromTop() { hidden_from_top = iface->isHiddenFromTop(this); }
  inline void reloadDhcpHost()    { is_dhcp_host = iface->isInDhcpRange(get_ip()); }
  inline bool isHiddenFromTop() { return hidden_from_top; }
  bool isOneWayTraffic()  const;
  bool isTwoWaysTraffic() const;
  virtual void lua_get_timeseries(lua_State* vm) { lua_pushnil(vm); };
  DeviceProtoStatus getDeviceAllowedProtocolStatus(ndpi_protocol proto, bool as_client);

  virtual void serialize(json_object *obj, DetailsLevel details_level);

  inline void requestStatsReset()                        { stats_reset_requested = true; };
  inline void requestNameReset()                         { name_reset_requested = true; };
  inline void requestDataReset()                         { data_delete_requested = true; requestStatsReset(); };
  void checkNameReset();
  void checkDataReset();
  void checkBroadcastDomain();
  bool hasAnomalies() const;
  void housekeepAlerts(ScriptPeriodicity p);
  virtual void inlineSetOSDetail(const char *detail) { }
  virtual const char* getOSDetail(char * const buf, ssize_t buf_len);
  void offlineSetNetbiosName(const char * const n);
  void offlineSetSSDPLocation(const char * const url);
  void offlineSetMDNSInfo(char * const s);
  void offlineSetMDNSName(const char * const n);
  void offlineSetMDNSTXTName(const char * const n);
  void setResolvedName(const char * const resolved_name);
  inline Fingerprint* getJA3Fingerprint()   { return(&fingerprints.ja3);   }
  inline Fingerprint* getHASSHFingerprint() { return(&fingerprints.hassh); }

  void setPrefsChanged()                   { prefs_loaded = false;  }
  virtual void reloadPrefs()               {}
  inline void checkReloadPrefs()           {
    if(!prefs_loaded) {
      reloadPrefs();
      prefs_loaded = true;
    }
  }
  inline MudRecording getMUDRecording()    { return(mud_pref);   };

  inline u_int32_t getScore()         const { return score.get(); };
  inline u_int32_t getScoreAsClient() const { return score.getClient(); };
  inline u_int32_t getScoreAsServer() const { return score.getServer(); };
  u_int16_t incScoreValue(u_int16_t score_incr, ScoreCategory score_category, bool as_client);
  u_int16_t decScoreValue(u_int16_t score_decr, ScoreCategory score_category, bool as_client);

  void setOS(OSType _os);
  OSType getOS() const;
  void incOSStats(time_t when, u_int16_t proto_id,
		       u_int64_t sent_packets, u_int64_t sent_bytes,
		       u_int64_t rcvd_packets, u_int64_t rcvd_bytes);
  void incCliContactedHosts(IpAddress *peer) { stats->incCliContactedHosts(peer); }
  void incCliContactedPorts(u_int16_t port)  { stats->incCliContactedPorts(port); }
  void incSrvHostContacts(IpAddress *peer)   { stats->incSrvHostContacts(peer);   }
  void incSrvPortsContacts(u_int16_t port)   { stats->incSrvPortsContacts(port);  }
  void incContactedService(char *name)       { stats->incContactedService(name);  }

  virtual void luaHostBehaviour(lua_State* vm) { lua_pushnil(vm); }
  virtual void incDohDoTUses(Host *srv_host) {}
};

#endif /* _HOST_H_ */

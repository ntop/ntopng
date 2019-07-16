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

#ifndef _HOST_H_
#define _HOST_H_

#include "ntop_includes.h"

class Host : public GenericHashEntry, public AlertableEntity {
 protected:
  IpAddress ip;
  Mac *mac;
  char *asname;
  struct {
    Fingerprint ssl;
  } fingerprints;
  bool stats_reset_requested, data_delete_requested;
  u_int16_t vlan_id, host_pool_id;
  HostStats *stats, *stats_shadow;
  time_t last_stats_reset;

  /* Host data: update Host::deleteHostData when adding new fields */
  struct {
    char * mdns, * mdns_txt;
    char * resolved; /* The name as resolved by ntopng DNS requests */
  } names;

  char *mdns_info;
  char *ssdpLocation;
  bool host_label_set;
  /* END Host data: */

  AlertCounter *syn_flood_attacker_alert, *syn_flood_victim_alert;
  AlertCounter *flow_flood_attacker_alert, *flow_flood_victim_alert;
  bool trigger_host_alerts;
  std::vector<u_int32_t> dropbox_namespaces;
  MonitoredGauge<u_int32_t> num_active_flows_as_client, num_active_flows_as_server,
    low_goodput_client_flows, low_goodput_server_flows;  
  u_int32_t asn;
  AutonomousSystem *as;
  Country *country;
  Vlan *vlan;
  bool blacklisted_host;

  Mutex m;
  u_int32_t mac_last_seen;
  u_int8_t num_resolve_attempts;
  time_t nextResolveAttempt;

  bool good_low_flow_detected;
  FlowAlertCounter *flow_alert_counter;
#ifdef NTOPNG_PRO
  TrafficShaper **host_traffic_shapers;
  bool has_blocking_quota, has_blocking_shaper;
#endif
  bool hidden_from_top;
  bool is_in_broadcast_domain;
  bool is_dhcp_host;

  void initialize(Mac *_mac, u_int16_t _vlan_id, bool init_all);
  bool statsResetRequested();
  void checkStatsReset();
#ifdef NTOPNG_PRO
  TrafficShaper *get_shaper(ndpi_protocol ndpiProtocol, bool isIngress);
  void get_quota(u_int16_t protocol, u_int64_t *bytes_quota, u_int32_t *secs_quota, u_int32_t *schedule_bitmap, bool *is_category);
#endif
  void luaNames(lua_State * const vm, char * const buf, ssize_t buf_size);
  void luaStrTableEntryLocked(lua_State * const vm, const char * const entry_name, const char * const entry);
  char* printMask(char *str, u_int str_len) { return ip.printMask(str, str_len, isLocalHost()); };
  void freeHostData();
  virtual void deleteHostData();
  char* get_mac_based_tskey(Mac *mac, char *buf, size_t bufsize);
  
 public:
  Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  Host(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip);

  virtual ~Host();

  virtual bool isLocalHost()  const = 0;
  virtual bool isSystemHost() const = 0;
  inline  bool isBroadcastDomainHost() const { return(is_in_broadcast_domain); };
  inline  bool isDhcpHost()            const { return(is_dhcp_host); };
  inline void setBroadcastDomainHost()       { is_in_broadcast_domain = true;  };
  inline void setSystemHost()                { /* TODO: remove */              };

  inline nDPIStats* get_ndpi_stats()       { return(stats->getnDPIStats()); };

  virtual void set_to_purge(time_t t) { /* Saves 1 extra-step of purge idle */
    iface->decNumHosts(isLocalHost());
    GenericHashEntry::set_to_purge(t);
  };

  inline bool isChildSafe() {
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
  void updateStats(struct timeval *tv);
  void incLowGoodputFlows(time_t t, bool asClient);
  void decLowGoodputFlows(time_t t, bool asClient);
  inline void incNumAnomalousFlows(bool asClient)   { return(stats->incNumAnomalousFlows(asClient)); };
  inline u_int16_t get_host_pool()         { return(host_pool_id);   };
  inline u_int16_t get_vlan_id()           { return(vlan_id);        };
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

  inline void incSentStats(u_int pkt_len)           { stats->incSentStats(pkt_len);          };
  inline void incRecvStats(u_int pkt_len)           { stats->incRecvStats(pkt_len);          };
  
  virtual int16_t get_local_network_id() const = 0;
  virtual HTTPstats* getHTTPstats()                  { return(NULL);                 };
  inline void set_ipv4(u_int32_t _ipv4)             { ip.set(_ipv4);                 };
  inline void set_ipv6(struct ndpi_in6_addr *_ipv6) { ip.set(_ipv6);                 };
  inline u_int32_t key()                            { return(ip.key());              };
  inline IpAddress* get_ip()                 { return(&ip);              }
  void set_mac(Mac  *m);
  inline bool isBlacklisted()                  { return(blacklisted_host);  };
  void reloadHostBlacklist();
  inline const u_int8_t* const get_mac() const { return(mac ? mac->get_mac() : NULL);}
  inline Mac* getMac() const                   { return(mac);              }
  char * getResolvedName(char * const buf, ssize_t buf_len);
  char * getMDNSName(char * const buf, ssize_t buf_len);
  char * getMDNSTXTName(char * const buf, ssize_t buf_len);
  virtual char * get_os(char * const buf, ssize_t buf_len);
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

  inline u_int64_t getNumBytesSent()           { return(stats->getNumBytesSent());   }
  inline u_int64_t getNumBytesRcvd()           { return(stats->getNumBytesRcvd());   }
  inline u_int64_t getNumDroppedFlows()        { return(stats->getNumDroppedFlows());}
  inline u_int64_t getNumBytes()               { return(stats->getNumBytes());}
  inline float getThptTrendDiff()              { return(stats->getThptTrendDiff());  }
  inline float getBytesThpt()                  { return(stats->getBytesThpt());      }
  inline float getPacketsThpt()                { return(stats->getPacketsThpt());    }
  inline void incNumDroppedFlows()             { stats->incNumDroppedFlows();        }

  inline u_int32_t get_asn()                   { return(asn);              }
  inline char*     get_asname()                { return(asname);           }
  inline AutonomousSystem* get_as()            { return(as);               }
  inline bool isPrivateHost()                  { return(ip.isPrivateAddress()); }
  bool isLocalInterfaceAddress();
  char* get_visual_name(char *buf, u_int buf_len);
  virtual char* get_string_key(char *buf, u_int buf_len) const { return(ip.print(buf, buf_len)); };
  char* get_hostkey(char *buf, u_int buf_len, bool force_vlan=false);
  char* get_tskey(char *buf, size_t bufsize);
  bool idle();
  virtual void incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {};
  virtual void lua(lua_State* vm, AddressTree * ptree, bool host_details,
	   bool verbose, bool returnHost, bool asListElement);
  void resolveHostName();
  void set_host_label(char *label_name, bool ignoreIfPresent);
  inline bool is_label_set() { return(host_label_set); };
  inline int compare(Host *h) { return(ip.compare(&h->ip)); };
  inline bool equal(IpAddress *_ip)  { return(_ip && ip.equal(_ip)); };
  void incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
		custom_app_t custom_app,
		u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
    bool peer_is_unicast);
  inline void checkpoint(lua_State* vm) { if(stats) return stats->checkpoint(vm); };
  void incHitter(Host *peer, u_int64_t sent_bytes, u_int64_t rcvd_bytes);
  virtual void updateHostTrafficPolicy(char *key) {};
  bool addIfMatching(lua_State* vm, AddressTree * ptree, char *key);
  bool addIfMatching(lua_State* vm, u_int8_t *mac);
  void updateSynAlertsCounter(time_t when, u_int8_t flags, Flow *f, bool syn_sent);
  inline void updateRoundTripTime(u_int32_t rtt_msecs) {
    if(as) as->updateRoundTripTime(rtt_msecs);
  }

  void incNumFlows(time_t t, bool as_client, Host *peer);
  void decNumFlows(time_t t, bool as_client, Host *peer);
  inline void incNumUnreachableFlows(bool as_server) { if(stats) stats->incNumUnreachableFlows(as_server); }
  inline void incNumHostUnreachableFlows(bool as_server) { if(stats) stats->incNumHostUnreachableFlows(as_server); };
  inline void incnDPIFlows(u_int16_t l7_protocol)    { if(stats) stats->incnDPIFlows(l7_protocol); }
 
  inline void incFlagStats(bool as_client, u_int8_t flags)  { stats->incFlagStats(as_client, flags); };
  virtual void incNumDNSQueriesSent(u_int16_t query_type) { };
  virtual void incNumDNSQueriesRcvd(u_int16_t query_type) { };
  virtual void incNumDNSResponsesSent(u_int32_t ret_code) { };
  virtual void incNumDNSResponsesRcvd(u_int32_t ret_code) { };
  virtual void luaDNS(lua_State *vm) const { };
  virtual void luaICMP(lua_State *vm, bool isV4, bool verbose) const    { };
  virtual void luaTCP(lua_State *vm) const { };
  virtual u_int16_t getNumActiveContactsAsClient() const  { return 0; };
  virtual u_int16_t getNumActiveContactsAsServer() const  { return 0; };
  virtual void postHashAdd();

  virtual NetworkStats* getNetworkStats(int16_t networkId) { return(NULL);   };
  inline Country* getCountryStats()                        { return country; };

  bool match(const AddressTree * const tree) const { return ip.match(tree); };
  void updateHostPool(bool isInlineCall, bool firstUpdate = false);
  virtual bool dropAllTraffic()  { return(false); };
  bool incFlowAlertHits(time_t when);
  virtual bool setRemoteToRemoteAlerts() { return(false); };
  virtual void incrVisitedWebSite(char *hostname) {};
  inline void incTotalAlerts()            { stats->incTotalAlerts(); }
  inline u_int32_t getTotalAlerts()       { return(stats->getTotalAlerts()); }
  virtual u_int32_t getActiveHTTPHosts()  { return(0); };
  inline u_int32_t getNumOutgoingFlows()  { return(num_active_flows_as_client.get()); }
  inline u_int32_t getNumIncomingFlows()  { return(num_active_flows_as_server.get()); }
  inline u_int32_t getNumActiveFlows()    { return(getNumOutgoingFlows()+getNumIncomingFlows()); }
  inline u_int32_t getTotalNumFlowsAsClient() const { return(stats->getTotalNumFlowsAsClient());  };
  inline u_int32_t getTotalNumFlowsAsServer() const { return(stats->getTotalNumFlowsAsServer());  };
  inline u_int32_t getTotalNumAnomalousOutgoingFlows() const { return stats->getTotalAnomalousNumFlowsAsClient(); };
  inline u_int32_t getTotalNumAnomalousIncomingFlows() const { return stats->getTotalAnomalousNumFlowsAsServer(); };
  inline u_int32_t getTotalNumUnreachableOutgoingFlows() const { return stats->getTotalUnreachableNumFlowsAsClient(); };
  inline u_int32_t getTotalNumUnreachableIncomingFlows() const { return stats->getTotalUnreachableNumFlowsAsServer(); };
  inline u_int32_t getTotalNumHostUnreachableOutgoingFlows() const { return stats->getTotalHostUnreachableNumFlowsAsClient(); };
  inline u_int32_t getTotalNumHostUnreachableIncomingFlows() const { return stats->getTotalHostUnreachableNumFlowsAsServer(); };
  void splitHostVlan(const char *at_sign_str, char *buf, int bufsize, u_int16_t *vlan_id);
  char* get_country(char *buf, u_int buf_len);
  char* get_city(char *buf, u_int buf_len);
  void get_geocoordinates(float *latitude, float *longitude);
  inline u_int16_t getVlanId() { return (vlan ? vlan->get_vlan_id() : 0); }
  inline void reloadHideFromTop() { hidden_from_top = iface->isHiddenFromTop(this); }
  inline void reloadDhcpHost()    { is_dhcp_host = iface->isInDhcpRange(get_ip()); }
  inline bool isHiddenFromTop() { return hidden_from_top; }
  inline bool isOneWayTraffic() { return !(stats->getNumBytesRcvd() > 0 && stats->getNumBytesSent() > 0); };
  virtual void tsLua(lua_State* vm) { lua_pushnil(vm); };
  DeviceProtoStatus getDeviceAllowedProtocolStatus(ndpi_protocol proto, bool as_client);

  virtual void serialize(json_object *obj, DetailsLevel details_level);

  inline void requestStatsReset()                        { stats_reset_requested = true; };
  inline void requestDataReset()                         { data_delete_requested = true; requestStatsReset(); };
  void checkDataReset();
  void checkBroadcastDomain();
  bool hasAnomalies();
  void luaAnomalies(lua_State* vm);
  bool triggerAlerts()                                   { return(trigger_host_alerts);       };
  void refreshHostAlertPrefs();
  void housekeepAlerts(ScriptPeriodicity p);
  inline u_int getNumDropboxPeers()                      { return(dropbox_namespaces.size()); };
  virtual void inlineSetOS(const char * const _os) {};
  void inlineSetSSDPLocation(const char * const url);
  void inlineSetMDNSInfo(char * const s);
  void inlineSetMDNSName(const char * const n);
  void inlineSetMDNSTXTName(const char * const n);
  void setResolvedName(const char * const resolved_name);
  void dissectDropbox(const char *payload, u_int16_t payload_len);
  void dumpDropbox(lua_State *vm);
  inline Fingerprint* getSSLFingerprint() { return(&fingerprints.ssl); }
  virtual void setFlowPort(bool as_server, u_int8_t proto, u_int16_t port, u_int16_t l7_proto) { ; }
  virtual void luaPortsDump(lua_State* vm) { lua_pushnil(vm); }    
};
#endif /* _HOST_H_ */

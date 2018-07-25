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

#ifndef _HOST_H_
#define _HOST_H_

#include "ntop_includes.h"

class Host : public Checkpointable, public GenericHashEntry, public GenericTrafficElement {
 protected:
  IpAddress ip;
  Mac *mac;
  char *symbolic_name;
  char *asname, *info;
  TrafficStats tcp_sent, tcp_rcvd;
  TrafficStats udp_sent, udp_rcvd;
  TrafficStats icmp_sent, icmp_rcvd;
  TrafficStats other_ip_sent, other_ip_rcvd;
  TrafficStats ingress_drops, egress_drops;
  PacketStats sent_stats, recv_stats;
  struct {
    u_int32_t pktRetr, pktOOO, pktLost, pktKeepAlive;
  } tcpPacketStats; /* Sent packets */
  u_int32_t total_num_flows_as_client, total_num_flows_as_server;
  u_int32_t total_activity_time /* sec */;

  virtual json_object* getJSONObject();

 private:
  u_int32_t low_goodput_client_flows, low_goodput_server_flows;
  u_int32_t last_epoch_update; /* useful to avoid multiple updates */

  /* Throughput */
  float goodput_bytes_thpt, last_goodput_bytes_thpt, bytes_goodput_thpt_diff;
  ValueTrend bytes_goodput_thpt_trend;

  u_int32_t asn;
  AutonomousSystem *as;
  Country *country;
  Vlan *vlan;
  bool host_label_set;
  u_int32_t host_quota_mb;

  Mutex *m;
  u_int32_t mac_last_seen;
  u_int8_t num_resolve_attempts;
  time_t nextResolveAttempt;

  u_int32_t num_active_flows_as_client, num_active_flows_as_server;
  bool good_low_flow_detected;

  char *ssdpLocation, *ssdpLocation_shadow;
#ifdef NTOPNG_PRO
  bool has_blocking_quota, has_blocking_shaper;
  HostPoolStats *quota_enforcement_stats, *quota_enforcement_stats_shadow;
  TrafficShaper **host_traffic_shapers;
#endif
  u_int64_t checkpoint_sent_bytes, checkpoint_rcvd_bytes;
  bool checkpoint_set;
  bool hidden_from_top;

  void initialize(Mac *_mac, u_int16_t _vlan_id, bool init_all);
  virtual void refreshHTTPBL() {};
  virtual bool readDHCPCache() { return false; };
#ifdef NTOPNG_PRO
  TrafficShaper *get_shaper(ndpi_protocol ndpiProtocol, bool isIngress);
  void get_quota(u_int16_t protocol, u_int64_t *bytes_quota, u_int32_t *secs_quota, u_int32_t *schedule_bitmap, bool *is_category);
#endif

  char* printMask(char *str, u_int str_len) { return ip.printMask(str, str_len, isLocalHost()); };
 public:
  Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  Host(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip);

  virtual ~Host();

  virtual bool isLocalHost()  = 0;
  virtual bool isSystemHost() = 0;
  inline void setSystemHost()               { /* TODO: remove */ };

  inline nDPIStats* get_ndpi_stats()       { return(ndpiStats);               };

  virtual void set_to_purge() { /* Saves 1 extra-step of purge idle */
    iface->decNumHosts(isLocalHost());
    GenericHashEntry::set_to_purge();
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

  virtual void updateStats(struct timeval *tv);
  void incLowGoodputFlows(bool asClient);
  void decLowGoodputFlows(bool asClient);

  inline void incRetransmittedPkts(u_int32_t num)   { tcpPacketStats.pktRetr += num;      };
  inline void incOOOPkts(u_int32_t num)             { tcpPacketStats.pktOOO += num;       };
  inline void incLostPkts(u_int32_t num)            { tcpPacketStats.pktLost += num;      };
  inline void incKeepAlivePkts(u_int32_t num)       { tcpPacketStats.pktKeepAlive += num; };
  virtual int16_t get_local_network_id() = 0;
  inline PacketStats* get_sent_stats()              { return(&sent_stats);           };
  inline PacketStats* get_recv_stats()              { return(&recv_stats);           };
  virtual HTTPstats* getHTTPstats()                  { return(NULL);                 };
  inline void set_ipv4(u_int32_t _ipv4)             { ip.set(_ipv4);                 };
  inline void set_ipv6(struct ndpi_in6_addr *_ipv6) { ip.set(_ipv6);                 };
  inline u_int32_t key()                            { return(ip.key());              };
  char* getJSON();
  virtual void setOS(char *_os) {};
  inline IpAddress* get_ip()                   { return(&ip);              }
  void set_mac(Mac  *m);
  void set_mac(char *m);
  void set_mac(u_int8_t *m);
  virtual bool isBlacklisted()                 { return(false);                     }
  inline u_int8_t*  get_mac()                  { return(mac ? mac->get_mac() : NULL);      }
  inline Mac* getMac()                         { return(mac);              }
  virtual char* get_traffic_category()         { return((char*)"");        }
  virtual char* get_os()                       { return((char*)"");        }
  inline char* get_name()                      { return(symbolic_name);    }
  inline char* get_httpbl()                    { refreshHTTPBL();     return(get_traffic_category()); }
#ifdef NTOPNG_PRO
  inline TrafficShaper *get_ingress_shaper(ndpi_protocol ndpiProtocol) { return(get_shaper(ndpiProtocol, true)); }
  inline TrafficShaper *get_egress_shaper(ndpi_protocol ndpiProtocol)  { return(get_shaper(ndpiProtocol, false)); }
  bool checkQuota(u_int16_t protocol, bool *is_category, const struct tm *now); /* Per-protocol quota check */
  bool checkCrossApplicationQuota(); /* Overall quota check (e.g., total traffic per host pool) */
  inline void incQuotaEnforcementStats(u_int32_t when, u_int16_t ndpi_proto,
				       ndpi_protocol_category_t category_id, u_int64_t sent_packets, u_int64_t sent_bytes,
				       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    if(quota_enforcement_stats)
      quota_enforcement_stats->incStats(when, ndpi_proto, category_id, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
  };
  inline bool hasBlockedTraffic() { return has_blocking_quota || has_blocking_shaper; };
  inline void resetBlockedTrafficStatus(){ has_blocking_quota = has_blocking_shaper = false; };
  inline void resetQuotaStats() { if(quota_enforcement_stats) quota_enforcement_stats->resetStats(); }
  void luaUsedQuotas(lua_State* vm);
#endif

  inline u_int32_t get_asn()                   { return(asn);              }
  inline char*     get_asname()                { return(asname);           }
  inline bool isPrivateHost()                  { return(ip.isPrivateAddress()); }
  bool isLocalInterfaceAddress();
  char* get_name(char *buf, u_int buf_len, bool force_resolution_if_not_found);
  char* get_visual_name(char *buf, u_int buf_len, bool from_info=false);
  inline char* get_string_key(char *buf, u_int buf_len) { return(ip.print(buf, buf_len)); };
  char* get_hostkey(char *buf, u_int buf_len, bool force_vlan=false);
  bool idle();
  virtual void incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {};
  virtual void lua(lua_State* vm, AddressTree * ptree, bool host_details,
	   bool verbose, bool returnHost, bool asListElement);
  void resolveHostName();
  void setName(char *name);
  void set_host_label(char *label_name, bool ignoreIfPresent);
  inline bool is_label_set() { return(host_label_set); };
  inline int compare(Host *h) { return(ip.compare(&h->ip)); };
  inline bool equal(IpAddress *_ip)  { return(_ip && ip.equal(_ip)); };
  void incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
		u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes);
  void incHitter(Host *peer, u_int64_t sent_bytes, u_int64_t rcvd_bytes);
  virtual void updateHostTrafficPolicy(char *key) {};
  char* serialize();
  virtual void  serialize2redis() {};
  bool addIfMatching(lua_State* vm, AddressTree * ptree, char *key);
  bool addIfMatching(lua_State* vm, u_int8_t *mac);
  virtual void updateSynFlags(time_t when, u_int8_t flags, Flow *f, bool syn_sent) {};
  inline void updateRoundTripTime(u_int32_t rtt_msecs) {
    if(as) as->updateRoundTripTime(rtt_msecs);
  }

  virtual void incNumFlows(bool as_client);
  void decNumFlows(bool as_client);

  inline void incFlagStats(bool as_client, u_int8_t flags)  { if (as_client) sent_stats.incFlagStats(flags); else recv_stats.incFlagStats(flags); };
  inline void incIngressDrops(u_int num_bytes)           { ingress_drops.incStats(num_bytes); };
  inline void incEgressDrops(u_int num_bytes)            { egress_drops.incStats(num_bytes);  };
  virtual void incNumDNSQueriesSent(u_int16_t query_type) { };
  virtual void incNumDNSQueriesRcvd(u_int16_t query_type) { };
  virtual void incNumDNSResponsesSent(u_int32_t ret_code) { };
  virtual void incNumDNSResponsesRcvd(u_int32_t ret_code) { };
  virtual bool triggerAlerts()                            { return(false); };

  virtual u_int32_t getNumAlerts(bool from_alertsmanager = false) { return(0); };
  virtual void setNumAlerts(u_int32_t num) {};
  virtual void postHashAdd();
  virtual void loadAlertsCounter() {};

  virtual NetworkStats* getNetworkStats(int16_t networkId) { return(NULL);   };
  inline Country* getCountryStats()                        { return country; };

  virtual void refreshHostAlertPrefs() {};
  virtual void updateHTTPHostRequest(char *virtual_host_name, u_int32_t num_req, u_int32_t bytes_sent, u_int32_t bytes_rcvd) {};

  bool match(AddressTree *tree) { return(get_ip() ? get_ip()->match(tree) : false); };
  void updateHostPool(bool isInlineCall, bool firstUpdate=false);
  virtual bool dropAllTraffic()  { return(false); };
  virtual bool dumpHostTraffic() { return(false); };
  virtual void setDumpTrafficPolicy(bool new_policy) {};
  bool serializeCheckpoint(json_object *my_object, DetailsLevel details_level);
  void checkPointHostTalker(lua_State *vm, bool saveCheckpoint);
  inline void setInfo(char *s) { if(info) free(info); info = strdup(s); }
  inline char* getInfo(char *buf, uint buf_len) { return get_visual_name(buf, buf_len, true); }
  virtual void incrVisitedWebSite(char *hostname) {};
  virtual u_int32_t getActiveHTTPHosts()  { return(0); };
  inline u_int32_t getNumOutgoingFlows()  { return(num_active_flows_as_client); }
  inline u_int32_t getNumIncomingFlows()  { return(num_active_flows_as_server); }
  inline u_int32_t getNumActiveFlows()    { return(getNumOutgoingFlows()+getNumIncomingFlows()); }
  void splitHostVlan(const char *at_sign_str, char *buf, int bufsize, u_int16_t *vlan_id);
  void setMDSNInfo(char *str);
  char* get_country(char *buf, u_int buf_len);
  char* get_city(char *buf, u_int buf_len);
  void get_geocoordinates(float *latitude, float *longitude);
  inline u_int16_t getVlanId() { return (vlan ? vlan->get_vlan_id() : 0); }
  inline void reloadHideFromTop() { hidden_from_top = iface->isHiddenFromTop(this); }
  inline bool isHiddenFromTop() { return hidden_from_top; }

  inline void setSSDPLocation(char *url) {
     if(url) {
	if(ssdpLocation_shadow) free(ssdpLocation_shadow);
	ssdpLocation_shadow = ssdpLocation;
	ssdpLocation = strdup(url);
     }
  }
};

#endif /* _HOST_H_ */

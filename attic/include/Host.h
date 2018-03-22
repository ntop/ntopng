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

typedef struct {
  const Flow *flow;
  time_t first;
  time_t last;
  u_int16_t pkts;
} InterFlowActivityStats;

class Host : public GenericHost {
 private:
  u_int32_t asn;
  AutonomousSystem *as;
  Vlan *vlan;
  char *symbolic_name, *continent, *country, *city, *asname, os[16], trafficCategory[12], *info;
  FrequentStringItems *top_sites;
  char *old_sites;
  bool blacklisted_host, blacklisted_alarm_emitted, drop_all_host_traffic, dump_host_traffic, dhcpUpdated, host_label_set;
  u_int32_t host_quota_mb;
  int16_t local_network_id;
  u_int32_t num_alerts_detected;
  float latitude, longitude;
  IpAddress ip;
  Mutex *m;
  Mac *mac;
  u_int8_t num_resolve_attempts;
  time_t nextResolveAttempt, nextSitesUpdate;
#ifdef NTOPNG_PRO
  CountMinSketch *sent_to_sketch, *rcvd_from_sketch;
#endif
  AlertCounter *syn_flood_attacker_alert, *syn_flood_victim_alert;
  AlertCounter *flow_flood_attacker_alert, *flow_flood_victim_alert;
  TrafficStats tcp_sent, tcp_rcvd;
  TrafficStats udp_sent, udp_rcvd;
  TrafficStats icmp_sent, icmp_rcvd;
  TrafficStats other_ip_sent, other_ip_rcvd;
  TrafficStats ingress_drops, egress_drops;
  ICMPstats *icmp;
  UserActivityStats *user_activities;
  InterFlowActivityStats *ifa_stats;
  PacketStats sent_stats, recv_stats;
  u_int32_t total_num_flows_as_client, total_num_flows_as_server;
  u_int32_t num_active_flows_as_client, num_active_flows_as_server;
  DnsStats *dns;
  HTTPstats *http;
  bool trigger_host_alerts, good_low_flow_detected;
  u_int32_t attacker_max_num_flows_per_sec, victim_max_num_flows_per_sec;
  u_int32_t attacker_max_num_syn_per_sec, victim_max_num_syn_per_sec;
  NetworkStats *networkStats;
  CategoryStats *categoryStats;

#ifdef NTOPNG_PRO
  L7Policy_t *l7Policy, *l7PolicyShadow;
  bool has_blocking_quota, has_blocking_shaper;
  HostPoolStats *quota_enforcement_stats, *quota_enforcement_stats_shadow;
#endif
  u_int16_t host_pool_id;

  struct {
    u_int32_t pktRetr, pktOOO, pktLost;
  } tcpPacketStats; /* Sent packets */

  void initialize(u_int8_t _mac[6], u_int16_t _vlan_id, bool init_all);
  void refreshHTTPBL();
  void computeHostSerial();
  json_object* getJSONObject();
  bool readDHCPCache();
#ifdef NTOPNG_PRO
  u_int8_t get_shaper_id(ndpi_protocol ndpiProtocol, bool isIngress);
  void get_quota(u_int16_t protocol, u_int64_t *bytes_quota, u_int32_t *secs_quota, bool *is_category);
#endif

 public:
  Host(NetworkInterface *_iface);
  Host(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId);
  Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  Host(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId, IpAddress *_ip);
  ~Host();

  void updateLocal();
  void updateStats(struct timeval *tv);
  void incLowGoodputFlows(bool asClient);
  void decLowGoodputFlows(bool asClient);
  void resetPeriodicStats(void);
  inline void incRetransmittedPkts(u_int32_t num)   { tcpPacketStats.pktRetr += num; };
  inline void incOOOPkts(u_int32_t num)             { tcpPacketStats.pktOOO += num;  };
  inline void incLostPkts(u_int32_t num)            { tcpPacketStats.pktLost += num; };
  inline int16_t get_local_network_id()             { return(local_network_id);      };
  inline PacketStats* get_sent_stats()              { return(&sent_stats);           };
  inline PacketStats* get_recv_stats()              { return(&recv_stats);           };
  inline HTTPstats* getHTTPstats()                  { return(http);                  };
  inline HTTPstats* getHTTP()                       { return(http);                  };
  inline void set_ipv4(u_int32_t _ipv4)             { ip.set(_ipv4);                 };
  inline void set_ipv6(struct ndpi_in6_addr *_ipv6) { ip.set(_ipv6);                 };
  inline u_int32_t key()                            { return(ip.key());              };
  char* getJSON();
  inline void setOS(char *_os)                 { if(os[0] == '\0') snprintf(os, sizeof(os), "%s", _os); }
  inline IpAddress* get_ip()                   { return(&ip);              }
  void set_mac(char *m);
  inline bool isBlacklisted()                  { return(blacklisted_host); }
  inline bool isBlacklistedAlarmEmitted()      { return(blacklisted_alarm_emitted); }
  inline void setBlacklistedAlarmEmitted()     { blacklisted_alarm_emitted = true; }
  bool hasAnomalies();
  inline u_int8_t*  get_mac()                  { return(mac ? mac->get_mac() : NULL);      }
  inline Mac* getMac()                         { return(mac);              }
  inline char* get_os()                        { return(os);               }
  inline char* get_name()                      { return(symbolic_name);    }
  inline char* get_continent()                 { return(continent);        }
  inline char* get_country()                   { return(country);          }
  inline char* get_city()                      { return(city);             }
  inline char* get_httpbl()                    { refreshHTTPBL();     return(trafficCategory); }
#ifdef NTOPNG_PRO
  inline u_int8_t get_ingress_shaper_id(ndpi_protocol ndpiProtocol) { return(get_shaper_id(ndpiProtocol, true)); }
  inline u_int8_t get_egress_shaper_id(ndpi_protocol ndpiProtocol)  { return(get_shaper_id(ndpiProtocol, false)); }
  bool checkQuota(u_int16_t protocol, bool *is_category);
  inline void incQuotaEnforcementStats(u_int32_t when, u_int16_t ndpi_proto,
				       ndpi_protocol_category_t category_id, u_int64_t sent_packets, u_int64_t sent_bytes,
				       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    if(quota_enforcement_stats)
      quota_enforcement_stats->incStats(when, ndpi_proto, category_id, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
  };
  inline void resetBlockedTrafficStatus(){ has_blocking_quota = has_blocking_shaper = false; };
  inline void resetQuotaStats() { if(quota_enforcement_stats) quota_enforcement_stats->resetStats(); }
  void luaUsedQuotas(lua_State* vm);
#endif
  inline u_int16_t get_host_pool()             { return(host_pool_id);     }
  inline u_int32_t get_asn()                   { return(asn);              }
  inline char*     get_asname()                { return(asname);           }
  inline bool isPrivateHost()                  { return(ip.isPrivateAddress()); }
  inline float get_latitude()                  { return(latitude);         }
  inline float get_longitude()                 { return(longitude);        }
  bool isLocalInterfaceAddress();
  char* get_name(char *buf, u_int buf_len, bool force_resolution_if_not_found);
  char* get_visual_name(char *buf, u_int buf_len, bool from_info=false);
  inline char* get_string_key(char *buf, u_int buf_len) { return(ip.print(buf, buf_len)); };
  char* get_hostkey(char *buf, u_int buf_len, bool force_vlan=false);
  bool idle();
  void incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer);
  void lua(lua_State* vm, AddressTree * ptree, bool host_details,
	   bool verbose, bool returnHost, bool asListElement,
	   bool exclude_deserialized_bytes);
  void luaAnomalies(lua_State* vm);
  void resolveHostName();
  void setName(char *name);
  void set_host_label(char *label_name, bool ignoreIfPresent);
  inline bool is_label_set() { return(host_label_set); };
  inline int compare(Host *h) { return(ip.compare(&h->ip)); };
  inline bool equal(u_int8_t *macaddr, IpAddress *_ip)  {
    if(macaddr == NULL)
      return(_ip && ip.equal(_ip));
    else
      return(_ip && mac && mac->equal(vlan_id, macaddr) && ip.equal(_ip));
  };
  void incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
		struct site_categories *category,
		u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes);
  void incHitter(Host *peer, u_int64_t sent_bytes, u_int64_t rcvd_bytes);
  void updateHostTrafficPolicy(char *key);
  char* serialize();
  void  serialize2redis();
  bool  deserialize(char *json_str, char *key);
  bool addIfMatching(lua_State* vm, AddressTree * ptree, char *key);
  void updateSynFlags(time_t when, u_int8_t flags, Flow *f, bool syn_sent);

  void incNumFlows(bool as_client);
  void decNumFlows(bool as_client);

  inline void incFlagStats(bool as_client, u_int8_t flags)  { if (as_client) sent_stats.incFlagStats(flags); else recv_stats.incFlagStats(flags); };
  inline void incIngressDrops(u_int num_bytes)           { ingress_drops.incStats(num_bytes);             };
  inline void incEgressDrops(u_int num_bytes)            { egress_drops.incStats(num_bytes);              };
  inline void incNumDNSQueriesSent(u_int16_t query_type) { if(dns) dns->incNumDNSQueriesSent(query_type); };
  inline void incNumDNSQueriesRcvd(u_int16_t query_type) { if(dns) dns->incNumDNSQueriesRcvd(query_type); };
  inline void incNumDNSResponsesSent(u_int32_t ret_code) { if(dns) dns->incNumDNSResponsesSent(ret_code); };
  inline void incNumDNSResponsesRcvd(u_int32_t ret_code) { if(dns) dns->incNumDNSResponsesRcvd(ret_code); };
  inline bool triggerAlerts()                            { return(trigger_host_alerts);                   };

  u_int32_t   getNumAlerts(bool from_alertsmanager = false);
  inline void setNumAlerts(u_int32_t num) { num_alerts_detected = num; };
  void postHashAdd();
  void loadAlertsCounter();

  inline NetworkStats* getNetworkStats(int16_t networkId){ return(iface->getNetworkStats(networkId));      };

  void refreshHostAlertPrefs();
  void updateHTTPHostRequest(char *virtual_host_name, u_int32_t num_req, u_int32_t bytes_sent, u_int32_t bytes_rcvd);

  bool match(AddressTree *tree) { return(get_ip() ? get_ip()->match(tree) : false); };
  void updateHostL7Policy();
  void updateHostPool();
  inline bool dropAllTraffic()  { return(drop_all_host_traffic); };
  inline bool dumpHostTraffic() { return(dump_host_traffic);     };
  void setDumpTrafficPolicy(bool new_policy);
  void getPeerBytes(lua_State* vm, u_int32_t peer_key);
  inline void incIngressNetworkStats(int16_t networkId, u_int64_t num_bytes) { if(networkStats) networkStats->incIngress(num_bytes); };
  inline void incEgressNetworkStats(int16_t networkId, u_int64_t num_bytes)  { if(networkStats) networkStats->incEgress(num_bytes);  };
  inline void incInnerNetworkStats(int16_t networkId, u_int64_t num_bytes)   { if(networkStats) networkStats->incInner(num_bytes);   };
  inline void setInfo(char *s) { if(info) free(info); info = strdup(s); }
  inline char* getInfo(char *buf, uint buf_len) { return get_visual_name(buf, buf_len, true); }
  void incrVisitedWebSite(char *hostname);
  const UserActivityCounter * getActivityBytes(UserActivityID id);
  void incActivityBytes(UserActivityID id, u_int64_t upbytes, u_int64_t downbytes, u_int64_t bgbytes);
  void incIfaPackets(InterFlowActivityProtos proto, const Flow * flow, time_t when);
  void getIfaStats(InterFlowActivityProtos proto, time_t when, int * count, u_int32_t * packets, time_t * max_diff);
  inline UserActivityStats* get_user_activities() { return(user_activities); }
  inline u_int32_t getNumOutgoingFlows()  { return(num_active_flows_as_client); }
  inline u_int32_t getNumIncomingFlows()  { return(num_active_flows_as_server); }
  inline u_int32_t getNumActiveFlows()    { return(getNumOutgoingFlows()+getNumIncomingFlows()); }
  void splitHostVlan(const char *at_sign_str, char *buf, int bufsize, u_int16_t *vlan_id);
  void setMDSNInfo(char *str);
  bool IsAllowedTrafficCategory(struct site_categories *category);
  inline bool isChildSafe() {
#ifdef NTOPNG_PRO
    return(iface->getHostPools()->isChildrenSafePool(host_pool_id));
#else
    return(false);
#endif
  }
};

#endif /* _HOST_H_ */

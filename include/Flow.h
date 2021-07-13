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

#ifndef _FLOW_H_
#define _FLOW_H_

#include "ntop_includes.h"

typedef struct {
  u_int32_t pktFrag;
} IPPacketStats;

typedef struct {
  u_int64_t last, next;
} TCPSeqNum;

class FlowAlert;
class FlowCheck;

class Flow : public GenericHashEntry {
 private:
  Host *cli_host, *srv_host;
  IpAddress *cli_ip_addr, *srv_ip_addr;
  ICMPinfo *icmp_info;
  u_int32_t flowCreationTime;
  u_int8_t cli2srv_tos, srv2cli_tos; /* RFC 2474, 3168 */
  u_int16_t cli_port, srv_port;
  VLANid vlanId;
  u_int32_t vrfId;
  u_int32_t srcAS, dstAS, prevAdjacentAS, nextAdjacentAS;
  u_int8_t protocol, src2dst_tcp_flags, dst2src_tcp_flags;
  u_int8_t src2dst_tcp_zero_window:1, dst2src_tcp_zero_window:1, _pad:6;
  u_int16_t flow_score;
  struct ndpi_flow_struct *ndpiFlow;
  ndpi_risk ndpi_flow_risk_bitmap;
  /* The bitmap of all possible flow alerts set by FlowCheck subclasses. When no alert is set, the 
     flow is in flow_alert_normal.

     A flow can have multiple alerts but at most ONE of its alerts is predominant
     of a flow, which is written into `predominant_alert`.
  */
  Bitmap128 alerts_map;
  FlowAlertType predominant_alert;          /* This is the predominant alert */
  u_int16_t  predominant_alert_score;       /* The score associated to the predominant alert */

  char *custom_flow_info;
  struct {
    struct ndpi_analyze_struct *c2s, *s2c;
  } entropy;
  u_int hash_entry_id; /* Uniquely identify this Flow inside the flows_hash hash table */

  bool detection_completed, extra_dissection_completed,
    twh_over, twh_ok, dissect_next_http_packet, passVerdict,
    l7_protocol_guessed, flow_dropped_counts_increased,
    good_tls_hs,
    quota_exceeded, has_malicious_cli_signature, has_malicious_srv_signature,
    swap_done, swap_requested;
  
#ifdef ALERTED_FLOWS_DEBUG
  bool iface_alert_inc, iface_alert_dec;
#endif
#ifdef NTOPNG_PRO
  bool ingress2egress_direction;
  u_int8_t routing_table_id;
  bool lateral_movement, periodicity_changed;
#ifndef HAVE_NEDGE
  FlowProfile *trafficProfile;
#else
  u_int16_t cli2srv_in, cli2srv_out, srv2cli_in, srv2cli_out;
  L7PolicySource_t cli_quota_source, srv_quota_source;
#endif
  CounterTrend throughputTrend, goodputTrend, thptRatioTrend;
#endif
  ndpi_protocol ndpiDetectedProtocol;
  custom_app_t custom_app;
  void *cli_id, *srv_id;
  json_object *json_info;
  ndpi_serializer *tlv_info;
  char *host_server_name, *bt_hash;
  IEC104Stats *iec104;
  char *suspicious_dga_domain; /* Stores the suspicious DGA domain for flows with NDPI_SUSPICIOUS_DGA_DOMAIN */
  OSType operating_system;
#ifdef HAVE_NEDGE
  u_int32_t last_conntrack_update; 
  u_int32_t marker;
#endif
  struct {
    char *source;
    json_object *json;
  } external_alert;
  bool trigger_immediate_periodic_update; /* needed to process external alerts */
  time_t next_call_periodic_update; /* The time at which the periodic lua script on this flow shall be called */
  u_int32_t periodic_update_ctr;

  union {
    struct {
      char *last_url;
      ndpi_http_method last_method;
      char *last_content_type;
      u_int16_t last_return_code;
    } http;

    struct {
      char *last_query;
      char *last_query_shadow;
      time_t last_query_update_time; /* The time when the last query was updated */
      u_int16_t last_query_type;
      u_int16_t last_return_code;
      bool invalid_chars_in_query;
    } dns;

    struct {
      char *name, *name_txt, *ssid;
      char *answer;
    } mdns;

    struct {
      char *location;
    } ssdp;

    struct {
      char *name;
    } netbios;

    struct {
      char *client_signature, *server_signature;
      struct {
	/* https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c */
	char *client_hash, *server_hash;
      } hassh;
    } ssh;

    struct {
      u_int16_t tls_version;
      u_int32_t notBefore, notAfter;
      char *client_alpn, *client_tls_supported_versions, *issuerDN, *subjectDN;
      char *client_requested_server_name, *server_names;
      /* Certificate dissection */
      struct {
	/* https://engineering.salesforce.com/tls-fingerprinting-with-ja3-and-ja3s-247362855967 */
	char *client_hash, *server_hash;
	u_int16_t server_cipher;
	ndpi_cipher_weakness server_unsafe_cipher;
      } ja3;
    } tls;

    struct {
      struct {
	u_int8_t icmp_type, icmp_code;
      } cli2srv, srv2cli;
      u_int16_t max_icmp_payload_size;
    } icmp;
  } protos;

  struct {
    u_int32_t device_ip;
    u_int32_t in_index, out_index;
    u_int16_t observation_point_id;
  } flow_device;

  /* eBPF Information */
  ParsedeBPF *cli_ebpf, *srv_ebpf;

  /* Stats */
  FlowTrafficStats stats;

  /* IP stats */
  IPPacketStats ip_stats_s2d, ip_stats_d2s;

  /* TCP stats */
  TCPSeqNum tcp_seq_s2d, tcp_seq_d2s;
  u_int16_t cli2srv_window, srv2cli_window;

  time_t doNotExpireBefore; /*
			      Used for collected flows via ZMQ to make sure that they are not immediately
			      expired if their last seen time is back in time with respect to ntopng
			    */
  struct timeval synTime, synAckTime, ackTime; /* network Latency (3-way handshake) */
  struct timeval clientNwLatency; /* The RTT/2 between the client and nprobe */
  struct timeval serverNwLatency; /* The RTT/2 between nprobe and the server */
  struct timeval c2sFirstGoodputTime;
  float rttSec, applLatencyMsec;

  InterarrivalStats *cli2srvPktTime, *srv2cliPktTime;
  
  /* Counter values at last host update */
  struct {
    PartializableFlowTrafficStats *partial;
    PartializableFlowTrafficStats delta;
    time_t first_seen, last_seen;
  } last_db_dump;

  /* Lazily initialized and used by a possible view interface */
  ViewInterfaceFlowStats *viewFlowStats;

  /* Partial used to periodically update stats out of flows */
  PartializableFlowTrafficStats *periodic_stats_update_partial;

#ifdef HAVE_NEDGE
  struct {
    struct {
      TrafficShaper *ingress, *egress;
    } cli2srv;

    struct {
      TrafficShaper *ingress, *egress;
    } srv2cli;
  } flowShaperIds;
#endif
  struct timeval last_update_time;

  float top_bytes_thpt, top_goodput_bytes_thpt, top_pkts_thpt;
  float bytes_thpt_cli2srv, goodput_bytes_thpt_cli2srv;
  float bytes_thpt_srv2cli, goodput_bytes_thpt_srv2cli;
  float pkts_thpt_cli2srv, pkts_thpt_srv2cli;
  ValueTrend bytes_thpt_trend, goodput_bytes_thpt_trend, pkts_thpt_trend;
  char* intoaV4(unsigned int addr, char* buf, u_short bufLen);
  void allocDPIMemory();
  bool checkTor(char *hostname);
  void setBittorrentHash(char *hash);
  void updateThroughputStats(float tdiff_msec,
			     u_int32_t diff_sent_packets, u_int64_t diff_sent_bytes, u_int64_t diff_sent_goodput_bytes,
			     u_int32_t diff_rcvd_packets, u_int64_t diff_rcvd_bytes, u_int64_t diff_rcvd_goodput_bytes);
  static void updatePacketStats(InterarrivalStats *stats, const struct timeval *when, bool update_iat);
  bool isReadyToBeMarkedAsIdle();
  char * printTCPState(char * const buf, u_int buf_len) const;
  void update_pools_stats(NetworkInterface *iface,
			  Host *cli_host, Host *srv_host,
			  const struct timeval *tv,
			  u_int64_t diff_sent_packets, u_int64_t diff_sent_bytes,
			  u_int64_t diff_rcvd_packets, u_int64_t diff_rcvd_bytes) const;
  /*
    Check (and possibly enqueues) the flow for dump
   */
  void dumpCheck(time_t t, bool last_dump_before_free);
  void updateCliJA3();
  void updateSrvJA3();
  void updateHASSH(bool as_client);
  void processExtraDissectedInformation();
  void processDetectedProtocol();      /* nDPI detected protocol */
  void processDetectedProtocolData();  /* nDPI detected protocol data (e.g., ndpiFlow->host_server_name) */
  void setExtraDissectionCompleted();
  void setProtocolDetectionCompleted();
  void updateProtocol(ndpi_protocol proto_id);
  const char* cipher_weakness2str(ndpi_cipher_weakness w) const;
  bool get_partial_traffic_stats(PartializableFlowTrafficStats **dst, PartializableFlowTrafficStats *delta, bool *first_partial) const;
  void lua_tos(lua_State* vm);

  void updateEntropy(struct ndpi_analyze_struct *e, u_int8_t *payload, u_int payload_len);
  void lua_entropy(lua_State* vm);
  void luaScore(lua_State* vm);
  void luaIEC104(lua_State* vm);
  void callFlowUpdate(time_t t);
  /*
    Method to trigger alerts, synchronous or asynchronous, depending on the last argument.
    - Asynchronous: The alerts bitmap is updated and the predominant alert is possibly updated.
                    Recipients enqueue is not performed.
    - Synchronous:  The alerts bitmap is updated and the predominant alert is possibly updated.
                    Immediate alert JSON generation and enqueue to the recipients are performed as well.
   */
  bool setAlertsBitmap(FlowAlertType alert_type, u_int16_t cli_inc, u_int16_t srv_inc, bool async);
  void setNormalToAlertedCounters();
  /* Decreases scores on both client and server hosts when the flow is being destructed */
  void decAllFlowScores();

 public:
  Flow(NetworkInterface *_iface,
       VLANid _vlanId, u_int16_t _observation_point_id,
       u_int8_t _protocol,
       Mac *_cli_mac, IpAddress *_cli_ip, u_int16_t _cli_port,
       Mac *_srv_mac, IpAddress *_srv_ip, u_int16_t _srv_port,
       const ICMPinfo * const icmp_info,
       time_t _first_seen, time_t _last_seen);
  ~Flow();

  inline Bitmap128 getAlertsBitmap() const { return(alerts_map); }

  /* Enqueues an alert to all available flow recipients. */
  bool enqueueAlertToRecipients(FlowAlert *alert);

  /*
    Called by FlowCheck subclasses to trigger a flow alert. This is an asynchronous call, faster, but can
    cause the alert JSON to be generated after the call.
    The FlowCheck should implement the buildAlert() method which is called in the predominant check to actually build the FlowAlert object.
   */
  bool triggerAlertAsync(FlowAlertType alert_type, u_int16_t cli_score_inc, u_int16_t srv_score_inc);

  /* 
     Called by FlowCheck subclasses to trigger a flow alert. This is a syncrhonous call, more expensive, but
     causes the alert (FlowAlert) to be immediately enqueued to all recipients.
   */
  bool triggerAlertSync(FlowAlert *alert, u_int16_t cli_score_inc, u_int16_t srv_score_inc);

  /*
    Enqueues the predominant alert of the flow to all available flow recipients.
   */
  void enqueuePredominantAlert();

  inline void setPredominantAlert(FlowAlertType alert_type, u_int16_t score);
  inline FlowAlertType getPredominantAlert() const { return predominant_alert; };
  inline u_int16_t getPredominantAlertScore() const { return predominant_alert_score; };
  inline AlertLevel getPredominantAlertSeverity() const { return Utils::mapScoreToSeverity(predominant_alert_score); };
  inline bool isFlowAlerted()    const { return(predominant_alert.id != flow_alert_normal); };
 
  inline char* getJa3CliHash() { return(protos.tls.ja3.client_hash); }
  
  bool isBlacklistedFlow()   const;
  bool isBlacklistedClient() const;
  bool isBlacklistedServer() const;
  struct site_categories* getFlowCategory(bool force_categorization);
  void freeDPIMemory();
  static const ndpi_protocol ndpiUnknownProtocol;
  bool isTiny() const;
  inline bool isProto(u_int16_t p) const { return(((ndpiDetectedProtocol.master_protocol == p)
						   || (ndpiDetectedProtocol.app_protocol == p))
						  ? true : false); }
  bool isTLSProto() const; 
  inline bool isTLS()  const { return(isProto(NDPI_PROTOCOL_TLS));  }
  inline bool isSSH()  const { return(isProto(NDPI_PROTOCOL_SSH));  }
  inline bool isDNS()  const { return(isProto(NDPI_PROTOCOL_DNS));  }
  inline bool isIEC60870()  const { return(isProto(NDPI_PROTOCOL_IEC60870));  }
  inline bool isMDNS() const { return(isProto(NDPI_PROTOCOL_MDNS)); }
  inline bool isSSDP() const { return(isProto(NDPI_PROTOCOL_SSDP)); }
  inline bool isNetBIOS() const { return(isProto(NDPI_PROTOCOL_NETBIOS)); }
  inline bool isDHCP() const { return(isProto(NDPI_PROTOCOL_DHCP)); }
  inline bool isNTP() const  { return(isProto(NDPI_PROTOCOL_NTP));  }
  inline bool isSMTP() const { return(isProto(NDPI_PROTOCOL_MAIL_SMTP) || isProto(NDPI_PROTOCOL_MAIL_SMTPS));  }
  inline bool isHTTP() const { return(isProto(NDPI_PROTOCOL_HTTP)); }
  inline bool isICMP() const { return(isProto(NDPI_PROTOCOL_IP_ICMP) || isProto(NDPI_PROTOCOL_IP_ICMPV6)); }

#ifdef NTOPNG_PRO
  inline bool isLateralMovement() const { return(lateral_movement);  }
  inline void setLateralMovement(bool change) { lateral_movement = change;  }
  inline bool isPeriodicityChanged() const { return(periodicity_changed);  }
  inline void setPeriodicityChanged(bool change) { periodicity_changed = change;  }
#endif

  inline bool isCliDeviceAllowedProtocol() const {
    return !cli_host || cli_host->getDeviceAllowedProtocolStatus(get_detected_protocol(), true) == device_proto_allowed;
  }		      
  inline bool isSrvDeviceAllowedProtocol() const {
    return !srv_host || srv_host->getDeviceAllowedProtocolStatus(get_detected_protocol(), false) == device_proto_allowed;
  }
  inline bool isDeviceAllowedProtocol() const {
    return isCliDeviceAllowedProtocol() && isSrvDeviceAllowedProtocol();
  }
  inline u_int16_t getCliDeviceDisallowedProtocol() const {
    DeviceProtoStatus cli_ps = cli_host->getDeviceAllowedProtocolStatus(get_detected_protocol(), true);
    return (cli_ps == device_proto_forbidden_app) ? ndpiDetectedProtocol.app_protocol : ndpiDetectedProtocol.master_protocol;
  }
  inline u_int16_t getSrvDeviceDisallowedProtocol() const {
    DeviceProtoStatus srv_ps = srv_host->getDeviceAllowedProtocolStatus(get_detected_protocol(), false);
    return (srv_ps == device_proto_forbidden_app) ? ndpiDetectedProtocol.app_protocol : ndpiDetectedProtocol.master_protocol;
  }
  inline bool isMaskedFlow() const {
    int16_t network_id;
    return(Utils::maskHost(get_cli_ip_addr()->isLocalHost(&network_id))
	   || Utils::maskHost(get_srv_ip_addr()->isLocalHost(&network_id)));
  };
  inline const char* getServerCipherClass()  const { return(isTLS() ? cipher_weakness2str(protos.tls.ja3.server_unsafe_cipher) : NULL); }
  char* serialize(bool use_labels = false);
  /* Prepares an alert JSON and puts int in the resulting `serializer`. */
  void alert2JSON(FlowAlert *alert, ndpi_serializer *serializer);
  json_object* flow2JSON();
  json_object* flow2es(json_object *flow_object);

  inline void updateJA3C(char *j) { if(j && (j[0] != '\0') && (protos.tls.ja3.client_hash == NULL)) protos.tls.ja3.client_hash = strdup(j); updateCliJA3(); }
  inline void updateJA3S(char *j) { if(j && (j[0] != '\0') && (protos.tls.ja3.server_hash == NULL)) protos.tls.ja3.server_hash = strdup(j); updateSrvJA3(); }
  
  inline u_int8_t getTcpFlags()        const { return(src2dst_tcp_flags | dst2src_tcp_flags);  };
  inline u_int8_t getTcpFlagsCli2Srv() const { return(src2dst_tcp_flags);                      };
  inline u_int8_t getTcpFlagsSrv2Cli() const { return(dst2src_tcp_flags);                      };
#ifdef HAVE_NEDGE
  bool checkPassVerdict(const struct tm *now);
  bool isPassVerdict() const;
  inline void setConntrackMarker(u_int32_t marker) 	{ this->marker = marker; }
  inline u_int32_t getConntrackMarker() 		{ return(marker); }
  void incFlowDroppedCounters();
#endif
  void setDropVerdict();
  u_int32_t getPid(bool client);
  u_int32_t getFatherPid(bool client);
  u_int32_t get_uid(bool client) const;
  char* get_proc_name(bool client);
  char* get_user_name(bool client);
  u_int32_t getNextTcpSeq(u_int8_t tcpFlags, u_int32_t tcpSeqNum, u_int32_t payloadLen) ;
  static double toMs(const struct timeval *t);
  void timeval_diff(struct timeval *begin, const struct timeval *end, struct timeval *result, u_short divide_by_two);
  char* getFlowInfo(char *buf, u_int buf_len);
  inline char* getFlowServerInfo() {
    return (isTLS() && protos.tls.client_requested_server_name) ? protos.tls.client_requested_server_name : host_server_name;
  }
  inline char* getBitTorrentHash() { return(bt_hash);          };
  inline void  setBTHash(char *h)  { if(!h) return; if(bt_hash) free(bt_hash); bt_hash = h; }
  inline void  setServerName(char *v)  { if(host_server_name) free(host_server_name);  host_server_name = v; }
  void updateTcpFlags(const struct bpf_timeval *when,
		      u_int8_t flags, bool src2dst_direction);
  void updateTcpWindow(u_int16_t window, bool src2dst_direction);
  void updateTcpSeqIssues(const ParsedFlow *pf);
  void updateDNS(ParsedFlow *zflow);
  void updateHTTP(ParsedFlow *zflow);
  void updateSuspiciousDGADomain();
  static void incTcpBadStats(bool src2dst_direction,
			     Host *cli, Host *srv,
			     NetworkInterface *iface,
			     u_int32_t ooo_pkts, u_int32_t retr_pkts,
			     u_int32_t lost_pkts, u_int32_t keep_alive_pkts);
  
  void updateTcpSeqNum(const struct bpf_timeval *when,
		       u_int32_t seq_num, u_int32_t ack_seq_num,
		       u_int16_t window, u_int8_t flags,
		       u_int16_t payload_len, bool src2dst_direction);

  void updateSeqNum(time_t when, u_int32_t sN, u_int32_t aN);
  void setDetectedProtocol(ndpi_protocol proto_id);
  void processPacket(const u_char *ip_packet, u_int16_t ip_len, u_int64_t packet_time,
		     u_int8_t *payload, u_int16_t payload_len);
  void processDNSPacket(const u_char *ip_packet, u_int16_t ip_len, u_int64_t packet_time);
  void processIEC60870Packet(bool src2dst_direction, const u_char *ip_packet, u_int16_t ip_len,
			     const u_char *payload, u_int16_t payload_len,
			     struct timeval *packet_time);
  
  void endProtocolDissection();
  inline void setCustomApp(custom_app_t ca) {
    memcpy(&custom_app, &ca, sizeof(custom_app));
  };
  inline custom_app_t getCustomApp() const {
    return custom_app;
  };
  u_int16_t getStatsProtocol() const;
  void setJSONInfo(json_object *json);
  void setTLVInfo(ndpi_serializer *tlv);
  void incStats(bool cli2srv_direction, u_int pkt_len,
		u_int8_t *payload, u_int payload_len, 
                u_int8_t l4_proto, u_int8_t is_fragment,
		u_int16_t tcp_flags, const struct timeval *when,
		u_int16_t fragment_extra_overhead);
  void addFlowStats(bool new_flow,
		    bool cli2srv_direction, u_int in_pkts, u_int in_bytes, u_int in_goodput_bytes,
		    u_int out_pkts, u_int out_bytes, u_int out_goodput_bytes, 
		    u_int in_fragments, u_int out_fragments,
		    time_t first_seen, time_t last_seen);
  bool check_swap(u_int32_t tcp_flags);

  inline bool isThreeWayHandshakeOK()    const { return(twh_ok);                          };
  inline bool isDetectionCompleted()     const { return(detection_completed);             };
  inline bool isOneWay()                 const { return(get_packets() && (!get_packets_cli2srv() || !get_packets_srv2cli())); };
  inline bool isBidirectional()          const { return(get_packets_cli2srv() && get_packets_srv2cli()); };
  inline bool isRemoteToRemote()         const { return (cli_host && srv_host && !cli_host->isLocalHost() && !srv_host->isLocalHost()); };
  inline bool isLocalToRemote() const {
    int16_t network_id;
    return get_cli_ip_addr()->isLocalHost(&network_id) && !get_srv_ip_addr()->isLocalHost(&network_id);
  };
  inline bool isRemoteToLocal() const {
    int16_t network_id;
    return !get_cli_ip_addr()->isLocalHost(&network_id) && get_srv_ip_addr()->isLocalHost(&network_id);
  };
  inline bool isUnicast()                const { return (cli_ip_addr && srv_ip_addr && !cli_ip_addr->isBroadMulticastAddress() && !srv_ip_addr->isBroadMulticastAddress()); };
  inline void* get_cli_id()              const { return(cli_id);                          };
  inline void* get_srv_id()              const { return(srv_id);                          };
  inline u_int32_t get_cli_ipv4()        const { return(cli_host->get_ip()->get_ipv4());  };
  inline u_int32_t get_srv_ipv4()        const { return(srv_host->get_ip()->get_ipv4());  };
  inline ndpi_protocol get_detected_protocol() const { return(isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol);          };
  inline struct ndpi_flow_struct* get_ndpi_flow()   const { return(ndpiFlow);                        };
  inline const struct ndpi_in6_addr* get_cli_ipv6() const { return(cli_host->get_ip()->get_ipv6());  };
  inline const struct ndpi_in6_addr* get_srv_ipv6() const { return(srv_host->get_ip()->get_ipv6());  };
  inline u_int16_t get_cli_port()        const { return(ntohs(cli_port));                 };
  inline u_int16_t get_srv_port()        const { return(ntohs(srv_port));                 };
  inline VLANid    get_vlan_id()              const { return(filterVLANid(vlanId));                        };
  inline u_int8_t  get_protocol()        const { return(protocol);                        };
  inline u_int64_t get_bytes()           const { return(stats.get_cli2srv_bytes() + stats.get_srv2cli_bytes() );                };
  inline u_int64_t get_bytes_cli2srv()   const { return(stats.get_cli2srv_bytes());                                             };
  inline u_int64_t get_bytes_srv2cli()   const { return(stats.get_srv2cli_bytes());                                             };
  inline u_int64_t get_goodput_bytes()   const { return(stats.get_cli2srv_goodput_bytes() + stats.get_srv2cli_goodput_bytes()); };
  inline u_int64_t get_goodput_bytes_cli2srv() const { return(stats.get_cli2srv_goodput_bytes()); };
  inline u_int64_t get_goodput_bytes_srv2cli() const { return(stats.get_srv2cli_goodput_bytes()); };
  inline u_int64_t get_packets()         const { return(stats.get_cli2srv_packets() + stats.get_srv2cli_packets());             };
  inline u_int32_t get_packets_cli2srv() const { return(stats.get_cli2srv_packets());                                           };
  inline u_int32_t get_packets_srv2cli() const { return(stats.get_srv2cli_packets());                                           };
  inline u_int64_t get_partial_bytes()           const { return get_partial_bytes_cli2srv() + get_partial_bytes_srv2cli();      };
  inline u_int64_t get_partial_packets()         const { return get_partial_packets_cli2srv() + get_partial_packets_srv2cli();  };
  inline u_int64_t get_partial_goodput_bytes()   const { return last_db_dump.delta.get_cli2srv_goodput_bytes() + last_db_dump.delta.get_srv2cli_goodput_bytes();       };
  inline u_int64_t get_partial_bytes_cli2srv()   const { return last_db_dump.delta.get_cli2srv_bytes();   };
  inline u_int64_t get_partial_bytes_srv2cli()   const { return last_db_dump.delta.get_srv2cli_bytes();   };
  inline u_int64_t get_partial_packets_cli2srv() const { return last_db_dump.delta.get_cli2srv_packets(); };
  inline u_int64_t get_partial_packets_srv2cli() const { return last_db_dump.delta.get_srv2cli_packets(); };
  bool needsExtraDissection();
  bool hasDissectedTooManyPackets();
  bool get_partial_traffic_stats_view(PartializableFlowTrafficStats *delta, bool *first_partial);
  bool update_partial_traffic_stats_db_dump();
  inline float get_pkts_thpt()           const { return(pkts_thpt_cli2srv + pkts_thpt_srv2cli);                   };
  inline float get_bytes_thpt()          const { return(bytes_thpt_cli2srv + bytes_thpt_srv2cli);                 };
  inline float get_goodput_bytes_thpt()  const { return(goodput_bytes_thpt_cli2srv + goodput_bytes_thpt_srv2cli); };
  inline float get_goodput_ratio()       const { return((float)(100*get_goodput_bytes()) / ((float)get_bytes() + 1)); };
  inline time_t get_partial_first_seen() const { return(last_db_dump.first_seen); };
  inline time_t get_partial_last_seen()  const { return(last_db_dump.last_seen);  };
  inline u_int32_t get_duration()        const { return((u_int32_t)(get_last_seen() - get_first_seen())); };
  inline char* get_protocol_name()       const { return(Utils::l4proto2name(protocol));   };

  inline Host* get_cli_host()               const { return(cli_host);    };
  inline Host* get_srv_host()               const { return(srv_host);    };
  inline const IpAddress* get_cli_ip_addr() const { return(cli_ip_addr); };
  inline const IpAddress* get_srv_ip_addr() const { return(srv_ip_addr); };
  inline const IpAddress* get_dns_srv_ip_addr() const { return((get_cli_port() == 53) ? get_cli_ip_addr() : get_srv_ip_addr()); };
  inline const IpAddress* get_dhcp_srv_ip_addr() const { return((get_cli_port() == 67) ? get_cli_ip_addr() : get_srv_ip_addr()); };

  inline json_object* get_json_info()	    const  { return(json_info);                       };
  inline ndpi_serializer* get_tlv_info()	    const  { return(tlv_info);                       };
  inline void setICMPPayloadSize(u_int16_t size)     { if(isICMP()) protos.icmp.max_icmp_payload_size = max(protos.icmp.max_icmp_payload_size, size); };
  inline u_int16_t getICMPPayloadSize()             const { return(isICMP() ? protos.icmp.max_icmp_payload_size : 0); };
  inline ICMPinfo* getICMPInfo()                    const { return(isICMP() ? icmp_info : NULL); }
  inline ndpi_protocol_breed_t get_protocol_breed() const {
    return(ndpi_get_proto_breed(iface->get_ndpi_struct(), isDetectionCompleted() ? ndpi_get_upper_proto(ndpiDetectedProtocol) : NDPI_PROTOCOL_UNKNOWN));
  };
  inline const char * const get_protocol_breed_name() const { return(ndpi_get_proto_breed_name(iface->get_ndpi_struct(), get_protocol_breed())); };
  inline ndpi_protocol_category_t get_protocol_category() const {
    return(ndpi_get_proto_category(iface->get_ndpi_struct(),
				   isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol));
};
  inline const char * const get_protocol_category_name() const {
    return(ndpi_category_get_name(iface->get_ndpi_struct(), get_protocol_category()));
  };
  char* get_detected_protocol_name(char *buf, u_int buf_len) const {
    return(iface->get_ndpi_full_proto_name(isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol, buf, buf_len));
  }
  static inline ndpi_protocol get_ndpi_unknown_protocol() { return ndpiUnknownProtocol; };

  /* NOTE: the caller must ensure that the hosts returned by these methods are not used
   * concurrently by subinterfaces since hosts are shared between all the subinterfaces of the same
   * ViewInterface. */
  inline Host* getViewSharedClient() { return(viewFlowStats ? viewFlowStats->getViewSharedClient() : get_cli_host()); };
  inline Host* getViewSharedServer() { return(viewFlowStats ? viewFlowStats->getViewSharedServer() : get_srv_host()); };

  u_int32_t get_packetsLost();
  u_int32_t get_packetsRetr();
  u_int32_t get_packetsOOO();

  inline const struct timeval *get_current_update_time() const {return &last_update_time; } ;
  u_int64_t get_current_bytes_cli2srv() const;
  u_int64_t get_current_bytes_srv2cli() const;
  u_int64_t get_current_goodput_bytes_cli2srv() const;
  u_int64_t get_current_goodput_bytes_srv2cli() const;
  u_int64_t get_current_packets_cli2srv() const;
  u_int64_t get_current_packets_srv2cli() const;

  inline bool is_swap_requested()  const { return swap_requested;  };
  inline bool is_swap_done()       const { return swap_done;       };
  inline void set_swap_done()            { swap_done = true;       };
  /*
    Returns actual client and server, that is the client and server as determined after
    the swap heuristic that has taken place.
   */
  inline void get_actual_peers(Host **actual_client, Host **actual_server) const {
    if(is_swap_requested())
      *actual_client = get_srv_host(), *actual_server = get_cli_host();
    else
      *actual_client = get_cli_host(), *actual_server = get_srv_host();
  };
  bool is_hash_entry_state_idle_transition_ready();
  void hosts_periodic_stats_update(NetworkInterface *iface, Host *cli_host, Host *srv_host, PartializableFlowTrafficStats *partial,
				   bool first_partial, const struct timeval *tv) const;
  void periodic_stats_update(const struct timeval *tv);
  void  set_hash_entry_id(u_int assigned_hash_entry_id);
  u_int get_hash_entry_id() const;

  static char* printTCPflags(u_int8_t flags, char * const buf, u_int buf_len);
  char* print(char *buf, u_int buf_len) const;
    
  u_int32_t key();
  static u_int32_t key(Host *cli, u_int16_t cli_port,
		       Host *srv, u_int16_t srv_port,
		       VLANid vlan_id,
		       u_int16_t _observation_point_id,
		       u_int16_t protocol);
  void lua(lua_State* vm, AddressTree * ptree,
	   DetailsLevel details_level, bool asListElement);
  void lua_get_min_info(lua_State* vm);
  void lua_duration_info(lua_State* vm);
  void lua_snmp_info(lua_State* vm);
  void lua_device_protocol_allowed_info(lua_State *vm);
  void lua_get_tcp_stats(lua_State *vm) const;

  void lua_get_unicast_info(lua_State* vm) const;
  void lua_get_status(lua_State* vm) const;
  void lua_get_protocols(lua_State* vm) const;
  void lua_get_bytes(lua_State* vm) const;
  void lua_get_dir_traffic(lua_State* vm, bool cli2srv) const;
  void lua_get_dir_iat(lua_State* vm, bool cli2srv) const;
  void lua_get_packets(lua_State* vm) const;
  void lua_get_throughput(lua_State* vm) const;
  void lua_get_time(lua_State* vm) const;
  void lua_get_ip(lua_State *vm, bool client) const;
  void lua_get_mac(lua_State *vm, bool client) const;
  void lua_get_info(lua_State *vm, bool client) const;
  void lua_get_tls_info(lua_State *vm) const;
  void lua_get_ssh_info(lua_State *vm) const;
  void lua_get_http_info(lua_State *vm) const;
  void lua_get_dns_info(lua_State *vm) const;
  void lua_get_tcp_info(lua_State *vm) const;
  void lua_get_port(lua_State *vm, bool client) const;
  void lua_get_geoloc(lua_State *vm, bool client, bool coords, bool country_city) const;
  void lua_get_risk_info(lua_State* vm);
  
  void getInfo(ndpi_serializer *serializer);
  void getHTTPInfo(ndpi_serializer *serializer) const;
  void getTLSInfo(ndpi_serializer *serializer) const;

  bool equal(const IpAddress *_cli_ip, const IpAddress *_srv_ip,
	     u_int16_t _cli_port, u_int16_t _srv_port,
	     VLANid _vlanId, u_int16_t _observation_point_id,
	     u_int8_t _protocol,
	     const ICMPinfo * const icmp_info,
	     bool *src2srv_direction) const;
  void sumStats(nDPIStats *ndpi_stats, FlowStats *stats);
  bool dump(time_t t, bool last_dump_before_free);
  bool match(AddressTree *ptree);
  void dissectHTTP(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectDNS(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectTLS(char *payload, u_int16_t payload_len);
  void dissectSSDP(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectMDNS(u_int8_t *payload, u_int16_t payload_len);
  void dissectNetBIOS(u_int8_t *payload, u_int16_t payload_len);
  void dissectBittorrent(char *payload, u_int16_t payload_len);
  void updateInterfaceLocalStats(bool src2dst_direction, u_int num_pkts, u_int pkt_len);
  void fillZmqFlowCategory(const ParsedFlow *zflow, ndpi_protocol *res) const;
  inline void setICMP(bool src2dst_direction, u_int8_t icmp_type, u_int8_t icmp_code, u_int8_t *icmpdata) {
    if(isICMP()) {
      if(src2dst_direction)
	protos.icmp.cli2srv.icmp_type = icmp_type, protos.icmp.cli2srv.icmp_code = icmp_code;
      else	
	protos.icmp.srv2cli.icmp_type = icmp_type, protos.icmp.srv2cli.icmp_code = icmp_code;
      // if(get_cli_host()) get_cli_host()->incICMP(icmp_type, icmp_code, src2dst_direction ? true : false, get_srv_host());
      // if(get_srv_host()) get_srv_host()->incICMP(icmp_type, icmp_code, src2dst_direction ? false : true, get_cli_host());
    }
  }
  inline void getICMP(u_int8_t *_icmp_type, u_int8_t *_icmp_code) {
    if(isBidirectional())
      *_icmp_type = protos.icmp.srv2cli.icmp_type, *_icmp_code = protos.icmp.srv2cli.icmp_code;
    else
      *_icmp_type = protos.icmp.cli2srv.icmp_type, *_icmp_code = protos.icmp.cli2srv.icmp_code;
  }
  inline u_int8_t getICMPType() {
    if(isICMP()) {
      return isBidirectional() ? protos.icmp.srv2cli.icmp_type : protos.icmp.cli2srv.icmp_type;
    }

    return 0;
  }
  inline bool hasInvalidDNSQueryChars()  { return(isDNS() && protos.dns.invalid_chars_in_query); }
  inline bool hasMaliciousSignature(bool as_client) const { return as_client ? has_malicious_cli_signature : has_malicious_srv_signature; }

  void setRisk(ndpi_risk r);
  void addRisk(ndpi_risk r);
  inline ndpi_risk getRiskBitmap() const { return ndpi_flow_risk_bitmap; }
  bool hasRisk(ndpi_risk_enum r) const;
  bool hasRisks() const;
  inline char* getDGADomain() const { return(hasRisk(NDPI_SUSPICIOUS_DGA_DOMAIN) && suspicious_dga_domain ? suspicious_dga_domain : (char*)""); }
  inline char* getDNSQuery()  const { return(isDNS() ? protos.dns.last_query : (char*)"");  }
  bool setDNSQuery(char *v);
  inline void  setDNSQueryType(u_int16_t t) { if(isDNS()) { protos.dns.last_query_type = t; } }
  inline void  setDNSRetCode(u_int16_t c)   { if(isDNS()) { protos.dns.last_return_code = c; } }
  inline u_int16_t getLastQueryType()       { return(isDNS() ? protos.dns.last_query_type : 0); }
  inline u_int16_t getDNSRetCode()          { return(isDNS() ? protos.dns.last_return_code : 0); }
  inline char* getHTTPURL()                 { return(isHTTP() ? protos.http.last_url : (char*)"");   }
  inline void  setHTTPURL(char *v)          { if(isHTTP()) { if(!protos.http.last_url) protos.http.last_url = v; } }
  void setHTTPMethod(const char* method, ssize_t method_len);
  void setHTTPMethod(ndpi_http_method m);
  inline void  setHTTPRetCode(u_int16_t c)  { if(isHTTP()) { protos.http.last_return_code = c; } }
  inline u_int16_t getHTTPRetCode()   const { return isHTTP() ? protos.http.last_return_code : 0;           };
  inline const char* getHTTPMethod()  const { return isHTTP() ? ndpi_http_method2str(protos.http.last_method) : (char*)"";        };
  inline char* getHTTPContentType()   const { return(isHTTP() ? protos.http.last_content_type : (char*)""); };

  void setExternalAlert(json_object *a);
  inline bool hasExternalAlert() const { return external_alert.json != NULL; };
  inline json_object *getExternalAlert() { return external_alert.json; };
  inline char *getExternalSource() { return external_alert.source; };
  void luaRetrieveExternalAlert(lua_State *vm);

  u_int32_t getSrvTcpIssues();
  u_int32_t getCliTcpIssues();
  double getCliRetrPercentage();
  double getSrvRetrPercentage();

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  inline void updateProfile()     { trafficProfile = iface->getFlowProfile(this); }
  inline char* get_profile_name() { return(trafficProfile ? trafficProfile->getName() : (char*)"");}
#endif
  /* http://bradhedlund.com/2008/12/19/how-to-calculate-tcp-throughput-for-long-distance-links/ */
  inline float getCli2SrvMaxThpt() const { return(rttSec ? ((float)(cli2srv_window*8)/rttSec) : 0); }
  inline float getSrv2CliMaxThpt() const { return(rttSec ? ((float)(srv2cli_window*8)/rttSec) : 0); }

  inline InterarrivalStats* getCli2SrvIATStats() const { return cli2srvPktTime; }
  inline InterarrivalStats* getSrv2CliIATStats() const { return srv2cliPktTime; }

  inline bool isTCP()            const { return protocol == IPPROTO_TCP; };
  inline bool isTCPEstablished() const { return (!isTCPClosed() && !isTCPReset() && isThreeWayHandshakeOK()); }
  inline bool isTCPConnecting()  const { return (src2dst_tcp_flags == TH_SYN
						 && (!dst2src_tcp_flags || (dst2src_tcp_flags == (TH_SYN | TH_ACK)))); }
  inline bool isTCPClosed()      const { return (((src2dst_tcp_flags & (TH_SYN | TH_ACK | TH_FIN)) == (TH_SYN | TH_ACK | TH_FIN))
						 && ((dst2src_tcp_flags & (TH_SYN | TH_ACK | TH_FIN)) == (TH_SYN | TH_ACK | TH_FIN))); }
  inline bool isTCPReset()       const { return (!isTCPClosed()
						 && ((src2dst_tcp_flags & TH_RST) || (dst2src_tcp_flags & TH_RST))); };
  inline bool isTCPRefused()     const { return (!isThreeWayHandshakeOK() && (dst2src_tcp_flags & TH_RST) == TH_RST); };
  inline bool isTCPZeroWindow()  const { return (src2dst_tcp_zero_window || dst2src_tcp_zero_window); };
  inline void setVRFid(u_int32_t v) { vrfId = v; }
  inline void setSrcAS(u_int32_t v) { srcAS = v; }
  inline void setDstAS(u_int32_t v) { dstAS = v; }
  inline void setPrevAdjacentAS(u_int32_t v) { prevAdjacentAS = v; }
  inline void setNextAdjacentAS(u_int32_t v) { nextAdjacentAS = v; }

  inline ViewInterfaceFlowStats* getViewInterfaceFlowStats() { return(viewFlowStats); }

  inline void setFlowNwLatency(const struct timeval * const tv, bool client) {
    if(client) {
      memcpy(&clientNwLatency, tv, sizeof(*tv));
      if(cli_host) cli_host->updateRoundTripTime(Utils::timeval2ms(&clientNwLatency));
    } else {
      memcpy(&serverNwLatency, tv, sizeof(*tv));
      if(srv_host) srv_host->updateRoundTripTime(Utils::timeval2ms(&serverNwLatency));
    }
  }
  inline void setFlowTcpWindow(u_int16_t window_val, bool client) {
    if(client)
      cli2srv_window = window_val;
    else
      srv2cli_window = window_val;
  }
  inline void setRtt() {
    rttSec = ((float)(serverNwLatency.tv_sec + clientNwLatency.tv_sec))
      +((float)(serverNwLatency.tv_usec + clientNwLatency.tv_usec)) / (float)1000000;
  }
  inline void setFlowApplLatency(float latency_msecs) { applLatencyMsec = latency_msecs; }
  inline void setFlowDevice(u_int32_t device_ip, u_int16_t observation_point_id,
			    u_int32_t inidx, u_int32_t outidx) {
    flow_device.device_ip = device_ip, flow_device.observation_point_id = observation_point_id;
    flow_device.in_index = inidx, flow_device.out_index = outidx;
  }
  inline u_int32_t getFlowDeviceIp()           { return flow_device.device_ip;             };
  inline u_int16_t getFlowObservationPointId() { return flow_device.observation_point_id;  };
  inline u_int16_t get_observation_point_id()  { return(getFlowObservationPointId());      };
  inline u_int32_t getFlowDeviceInIndex()      { return flow_device.in_index;              };
  inline u_int32_t getFlowDeviceOutIndex()     { return flow_device.out_index;             };

  inline const u_int16_t getScore()            const { return(flow_score); };

#ifdef HAVE_NEDGE
  inline void setLastConntrackUpdate(u_int32_t when) { last_conntrack_update = when; }
  bool isNetfilterIdleFlow() const;

  void setPacketsBytes(time_t now, u_int32_t s2d_pkts, u_int32_t d2s_pkts, u_int64_t s2d_bytes, u_int64_t d2s_bytes);  
  void getFlowShapers(bool src2dst_direction, TrafficShaper **shaper_ingress, TrafficShaper **shaper_egress) {
    if(src2dst_direction) {
      *shaper_ingress = flowShaperIds.cli2srv.ingress,
	*shaper_egress = flowShaperIds.cli2srv.egress;
    } else {
      *shaper_ingress = flowShaperIds.srv2cli.ingress,
	*shaper_egress = flowShaperIds.srv2cli.egress;
    }
  }
  bool updateDirectionShapers(bool src2dst_direction, TrafficShaper **ingress_shaper, TrafficShaper **egress_shaper);
  void updateFlowShapers(bool first_update=false);
  void recheckQuota(const struct tm *now);
  inline u_int8_t getFlowRoutingTableId() { return(routing_table_id); }
  inline void setIngress2EgressDirection(bool _ingress2egress) { ingress2egress_direction = _ingress2egress; }
  inline bool isIngress2EgressDirection() { return(ingress2egress_direction); }
#endif
  void housekeep(time_t t);
  void setParsedeBPFInfo(const ParsedeBPF * const ebpf, bool src2dst_direction);
  inline const ContainerInfo* getClientContainerInfo() const {
    return cli_ebpf && cli_ebpf->container_info_set ? &cli_ebpf->container_info : NULL;
  }
  inline const ContainerInfo* getServerContainerInfo() const {
    return srv_ebpf && srv_ebpf->container_info_set ? &srv_ebpf->container_info : NULL;
  }
  inline const ProcessInfo * getClientProcessInfo() const {
    return cli_ebpf && cli_ebpf->process_info_set ? &cli_ebpf->process_info : NULL;
  }
  inline const ProcessInfo* getServerProcessInfo() const {
    return srv_ebpf && srv_ebpf->process_info_set ? &srv_ebpf->process_info : NULL;
  }
  inline const TcpInfo* getClientTcpInfo() const {
    return cli_ebpf && cli_ebpf->tcp_info_set ? &cli_ebpf->tcp_info : NULL;
  }
  inline const TcpInfo* getServerTcpInfo() const {
    return srv_ebpf && srv_ebpf->tcp_info_set ? &srv_ebpf->tcp_info : NULL;
  }

  inline bool isNotPurged() {
    return(getInterface()->isPacketInterface()
	   && getInterface()->is_purge_idle_interface()
	   && (!idle())
	   && is_active_entry_now_idle(10 * getInterface()->getFlowMaxIdle()));
  }

  inline u_int16_t getTLSVersion()   { return(isTLS() ? protos.tls.tls_version : 0); }
  inline u_int32_t getTLSNotBefore() { return(isTLS() ? protos.tls.notBefore   : 0); };
  inline u_int32_t getTLSNotAfter()  { return(isTLS() ? protos.tls.notAfter    : 0); };
  inline char* getTLSCertificateIssuerDN()  { return(isTLSProto() ? protos.tls.issuerDN  : NULL); }
  inline char* getTLSCertificateSubjectDN() { return(isTLSProto() ? protos.tls.subjectDN : NULL); }

  inline void setTOS(u_int8_t tos, bool is_cli_tos) { if(is_cli_tos) cli2srv_tos = tos; srv2cli_tos = tos; }
  inline u_int8_t getTOS(bool is_cli_tos) const { return (is_cli_tos ? cli2srv_tos : srv2cli_tos); }

  inline u_int8_t getCli2SrvDSCP() const { return (cli2srv_tos & 0xFC) >> 2; }
  inline u_int8_t getSrv2CliDSCP() const { return (srv2cli_tos & 0xFC) >> 2; }

  inline u_int8_t getCli2SrvECN()  { return (cli2srv_tos & 0x3); }
  inline u_int8_t getSrv2CliECN()  { return (srv2cli_tos & 0x3); }

  inline float getEntropy(bool src2dst_direction) {
    struct ndpi_analyze_struct *e = src2dst_direction ? entropy.c2s : entropy.s2c;

    return(e ? ndpi_data_entropy(e) : 0);
  }

  inline void setCustomFlowInfo(char *what) {
    /* NOTE: this is not a reentrant call */
    if(what) {
      if(custom_flow_info) free(custom_flow_info);
      custom_flow_info = strdup(what);
    }
  }

  inline bool timeToPeriodicDump(u_int sec) {
    return((sec - get_first_seen() < CONST_DB_DUMP_FREQUENCY) || (sec - get_partial_last_seen() < CONST_DB_DUMP_FREQUENCY));
  }

  u_char* getCommunityId(u_char *community_id, u_int community_id_len);

  inline FlowTrafficStats* getTrafficStats() { return(&stats); };
};

#endif /* _FLOW_H_ */

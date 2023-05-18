/*
 *
 * (C) 2013-23 - ntop.org
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
  u_int32_t privateFlowId /* Used to store specific flow info such as DNS
                             TransactionId */
      ;
  u_int8_t cli2srv_tos, srv2cli_tos; /* RFC 2474, 3168 */
  u_int16_t cli_port, srv_port;
  u_int16_t vlanId;
  u_int32_t vrfId;
  u_int32_t srcAS, dstAS, prevAdjacentAS, nextAdjacentAS;
  u_int32_t protocolErrorCode;
  u_int8_t protocol, src2dst_tcp_flags, dst2src_tcp_flags, flow_verdict;
  u_int16_t flow_score;
  u_int8_t view_cli_mac[6], view_srv_mac[6];
  struct ndpi_flow_struct *ndpiFlow;
  ndpi_risk ndpi_flow_risk_bitmap;
  /* The bitmap of all possible flow alerts set by FlowCheck subclasses.
     When no alert is set, the flow is in flow_alert_normal.

     A flow can have multiple alerts but at most ONE of its alerts is
     predominant of a flow, which is written into `predominant_alert`.
  */
  Bitmap128 alerts_map;
  FlowAlertType predominant_alert;   /* This is the predominant alert */
  u_int16_t predominant_alert_score; /* The score associated to the predominant
                                        alert */
  struct {
    u_int8_t is_cli_attacker : 1, is_cli_victim : 1, is_srv_attacker : 1,
        is_srv_victim : 1;
  } predominant_alert_info;

  char *json_protocol_info, *riskInfo;

  /* Calculate the entropy on the first MAX_ENTROPY_BYTES bytes */
  struct {
    struct ndpi_analyze_struct *c2s, *s2c;
  } initial_bytes_entropy;

  u_int32_t hash_entry_id; /* Uniquely identify this Flow inside the flows_hash
                              hash table */

  u_int16_t detection_completed : 1, extra_dissection_completed : 1,
      twh_over : 1, twh_ok : 1, dissect_next_http_packet : 1, passVerdict : 1,
      flow_dropped_counts_increased : 1, quota_exceeded : 1, swap_done : 1,
      swap_requested : 1, has_malicious_cli_signature : 1,
      has_malicious_srv_signature : 1, src2dst_tcp_zero_window : 1,
      dst2src_tcp_zero_window : 1, non_zero_payload_observed : 1,
      is_periodic_flow : 1;

  enum ndpi_rtp_stream_type rtp_stream_type;
#ifdef ALERTED_FLOWS_DEBUG
  bool iface_alert_inc, iface_alert_dec;
#endif
#ifdef NTOPNG_PRO
  bool ingress2egress_direction;
  bool lateral_movement;
  PeriodicityStatus periodicity_status;
#ifndef HAVE_NEDGE
  FlowProfile *trafficProfile;
#else
  u_int8_t routing_table_id;
  u_int16_t cli2srv_in, cli2srv_out, srv2cli_in, srv2cli_out;
  L7PolicySource_t cli_quota_source, srv_quota_source;
#endif
  CounterTrend throughputTrend, goodputTrend, thptRatioTrend;
#endif
  char *ndpiAddressFamilyProtocol;
  ndpi_protocol ndpiDetectedProtocol;
  custom_app_t custom_app;

  struct {
    bool alertTriggered;
    u_int8_t score;
    char *msg;
  } customFlowAlert;
  json_object *json_info;
  ndpi_serializer *tlv_info;
  ndpi_confidence_t confidence;
  char *host_server_name, *bt_hash;
  IEC104Stats *iec104;
  char *suspicious_dga_domain; /* Stores the suspicious DGA domain for flows
                                  with NDPI_SUSPICIOUS_DGA_DOMAIN */
  OSType operating_system;
#ifdef HAVE_NEDGE
  u_int32_t last_conntrack_update;
  u_int32_t marker;
#endif
  struct {
    char *source;
    json_object *json;
  } external_alert;
  bool
      trigger_immediate_periodic_update; /* needed to process external alerts */
  time_t next_call_periodic_update; /* The time at which the periodic lua script
                                       on this flow shall be called */

  /* Flow payload */
  u_int16_t flow_payload_len;
  char *flow_payload;

  union {
    struct {
      char *last_url, *last_user_agent, *last_server;
      ndpi_http_method last_method;
      u_int16_t last_return_code;
    } http;

    struct {
      char *last_query;
      char *last_query_shadow;
      time_t
          last_query_update_time; /* The time when the last query was updated */
      u_int16_t last_query_type;
      u_int16_t last_return_code;
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
        /* https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c
         */
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
        /* https://engineering.salesforce.com/tls-fingerprinting-with-ja3-and-ja3s-247362855967
         */
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

      struct {
        float min_entropy, max_entropy;
      } client_to_server;
    } icmp;
  } protos;

  struct {
    u_int32_t device_ip;
    u_int32_t in_index, out_index;
    u_int16_t observation_point_id;
  } flow_device;

  /* eBPF Information */
  ParsedeBPF *ebpf;

  /* Stats */
  FlowTrafficStats stats;

  /* IP stats */
  IPPacketStats ip_stats_s2d, ip_stats_d2s;

  /* TCP stats */
  TCPSeqNum tcp_seq_s2d, tcp_seq_d2s;
  u_int16_t cli2srv_window, srv2cli_window;

  struct timeval synTime, synAckTime,
      ackTime;                    /* network Latency (3-way handshake) */
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
    bool in_progress; /* Set to true when the flow is enqueued to be dumped */
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

  /*
     IMPORTANT NOTE

     if you add a new 'directional' field such as cliX and serverX
     you need to handle it in the Flow::swap() method
  */

  void deferredInitialization();
  char *intoaV4(unsigned int addr, char *buf, u_short bufLen);
  void allocDPIMemory();
  bool checkTor(char *hostname);
  void setBittorrentHash(char *hash);
  void updateThroughputStats(float tdiff_msec, u_int32_t diff_sent_packets,
                             u_int64_t diff_sent_bytes,
                             u_int64_t diff_sent_goodput_bytes,
                             u_int32_t diff_rcvd_packets,
                             u_int64_t diff_rcvd_bytes,
                             u_int64_t diff_rcvd_goodput_bytes);
  static void updatePacketStats(InterarrivalStats *stats,
                                const struct timeval *when, bool update_iat);
  char *printTCPState(char *const buf, u_int buf_len) const;
  void update_pools_stats(NetworkInterface *iface, Host *cli_host,
                          Host *srv_host, const struct timeval *tv,
                          u_int64_t diff_sent_packets,
                          u_int64_t diff_sent_bytes,
                          u_int64_t diff_rcvd_packets,
                          u_int64_t diff_rcvd_bytes) const;
  /*
    Check (and possibly enqueues) the flow for dump
   */
  void dumpCheck(time_t t, bool last_dump_before_free);
  void updateCliJA3();
  void updateSrvJA3();
  void updateHASSH(bool as_client);
  void processExtraDissectedInformation();
  void processDetectedProtocol(
      u_int8_t *payload, u_int16_t payload_len); /* nDPI detected protocol */
  void processDetectedProtocolData(); /* nDPI detected protocol data (e.g.,
                                         ndpiFlow->host_server_name) */
  void setExtraDissectionCompleted();
  void setProtocolDetectionCompleted(u_int8_t *payload, u_int16_t payload_len);
  void updateProtocol(ndpi_protocol proto_id);
  const char *cipher_weakness2str(ndpi_cipher_weakness w) const;
  bool get_partial_traffic_stats(PartializableFlowTrafficStats **dst,
                                 PartializableFlowTrafficStats *delta,
                                 bool *first_partial) const;
  void lua_tos(lua_State *vm);
  void lua_confidence(lua_State *vm);
  void updateEntropy(struct ndpi_analyze_struct *e, u_int8_t *payload,
                     u_int payload_len);
  void lua_entropy(lua_State *vm);
  void luaScore(lua_State *vm);
  void luaIEC104(lua_State *vm);
  void callFlowUpdate(time_t t);
  /*
    Method to trigger alerts, synchronous or asynchronous, depending on the last
    argument.
    - Asynchronous: The alerts bitmap is updated and the predominant alert is
    possibly updated. Recipients enqueue is not performed.
    - Synchronous:  The alerts bitmap is updated and the predominant alert is
    possibly updated. Immediate alert JSON generation and enqueue to the
    recipients are performed as well.
   */
  bool setAlertsBitmap(FlowAlertType alert_type, u_int16_t cli_inc,
                       u_int16_t srv_inc, bool async);
  void setNormalToAlertedCounters();
  /* Decreases scores on both client and server hosts when the flow is being
   * destructed */
  void decAllFlowScores();
  void updateServerPortsStats(Host *server_host, ndpi_protocol *proto);
  void updateClientContactedPorts(Host *client, ndpi_protocol *proto);
  void updateTCPHostServices(Host *cli_h, Host *srv_h);
  void updateUDPHostServices();

 public:
  Flow(NetworkInterface *_iface, u_int16_t _u_int16_t,
       u_int16_t _observation_point_id, u_int32_t _private_flow_id,
       u_int8_t _protocol, Mac *_cli_mac, IpAddress *_cli_ip,
       u_int16_t _cli_port, Mac *_srv_mac, IpAddress *_srv_ip,
       u_int16_t _srv_port, const ICMPinfo *const icmp_info, time_t _first_seen,
       time_t _last_seen, u_int8_t *_view_cli_mac, u_int8_t *_view_srv_mac);
  ~Flow();

  inline Bitmap128 getAlertsBitmap() const { return (alerts_map); }

  /* Enqueues an alert to all available flow recipients. */
  bool enqueueAlertToRecipients(FlowAlert *alert);

  /*
    Called by FlowCheck subclasses to trigger a flow alert. This is an
    asynchronous call, faster, but can cause the alert JSON to be generated
    after the call. The FlowCheck should implement the buildAlert() method which
    is called in the predominant check to actually build the FlowAlert object.
   */
  bool triggerAlertAsync(FlowAlertType alert_type, u_int16_t cli_score_inc,
                         u_int16_t srv_score_inc);

  /*
     Called by FlowCheck subclasses to trigger a flow alert. This is a
     syncrhonous call, more expensive, but causes the alert (FlowAlert) to be
     immediately enqueued to all recipients.
   */
  bool triggerAlertSync(FlowAlert *alert, u_int16_t cli_score_inc,
                        u_int16_t srv_score_inc);

  /*
    Enqueues the predominant alert of the flow to all available flow recipients.
   */
  void enqueuePredominantAlert();

  inline void setFlowVerdict(u_int8_t _flow_verdict) {
    flow_verdict = _flow_verdict;
  };

  inline void setPredominantAlert(FlowAlertType alert_type, u_int16_t score);
  inline FlowAlertType getPredominantAlert() const {
    return predominant_alert;
  };
  inline u_int16_t getPredominantAlertScore() const {
    return predominant_alert_score;
  };
  inline AlertLevel getPredominantAlertSeverity() const {
    return Utils::mapScoreToSeverity(predominant_alert_score);
  };
  inline bool isFlowAlerted() const {
    return (predominant_alert.id != flow_alert_normal);
  };

  void setPredominantAlertInfo(FlowAlert *alert);
  inline u_int8_t isClientAttacker() {
    return predominant_alert_info.is_cli_attacker;
  };
  inline u_int8_t isClientVictim() {
    return predominant_alert_info.is_cli_victim;
  };
  inline u_int8_t isServerAttacker() {
    return predominant_alert_info.is_srv_attacker;
  };
  inline u_int8_t isServerVictim() {
    return predominant_alert_info.is_srv_victim;
  };
  inline char *getProtocolInfo() { return json_protocol_info; };

  void setProtocolJSONInfo();
  void getProtocolJSONInfo(ndpi_serializer *serializer);

  inline char *getJa3CliHash() { return (protos.tls.ja3.client_hash); }

  bool isBlacklistedFlow() const;
  bool isBlacklistedClient() const;
  bool isBlacklistedServer() const;
  struct site_categories *getFlowCategory(bool force_categorization);
  void freeDPIMemory();
  static const ndpi_protocol ndpiUnknownProtocol;
  bool isTiny() const;
  inline bool isProto(u_int16_t p) const {
    return (((ndpiDetectedProtocol.master_protocol == p) ||
             (ndpiDetectedProtocol.app_protocol == p))
                ? true
                : false);
  }
  bool isTLS() const;
  inline bool isEncryptedProto() const {
    return (ndpi_is_encrypted_proto(iface->get_ndpi_struct(),
                                    ndpiDetectedProtocol));
  }
  inline bool isSSH() const { return (isProto(NDPI_PROTOCOL_SSH)); }
  inline bool isDNS() const { return (isProto(NDPI_PROTOCOL_DNS)); }
  inline bool isZoomRTP() const {
    return (isProto(NDPI_PROTOCOL_ZOOM) && isProto(NDPI_PROTOCOL_RTP));
  }
  inline bool isIEC60870() const { return (isProto(NDPI_PROTOCOL_IEC60870)); }
  inline bool isMDNS() const { return (isProto(NDPI_PROTOCOL_MDNS)); }
  inline bool isSSDP() const { return (isProto(NDPI_PROTOCOL_SSDP)); }
  inline bool isNetBIOS() const { return (isProto(NDPI_PROTOCOL_NETBIOS)); }
  inline bool isDHCP() const { return (isProto(NDPI_PROTOCOL_DHCP)); }
  inline bool isNTP() const { return (isProto(NDPI_PROTOCOL_NTP)); }
  inline bool isSMTP() const {
    return (isProto(NDPI_PROTOCOL_MAIL_SMTP) ||
            isProto(NDPI_PROTOCOL_MAIL_SMTPS));
  }
  inline bool isHTTP() const { return (isProto(NDPI_PROTOCOL_HTTP)); }
  inline bool isICMP() const {
    return (isProto(NDPI_PROTOCOL_IP_ICMP) || isProto(NDPI_PROTOCOL_IP_ICMPV6));
  }
  inline bool isBittorrent() const {
    return (isProto(NDPI_PROTOCOL_BITTORRENT));
  }

#if defined(NTOPNG_PRO)
  inline bool isLateralMovement() const { return (lateral_movement); }
  inline void setLateralMovement(bool change) { lateral_movement = change; }
  PeriodicityStatus getPeriodicity() const { return (periodicity_status); }
  inline void setPeriodicity(PeriodicityStatus _periodicity_status) {
    periodicity_status = _periodicity_status;
  }
#endif

  inline bool isCliDeviceAllowedProtocol() const {
    return !cli_host ||
           cli_host->getDeviceAllowedProtocolStatus(
               get_detected_protocol(), true) == device_proto_allowed;
  }
  inline bool isSrvDeviceAllowedProtocol() const {
    return !srv_host ||
           get_bytes_srv2cli() ==
               0 /* Server must respond to be considered NOT allowed */
           || srv_host->getDeviceAllowedProtocolStatus(
                  get_detected_protocol(), false) == device_proto_allowed;
  }
  inline bool isDeviceAllowedProtocol() const {
    return isCliDeviceAllowedProtocol() && isSrvDeviceAllowedProtocol();
  }
  inline u_int16_t getCliDeviceDisallowedProtocol() const {
    DeviceProtoStatus cli_ps =
        cli_host->getDeviceAllowedProtocolStatus(get_detected_protocol(), true);
    return (cli_ps == device_proto_forbidden_app)
               ? ndpiDetectedProtocol.app_protocol
               : ndpiDetectedProtocol.master_protocol;
  }
  inline u_int16_t getSrvDeviceDisallowedProtocol() const {
    DeviceProtoStatus srv_ps = srv_host->getDeviceAllowedProtocolStatus(
        get_detected_protocol(), false);
    return (srv_ps == device_proto_forbidden_app)
               ? ndpiDetectedProtocol.app_protocol
               : ndpiDetectedProtocol.master_protocol;
  }
  inline bool isMaskedFlow() const {
    return (Utils::maskHost(get_cli_ip_addr()->isLocalHost()) ||
            Utils::maskHost(get_srv_ip_addr()->isLocalHost()));
  };
  inline const char *getServerCipherClass() const {
    return (isTLS() ? cipher_weakness2str(protos.tls.ja3.server_unsafe_cipher)
                    : NULL);
  }
  char *serialize(bool use_labels = false);
  /* Prepares an alert JSON and puts int in the resulting `serializer`. */
  void alert2JSON(FlowAlert *alert, ndpi_serializer *serializer);
  json_object *flow2JSON();
  json_object *flow2es(json_object *flow_object);
  void formatECSInterface(json_object *my_object);
  void formatECSNetwork(json_object *my_object, const IpAddress *addr);
  void formatECSHost(json_object *my_object, bool is_client,
                     const IpAddress *addr, Host *host);
  void formatECSEvent(json_object *my_object);
  void formatECSFlow(json_object *my_object);
  void formatSyslogFlow(json_object *my_object);
  void formatGenericFlow(json_object *my_object);
  void formatECSExtraInfo(json_object *my_object);
  void formatECSAppProto(json_object *my_object);
  void formatECSObserver(json_object *my_object);

  inline u_int16_t getLowerProtocol() {
    return (ndpi_get_lower_proto(ndpiDetectedProtocol));
  }

  inline void updateJA3C(char *j) {
    if (j && (j[0] != '\0') && (protos.tls.ja3.client_hash == NULL))
      protos.tls.ja3.client_hash = strdup(j);
    updateCliJA3();
  }
  inline void updateJA3S(char *j) {
    if (j && (j[0] != '\0') && (protos.tls.ja3.server_hash == NULL))
      protos.tls.ja3.server_hash = strdup(j);
    updateSrvJA3();
  }

  inline u_int8_t getTcpFlags() const {
    return (src2dst_tcp_flags | dst2src_tcp_flags);
  };
  inline u_int8_t getTcpFlagsCli2Srv() const { return (src2dst_tcp_flags); };
  inline u_int8_t getTcpFlagsSrv2Cli() const { return (dst2src_tcp_flags); };
#ifdef HAVE_NEDGE
  bool checkPassVerdict(const struct tm *now);
  bool isPassVerdict() const;
  inline void setConntrackMarker(u_int32_t marker) { this->marker = marker; }
  inline u_int32_t getConntrackMarker() { return (marker); }
  void incFlowDroppedCounters();
#endif
  void setDropVerdict();
  u_int32_t getPid(bool client);
  u_int32_t getFatherPid(bool client);
  u_int32_t get_uid(bool client) const;
  char *get_proc_name(bool client);
  char *get_user_name(bool client);
  u_int32_t getNextTcpSeq(u_int8_t tcpFlags, u_int32_t tcpSeqNum,
                          u_int32_t payloadLen);
  static double toMs(const struct timeval *t);
  void timeval_diff(struct timeval *begin, const struct timeval *end,
                    struct timeval *result, u_short divide_by_two);
  char *getFlowInfo(char *buf, u_int buf_len, bool isLuaRequest);
  inline char *getFlowServerInfo() {
    return (isTLS() && protos.tls.client_requested_server_name)
               ? protos.tls.client_requested_server_name
               : host_server_name;
  }
  inline char *getBitTorrentHash() { return (bt_hash); };
  inline void setBTHash(char *h) {
    if (!h) return;
    if (bt_hash) free(bt_hash);
    bt_hash = h;
  }
  inline void setServerName(char *v) {
    if (host_server_name) free(host_server_name);
    host_server_name = v;
  }
  void updateICMPFlood(const struct bpf_timeval *when, bool src2dst_direction);
  void updateDNSFlood(const struct bpf_timeval *when, bool src2dst_direction);
  void updateSNMPFlood(const struct bpf_timeval *when, bool src2dst_direction);
  void updateTcpFlags(const struct bpf_timeval *when, u_int8_t flags,
                      bool src2dst_direction);
  void updateTcpWindow(u_int16_t window, bool src2dst_direction);
  void updateTcpSeqIssues(const ParsedFlow *pf);
  void updateTLS(ParsedFlow *zflow);
  void updateDNS(ParsedFlow *zflow);
  void updateHTTP(ParsedFlow *zflow);
  void updateSuspiciousDGADomain();
  static void incTcpBadStats(bool src2dst_direction, Host *cli, Host *srv,
                             NetworkInterface *iface, u_int32_t ooo_pkts,
                             u_int32_t retr_pkts, u_int32_t lost_pkts,
                             u_int32_t keep_alive_pkts);

  void updateTcpSeqNum(const struct bpf_timeval *when, u_int32_t seq_num,
                       u_int32_t ack_seq_num, u_int16_t window, u_int8_t flags,
                       u_int16_t payload_len, bool src2dst_direction);

  void updateSeqNum(time_t when, u_int32_t sN, u_int32_t aN);
  void setDetectedProtocol(ndpi_protocol proto_id);
  void processPacket(const struct pcap_pkthdr *h, const u_char *ip_packet,
                     u_int16_t ip_len, u_int64_t packet_time, u_int8_t *payload,
                     u_int16_t payload_len, u_int16_t src_port);
  void processDNSPacket(const u_char *ip_packet, u_int16_t ip_len,
                        u_int64_t packet_time);
  void processIEC60870Packet(bool tx_direction, const u_char *payload,
                             u_int16_t payload_len,
                             struct timeval *packet_time);

  void endProtocolDissection();
  inline void setCustomApp(custom_app_t ca) {
    memcpy(&custom_app, &ca, sizeof(custom_app));
  };
  inline custom_app_t getCustomApp() const { return custom_app; };
  u_int16_t getStatsProtocol() const;
  void setJSONInfo(json_object *json);
  void setTLVInfo(ndpi_serializer *tlv);
  void incStats(bool cli2srv_direction, u_int pkt_len, u_int8_t *payload,
                u_int payload_len, u_int8_t l4_proto, u_int8_t is_fragment,
                u_int16_t tcp_flags, const struct timeval *when,
                u_int16_t fragment_extra_overhead);
  void addFlowStats(bool new_flow, bool cli2srv_direction, u_int in_pkts,
                    u_int in_bytes, u_int in_goodput_bytes, u_int out_pkts,
                    u_int out_bytes, u_int out_goodput_bytes,
                    u_int in_fragments, u_int out_fragments, time_t first_seen,
                    time_t last_seen);
  void check_swap();

  inline bool isThreeWayHandshakeOK() const { return (twh_ok ? true : false); };
  inline bool isDetectionCompleted() const {
    return (detection_completed ? true : false);
  };
  inline bool isOneWay() const {
    return (get_packets() &&
            (!get_packets_cli2srv() || !get_packets_srv2cli()));
  };
  inline bool isBidirectional() const {
    return (get_packets_cli2srv() && get_packets_srv2cli());
  };
  inline bool isRemoteToRemote() const {
    return (cli_host && srv_host && !cli_host->isLocalHost() &&
            !srv_host->isLocalHost());
  };
  inline bool isLocalToRemote() const {
    return get_cli_ip_addr()->isLocalHost() &&
           !get_srv_ip_addr()->isLocalHost();
  };
  inline bool isRemoteToLocal() const {
    return !get_cli_ip_addr()->isLocalHost() &&
           get_srv_ip_addr()->isLocalHost();
  };
  inline bool isLocalToLocal() const {
    return get_cli_ip_addr()->isLocalHost() && get_srv_ip_addr()->isLocalHost();
  };
  inline bool isUnicast() const {
    return (cli_ip_addr && srv_ip_addr &&
            !cli_ip_addr->isBroadMulticastAddress() &&
            !srv_ip_addr->isBroadMulticastAddress());
  };
  inline u_int32_t get_cli_ipv4() const {
    return (cli_host->get_ip()->get_ipv4());
  };
  inline u_int32_t get_srv_ipv4() const {
    return (srv_host->get_ip()->get_ipv4());
  };
  inline ndpi_protocol get_detected_protocol() const {
    return (isDetectionCompleted() ? ndpiDetectedProtocol
                                   : ndpiUnknownProtocol);
  };
  inline struct ndpi_flow_struct *get_ndpi_flow() const { return (ndpiFlow); };
  inline const struct ndpi_in6_addr *get_cli_ipv6() const {
    return (cli_host->get_ip()->get_ipv6());
  };
  inline const struct ndpi_in6_addr *get_srv_ipv6() const {
    return (srv_host->get_ip()->get_ipv6());
  };
  inline u_int16_t get_cli_port() const { return (ntohs(cli_port)); };
  inline u_int16_t get_srv_port() const { return (ntohs(srv_port)); };
  inline u_int16_t get_vlan_id() const { return (vlanId); };
  inline u_int8_t get_protocol() const { return (protocol); };
  inline u_int64_t get_bytes() const {
    return (stats.get_cli2srv_bytes() + stats.get_srv2cli_bytes());
  };
  inline u_int64_t get_bytes_cli2srv() const {
    return (stats.get_cli2srv_bytes());
  };
  inline u_int64_t get_bytes_srv2cli() const {
    return (stats.get_srv2cli_bytes());
  };
  inline u_int64_t get_goodput_bytes() const {
    return (stats.get_cli2srv_goodput_bytes() +
            stats.get_srv2cli_goodput_bytes());
  };
  inline u_int64_t get_goodput_bytes_cli2srv() const {
    return (stats.get_cli2srv_goodput_bytes());
  };
  inline u_int64_t get_goodput_bytes_srv2cli() const {
    return (stats.get_srv2cli_goodput_bytes());
  };
  inline u_int64_t get_packets() const {
    return (stats.get_cli2srv_packets() + stats.get_srv2cli_packets());
  };
  inline u_int32_t get_packets_cli2srv() const {
    return (stats.get_cli2srv_packets());
  };
  inline u_int32_t get_packets_srv2cli() const {
    return (stats.get_srv2cli_packets());
  };
  inline u_int64_t get_partial_bytes() const {
    return get_partial_bytes_cli2srv() + get_partial_bytes_srv2cli();
  };
  inline u_int64_t get_partial_packets() const {
    return get_partial_packets_cli2srv() + get_partial_packets_srv2cli();
  };
  inline u_int64_t get_partial_goodput_bytes() const {
    return last_db_dump.delta.get_cli2srv_goodput_bytes() +
           last_db_dump.delta.get_srv2cli_goodput_bytes();
  };
  inline u_int64_t get_partial_bytes_cli2srv() const {
    return last_db_dump.delta.get_cli2srv_bytes();
  };
  inline u_int64_t get_partial_bytes_srv2cli() const {
    return last_db_dump.delta.get_srv2cli_bytes();
  };
  inline u_int64_t get_partial_packets_cli2srv() const {
    return last_db_dump.delta.get_cli2srv_packets();
  };
  inline u_int64_t get_partial_packets_srv2cli() const {
    return last_db_dump.delta.get_srv2cli_packets();
  };
  inline void set_dump_in_progress() { last_db_dump.in_progress = true; };
  inline void set_dump_done() { last_db_dump.in_progress = false; };
  bool needsExtraDissection();
  bool hasDissectedTooManyPackets();
  bool get_partial_traffic_stats_view(PartializableFlowTrafficStats *delta,
                                      bool *first_partial);
  bool update_partial_traffic_stats_db_dump();
  inline float get_pkts_thpt() const {
    return (pkts_thpt_cli2srv + pkts_thpt_srv2cli);
  };
  inline float get_bytes_thpt() const {
    return (bytes_thpt_cli2srv + bytes_thpt_srv2cli);
  };
  inline float get_goodput_bytes_thpt() const {
    return (goodput_bytes_thpt_cli2srv + goodput_bytes_thpt_srv2cli);
  };
  inline float get_goodput_ratio() const {
    return ((float)(100 * get_goodput_bytes()) / ((float)get_bytes() + 1));
  };
  inline time_t get_partial_first_seen() const {
    return (last_db_dump.first_seen);
  };
  inline time_t get_partial_last_seen() const {
    return (last_db_dump.last_seen);
  };
  inline u_int32_t get_duration() const {
    return ((u_int32_t)(get_last_seen() - get_first_seen()));
  };
  inline char *get_protocol_name() const {
    return (Utils::l4proto2name(protocol));
  };

  inline Host *get_cli_host() const { return (cli_host); };
  inline Host *get_srv_host() const { return (srv_host); };
  inline IpAddress *get_cli_ip_addr() const { return (cli_ip_addr); };
  inline IpAddress *get_srv_ip_addr() const { return (srv_ip_addr); };
  inline IpAddress *get_dns_srv_ip_addr() const {
    return ((get_cli_port() == 53) ? get_cli_ip_addr() : get_srv_ip_addr());
  };
  inline IpAddress *get_dhcp_srv_ip_addr() const {
    return ((get_cli_port() == 67) ? get_cli_ip_addr() : get_srv_ip_addr());
  };

  inline json_object *get_json_info() const { return (json_info); };
  inline ndpi_serializer *get_tlv_info() const { return (tlv_info); };
  inline void setICMPPayloadSize(u_int16_t size) {
    if (isICMP())
      protos.icmp.max_icmp_payload_size =
          max(protos.icmp.max_icmp_payload_size, size);
  };
  inline u_int16_t getICMPPayloadSize() const {
    return (isICMP() ? protos.icmp.max_icmp_payload_size : 0);
  };
  inline ICMPinfo *getICMPInfo() const { return (isICMP() ? icmp_info : NULL); }
  inline ndpi_protocol_breed_t get_protocol_breed() const {
    return (ndpi_get_proto_breed(
        iface->get_ndpi_struct(),
        isDetectionCompleted() ? ndpi_get_upper_proto(ndpiDetectedProtocol)
                               : NDPI_PROTOCOL_UNKNOWN));
  };
  inline const char *get_protocol_breed_name() const {
    return (ndpi_get_proto_breed_name(iface->get_ndpi_struct(),
                                      get_protocol_breed()));
  };
  inline ndpi_protocol_category_t get_protocol_category() const {
    return (ndpi_get_proto_category(
        iface->get_ndpi_struct(),
        isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol));
  };
  inline const char *get_protocol_category_name() const {
    return (ndpi_category_get_name(iface->get_ndpi_struct(),
                                   get_protocol_category()));
  };
  char *get_detected_protocol_name(char *buf, u_int buf_len) const {
    return (iface->get_ndpi_full_proto_name(
        isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol,
        buf, buf_len));
  }
  static inline ndpi_protocol get_ndpi_unknown_protocol() {
    return ndpiUnknownProtocol;
  };

  /* NOTE: the caller must ensure that the hosts returned by these methods are
   * not used concurrently by subinterfaces since hosts are shared between all
   * the subinterfaces of the same ViewInterface. */
  inline Host *getViewSharedClient() {
    return (viewFlowStats ? viewFlowStats->getViewSharedClient()
                          : get_cli_host());
  };
  inline Host *getViewSharedServer() {
    return (viewFlowStats ? viewFlowStats->getViewSharedServer()
                          : get_srv_host());
  };

  u_int32_t get_packetsLost();
  u_int32_t get_packetsRetr();
  u_int32_t get_packetsOOO();

  inline const struct timeval *get_current_update_time() const {
    return &last_update_time;
  };
  u_int64_t get_current_bytes_cli2srv() const;
  u_int64_t get_current_bytes_srv2cli() const;
  u_int64_t get_current_goodput_bytes_cli2srv() const;
  u_int64_t get_current_goodput_bytes_srv2cli() const;
  u_int64_t get_current_packets_cli2srv() const;
  u_int64_t get_current_packets_srv2cli() const;

  inline bool is_swap_requested() const {
    return (swap_requested ? true : false);
  };
  inline bool is_swap_done() const { return (swap_done ? true : false); };
  inline void set_swap_done() { swap_done = 1; };
  /*
    Returns actual client and server, that is the client and server as
    determined after the swap heuristic that has taken place.
   */
  inline void get_actual_peers(Host **actual_client,
                               Host **actual_server) const {
    if (is_swap_requested())
      *actual_client = get_srv_host(), *actual_server = get_cli_host();
    else
      *actual_client = get_cli_host(), *actual_server = get_srv_host();
  };
  bool is_hash_entry_state_idle_transition_ready();
  void hosts_periodic_stats_update(NetworkInterface *iface, Host *cli_host,
                                   Host *srv_host,
                                   PartializableFlowTrafficStats *partial,
                                   bool first_partial,
                                   const struct timeval *tv);
  void periodic_stats_update(const struct timeval *tv);
  void set_hash_entry_id(u_int32_t assigned_hash_entry_id);
  u_int32_t get_hash_entry_id() const;

  static char *printTCPflags(u_int8_t flags, char *const buf, u_int buf_len);
  char *print(char *buf, u_int buf_len) const;

  u_int32_t key();
  static u_int32_t key(Host *cli, u_int16_t cli_port, Host *srv,
                       u_int16_t srv_port, u_int16_t vlan_id,
                       u_int16_t _observation_point_id, u_int16_t protocol);
  void lua(lua_State *vm, AddressTree *ptree, DetailsLevel details_level,
           bool asListElement);
  void lua_get_min_info(lua_State *vm);
  void lua_duration_info(lua_State *vm);
  void lua_snmp_info(lua_State *vm);
  void lua_device_protocol_allowed_info(lua_State *vm);
  void lua_get_tcp_stats(lua_State *vm) const;

  void lua_get_unicast_info(lua_State *vm) const;
  void lua_get_status(lua_State *vm) const;
  void lua_get_protocols(lua_State *vm) const;
  void lua_get_bytes(lua_State *vm) const;
  void lua_get_dir_traffic(lua_State *vm, bool cli2srv) const;
  void lua_get_dir_iat(lua_State *vm, bool cli2srv) const;
  void lua_get_packets(lua_State *vm) const;
  void lua_get_throughput(lua_State *vm) const;
  void lua_get_time(lua_State *vm) const;
  void lua_get_ip(lua_State *vm, bool client) const;
  void lua_get_mac(lua_State *vm, bool client) const;
  void lua_get_info(lua_State *vm, bool client) const;
  void lua_get_tls_info(lua_State *vm) const;
  void lua_get_ssh_info(lua_State *vm) const;
  void lua_get_http_info(lua_State *vm) const;
  void lua_get_dns_info(lua_State *vm) const;
  void lua_get_tcp_info(lua_State *vm) const;
  void lua_get_port(lua_State *vm, bool client) const;
  void lua_get_geoloc(lua_State *vm, bool client, bool coords,
                      bool country_city) const;
  void lua_get_risk_info(lua_State *vm);

  void getInfo(ndpi_serializer *serializer);
  void getHTTPInfo(ndpi_serializer *serializer) const;
  void getDNSInfo(ndpi_serializer *serializer) const;
  void getICMPInfo(ndpi_serializer *serializer) const;
  void getTLSInfo(ndpi_serializer *serializer) const;
  void getMDNSInfo(ndpi_serializer *serializer) const;
  void getNetBiosInfo(ndpi_serializer *serializer) const;
  void getSSHInfo(ndpi_serializer *serializer) const;

  bool equal(const Mac *src_mac, const Mac *dst_mac, const IpAddress *_cli_ip,
             const IpAddress *_srv_ip, u_int16_t _cli_port, u_int16_t _srv_port,
             u_int16_t _u_int16_t, u_int16_t _observation_point_id,
             u_int32_t _private_flow_id, u_int8_t _protocol,
             const ICMPinfo *const icmp_info, bool *src2srv_direction) const;
  void sumStats(nDPIStats *ndpi_stats, FlowStats *stats);
  bool dump(time_t t, bool last_dump_before_free);
  bool match(AddressTree *ptree);
  void dissectHTTP(bool src2dst_direction, char *payload,
                   u_int16_t payload_len);
  void dissectDNS(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectTLS(char *payload, u_int16_t payload_len);
  void dissectSSDP(bool src2dst_direction, char *payload,
                   u_int16_t payload_len);
  void dissectMDNS(u_int8_t *payload, u_int16_t payload_len);
  void dissectNetBIOS(u_int8_t *payload, u_int16_t payload_len);
  void dissectBittorrent(char *payload, u_int16_t payload_len);
  void fillZmqFlowCategory(const ParsedFlow *zflow, ndpi_protocol *res) const;
  inline void setICMP(bool src2dst_direction, u_int8_t icmp_type,
                      u_int8_t icmp_code, u_int8_t *icmpdata) {
    if (isICMP()) {
      if (src2dst_direction)
        protos.icmp.cli2srv.icmp_type = icmp_type,
        protos.icmp.cli2srv.icmp_code = icmp_code;
      else
        protos.icmp.srv2cli.icmp_type = icmp_type,
        protos.icmp.srv2cli.icmp_code = icmp_code;
      // if(get_cli_host()) get_cli_host()->incICMP(icmp_type, icmp_code,
      // src2dst_direction ? true : false, get_srv_host()); if(get_srv_host())
      // get_srv_host()->incICMP(icmp_type, icmp_code, src2dst_direction ? false
      // : true, get_cli_host());
    }
  }
  inline void getICMP(u_int8_t *_icmp_type, u_int8_t *_icmp_code) {
    if (isBidirectional())
      *_icmp_type = protos.icmp.srv2cli.icmp_type,
      *_icmp_code = protos.icmp.srv2cli.icmp_code;
    else
      *_icmp_type = protos.icmp.cli2srv.icmp_type,
      *_icmp_code = protos.icmp.cli2srv.icmp_code;
  }
  inline u_int8_t getICMPType() {
    if (isICMP()) {
      return isBidirectional() ? protos.icmp.srv2cli.icmp_type
                               : protos.icmp.cli2srv.icmp_type;
    }

    return 0;
  }

  inline bool hasInvalidDNSQueryChars() const {
    return (isDNS() && hasRisk(NDPI_INVALID_CHARACTERS));
  }
  inline bool hasMaliciousSignature(bool as_client) const {
    return as_client ? has_malicious_cli_signature
                     : has_malicious_srv_signature;
  }

  void setRisk(ndpi_risk r);
  void addRisk(ndpi_risk r);
  inline ndpi_risk getRiskBitmap() const { return ndpi_flow_risk_bitmap; }
  bool hasRisk(ndpi_risk_enum r) const;
  bool hasRisks() const;
  void clearRisks();
  inline void setDGADomain(char *name) {
    if (name) {
      if (suspicious_dga_domain) free(suspicious_dga_domain);
      suspicious_dga_domain = strdup(name);
    }
  }
  inline char *getDGADomain() const {
    return (hasRisk(NDPI_SUSPICIOUS_DGA_DOMAIN) && suspicious_dga_domain
                ? suspicious_dga_domain
                : (char *)"");
  }
  inline char *getDNSQuery() const {
    return (isDNS() ? protos.dns.last_query : (char *)"");
  }
  bool setDNSQuery(char *v);
  inline void setDNSQueryType(u_int16_t t) {
    if (isDNS()) {
      protos.dns.last_query_type = t;
    }
  }
  inline void setDNSRetCode(u_int16_t c) {
    if (isDNS()) {
      protos.dns.last_return_code = c;
    }
  }
  inline u_int16_t getLastQueryType() {
    return (isDNS() ? protos.dns.last_query_type : 0);
  }
  inline u_int16_t getDNSRetCode() {
    return (isDNS() ? protos.dns.last_return_code : 0);
  }
  inline char *getHTTPURL() {
    return (isHTTP() ? protos.http.last_url : (char *)"");
  }
  inline void setHTTPURL(char *v) {
    if (isHTTP()) {
      if (!protos.http.last_url) protos.http.last_url = v;
    } else {
      if (v) free(v);
    }
  }
  inline char *getHTTPUserAgent() {
    return (isHTTP() ? protos.http.last_user_agent : (char *)"");
  }
  inline void setHTTPUserAgent(char *v) {
    if (isHTTP()) {
      if (!protos.http.last_user_agent) protos.http.last_user_agent = v;
    } else {
      if (v) free(v);
    }
  }
  void setHTTPMethod(const char *method, ssize_t method_len);
  void setHTTPMethod(ndpi_http_method m);
  inline void setHTTPRetCode(u_int16_t c) {
    if (isHTTP()) {
      protos.http.last_return_code = c;
    }
  }
  inline u_int16_t getHTTPRetCode() const {
    return isHTTP() ? protos.http.last_return_code : 0;
  };
  inline const char *getHTTPMethod() const {
    return isHTTP() ? ndpi_http_method2str(protos.http.last_method)
                    : (char *)"";
  };

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
  inline void updateProfile() { trafficProfile = iface->getFlowProfile(this); }
  inline char *get_profile_name() {
    return (trafficProfile ? trafficProfile->getName() : (char *)"");
  }
#endif
  /* http://bradhedlund.com/2008/12/19/how-to-calculate-tcp-throughput-for-long-distance-links/
   */
  inline float getCli2SrvMaxThpt() const {
    return (rttSec ? ((float)(cli2srv_window * 8) / rttSec) : 0);
  }
  inline float getSrv2CliMaxThpt() const {
    return (rttSec ? ((float)(srv2cli_window * 8) / rttSec) : 0);
  }

  inline InterarrivalStats *getCli2SrvIATStats() const {
    return cli2srvPktTime;
  }
  inline InterarrivalStats *getSrv2CliIATStats() const {
    return srv2cliPktTime;
  }

  inline bool isTCP() const { return protocol == IPPROTO_TCP; };
  inline bool isTCPEstablished() const {
    return (!isTCPClosed() && !isTCPReset() && isThreeWayHandshakeOK());
  }
  inline bool isTCPConnecting() const {
    return (src2dst_tcp_flags == TH_SYN &&
            (!dst2src_tcp_flags || (dst2src_tcp_flags == (TH_SYN | TH_ACK))));
  }
  inline bool isTCPClosed() const {
    return (((src2dst_tcp_flags & (TH_SYN | TH_ACK | TH_FIN)) ==
             (TH_SYN | TH_ACK | TH_FIN)) &&
            ((dst2src_tcp_flags & (TH_SYN | TH_ACK | TH_FIN)) ==
             (TH_SYN | TH_ACK | TH_FIN)));
  }
  inline bool isTCPReset() const {
    return (!isTCPClosed() &&
            ((src2dst_tcp_flags & TH_RST) || (dst2src_tcp_flags & TH_RST)));
  };
  inline bool isTCPRefused() const {
    return (!isThreeWayHandshakeOK() && (dst2src_tcp_flags & TH_RST) == TH_RST);
  };
  inline bool isTCPZeroWindow() const {
    return (src2dst_tcp_zero_window || dst2src_tcp_zero_window);
  };
  inline void setVRFid(u_int32_t v) { vrfId = v; }
  inline void setSrcAS(u_int32_t v) { srcAS = v; }
  inline void setDstAS(u_int32_t v) { dstAS = v; }
  inline void setPrevAdjacentAS(u_int32_t v) { prevAdjacentAS = v; }
  inline void setNextAdjacentAS(u_int32_t v) { nextAdjacentAS = v; }

  inline ViewInterfaceFlowStats *getViewInterfaceFlowStats() {
    return (viewFlowStats);
  }

  inline double getFlowNwLatency(bool client) const {
    return client ? Utils::timeval2ms(&clientNwLatency)
                  : Utils::timeval2ms(&serverNwLatency);
  };
  inline void setFlowNwLatency(const struct timeval *const tv, bool client) {
    if (client) {
      memcpy(&clientNwLatency, tv, sizeof(*tv));
      if (cli_host)
        cli_host->updateRoundTripTime(Utils::timeval2ms(&clientNwLatency));
    } else {
      memcpy(&serverNwLatency, tv, sizeof(*tv));
      if (srv_host)
        srv_host->updateRoundTripTime(Utils::timeval2ms(&serverNwLatency));
    }
  }
  inline void setFlowTcpWindow(u_int16_t window_val, bool client) {
    if (client)
      cli2srv_window = window_val;
    else
      srv2cli_window = window_val;
  }
  inline void setRtt() {
    rttSec = ((float)(serverNwLatency.tv_sec + clientNwLatency.tv_sec)) +
             ((float)(serverNwLatency.tv_usec + clientNwLatency.tv_usec)) /
                 (float)1000000;
  }
  inline void setFlowApplLatency(float latency_msecs) {
    applLatencyMsec = latency_msecs;
  }
  inline void setFlowDevice(u_int32_t device_ip, u_int16_t observation_point_id,
                            u_int32_t inidx, u_int32_t outidx) {
    ObservationPoint *obs_point;

    flow_device.device_ip = device_ip,
    flow_device.observation_point_id = observation_point_id;
    flow_device.in_index = inidx, flow_device.out_index = outidx;
    if (cli_host) cli_host->setLastDeviceIp(device_ip);
    if (srv_host) srv_host->setLastDeviceIp(device_ip);

    if ((obs_point = iface->getObsPoint(observation_point_id, true, true)) !=
        NULL)
      obs_point->addProbeIp(device_ip);
  }
  inline u_int32_t getFlowDeviceIP() { return flow_device.device_ip; };
  inline u_int16_t getFlowObservationPointId() {
    return flow_device.observation_point_id;
  };
  inline u_int16_t get_observation_point_id() {
    return (getFlowObservationPointId());
  };
  inline u_int32_t getFlowDeviceInIndex() { return flow_device.in_index; };
  inline u_int32_t getFlowDeviceOutIndex() { return flow_device.out_index; };

  inline const u_int16_t getScore() const { return (flow_score); };

#ifdef HAVE_NEDGE
  inline void setLastConntrackUpdate(u_int32_t when) {
    last_conntrack_update = when;
  }
  bool isNetfilterIdleFlow() const;

  void setPacketsBytes(time_t now, u_int32_t s2d_pkts, u_int32_t d2s_pkts,
                       u_int64_t s2d_bytes, u_int64_t d2s_bytes);
  void getFlowShapers(bool src2dst_direction, TrafficShaper **shaper_ingress,
                      TrafficShaper **shaper_egress) {
    if (src2dst_direction) {
      *shaper_ingress = flowShaperIds.cli2srv.ingress,
      *shaper_egress = flowShaperIds.cli2srv.egress;
    } else {
      *shaper_ingress = flowShaperIds.srv2cli.ingress,
      *shaper_egress = flowShaperIds.srv2cli.egress;
    }
  }
  bool updateDirectionShapers(bool src2dst_direction,
                              TrafficShaper **ingress_shaper,
                              TrafficShaper **egress_shaper);
  void updateFlowShapers(bool first_update = false);
  void recheckQuota(const struct tm *now);
  inline u_int8_t getFlowRoutingTableId() { return (routing_table_id); }
  inline void setIngress2EgressDirection(bool _ingress2egress) {
    ingress2egress_direction = _ingress2egress;
  }
  inline bool isIngress2EgressDirection() { return (ingress2egress_direction); }
#endif
  void housekeep(time_t t);
  void setParsedeBPFInfo(const ParsedeBPF *const _ebpf, bool swap_directions);
  inline const ContainerInfo *getClientContainerInfo() const {
    return ebpf && ebpf->container_info_set ? &ebpf->src_container_info : NULL;
  }
  inline const ContainerInfo *getServerContainerInfo() const {
    return ebpf && ebpf->container_info_set ? &ebpf->dst_container_info : NULL;
  }
  inline const ProcessInfo *getClientProcessInfo() const {
    return ebpf && ebpf->process_info_set ? &ebpf->src_process_info : NULL;
  }
  inline const ProcessInfo *getServerProcessInfo() const {
    return ebpf && ebpf->process_info_set ? &ebpf->dst_process_info : NULL;
  }
  inline const TcpInfo *getClientTcpInfo() const {
    return ebpf && ebpf->tcp_info_set ? &ebpf->src_tcp_info : NULL;
  }
  inline const TcpInfo *getServerTcpInfo() const {
    return ebpf && ebpf->tcp_info_set ? &ebpf->dst_tcp_info : NULL;
  }

  inline bool isNotPurged() {
    return (getInterface()->isPacketInterface() &&
            getInterface()->is_purge_idle_interface() && (!idle()) &&
            is_active_entry_now_idle(10 * getInterface()->getFlowMaxIdle()));
  }

  inline u_int16_t getTLSVersion() {
    return (isTLS() ? protos.tls.tls_version : 0);
  }
  inline u_int32_t getTLSNotBefore() {
    return (isTLS() ? protos.tls.notBefore : 0);
  };
  inline u_int32_t getTLSNotAfter() {
    return (isTLS() ? protos.tls.notAfter : 0);
  };
  inline char *getTLSCertificateIssuerDN() {
    return (isTLS() ? protos.tls.issuerDN : NULL);
  }
  inline char *getTLSCertificateSubjectDN() {
    return (isTLS() ? protos.tls.subjectDN : NULL);
  }
  inline void setTLSCertificateIssuerDN(char *issuer) {
    if (protos.tls.issuerDN) free(protos.tls.issuerDN);
    protos.tls.issuerDN = strdup(issuer);
  }
  inline void setTOS(u_int8_t tos, bool is_cli_tos) {
    if (is_cli_tos) cli2srv_tos = tos;
    srv2cli_tos = tos;
  }
  inline u_int8_t getTOS(bool is_cli_tos) const {
    return (is_cli_tos ? cli2srv_tos : srv2cli_tos);
  }

  inline u_int8_t getCli2SrvDSCP() const { return (cli2srv_tos & 0xFC) >> 2; }
  inline u_int8_t getSrv2CliDSCP() const { return (srv2cli_tos & 0xFC) >> 2; }

  inline u_int8_t getCli2SrvECN() { return (cli2srv_tos & 0x3); }
  inline u_int8_t getSrv2CliECN() { return (srv2cli_tos & 0x3); }

  inline float getEntropy(bool src2dst_direction) {
    struct ndpi_analyze_struct *e = src2dst_direction
                                        ? initial_bytes_entropy.c2s
                                        : initial_bytes_entropy.s2c;

    return (e ? ndpi_data_entropy(e) : 0);
  }

  inline float getICMPPacketsEntropy() {
    return (protos.icmp.client_to_server.max_entropy -
            protos.icmp.client_to_server.min_entropy);
  }

  inline bool timeToPeriodicDump(u_int sec) {
    return ((sec - get_first_seen() >= CONST_DB_DUMP_FREQUENCY) &&
            (sec - get_partial_last_seen() >= CONST_DB_DUMP_FREQUENCY));
  }

  u_char *getCommunityId(u_char *community_id, u_int community_id_len);
  void setJSONRiskInfo(char *r);
  char *getJSONRiskInfo();
  void getJSONRiskInfo(ndpi_serializer *serializer);

  inline FlowTrafficStats *getTrafficStats() { return (&stats); };
  inline char *get_custom_category_file() const {
    return ((char *)ndpiDetectedProtocol.custom_category_userdata);
  }

  inline u_int8_t *getViewCliMac() { return (view_cli_mac); };
  inline u_int8_t *getViewSrvMac() { return (view_srv_mac); };

  inline u_int32_t getErrorCode() { return (protocolErrorCode); }
  inline void setErrorCode(u_int32_t rc) { protocolErrorCode = rc; }

  inline char *getAddressFamilyProtocol() const {
    return (ndpiAddressFamilyProtocol);
  }
  inline void setAddressFamilyProtocol(char *proto) {
    ndpiAddressFamilyProtocol = strdup(proto);
  }

  inline ndpi_confidence_t getConfidence() { return (confidence); }
  inline void setConfidence(ndpi_confidence_t rc) { confidence = rc; }

  inline u_int8_t getCliLocation() {
    if (cli_host && cli_host->isMulticastHost())
      return 2;  // Multicast host
    else if (cli_host && cli_host->isLocalHost())
      return 1;  // Local host
    else
      return 0;  // Remote host
  }
  inline u_int8_t getSrvLocation() {
    if (srv_host && srv_host->isMulticastHost())
      return 2;  // Multicast host
    else if (srv_host && srv_host->isLocalHost())
      return 1;  // Local host
    else
      return 0;  // Remote host
  }

  inline u_int32_t getPrivateFlowId() const { return (privateFlowId); }

  inline bool isCustomFlowAlertTriggered() {
    return (customFlowAlert.alertTriggered);
  }
  inline u_int8_t getCustomFlowAlertScore() { return (customFlowAlert.score); }
  inline char *getCustomFlowAlertMessage() { return (customFlowAlert.msg); }
  void triggerCustomFlowAlert(u_int8_t score, char *msg);
  inline void setRTPStreamType(enum ndpi_rtp_stream_type s) {
    rtp_stream_type = s;
  }
  inline enum ndpi_rtp_stream_type getRTPStreamType() {
    return (rtp_stream_type);
  }
  inline void setPeriodicFlow() { is_periodic_flow = 1; }
  inline bool isPeriodicFlow() { return (is_periodic_flow ? true : false); }
  void swap();
  bool isDPIDetectedFlow();
};

#endif /* _FLOW_H_ */

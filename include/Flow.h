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

#ifndef _FLOW_H_
#define _FLOW_H_

#include "ntop_includes.h"

typedef struct {
  u_int32_t pktRetr, pktOOO, pktLost, pktKeepAlive;
  u_int64_t last, next;
} TCPPacketStats;

typedef struct {
  struct timeval lastTime;
  u_int64_t total_delta_ms;
  float min_ms, max_ms;
} InterarrivalStats;

typedef struct {
  InterarrivalStats pktTime;
} FlowPacketStats;

typedef enum {
  flow_state_other = 0,
  flow_state_syn,
  flow_state_established,
  flow_state_rst,
  flow_state_fin,
} FlowState;

typedef enum {
  SSL_STAGE_UNKNOWN = 0,
  SSL_STAGE_HELLO,
  SSL_STAGE_CCS
} FlowSSLStage;

typedef enum {
  SSL_ENCRYPTION_PLAIN = 0x0,
  SSL_ENCRYPTION_SERVER = 0x1,
  SSL_ENCRYPTION_CLIENT = 0x2,
  SSL_ENCRYPTION_BOTH = 0x3,
} FlowSSLEncryptionStatus;

typedef struct buffered_packet {
  const struct pcap_pkthdr h;
  u_char *packet;
  struct buffered_packet *next;
} BufferedPacket;

class Flow : public GenericHashEntry {
 private:
  Host *cli_host, *srv_host;
  u_int16_t cli_port, srv_port;
  u_int16_t vlanId;
  FlowState state;
  u_int32_t vrfId;
  u_int8_t protocol, src2dst_tcp_flags, dst2src_tcp_flags;
  struct ndpi_flow_struct *ndpiFlow;
  BufferedPacket *flow_packets_head, *flow_packets_tail;
  bool detection_completed, protocol_processed, idle_flow,
    cli2srv_direction, twh_over, dissect_next_http_packet, passVerdict,
    check_tor, l7_protocol_guessed, flow_alerted, flow_dropped_counts_increased,
    good_low_flow_detected, good_ssl_hs,
    quota_exceeded, cli_quota_app_proto, cli_quota_is_category, srv_quota_app_proto, srv_quota_is_category;
  u_int16_t diff_num_http_requests;
#ifdef NTOPNG_PRO
  bool ingress2egress_direction;
  u_int8_t routing_table_id;
#ifndef HAVE_NEDGE
  FlowProfile *trafficProfile;
#else
  u_int16_t cli2srv_in, cli2srv_out, srv2cli_in, srv2cli_out;
#endif
  CounterTrend throughputTrend, goodputTrend, thptRatioTrend;
#endif
  ndpi_protocol ndpiDetectedProtocol;
  void *cli_id, *srv_id;
  char *json_info, *host_server_name, *bt_hash;
  bool dump_flow_traffic;
#ifdef HAVE_NEDGE
  u_int32_t last_conntrack_update; 
#endif
  
  union {
    struct {
      char *last_url, *last_method;
      char *last_content_type;
      u_int16_t last_return_code;
    } http;

    struct {
      char *last_query;
      bool invalid_query;
    } dns;

    struct {
      char *client_signature, *server_signature;
    } ssh;

    struct {
      char *certificate, *server_certificate;
      FlowSSLStage cli_stage, srv_stage;
      u_int8_t hs_packets;
      bool is_data;
      /* firstdata refers to the time where encryption is active on both ends */
      bool firstdata_seen;
      struct timeval clienthello_time, hs_end_time, lastdata_time;
      float hs_delta_time, delta_firstData, deltaTime_data;
    } ssl;

    struct {
      u_int8_t icmp_type, icmp_code;
      u_int16_t icmp_echo_id;
    } icmp;
  } protos;

  struct {
    u_int32_t device_ip;
    u_int16_t in_index, out_index;
  } flow_device;

  /* Process Information */
  ProcessInfo *client_proc, *server_proc;

  /* Stats */
  u_int32_t cli2srv_packets, srv2cli_packets;
  u_int64_t cli2srv_bytes, srv2cli_bytes;
  /* https://en.wikipedia.org/wiki/Goodput */
  u_int64_t cli2srv_goodput_bytes, srv2cli_goodput_bytes;

  /* TCP stats */
  TCPPacketStats tcp_stats_s2d, tcp_stats_d2s;
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

  FlowPacketStats cli2srvStats, srv2cliStats;

  /* Counter values at last host update */
  struct {
    u_int32_t cli2srv_packets, srv2cli_packets;
    u_int64_t cli2srv_bytes, srv2cli_bytes;
    u_int64_t cli2srv_goodput_bytes, srv2cli_goodput_bytes;
    u_int32_t last_dump;
  } last_db_dump;

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

  float bytes_thpt, goodput_bytes_thpt, top_bytes_thpt, top_goodput_bytes_thpt, top_pkts_thpt;
  float bytes_thpt_cli2srv, goodput_bytes_thpt_cli2srv;
  float bytes_thpt_srv2cli, goodput_bytes_thpt_srv2cli;
  float pkts_thpt, pkts_thpt_cli2srv, pkts_thpt_srv2cli;
  ValueTrend bytes_thpt_trend, goodput_bytes_thpt_trend, pkts_thpt_trend;
  //TimeSeries<float> *bytes_rate;
  u_int64_t cli2srv_last_packets, srv2cli_last_packets,
    prev_cli2srv_last_packets, prev_srv2cli_last_packets;
  u_int64_t cli2srv_last_bytes, srv2cli_last_bytes,
    cli2srv_last_goodput_bytes, srv2cli_last_goodput_bytes,
    prev_cli2srv_last_bytes, prev_srv2cli_last_bytes,
    prev_cli2srv_last_goodput_bytes, prev_srv2cli_last_goodput_bytes;

  //  tcpFlags = tp->th_flags, tcpSeqNum = ntohl(tp->th_seq), tcpAckNum = ntohl(tp->th_ack), tcpWin = ntohs(tp->th_win);
  char* intoaV4(unsigned int addr, char* buf, u_short bufLen);
  void processLua(lua_State* vm, ProcessInfo *proc, bool client);
  void processJson(bool is_src, json_object *my_object, ProcessInfo *proc);
  void allocDPIMemory();
  bool checkTor(char *hostname);
  void setBittorrentHash(char *hash);
  bool isLowGoodput();
  void updatePacketStats(InterarrivalStats *stats, const struct timeval *when);
  void dumpPacketStats(lua_State* vm, bool cli2srv_direction);
  inline bool isBlacklistedFlow() {
    return(cli_host && srv_host && (cli_host->isBlacklisted()
				    || srv_host->isBlacklisted()
				    || (((u_int8_t)ndpiDetectedProtocol.category) == CUSTOM_CATEGORY_MALWARE)));
  };
  inline u_int32_t getCurrentInterArrivalTime(time_t now, bool cli2srv_direction) {
    return(1000 /* msec */
	   * (now - (cli2srv_direction ? cli2srvStats.pktTime.lastTime.tv_sec : srv2cliStats.pktTime.lastTime.tv_sec)));
  }
  char* printTCPflags(u_int8_t flags, char *buf, u_int buf_len);
  inline bool isProto(u_int16_t p ) { return((ndpi_get_lower_proto(ndpiDetectedProtocol) == p) ? true : false); }
#ifdef NTOPNG_PRO
  void update_pools_stats(const struct timeval *tv,
			  u_int64_t diff_sent_packets, u_int64_t diff_sent_bytes,
			  u_int64_t diff_rcvd_packets, u_int64_t diff_rcvd_bytes);
#endif
  void dumpFlowAlert();

 public:
  Flow(NetworkInterface *_iface,
       u_int16_t _vlanId, u_int8_t _protocol,
       Mac *_cli_mac, IpAddress *_cli_ip, u_int16_t _cli_port,
       Mac *_srv_mac, IpAddress *_srv_ip, u_int16_t _srv_port,
       time_t _first_seen, time_t _last_seen);
  ~Flow();

  virtual void set_to_purge() {
    /* not called from the datapath for flows, so it is only
       safe to touch low goodput uses */
    if(good_low_flow_detected) {
      if(cli_host) cli_host->decLowGoodputFlows(true);
      if(srv_host) srv_host->decLowGoodputFlows(false);
    }
    GenericHashEntry::set_to_purge();
  };

  FlowStatus getFlowStatus();
  struct site_categories* getFlowCategory(bool force_categorization);
  void freeDPIMemory();
  bool isTiny();
  inline bool isSSL()                  { return(isProto(NDPI_PROTOCOL_SSL));  }
  inline bool isSSH()                  { return(isProto(NDPI_PROTOCOL_SSH));  }
  inline bool isDNS()                  { return(isProto(NDPI_PROTOCOL_DNS));  }
  inline bool isDHCP()                 { return(isProto(NDPI_PROTOCOL_DHCP)); }
  inline bool isHTTP()                 { return(isProto(NDPI_PROTOCOL_HTTP)); }
  inline bool isICMP()                 { return(isProto(NDPI_PROTOCOL_IP_ICMP) || isProto(NDPI_PROTOCOL_IP_ICMPV6)); }
  inline bool isMaskedFlow() {
    return(!get_cli_host() || Utils::maskHost(get_cli_host()->isLocalHost())
	   || !get_srv_host() || Utils::maskHost(get_srv_host()->isLocalHost()));
  };
  char* serialize(bool es_json = false);
  json_object* flow2json();
  json_object* flow2es(json_object *flow_object);
  inline u_int8_t getTcpFlags()        { return(src2dst_tcp_flags | dst2src_tcp_flags);  };
  inline u_int8_t getTcpFlagsCli2Srv() { return(src2dst_tcp_flags);                      };
  inline u_int8_t getTcpFlagsSrv2Cli() { return(dst2src_tcp_flags);                      };
#ifdef HAVE_NEDGE
  bool checkPassVerdict(const struct tm *now);
  bool isPassVerdict();
#endif
  void setDropVerdict();
  void incFlowDroppedCounters();

  u_int32_t getPid(bool client);
  u_int32_t getFatherPid(bool client);
  char* get_username(bool client);
  char* get_proc_name(bool client);
  u_int32_t getNextTcpSeq(u_int8_t tcpFlags, u_int32_t tcpSeqNum, u_int32_t payloadLen) ;
  double toMs(const struct timeval *t);
  void timeval_diff(struct timeval *begin, const struct timeval *end, struct timeval *result, u_short divide_by_two);
  char* getFlowInfo();
  inline char* getFlowServerInfo() {
    return (isSSL() && protos.ssl.certificate) ? protos.ssl.certificate : host_server_name;
  }
  inline char* getBitTorrentHash() { return(bt_hash);          };
  inline void  setBTHash(char *h)  { if(!h) return; if(bt_hash) { free(bt_hash); bt_hash = NULL; }; bt_hash = strdup(h); }
  inline void  setServerName(char *v)  { if(host_server_name) free(host_server_name);  host_server_name = strdup(v); }
  void updateTcpFlags(const struct bpf_timeval *when,
		      u_int8_t flags, bool src2dst_direction);
  void incTcpBadStats(bool src2dst_direction,
          u_int32_t ooo_pkts, u_int32_t retr_pkts, u_int32_t lost_pkts);

  void updateTcpSeqNum(const struct bpf_timeval *when,
		       u_int32_t seq_num, u_int32_t ack_seq_num,
		       u_int16_t window, u_int8_t flags,
		       u_int16_t payload_len, bool src2dst_direction);

  void updateSeqNum(time_t when, u_int32_t sN, u_int32_t aN);
  void processDetectedProtocol();
  void setDetectedProtocol(ndpi_protocol proto_id, bool forceDetection);
  void setJSONInfo(const char *json);
  bool isFlowPeer(char *numIP, u_int16_t vlanId);
  void incStats(bool cli2srv_direction, u_int pkt_len,
		u_int8_t *payload, u_int payload_len, u_int8_t l4_proto,
		const struct timeval *when);
  void addFlowStats(bool cli2srv_direction, u_int in_pkts, u_int in_bytes, u_int in_goodput_bytes,
		    u_int out_pkts, u_int out_bytes, u_int out_goodput_bytes, time_t last_seen);
  inline bool isDetectionCompleted()              { return(detection_completed);             };
  inline struct ndpi_flow_struct* get_ndpi_flow() { return(ndpiFlow);                        };
  inline void* get_cli_id()                       { return(cli_id);                          };
  inline void* get_srv_id()                       { return(srv_id);                          };
  inline u_int32_t get_cli_ipv4()                 { return(cli_host->get_ip()->get_ipv4());  };
  inline u_int32_t get_srv_ipv4()                 { return(srv_host->get_ip()->get_ipv4());  };
  inline struct ndpi_in6_addr* get_cli_ipv6()     { return(cli_host->get_ip()->get_ipv6());  };
  inline struct ndpi_in6_addr* get_srv_ipv6()     { return(srv_host->get_ip()->get_ipv6());  };
  inline u_int16_t get_cli_port()                 { return(ntohs(cli_port));                 };
  inline u_int16_t get_srv_port()                 { return(ntohs(srv_port));                 };
  inline u_int16_t get_vlan_id()                  { return(vlanId);                          };
  inline u_int8_t  get_protocol()                 { return(protocol);                        };
  inline u_int64_t get_bytes()                    { return(cli2srv_bytes+srv2cli_bytes);     };
  inline u_int64_t get_bytes_cli2srv()            { return(cli2srv_bytes);                   };
  inline u_int64_t get_bytes_srv2cli()            { return(srv2cli_bytes);                   };
  inline u_int64_t get_goodput_bytes()            { return(cli2srv_goodput_bytes+srv2cli_goodput_bytes);     };
  inline u_int64_t get_packets()                  { return(cli2srv_packets+srv2cli_packets); };
  inline u_int64_t get_packets_cli2srv()          { return(cli2srv_packets);                 };
  inline u_int64_t get_packets_srv2cli()          { return(srv2cli_packets);                 };
  inline u_int64_t get_partial_bytes()            { return(get_bytes() - (last_db_dump.cli2srv_bytes+last_db_dump.srv2cli_bytes));       };
  inline u_int64_t get_partial_bytes_cli2srv()    { return(cli2srv_bytes - last_db_dump.cli2srv_bytes);       };
  inline u_int64_t get_partial_bytes_srv2cli()    { return(srv2cli_bytes - last_db_dump.srv2cli_bytes);       };
  inline u_int64_t get_partial_packets_cli2srv()  { return(cli2srv_packets - last_db_dump.cli2srv_packets);   };
  inline u_int64_t get_partial_packets_srv2cli()  { return(srv2cli_packets - last_db_dump.srv2cli_packets);   };
  inline u_int64_t get_partial_goodput_bytes()    { return(get_goodput_bytes() - (last_db_dump.cli2srv_goodput_bytes+last_db_dump.srv2cli_goodput_bytes));       };
  inline u_int64_t get_partial_packets()          { return(get_packets() - (last_db_dump.cli2srv_packets+last_db_dump.srv2cli_packets)); };
  inline float get_bytes_thpt()                   { return(bytes_thpt);                      };
  inline float get_goodput_bytes_thpt()           { return(goodput_bytes_thpt);              };

  inline time_t get_partial_first_seen()          { return(last_db_dump.last_dump == 0 ? get_first_seen() : last_db_dump.last_dump); };
  inline time_t get_partial_last_seen()           { return(get_last_seen()); };
  inline u_int32_t get_duration()                 { return((u_int32_t)(get_last_seen()-get_first_seen())); };
  inline char* get_protocol_name()                { return(Utils::l4proto2name(protocol));   };
  inline ndpi_protocol get_detected_protocol()    { return(ndpiDetectedProtocol);          };
  void fixAggregatedFlowFields();
  inline ndpi_protocol_category_t get_detected_protocol_category() { return ndpi_get_proto_category(iface->get_ndpi_struct(), ndpiDetectedProtocol); };
  inline Host* get_cli_host()                     { return(cli_host);                        };
  inline Host* get_srv_host()                     { return(srv_host);                        };
  inline char* get_json_info()			  { return(json_info);                       };
  inline ndpi_protocol_breed_t get_protocol_breed() { return(ndpi_get_proto_breed(iface->get_ndpi_struct(), ndpiDetectedProtocol.app_protocol)); };
  inline char* get_protocol_breed_name()            { return(ndpi_get_proto_breed_name(iface->get_ndpi_struct(),
										       ndpi_get_proto_breed(iface->get_ndpi_struct(),
													    ndpiDetectedProtocol.app_protocol))); };
  char* get_detected_protocol_name(char *buf, u_int buf_len) {
    return(ndpi_protocol2name(iface->get_ndpi_struct(), ndpiDetectedProtocol, buf, buf_len));
  }

  u_int32_t get_packetsLost();
  u_int32_t get_packetsRetr();
  u_int32_t get_packetsOOO();

  u_int64_t get_current_bytes_cli2srv();
  u_int64_t get_current_bytes_srv2cli();
  u_int64_t get_current_goodput_bytes_cli2srv();
  u_int64_t get_current_goodput_bytes_srv2cli();
  u_int64_t get_current_packets_cli2srv();
  u_int64_t get_current_packets_srv2cli();
  void handle_process(ProcessInfo *pinfo, bool client_process);
  inline bool idle() { return(idle_flow); }
  bool isReadyToPurge();
  inline bool is_l7_protocol_guessed() { return(l7_protocol_guessed); };
  char* print(char *buf, u_int buf_len);
  void update_hosts_stats(struct timeval *tv);
  u_int32_t key();
  static u_int32_t key(Host *cli, u_int16_t cli_port,
		       Host *srv, u_int16_t srv_port,
		       u_int16_t vlan_id,
		       u_int16_t protocol);
  void lua(lua_State* vm, AddressTree * ptree, DetailsLevel details_level, bool asListElement);
  bool equal(IpAddress *_cli_ip, IpAddress *_srv_ip,
	     u_int16_t _cli_port, u_int16_t _srv_port,
	     u_int16_t _vlanId, u_int8_t _protocol,
	     bool *src2srv_direction);
  void sumStats(nDPIStats *stats);
  void guessProtocol();
  bool dumpFlow();
  bool dumpFlowTraffic(void);
  bool match(AddressTree *ptree);
  inline Host* get_real_client() { return(cli2srv_direction ? cli_host : srv_host); }
  inline Host* get_real_server() { return(cli2srv_direction ? srv_host : cli_host); }
  inline bool isSuspiciousFlowThpt();
  void dissectSSL(u_int8_t *payload, u_int16_t payload_len, const struct bpf_timeval *when, bool cli2srv);
  void dissectHTTP(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectSSDP(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectMDNS(u_int8_t *payload, u_int16_t payload_len);
  void dissectBittorrent(char *payload, u_int16_t payload_len);
  void updateInterfaceLocalStats(bool src2dst_direction, u_int num_pkts, u_int pkt_len);
  inline void setICMP(bool src2dst_direction, u_int8_t icmp_type, u_int8_t icmp_code, u_int8_t *icmpdata) {
    if(isICMP()) {
      protos.icmp.icmp_type = icmp_type, protos.icmp.icmp_code = icmp_code;
      if(get_cli_host()) get_cli_host()->incICMP(icmp_type, icmp_code, src2dst_direction ? true : false, get_srv_host());
      if(get_srv_host()) get_srv_host()->incICMP(icmp_type, icmp_code, src2dst_direction ? false : true, get_cli_host());
      protos.icmp.icmp_echo_id = ntohs(*((u_int16_t*)&icmpdata[4]));
    }
  }
  inline void getICMP(u_int8_t *_icmp_type, u_int8_t *_icmp_code, u_int16_t *_icmp_echo_id) {
    *_icmp_type = protos.icmp.icmp_type, *_icmp_code = protos.icmp.icmp_code, *_icmp_echo_id = protos.icmp.icmp_echo_id;
  }
  inline char* getDNSQuery()        { return(isDNS() ? protos.dns.last_query : (char*)"");  }
  inline void  setDNSQuery(char *v) { if(isDNS()) { if(protos.dns.last_query) free(protos.dns.last_query);  protos.dns.last_query = strdup(v); } }
  inline char* getHTTPURL()         { return(isHTTP() ? protos.http.last_url : (char*)"");   }
  inline void  setHTTPURL(char *v)  { if(isHTTP()) { if(protos.http.last_url) free(protos.http.last_url);  protos.http.last_url = strdup(v); } }
  inline char* getHTTPContentType() { return(isHTTP() ? protos.http.last_content_type : (char*)"");   }
  inline char* getSSLCertificate()  { return(isSSL() ? protos.ssl.certificate : (char*)""); }
  bool isSSLProto();
  inline bool isSSLData()              { return(isSSLProto() && good_ssl_hs && protos.ssl.is_data);  }
  inline bool isSSLHandshake()         { return(isSSLProto() && good_ssl_hs && !protos.ssl.is_data); }
  inline bool hasSSLHandshakeEnded()   { return(getSSLEncryptionStatus() == SSL_ENCRYPTION_BOTH);    }
  FlowSSLEncryptionStatus getSSLEncryptionStatus();
  void setDumpFlowTraffic(bool what)   { dump_flow_traffic = what; }
  bool getDumpFlowTraffic(void)        { return dump_flow_traffic; }

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  inline void updateProfile()     { trafficProfile = iface->getFlowProfile(this); }
  inline char* get_profile_name() { return(trafficProfile ? trafficProfile->getName() : (char*)"");}
#endif
  inline float getFlowRTT() { return(rttSec); }
  /* http://bradhedlund.com/2008/12/19/how-to-calculate-tcp-throughput-for-long-distance-links/ */
  inline float getCli2SrvMaxThpt() { return(rttSec ? ((float)(cli2srv_window*8)/rttSec) : 0); }
  inline float getSrv2CliMaxThpt() { return(rttSec ? ((float)(srv2cli_window*8)/rttSec) : 0); }

  inline u_int32_t getCli2SrvCurrentInterArrivalTime(time_t now) { return(getCurrentInterArrivalTime(now, true));  }
  inline u_int32_t getSrv2CliCurrentInterArrivalTime(time_t now) { return(getCurrentInterArrivalTime(now, false)); }

  inline u_int32_t getCli2SrvMinInterArrivalTime()  { return(cli2srvStats.pktTime.min_ms); }
  inline u_int32_t getCli2SrvMaxInterArrivalTime()  { return(cli2srvStats.pktTime.max_ms); }
  inline u_int32_t getCli2SrvAvgInterArrivalTime()  { return((cli2srv_packets < 2) ? 0 : cli2srvStats.pktTime.total_delta_ms / (cli2srv_packets-1)); }
  inline u_int32_t getSrv2CliMinInterArrivalTime()  { return(srv2cliStats.pktTime.min_ms); }
  inline u_int32_t getSrv2CliMaxInterArrivalTime()  { return(srv2cliStats.pktTime.max_ms); }
  inline u_int32_t getSrv2CliAvgInterArrivalTime()  { return((srv2cli_packets < 2) ? 0 : srv2cliStats.pktTime.total_delta_ms / (srv2cli_packets-1)); }
  bool isIdleFlow();
  inline FlowState getFlowState()                   { return(state);                          }
  inline bool      isEstablished()                  { return state == flow_state_established; }
  inline bool      isFlowAlerted()                  { return(flow_alerted);                   }
  inline void      setFlowAlerted()                 { flow_alerted = true;                    }
  inline void      setVRFid(u_int32_t v)            { vrfId = v;                              }

  inline bool      setFlowDevice(u_int32_t device_ip, u_int16_t inidx, u_int16_t outidx) {
    if((flow_device.device_ip > 0 && flow_device.device_ip != device_ip)
       || (flow_device.in_index > 0 && flow_device.in_index != inidx)
       || (flow_device.out_index > 0 && flow_device.out_index != outidx))
      return false;
    if(device_ip) flow_device.device_ip = device_ip;
    if(inidx)     flow_device.in_index = inidx;
    if(outidx)    flow_device.out_index = outidx;
    return true;
  }
  inline u_int32_t getFlowDeviceIp()       { return flow_device.device_ip; };
  inline u_int16_t getFlowDeviceInIndex()  { return flow_device.in_index;  };
  inline u_int16_t getFlowDeviceOutIndex() { return flow_device.out_index; };
#ifdef HAVE_NEDGE
  inline void setLastConntrackUpdate(u_int32_t when) { last_conntrack_update = when; }
  bool isNetfilterIdleFlow();
#endif
  
#ifdef HAVE_NEDGE
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
  void addPacketToDump(const struct pcap_pkthdr *h, const u_char *packet);
  void flushBufferedPackets();
  void housekeep();
};

#endif /* _FLOW_H_ */

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

#ifndef _NTOP_TYPEDEFS_H_
#define _NTOP_TYPEDEFS_H_

#ifndef __linux__
#ifndef TCP_ESTABLISHED
/* /usr/include/netinet/tcp.h */
enum {
      TCP_ESTABLISHED = 1,
      TCP_SYN_SENT,
      TCP_SYN_RECV,
      TCP_FIN_WAIT1,
      TCP_FIN_WAIT2,
      TCP_TIME_WAIT,
      TCP_CLOSE,
      TCP_CLOSE_WAIT,
      TCP_LAST_ACK,
      TCP_LISTEN,
      TCP_CLOSING   /* now a valid state */
};
#endif
#endif

typedef struct {
  const char *string;
  int64_t int_num;
  double double_num;
} ParsedValue;

typedef enum {
  no_host_mask = 0,
  mask_local_hosts = 1,
  mask_remote_hosts = 2
} HostMask;

/* Struct used to pass parameters when walking hosts and flows periodically to update their stats */
class AlertCheckLuaEngine;
typedef struct {
  NetworkInterface *iface;
  AlertCheckLuaEngine *acle;
  struct timeval *tv;
  time_t deadline;
  bool quick_update;
  bool skip_user_scripts;
} periodic_ht_state_update_user_data_t;

typedef struct {
  struct timeval *tv;
} periodic_stats_update_user_data_t;

/* Keep in sync with alert_consts.alerts_granularities and Utils */
typedef enum {
  no_periodicity = -1,
  aperiodic_script = 0,
  minute_script,
  five_minute_script,
  hour_script,
  day_script,
  MAX_NUM_PERIODIC_SCRIPTS /* IMPORTANT: leave it as last element */
} ScriptPeriodicity;

typedef enum {
  threshold_hourly = 0,
  threshold_daily
} ThresholdType;

typedef enum {
  trend_unknown = 0,
  trend_up = 1,
  trend_down = 2,
  trend_stable = 3
} ValueTrend;

typedef enum {
  location_none = 0,
  location_local_only,
  location_remote_only,
  location_broadcast_domain_only,
  location_all,
} LocationPolicy;

typedef enum {
  tcp_flow_state_filter_all = 0,
  tcp_flow_state_established,
  tcp_flow_state_connecting,
  tcp_flow_state_closed,
  tcp_flow_state_reset,
} TcpFlowStateFilter;

typedef enum {
  traffic_type_all = 0,
  traffic_type_one_way = 1,
  traffic_type_bidirectional = 2,
} TrafficType;

/* keep in sync with Utils::policySource */
typedef enum {
  policy_source_default = 0,
  policy_source_pool = 1,
  policy_source_protocol = 2,
  policy_source_category = 3,
  policy_source_device_protocol = 4,
  policy_source_schedule = 5,
} L7PolicySource_t;

/* Status are handled in Lua (alert_consts.lua) */
typedef uint8_t AlertType;
#define alert_none ((uint8_t)-1)

typedef enum {
  alert_level_none = -1,
  alert_level_info = 0,
  alert_level_warning,
  alert_level_error
} AlertLevel;

/*
  Keep in sync with alert_utils.lua:alert_entity_keys 
  This is field "entity_type" of JSON put on "ntopng.alerts.notifications_queue"
 */
typedef enum {
  alert_entity_none = -1,
  alert_entity_interface = 0,
  alert_entity_host,
  alert_entity_network,
  alert_entity_snmp_device,
  alert_entity_flow,
  alert_entity_mac,
  alert_entity_host_pool,
  alert_entity_process,
  alert_entity_user,
  alert_entity_influx_db,
} AlertEntity;

typedef enum {
  alert_on = 1,       /* An issue has been discovered and an alert has been triggered */
  alert_off = 2,      /* A previous alert has been fixed */
  alert_permanent = 3 /* Alert that can't be fixed (e.g. a flow with an anomaly) */
} AlertStatus;

typedef enum {
  IPV4 = 4,
  IPV6 = 6
} IPVersion;

#ifdef NTOPNG_PRO
typedef enum {
  status_ok = 0,
  status_warning,
} NagiosAlertStatus;
#endif

struct zmq_msg_hdr_v0 {
  char url[32];
  u_int32_t version;
  u_int32_t size;
};

struct zmq_msg_hdr {
  char url[16];
  u_int8_t version, source_id;
  u_int16_t size;
  u_int32_t msg_id;
};

typedef uint8_t dump_mac_t[DUMP_MAC_SIZE];
typedef char macstr_t[MACSTR_SIZE];

typedef struct {
  u_int8_t counter[NUM_MINUTES_PER_DAY];
} activity_bitmap;

enum SQLfield { SF_NONE, SF_SELECT, SF_FROM, SF_WHERE, SF_AND, SF_LIMIT, SF_TOK };

#ifndef __OpenBSD__
#define bpf_timeval timeval
#endif

typedef struct ether80211q {
  u_int16_t vlanId;
  u_int16_t protoType;
} Ether80211q;

typedef enum {
  ebpf_event_type_unknown = 0,
  ebpf_event_type_tcp_accept,
  ebpf_event_type_tcp_connect,
  ebpf_event_type_tcp_connect_failed,
  ebpf_event_type_tcp_close,
  epbf_event_type_tcp_retransmit,
  ebpf_event_type_udp_send,
  ebpf_event_type_udp_recv,
} eBPFEventType;

typedef struct {
  u_int32_t pid, father_pid;
  char *process_name, *father_process_name;
  char *uid_name, *father_uid_name;
  u_int32_t uid /* User Id */, gid; /* Group Id */
  u_int32_t father_uid /* User Id */, father_gid; /* Group Id */
  u_int32_t actual_memory, peak_memory;
} ProcessInfo;

typedef enum {
  container_info_data_type_unknown,
  container_info_data_type_k8s,
  container_info_data_type_docker
} ContainerInfoDataType;

typedef struct {
  char *id;
  char *name;
  union {
    struct {
      char *pod;
      char *ns;
    } k8s;
    struct {
      /* Reseved for future use */
    } docker;
  } data;
  ContainerInfoDataType data_type;
} ContainerInfo;

typedef struct {
  int conn_state;
  u_int64_t rcvd_bytes, sent_bytes;
  u_int32_t retx_pkts, lost_pkts;
  u_int32_t in_segs, out_segs, unacked_segs;
  double rtt, rtt_var;
} TcpInfo;

/* Handle vendor-proprietary applications.
   Must stay with 32-bit integers as, at least sonicwall, uses
   32-bit application ids. */
typedef struct {
  u_int32_t pen;
  u_int32_t app_id;
  u_int32_t remapped_app_id;
} custom_app_t;

/* IMPORTANT: whenever the Parsed_FlowSerial is changed, nProbe must be updated too */


typedef struct zmq_remote_stats {
  char remote_ifname[32], remote_ifaddress[64];
  char remote_probe_address[64], remote_probe_public_address[64];
  u_int8_t  num_exporters;
  u_int64_t remote_bytes, remote_pkts, num_flow_exports;
  u_int32_t remote_ifspeed, remote_time, avg_bps, avg_pps;
  u_int32_t remote_lifetime_timeout, remote_idle_timeout;
  u_int32_t export_queue_full, too_many_flows, elk_flow_drops,
    sflow_pkt_sample_drops, flow_collection_drops, flow_collection_udp_socket_drops;
} ZMQ_RemoteStats;

typedef struct zmq_template {
  u_int32_t pen, field;
  const char *format, *name, *descr;
} ZMQ_Template;

typedef struct zmq_field_map {
  u_int32_t pen, field;
  const char *map;
} ZMQ_FieldMap;

typedef struct zmq_field_value_map {
  u_int32_t pen, field, value;
  const char *map;
} ZMQ_FieldValueMap;

struct vm_ptree {
  lua_State* vm;
  AddressTree *ptree;
};

struct active_flow_stats {
  u_int32_t num_flows,
    ndpi_bytes[NDPI_MAX_SUPPORTED_PROTOCOLS+NDPI_MAX_NUM_CUSTOM_PROTOCOLS],
    breeds_bytes[NUM_BREEDS];
};

struct grev1_header {
  u_int16_t flags_and_version;
  u_int16_t proto;
};

struct string_list {
  char *str;
  struct string_list *prev, *next;
};

/* Status are handled in Lua (flow_consts.lua) */
typedef uint8_t FlowStatus;
#define status_normal 0

typedef enum {
  flow_lua_call_protocol_detected = 0,
  flow_lua_call_flow_status_changed,
  flow_lua_call_periodic_update,
  flow_lua_call_idle,
} FlowLuaCall;

typedef enum {
  details_normal = 0,
  details_high,
  details_higher,
  details_max,
} DetailsLevel;

typedef enum {
  /* Flows */
  column_client = 0,
  column_server,
  column_vlan,
  column_proto_l4,
  column_ndpi,
  column_duration,
  column_thpt,
  column_bytes,
  column_info,
  column_client_rtt,
  column_server_rtt,
  /* Hosts */
  column_ip,
  column_alerts,
  column_name,
  column_since,
  column_asn,
  column_asname,
  column_local_network_id,
  column_local_network,
  column_country,
  column_mac,
  column_os,
  column_num_flows, /* = column_incomingflows + column_outgoingflows */
  column_num_dropped_flows, /* for bridge interfaces */
  /* column_thpt, */
  column_traffic,
  /* sort criteria */
  column_traffic_sent,
  column_traffic_rcvd,
  column_traffic_unknown,
  column_num_flows_as_client,
  column_num_flows_as_server,
  column_total_num_anomalous_flows_as_client,
  column_total_num_anomalous_flows_as_server,
  column_total_num_unreachable_flows_as_client,
  column_total_num_unreachable_flows_as_server,
  column_total_alerts,
  column_pool_id,
  /* Macs */
  column_num_hosts,
  column_manufacturer,
  column_device_type,
  column_arp_total,
  column_arp_sent,
  column_arp_rcvd
} sortField;

typedef struct {
  u_int32_t deviceIP, ifIndex, ifType, ifSpeed;
  char *ifName;
  bool ifFullDuplex, ifAdminStatus, ifOperStatus, ifPromiscuousMode;
  u_int64_t ifInOctets, ifInPackets, ifInErrors,
    ifOutOctets, ifOutPackets, ifOutErrors;
  ContainerInfo container_info;
  bool container_info_set;
} sFlowInterfaceStats;

typedef struct {
  const char *class_name;
  const luaL_Reg *class_methods;
} ntop_class_reg;

typedef enum {
  callback_flow_create,
  callback_flow_delete,
  callback_flow_update,
  callback_flow_proto_callback
} LuaCallback;

typedef enum {
  user_script_context_inline,
  user_script_context_periodic,
} UserScriptContext;

typedef enum {
  walker_hosts = 0,
  walker_flows,
  walker_macs,
  walker_ases,
  walker_countries,
  walker_vlans,
} WalkerType;

typedef enum {
  flowhashing_none = 0,
  flowhashing_probe_ip,
  flowhashing_iface_idx,
  flowhashing_ingress_iface_idx,
  flowhashing_vlan,
  flowhashing_vrfid /* VRF Id */
} FlowHashingEnum;

typedef enum {
  hash_entry_state_allocated = 0,
  hash_entry_state_flow_notyetdetected,   /* Flow only */
  hash_entry_state_flow_protocoldetected, /* Flow only */
  hash_entry_state_active,
  hash_entry_state_idle,
} HashEntryState;

typedef enum {
  device_proto_allowed = 0,
  device_proto_forbidden_master,
  device_proto_forbidden_app
} DeviceProtoStatus;

struct keyval {
  const char *key;
  char *val;
};

typedef struct {
  u_int64_t shadow_head;
  u_char __cacheline_padding_1[56];
  volatile u_int64_t head;
  u_char __cacheline_padding_2[56];
  volatile u_int64_t tail;
  u_char __cacheline_padding_3[56];
  u_int64_t shadow_tail;
  u_char __cacheline_padding_4[56];
  void *items[QUEUE_ITEMS];
} spsc_queue_t;

class StringCache {
 public:
  std::string value;
  time_t expire;
};

PACK_ON

struct arp_header {
  u_int16_t ar_hrd;/* Format of hardware address.  */
  u_int16_t ar_pro;/* Format of protocol address.  */
  u_int8_t  ar_hln;/* Length of hardware address.  */
  u_int8_t  ar_pln;/* Length of protocol address.  */
  u_int16_t ar_op;/* ARP opcode (command).  */
  u_char arp_sha[6];/* sender hardware address */
  u_int32_t arp_spa;/* sender protocol address */
  u_char arp_tha[6];/* target hardware address */
  u_int32_t arp_tpa;/* target protocol address */
} PACK_OFF;

PACK_ON
struct arp_packet {
  u_char dst_mac[6], src_mac[6];
  u_int16_t proto;
  struct arp_header arph;
} PACK_OFF;

PACK_ON
struct dhcp_packet {
  u_int8_t	msgType;
  u_int8_t	htype;
  u_int8_t	hlen;
  u_int8_t	hops;
  u_int32_t	xid;/* 4 */
  u_int16_t	secs;/* 8 */
  u_int16_t	flags;
  u_int32_t	ciaddr;/* 12 */
  u_int32_t	yiaddr;/* 16 */
  u_int32_t	siaddr;/* 20 */
  u_int32_t	giaddr;/* 24 */
  u_int8_t	chaddr[16]; /* 28 */
  u_int8_t	sname[64]; /* 44 */
  u_int8_t	file[128]; /* 108 */
  u_int32_t	magic; /* 236 */
  u_int8_t	options[308];
} PACK_OFF;

/* http://en.wikipedia.org/wiki/SCTP_packet_structure */
PACK_ON
struct sctphdr {
  /* Common Header */
  u_int16_t sport, dport;
  u_int32_t verification_tag; /* A 32-bit random value created during initialization to distinguish stale packets from a previous connection. */
  u_int32_t checksum; /*  CRC32c algorithm */
} PACK_OFF;

#ifdef NTOPNG_PRO

typedef struct {
  char *host_or_mac;
  time_t lifetime;
  UT_hash_handle hh; /* makes this structure hashable */
} volatile_members_t;

#endif

/*
  NOTE:
  Keep in sync with discover.lua (asset_icons)
*/
typedef enum {
  device_unknown = 0,
  device_printer,
  device_video,
  device_workstation,
  device_laptop,
  device_tablet,
  device_phone,
  device_tv,
  device_networking,
  device_wifi,
  device_nas,
  device_multimedia,
  device_iot,
  
  device_max_type /* Leave it at the end */
} DeviceType;

typedef struct {
  NDPI_PROTOCOL_BITMASK clientAllowed, serverAllowed;
} DeviceProtocolBitmask;

#ifndef HAVE_NEDGE
class SNMP;
#endif

typedef struct {
  u_int32_t pktRetr, pktOOO, pktLost, pktKeepAlive;
} FlowTCPPacketStats;

typedef struct {
  u_int8_t num_get, num_post, num_head, num_put, num_other;
  u_int8_t num_1xx, num_2xx, num_3xx, num_4xx, num_5xx;
} FlowHTTPStats;

typedef struct {
  u_int8_t num_a, num_ns, num_cname, num_soa,
    num_ptr, num_mx, num_txt, num_aaaa,
    num_any, num_other;
  u_int8_t num_replies_ok, num_replies_error;
} FlowDNSStats;

/* Forward class declarations for the Lua context */
class NetworkStats;
class Host;
class Flow;

struct ntopngLuaContext {
  char *allowed_ifname, *user, *group;
  void *zmq_context, *zmq_subscriber;
  struct mg_connection *conn;
  AddressTree *allowedNets;
  NetworkInterface *iface;
  AddressTree *addr_tree;
#ifndef WIN32
  Ping *ping;
#endif
#ifndef HAVE_NEDGE
  SNMP *snmp;
#endif
  Host *host;
  NetworkStats *network;
  Flow *flow;
  bool localuser;

  /* Packet capture */
  struct {
    bool captureInProgress;
    pthread_t captureThreadLoop;
    pcap_t *pd;
    pcap_dumper_t *dumper;
    u_int32_t end_capture;
  } pkt_capture;

  /* Live capture written to mongoose socket */
  struct {
    u_int32_t capture_until, capture_max_pkts, num_captured_packets;
    void *matching_host;
    bool bpfFilterSet;
    struct bpf_program fcode;
    
    /* Status */
    bool pcaphdr_sent;
    bool stopped;
  } live_capture;
};

typedef enum {
  located_on_lan_interface = 1,
  located_on_wan_interface,
  located_on_unknown_interface,
} MacLocation;

typedef enum {
  interface_type_UNKNOWN = 0,
  interface_type_PCAP,
  interface_type_PCAP_DUMP,
  interface_type_ZMQ,
  interface_type_VLAN,
  interface_type_FLOW,
  interface_type_VIEW,
  interface_type_PF_RING,
  interface_type_NETFILTER,
  interface_type_DIVERT,
  interface_type_DUMMY,
  interface_type_ZC_FLOW,
  interface_type_SYSLOG 
} InterfaceType;

/* Update Flow::dissectHTTP when extending the type below */
/* Keep in sync with discover.os2label */
typedef enum {
  os_unknown = 0,
  os_linux,
  os_windows,
  os_macos,
  os_ios,
  os_android,
  os_laserjet,
  os_apple_airport,
  os_max_os /* Keep as last element */
} OperatingSystem;

/* Action to be performed after ntopng shutdown*/
typedef enum {
  after_shutdown_nop = 0,
  after_shutdown_reboot = 1,
  after_shutdown_poweroff = 2,
  after_shutdown_restart_self = 3,
} AfterShutdownAction;

typedef struct {
  bool admin;
  char *allowedIfname;
  char *allowedNets;
  char *language;
} HTTPAuthenticator;

typedef struct {
  double namelookup, connect, appconnect, pretransfer, redirect, start, total;
} HTTPTranferStats;

typedef struct {
  lua_State* vm;
  time_t last_conn_check;
} ProgressState;

struct pcap_disk_timeval {
  u_int32_t tv_sec;
  u_int32_t tv_usec;
};

struct pcap_disk_pkthdr {
  struct pcap_disk_timeval ts; /* time stamp                    */
  u_int32_t caplen;            /* length of portion present     */
  u_int32_t len;               /* length this packet (off wire) */
};

typedef struct dhcp_range {
  IpAddress first_ip;
  IpAddress last_ip;
} dhcp_range;

typedef struct cpu_load_stats {
  float load;
} cpu_load_stats;

typedef struct grouped_alerts_counters {
  std::map<AlertType, u_int32_t> types;
  std::map<AlertLevel, u_int32_t> severities;
} grouped_alerts_counters;

/* ICMP stats required for timeseries generation */
typedef struct ts_icmp_stats {
  u_int16_t echo_packets_sent;
  u_int16_t echo_packets_rcvd;
  u_int16_t echo_reply_packets_sent;
  u_int16_t echo_reply_packets_rcvd;
} ts_icmp_stats;

class AlertableEntity;
typedef void (alertable_callback)(AlertableEntity *alertable, void *user_data);

typedef struct bcast_domain_info {
  bool is_interface_network;
  u_int64_t hits;
} bcast_domain_info;

typedef enum mud_recording {
  mud_recording_disabled = 0,
  mud_recording_general_purpose = 1,
  mud_recording_special_purpose = 2,
} MudRecording;

#endif /* _NTOP_TYPEDEFS_H_ */

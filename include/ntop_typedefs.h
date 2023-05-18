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
  TCP_CLOSING /* now a valid state */
};
#endif
#endif

typedef struct {
  const char *string;
  int64_t int_num;
  double double_num;
  bool boolean;
} ParsedValue;

typedef enum {
  no_host_mask = 0,
  mask_local_hosts = 1,
  mask_remote_hosts = 2
} HostMask;

/* Struct used to pass parameters when walking hosts and flows periodically to
 * update their stats */
class AlertCheckLuaEngine;
class ThreadedActivityStats;
typedef struct {
  lua_State *vm;
  NetworkInterface *iface;
  AlertCheckLuaEngine *acle;
  struct timeval *tv;
  time_t deadline;
  bool no_time_left;
  bool skip_checks;
  ThreadedActivityStats *thstats;
  u_int32_t cur_entries;
  u_int32_t tot_entries;
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
  /* IMPORTANT: update MAX_NUM_PERIODIC_SCRIPTS as new entries are added */
} ScriptPeriodicity;

typedef enum {
  check_category_other = 0,
  check_category_security = 1,
  check_category_internals = 2,
  check_category_network = 3,
  check_category_system = 4,
  check_category_ids_ips = 5, /* Intrusion prevention. Used for checks that add
                                 hosts to the jailed pool */
  MAX_NUM_SCRIPT_CATEGORIES
} CheckCategory; /* Keep in sync with checks.check_categories in
                    scripts/lua/modules/checks.lua  */

typedef enum {
  alert_category_other = 0,
  alert_category_security = 1,
  alert_category_internals = 2,
  alert_category_network = 3,
  alert_category_system = 4,
  alert_category_ids_ips = 5,
  MAX_NUM_ALERT_CATEGORIES
} AlertCategory; /* TODO: keep in sync with CheckCategory until we remove
                    CheckCategory */

/*
  This is a subset of CheckCategory as flow scripts fall only in this subset
 */
typedef enum {
  score_category_network = 0,
  score_category_security,
  MAX_NUM_SCORE_CATEGORIES
} ScoreCategory;

#define MAX_NUM_PERIODIC_SCRIPTS 6

typedef enum {
  trend_unknown = 0,
  trend_up = 1,
  trend_down = 2,
  trend_stable = 3
} ValueTrend;

typedef enum {
  location_none = 0,
  location_local_only,
  location_local_only_no_tx,
  location_local_only_no_tcp_tx,
  location_remote_only,
  location_remote_only_no_tx,
  location_remote_only_no_tcp_tx,
  location_broadcast_domain_only,
  location_private_only, /* Only 192.168.0.0/16 and other private */
  location_public_only,  /* Only non-private */
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
  traffic_type_unidirectional = 1,
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
typedef u_int32_t AlertType;
#define alert_none ((u_int8_t)-1)

typedef enum {
  alert_level_none = 0,
  alert_level_debug = 1,
  alert_level_info = 2,
  alert_level_notice = 3,
  alert_level_warning = 4,
  alert_level_error = 5,
  alert_level_critical = 6,
  alert_level_alert = 7,
  alert_level_emergency = 8,
  ALERT_LEVEL_MAX_LEVEL = 9
} AlertLevel;

/*
  Used to group alert score into coarser-grained groups.
 */
typedef enum {
  alert_level_group_none = 0,
  alert_level_group_notice_or_lower = 1,
  alert_level_group_warning = 2,
  alert_level_group_error = 3,
  alert_level_group_critical = 4,
  alert_level_group_emergency = 5,
  ALERT_LEVEL_GROUP_MAX_LEVEL = 9,
} AlertLevelGroup;

/*
  Used to filter engaged alerts according to the role
  NOTE: Keep in sync with Lua alert_roles.lua
 */
typedef enum {
  alert_role_is_any = 0,
  alert_role_is_attacker = 1,
  alert_role_is_victim = 2,
  alert_role_is_client = 3,
  alert_role_is_server = 4,
  alert_role_is_none = 5,
} AlertRole;

/*
  Keep in sync with alert_entities.lua entity_id
 */
typedef enum {
  alert_entity_none = -1,
  alert_entity_interface = 0,
  alert_entity_host = 1,
  alert_entity_network = 2,
  alert_entity_snmp_device = 3,
  alert_entity_flow = 4,
  alert_entity_mac = 5,
  alert_entity_host_pool = 6,
  alert_entity_user = 7,
  alert_entity_am_host = 8,
  alert_entity_system = 9,
  alert_entity_test = 10,
  alert_entity_asn = 11,
  alert_entity_l7 = 12,

  /* Add new entities above ^ and do not exceed alert_entity_other */
  alert_entity_other = 15,
  ALERT_ENTITY_MAX_NUM_ENTITIES = 16
} AlertEntity;

typedef enum { IPV4 = 4, IPV6 = 6 } IPVersion;

struct zmq_msg_hdr_v0 {
  char url[32];
  u_int32_t version;
  u_int32_t size;
};

struct zmq_msg_hdr_v1 {
  char url[16];
  u_int8_t version, source_id;
  u_int16_t size;
  u_int32_t msg_id;
};

struct zmq_msg_hdr_v2 {
  char url[16];
  u_int8_t version;
  u_int16_t size;
  u_int32_t msg_id, source_id;
};

typedef u_int8_t dump_mac_t[DUMP_MAC_SIZE];
typedef char macstr_t[MACSTR_SIZE];

typedef struct {
  u_int8_t counter[NUM_MINUTES_PER_DAY];
} activity_bitmap;

enum SQLfield {
  SF_NONE,
  SF_SELECT,
  SF_FROM,
  SF_WHERE,
  SF_AND,
  SF_LIMIT,
  SF_TOK
};

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
  char *cmd_line;
  char *pkg_name, *father_pkg_name;
  char *uid_name, *father_uid_name;
  u_int32_t uid /* User Id */, gid;               /* Group Id */
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

/* IMPORTANT: whenever the Parsed_FlowSerial is changed, nProbe must be updated
 * too */

typedef struct zmq_remote_stats {
  char remote_ifname[32], remote_ifaddress[64];
  char remote_probe_address[64], remote_probe_public_address[64];
  char remote_probe_version[64], remote_probe_os[64];
  char remote_probe_license[64], remote_probe_edition[64];
  char remote_probe_maintenance[64];
  u_int8_t source_id, num_exporters;
  u_int64_t remote_bytes, remote_pkts, num_flow_exports;
  u_int32_t remote_ifspeed, remote_time, local_time, avg_bps, avg_pps;
  u_int32_t remote_lifetime_timeout, remote_idle_timeout,
      remote_collected_lifetime_timeout;
  u_int32_t export_queue_full, too_many_flows, elk_flow_drops,
      sflow_pkt_sample_drops, flow_collection_drops,
      flow_collection_udp_socket_drops;
  struct {
    u_int64_t nf_ipfix_flows;
    u_int64_t sflow_samples;
  } flow_collection;
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
  lua_State *vm;
  AddressTree *ptree;
};

struct active_flow_stats {
  u_int32_t num_flows,
      ndpi_bytes[NDPI_MAX_SUPPORTED_PROTOCOLS + NDPI_MAX_NUM_CUSTOM_PROTOCOLS],
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

typedef enum {
  flow_check_protocol_detected = 0,
  flow_check_periodic_update,
  flow_check_flow_end,
  flow_check_flow_begin,
  flow_check_flow_none /* Flow check not bound to protoDetected, periodicUpdate,
                          flowEnd, flowBegin */
} FlowChecks;

/* NOTE: Throw modules/alert_keys.lua as it has been merged with
 * modules/alert_keys.lua */
/* NOTE: keep in sync with modules/alert_keys/flow_alert_keys.lua */
typedef enum {
  flow_alert_normal = 0,
  flow_alert_blacklisted = 1,
  flow_alert_blacklisted_country = 2,
  flow_alert_flow_blocked = 3,
  flow_alert_data_exfiltration = 4,
  flow_alert_device_protocol_not_allowed = 5,
  flow_alert_dns_data_exfiltration = 6,
  flow_alert_dns_invalid_query = 7,
  flow_alert_elephant_flow = 8,
  flow_alert_notused_1 = 9,
  flow_alert_external = 10,
  flow_alert_longlived = 11,
  flow_alert_low_goodput = 12,
  flow_alert_notused_2 = 13,
  flow_alert_internals = 14,
  flow_alert_notused_3 = 15,
  flow_alert_remote_to_remote = 16,
  flow_alert_notused_4 = 17,
  flow_alert_notused_5 = 18,
  flow_alert_tcp_packets_issues = 19,
  flow_alert_tcp_connection_refused = 20,
  flow_alert_notused_7 = 21,
  flow_alert_ndpi_tls_certificate_expired = 22,
  flow_alert_ndpi_tls_certificate_mismatch = 23,
  flow_alert_ndpi_tls_old_protocol_version = 24,
  flow_alert_ndpi_tls_unsafe_ciphers = 25,
  flow_alert_ndpi_unidirectional_traffic = 26,
  flow_alert_web_mining_detected = 27,
  flow_alert_ndpi_tls_certificate_selfsigned = 28,
  flow_alert_ndpi_binary_application_transfer = 29,
  flow_alert_ndpi_known_proto_on_non_std_port = 30,
  flow_alert_noutused_8 = 31,
  flow_alert_unexpected_dhcp_server = 32,
  flow_alert_unexpected_dns_server = 33,
  flow_alert_unexpected_smtp_server = 34,
  flow_alert_unexpected_ntp_server = 35,
  flow_alert_zero_tcp_window = 36,
  flow_alert_iec_invalid_transition = 37,
  flow_alert_remote_to_local_insecure_proto = 38,
  flow_alert_ndpi_url_possible_xss = 39,
  flow_alert_ndpi_url_possible_sql_injection = 40,
  flow_alert_ndpi_url_possible_rce_injection = 41,
  flow_alert_ndpi_http_suspicious_user_agent = 42,
  flow_alert_ndpi_numeric_ip_host = 43,
  flow_alert_ndpi_http_suspicious_url = 44,
  flow_alert_ndpi_http_suspicious_header = 45,
  flow_alert_ndpi_tls_not_carrying_https = 46,
  flow_alert_ndpi_suspicious_dga_domain = 47,
  flow_alert_ndpi_malformed_packet = 48,
  flow_alert_ndpi_ssh_obsolete_server = 49,
  flow_alert_ndpi_smb_insecure_version = 50,
  flow_alert_ndpi_tls_suspicious_esni_usage = 51,
  flow_alert_ndpi_unsafe_protocol = 52,
  flow_alert_ndpi_dns_suspicious_traffic = 53,
  flow_alert_ndpi_tls_missing_sni = 54,
  flow_alert_iec_unexpected_type_id = 55,
  flow_alert_tcp_no_data_exchanged = 56,
  flow_alert_remote_access = 57,
  flow_alert_lateral_movement = 58,
  flow_alert_periodicity_changed = 59,
  flow_alert_ndpi_tls_cert_validity_too_long = 60,
  flow_alert_ndpi_ssh_obsolete_client = 61,
  flow_alert_ndpi_clear_text_credentials = 62,
  flow_alert_ndpi_http_suspicious_content = 63,
  flow_alert_ndpi_dns_large_packet = 64,
  flow_alert_ndpi_dns_fragmented = 65,
  flow_alert_ndpi_invalid_characters = 66,
  flow_alert_broadcast_non_udp_traffic = 67,
  flow_alert_ndpi_possible_exploit = 68,
  flow_alert_ndpi_tls_certificate_about_to_expire = 69,
  flow_alert_ndpi_punicody_idn = 70,
  flow_alert_ndpi_error_code_detected = 71,
  flow_alert_ndpi_http_crawler_bot = 72,
  flow_alert_ndpi_suspicious_entropy = 73,
  flow_alert_iec_invalid_command_transition = 74,
  flow_alert_connection_failed = 75,
  flow_alert_ndpi_anonymous_subscriber = 76,
  flow_alert_unidirectional_traffic = 77,
  flow_alert_ndpi_desktop_or_file_sharing_session = 78,
  flow_alert_ndpi_malicious_ja3 = 79,
  flow_alert_ndpi_malicious_sha1_certificate = 80,
  flow_alert_ndpi_tls_uncommon_alpn = 81,
  flow_alert_ndpi_tls_suspicious_extension = 82,
  flow_alert_ndpi_tls_fatal_alert = 83,
  flow_alert_ndpi_http_obsolete_server = 84,
  flow_alert_ndpi_risky_asn = 85,
  flow_alert_ndpi_risky_domain = 86,
  flow_alert_custom_lua_script = 87,
  flow_alert_ndpi_periodic_flow = 88,
  flow_alert_ndpi_minor_issues = 89,
  flow_alert_ndpi_tcp_issues = 90,
  flow_alert_vlan_bidirectional_traffic = 91,
  flow_alert_rare_destination = 92,

  MAX_DEFINED_FLOW_ALERT_TYPE, /* Leave it as last member */

  MAX_FLOW_ALERT_TYPE =
      127 /* Constrained by `Bitmap128 alert_map` inside Flow.h */
} FlowAlertTypeEnum;

typedef struct {
  FlowAlertTypeEnum id;
  AlertCategory category;
} FlowAlertType;

typedef struct {
  FlowAlertType alert_type;
  const char *alert_lua_name;
} FlowAlertTypeExtended;

/*
   Each C++ host check must have an entry here,
   returned with HostCheckID getID()
*/
typedef enum {
  host_alert_normal = 0,
  host_alert_smtp_server_contacts = 1,
  host_alert_dns_server_contacts = 2,
  host_alert_ntp_server_contacts = 3,
  host_alert_flow_flood = 4,
  host_alert_syn_scan = 5,
  host_alert_syn_flood = 6,
  host_alert_domain_names_contacts = 7,
  host_alert_p2p_traffic = 8,
  host_alert_dns_traffic = 9,
  host_alert_flows_anomaly = 10,
  host_alert_score_anomaly = 11,
  host_alert_remote_connection = 12,
  host_alert_host_log = 13,
  host_alert_dangerous_host = 14,
  host_alert_ntp_traffic = 15,
  host_alert_countries_contacts = 16,
  host_alert_score_threshold = 17,
  host_alert_icmp_flood = 18,
  host_alert_pkt_threshold = 19,
  host_alert_scan_detected = 20,
  host_alert_fin_scan = 21,
  host_alert_dns_flood = 22,
  host_alert_snmp_flood = 23,
  host_alert_custom_lua_script = 24,
  host_alert_rst_scan = 25,
  host_alert_traffic_volume = 26,
  host_alert_external_script = 27, /* Triggered from Lua (see rest/v2/trigger/host/alert.lua) */

  MAX_DEFINED_HOST_ALERT_TYPE, /* Leave it as last member */
  MAX_HOST_ALERT_TYPE = 32     /* Constrained by HostAlertBitmap */
} HostAlertTypeEnum;

typedef struct {
  HostAlertTypeEnum id;
  AlertCategory category;
} HostAlertType;

class HostAlert;
typedef std::pair<HostAlert *, bool> HostAlertReleasedPair;
typedef Bitmap<u_int32_t> HostAlertBitmap;

typedef enum {
  host_check_http_replies_requests_ratio = 0,
  host_check_dns_replies_requests_ratio,
  host_check_syn_flood,
  host_check_syn_scan,
  host_check_flow_flood,
  host_check_ntp_server_contacts,
  host_check_smtp_server_contacts,
  host_check_countries_contacts,
  host_check_dns_server_contacts,
  host_check_score_host,
  host_check_p2p_traffic,
  host_check_dns_traffic,
  host_check_flow_anomaly,
  host_check_score_anomaly,
  host_check_remote_connection,
  host_check_dangerous_host,
  host_check_ntp_traffic,
  host_check_domain_names_contacts,
  host_check_score_threshold,
  host_check_icmp_flood,
  host_check_pkt_threshold,
  host_check_scan_detection,
  host_check_mac_reassociation,
  host_check_fin_scan,
  host_check_dns_flood,
  host_check_snmp_flood,
  host_check_custom_lua_script,
  host_check_rst_scan,
  host_check_traffic_volume, /* Dummy check (see
                                ntop_interface_update_ip_reassignment) */
  host_check_external_script,

  NUM_DEFINED_HOST_CHECKS, /* Leave it as last member */
} HostCheckID;

typedef enum {
  flow_lua_call_exec_status_ok = 0, /* Call executed successfully */
  flow_lua_call_exec_status_not_executed_script_failure, /* Call NOT executed as
                                                            the script failed to
                                                            load (syntax?)   */
  flow_lua_call_exec_status_not_executed_no_time_left,   /* Call NOT executed as
                                                            the deadline was
                                                            approaching         */
  flow_lua_call_exec_status_not_executed_unknown_call,   /* Call NOT executed as
                                                            the function to be
                                                            called is unknown */
  flow_lua_call_exec_status_not_executed_shutdown_in_progress, /* Call NOT
                                                                  executed as a
                                                                  shutdown was
                                                                  in progress */
  flow_lua_call_exec_status_not_executed_vm_not_allocated, /* Call NOT executed
                                                              as the vm wasn't
                                                              allocated */
  flow_lua_call_exec_status_not_executed_not_pending, /* Call NOT executed as
                                                         other hooks have
                                                         already been exec.  */
  flow_lua_call_exec_status_unsupported_call, /* Call NOT executed as not
                                                 supported */
} FlowLuaCallExecStatus;

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
  column_device_ip,
  column_in_index,
  column_out_index,
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
  column_num_flows,         /* = column_incomingflows + column_outgoingflows */
  column_num_dropped_flows, /* for bridge interfaces */
  /* column_thpt, */
  column_traffic,
  /* sort criteria */
  column_traffic_sent,
  column_traffic_rcvd,
  column_traffic_unknown,
  column_num_flows_as_client,
  column_num_flows_as_server,
  column_total_num_alerted_flows_as_client,
  column_total_num_alerted_flows_as_server,
  column_total_num_unreachable_flows_as_client,
  column_total_num_unreachable_flows_as_server,
  column_total_num_retx_sent,
  column_total_num_retx_rcvd,
  column_total_alerts,
  column_pool_id,
  column_score,
  column_score_as_client,
  column_score_as_server,
  /* Macs */
  column_num_hosts,
  column_manufacturer,
  column_device_type,
  column_arp_total,
  column_arp_sent,
  column_arp_rcvd,
  column_last_seen,
  column_first_seen,
  column_obs_point,
  column_alerted_flows,
  column_tcp_udp_unresp_as_client,
  column_tcp_udp_unresp_as_server
} sortField;

typedef struct {
  u_int32_t samplesGenerated; /* The sequence number of this counter sample */
  u_int32_t deviceIP, ifIndex, ifType, ifSpeed;
  char *ifName;
  bool ifFullDuplex, ifAdminStatus, ifOperStatus, ifPromiscuousMode;
  u_int64_t ifInOctets, ifInPackets, ifInErrors, ifOutOctets, ifOutPackets,
      ifOutErrors;
  ContainerInfo container_info;
  bool container_info_set;
} sFlowInterfaceStats;

typedef struct {
  const char *class_name;
  const luaL_Reg *class_methods;
} ntop_class_reg;

typedef enum {
  walker_hosts = 0,
  walker_flows,
  walker_macs,
  walker_ases,
  walker_countries,
  walker_vlans,
  walker_oses,
  walker_obs
} WalkerType;

typedef enum {
  flowhashing_none = 0,
  flowhashing_probe_ip,
  flowhashing_iface_idx,
  flowhashing_ingress_iface_idx,
  flowhashing_vlan,
  flowhashing_vrfid, /* VRF Id */
  flowhashing_probe_ip_and_ingress_iface_idx,
} FlowHashingEnum;

typedef enum {
  hash_entry_state_allocated = 0,
  hash_entry_state_flow_notyetdetected,   /* Flow only */
  hash_entry_state_flow_protocoldetected, /* Flow only */
  hash_entry_state_active,
  hash_entry_state_idle,
} HashEntryState;

typedef enum {
  threaded_activity_state_unknown = -1,
  threaded_activity_state_sleeping,
  threaded_activity_state_queued,
  threaded_activity_state_running,
} ThreadedActivityState;

typedef enum {
  device_proto_allowed = 0,
  device_proto_forbidden_master,
  device_proto_forbidden_app
} DeviceProtoStatus;

struct keyval {
  const char *key;
  char *val;
};

class StringCache {
 public:
  std::string value;
  time_t expire;
};

PACK_ON

struct arp_header {
  u_int16_t ar_hrd;  /* Format of hardware address.  */
  u_int16_t ar_pro;  /* Format of protocol address.  */
  u_int8_t ar_hln;   /* Length of hardware address.  */
  u_int8_t ar_pln;   /* Length of protocol address.  */
  u_int16_t ar_op;   /* ARP opcode (command).  */
  u_char arp_sha[6]; /* sender hardware address */
  u_int32_t arp_spa; /* sender protocol address */
  u_char arp_tha[6]; /* target hardware address */
  u_int32_t arp_tpa; /* target protocol address */
} PACK_OFF;

PACK_ON
struct arp_packet {
  u_char dst_mac[6], src_mac[6];
  u_int16_t proto;
  struct arp_header arph;
} PACK_OFF;

PACK_ON
struct dhcp_packet {
  u_int8_t msgType;
  u_int8_t htype;
  u_int8_t hlen;
  u_int8_t hops;
  u_int32_t xid;  /* 4 */
  u_int16_t secs; /* 8 */
  u_int16_t flags;
  u_int32_t ciaddr;    /* 12 */
  u_int32_t yiaddr;    /* 16 */
  u_int32_t siaddr;    /* 20 */
  u_int32_t giaddr;    /* 24 */
  u_int8_t chaddr[16]; /* 28 */
  u_int8_t sname[64];  /* 44 */
  u_int8_t file[128];  /* 108 */
  u_int32_t magic;     /* 236 */
  u_int8_t options[308];
} PACK_OFF;

/* http://en.wikipedia.org/wiki/SCTP_packet_structure */
PACK_ON
struct sctphdr {
  /* Common Header */
  u_int16_t sport, dport;
  u_int32_t verification_tag; /* A 32-bit random value created during
                                 initialization to distinguish stale packets
                                 from a previous connection. */
  u_int32_t checksum;         /*  CRC32c algorithm */
} PACK_OFF;

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

class SNMP;

typedef struct {
  u_int32_t pktRetr, pktOOO, pktLost, pktKeepAlive;
} FlowTCPPacketStats;

typedef struct {
  u_int8_t num_get, num_post, num_head, num_put, num_other;
  u_int8_t num_1xx, num_2xx, num_3xx, num_4xx, num_5xx;
} FlowHTTPStats;

typedef struct {
  u_int8_t num_a, num_ns, num_cname, num_soa, num_ptr, num_mx, num_txt,
      num_aaaa, num_any, num_other;
  u_int8_t num_replies_ok, num_replies_error;
} FlowDNSStats;

/* Forward class declarations for the Lua context */
class NetworkStats;
class Host;
class Flow;
class ThreadedActivity;
class ThreadedActivityStats;

struct ntopngLuaContext {
  char *allowed_ifname, *user, *group, *csrf;
  char *sqlite_hosts_filter, *sqlite_flows_filter;
  bool sqlite_filters_loaded;
  void *zmq_context, *zmq_subscriber;
  struct mg_connection *conn;
  AddressTree *allowedNets;
  NetworkInterface *iface;
  AddressTree *addr_tree;
  SNMP *snmpBatch, *snmpAsyncEngine[MAX_NUM_ASYNC_SNMP_ENGINES];
  Host *host;
  NetworkStats *network;
  Flow *flow;
  bool localuser;
  u_int16_t observationPointId;

  /* Capabilities bitmap */
  u_int64_t capabilities;

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

    /* Partial sends */
    char send_buffer[1600];
    u_int data_not_yet_sent_len; /*
                                    Amount of data that was
                                    not sent mostly due to
                                    socket buffering
                                 */
  } live_capture;

  /*
     Indicate the time when the vm will be reloaded.
     This can be used so that Lua scripts running in an infinite-loop fashion,
     e.g., notifications.lua, can know when to break so they can be reloaded
     with new configurations. Useful when user scripts change or when recipient
     configurations change.
   */
  time_t next_reload;
  /* Periodic scripts (ThreadedActivity.cpp) */
  time_t deadline;
  const ThreadedActivity *threaded_activity;
  ThreadedActivityStats *threaded_activity_stats;

#if defined(NTOPNG_PRO)
  BinAnalysis *bin;
#endif
};

typedef enum {
  lan_interface = 1,
  wan_interface,
  other_interface,
  unknown_interface,
} InterfaceLocation;

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
  os_max_os, /* Keep as last element */
  os_any
} OSType;

/* Keep in sync with hosts_map_utils.lua */
typedef enum {
  ALL_FLOWS = 0,
  UNREACHABLE_FLOWS = 1,
  ALERTED_FLOWS = 2,
  DNS_QUERIES = 3,
  SYN_DISTRIBUTION = 4,
  SYN_VS_RST = 5,
  SYN_VS_SYNACK = 6,
  TCP_PKTS_SENT_VS_RCVD = 7,
  TCP_BYTES_SENT_VS_RCVD = 8,
  ACTIVE_ALERT_FLOWS = 9,
  TRAFFIC_RATIO = 10,
  SCORE = 11,
  BLACKLISTED_FLOWS_HOSTS = 12,
  HOSTS_TCP_FLOWS_UNIDIRECTIONAL = 13,
} HostWalkMode;

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

/*
  An enum to identify possible capabilities for non-admin web users.
  Enum i-th will represent the i-th bit in a 64-bit bitmap of user capabilities
 */
typedef enum {
  capability_pools = 0,
  capability_notifications = 1,
  capability_snmp = 2,
  capability_active_monitoring = 3,
  capability_preferences = 4,
  capability_developer = 5,
  capability_checks = 6,
  capability_flowdevices = 7,
  capability_alerts = 8,
  capability_historical_flows = 9,
  capability_pcap_download = 10,
  MAX_NUM_USER_CAPABILITIES = 11 /* Do NOT go above 63 */
} UserCapabilities;

typedef struct {
  double namelookup, connect, appconnect, pretransfer, redirect, start, total;
} HTTPTranferStats;

typedef struct {
  lua_State *vm;
  time_t last_conn_check;
  struct {
    u_int32_t download, upload;
  } bytes;
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
  std::map<std::pair<AlertEntity, AlertType>, u_int32_t> types;
  std::map<std::pair<AlertEntity, AlertLevel>, u_int32_t> severities;
} grouped_alerts_counters;

/* ICMP stats required for timeseries generation */
typedef struct ts_icmp_stats {
  u_int16_t echo_packets_sent;
  u_int16_t echo_packets_rcvd;
  u_int16_t echo_reply_packets_sent;
  u_int16_t echo_reply_packets_rcvd;
} ts_icmp_stats;

class AlertableEntity;
typedef void(alertable_callback)(AlertEntity alert_entity_type,
                                 AlertableEntity *alertable, void *user_data);

typedef struct bcast_domain_info {
  bool is_interface_network;
  u_int64_t hits;
} bcast_domain_info;

typedef enum ts_driver {
  ts_driver_rrd = 0,
  ts_driver_influxdb,
  ts_driver_prometheus
} TsDriver;

/* Wrapper for pcap_if_t and pfring_if_t */
typedef struct _ntop_if_t {
  /* pcap fields */
  char *name;
  char *description;
  /* PF_RING related fields */
  char *module;
  int license;
  _ntop_if_t *next;
} ntop_if_t;

typedef enum {
  service_allowed = 0,
  service_denied,
  service_undecided,
  service_unknown
} ServiceAcceptance;

typedef enum {
  ntopng_edition_community,
  ntopng_edition_pro,
  ntopng_edition_enterprise_m,
  ntopng_edition_enterprise_l
} NtopngEdition;

typedef enum {
  map_column_l7_protocol = 0,
  map_column_client,
  map_column_server,
  map_column_vlan,
  map_column_port,
  map_column_contacts,
  map_column_last_seen,
  map_column_observations,
  map_column_frequency,
  map_column_info,
  map_column_in_edges,
  map_column_out_edges,
  map_column_total_edges,
  map_column_host,
  map_column_rank
} mapSortingColumn;

typedef enum { asc = 0, desc } sortingOrder;

typedef struct _MapsFilters {
  bool periodicity_or_service;
  NetworkInterface *iface;
  u_int8_t *mac;
  IpAddress *ip;
  bool unicast;
  u_int16_t vlan_id;
  u_int16_t host_pool_id;
  u_int16_t port;
  u_int16_t ndpi_proto;
  int16_t network_id;
  u_int32_t first_seen;
  ServiceAcceptance status;
  char host_to_search[32];
  u_int32_t maxHits;
  u_int32_t startingHit;
  mapSortingColumn sort_column;
  sortingOrder sort_order;
  bool standard_view;
  u_int8_t cli_location;
  u_int8_t srv_location;
} MapsFilters;

typedef struct _MapsFilteringMenu {
  std::set<u_int16_t> *proto_map;
  std::set<u_int16_t> *vlan_map;
  std::set<u_int16_t> *pool_map;
} MapsFilteringMenu;

typedef struct {
  union {
    ipAddress ip;
    u_int8_t mac[6];
  } addr;
  u_int8_t by_mac : 1, not_used : 7;
} PeriodicityStatsPeerKey;

typedef struct {
  PeriodicityStatsPeerKey src, dst;
  u_int16_t vlan_id, server_port;
  u_int8_t l4_proto;
} PeriodicityStatsKey;

/* This enum is used to dump the confidences types to the db */
typedef enum { confidence_guessed = 0, confidence_dpi = 1 } ndpiConfidence;

typedef struct {
  u_int32_t bytes_sent;
  u_int32_t bytes_rcvd;
} InOutTraffic;

typedef enum {
  application_criteria = 1,
  client_criteria,
  server_criteria,
  client_server_criteria,
  app_client_server_criteria,
  info_criteria
} AnalysisCriteria;

#endif /* _NTOP_TYPEDEFS_H_ */

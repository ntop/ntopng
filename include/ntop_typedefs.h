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

#ifndef _NTOP_TYPEDEFS_H_
#define _NTOP_TYPEDEFS_H_

typedef enum {
  no_host_mask = 0,
  mask_local_hosts = 1,
  mask_remote_hosts = 2
} HostMask;

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
  location_all,
} LocationPolicy;

typedef enum {
  alert_none = -1,
  alert_syn_flood = 0,
  alert_flow_flood,
  alert_threshold_exceeded,
  alert_suspicious_activity,
  alert_interface_alerted,
  alert_flow_misbehaviour,
  alert_flow_remote_to_remote,
  alert_flow_blacklisted,
  alert_flow_blocked,
  alert_flow_web_mining = 21,
  alert_nfq_flushed = 22,
} AlertType; /*
	       NOTE:
	       keep it in sync with alert_type_keys
	       in ntopng/scripts/lua/modules/lua_utils.lua
	     */

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
  alert_entity_interface = 0,
  alert_entity_host,
  alert_entity_network,
  alert_entity_snmp_device,
  alert_entity_flow,
  alert_entity_mac,
  alert_entity_host_pool,
  alert_entity_process
} AlertEntity;

typedef enum {
  alert_engine_periodic_1min = 0,
  alert_engine_periodic_5min,
  alert_engine_periodic_hour,
  alert_engine_periodic_day,
} AlertEngine;

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
  u_int8_t version, _pad;
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

typedef struct {
  u_int32_t pid, father_pid;
  char name[48], father_name[48], user_name[48];
  u_int32_t actual_memory, peak_memory;
  float average_cpu_load, percentage_iowait_time;
  u_int32_t num_vm_page_faults;
} ProcessInfo;

typedef struct zmq_flow_core {
  u_int8_t version; /* 0 so far */
  IpAddress src_ip, dst_ip;
  u_int32_t deviceIP;
  u_int16_t src_port, dst_port, l7_proto, inIndex, outIndex;
  u_int16_t vlan_id, pkt_sampling_rate;
  u_int8_t l4_proto, tcp_flags;
  u_int32_t in_pkts, in_bytes, out_pkts, out_bytes, vrfId;
  u_int8_t absolute_packet_octet_counters;
  struct {
    u_int32_t ooo_in_pkts, ooo_out_pkts;
    u_int32_t retr_in_pkts, retr_out_pkts;
    u_int32_t lost_in_pkts, lost_out_pkts;
  } tcp;
  u_int32_t first_switched, last_switched;
  u_int8_t src_mac[6], dst_mac[6], direction, source_id;

  /* Extensions used only during serialization */
  u_int16_t extn_len;
  //char extn[];
} ZMQ_FlowCore;

typedef struct zmq_flow {
  ZMQ_FlowCore core;
  json_object *additional_fields;
  char *http_url, *http_site, *dns_query, *ssl_server_name, *bittorrent_hash;
  /* Process Extensions */
  ProcessInfo src_process, dst_process;
} ZMQ_Flow;

/* IMPORTANT: whenever the ZMQ_FlowSerial is changed, nProbe must be updated too */


typedef struct zmq_remote_stats {
  char remote_ifname[32], remote_ifaddress[64];
  char remote_probe_address[64], remote_probe_public_address[64];
  u_int8_t  num_exporters;
  u_int64_t remote_bytes, remote_pkts, num_flow_exports;
  u_int32_t remote_ifspeed, remote_time, avg_bps, avg_pps;
  u_int32_t remote_lifetime_timeout, remote_idle_timeout;
  u_int32_t export_queue_too_long, too_many_flows, elk_flow_drops, sflow_pkt_sample_drops;
} ZMQ_RemoteStats;

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

/*
  Remember to update
  - Utils.cpp      Utils::flowStatus2str()
  - lua_utils.lua  getFlowStatus(status)
 */
typedef enum {
  status_normal = 0,
  status_slow_tcp_connection /* 1 */,
  status_slow_application_header /* 2 */,
  status_slow_data_exchange /* 3 */,
  status_low_goodput /* 4 */,
  status_suspicious_tcp_syn_probing /* 5 */,
  status_tcp_connection_issues /* 6 - i.e. too many retransmission, ooo... or similar */,
  status_suspicious_tcp_probing /* 7 */,
  status_flow_when_interface_alerted /* 8 */,
  status_tcp_connection_refused /* 9 */,
  status_ssl_certificate_mismatch /* 10 */,
  status_dns_invalid_query /* 11 */,
  status_remote_to_remote /* 12 */,
  status_blacklisted /* 13 */,
  status_blocked /* 14 */,
  status_web_mining_detected /* 15 */,
} FlowStatus;

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
  column_uploaders,
  column_downloaders,
  column_unknowers,
  column_incomingflows,
  column_outgoingflows,
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
  bool ifFullDuplex, ifAdminStatus, ifOperStatus, ifPromiscuousMode;
  u_int64_t ifInOctets, ifInPackets, ifInErrors,
    ifOutOctets, ifOutPackets, ifOutErrors;
} sFlowInterfaceStats;

typedef struct {
  u_int32_t sent_requests, sent_replies;
  u_int32_t rcvd_requests, rcvd_replies;
} ArpStats;

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

typedef struct {
  char *key, *value;
  time_t expire;
  UT_hash_handle hh; /* makes this structure hashable */
} StringCache_t;

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

class SNMP; /* Forward */

struct ntopngLuaContext {
  char *allowed_ifname, *user;
  void *zmq_context, *zmq_subscriber;
  struct mg_connection *conn;
  AddressTree *allowedNets;
  NetworkInterface *iface;
  SNMP *snmp;

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
  interface_type_ZC_FLOW  
} InterfaceType;

/* Update Flow::dissectHTTP when extending the type below */
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
} AfterShutdownAction;

typedef struct {
  double namelookup, connect, appconnect, pretransfer, redirect, start, total;
} HTTPTranferStats;

struct pcap_disk_timeval {
  u_int32_t tv_sec;
  u_int32_t tv_usec;
};

struct pcap_disk_pkthdr {
  struct pcap_disk_timeval ts; /* time stamp                    */
  u_int32_t caplen;            /* length of portion present     */
  u_int32_t len;               /* length this packet (off wire) */
};

#endif /* _NTOP_TYPEDEFS_H_ */

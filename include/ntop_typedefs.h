/*
 *
 * (C) 2013-16 - ntop.org
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
  alert_syn_flood = 0,
  alert_flow_flood,
  alert_threshold_exceeded,
  alert_dangerous_host,
  alert_periodic_activity,
  alert_quota,
  alert_malware_detection,
  alert_host_under_attack,
  alert_host_attacker,
  alert_app_misconfiguration,
  alert_suspicious_activity,
  alert_too_many_alerts
} AlertType; /*
	       NOTE:
	       keep it in sync with alert_type_keys
	       in ntopng/scripts/lua/modules/lua_utils.lua
	     */

typedef enum {
  notify_all_alerts = 0,
  notify_errors_and_warnings,
  notify_errors_only,  
} SlackNotificationChoice;

typedef enum {
  alert_level_info = 0,
  alert_level_warning,
  alert_level_error,
} AlertLevel;

typedef enum {
  alert_entity_interface = 0,
  alert_entity_host,
  alert_entity_network,
  alert_entity_snmp_device,
  alert_entity_flow
} AlertEntity;

typedef enum {
  alert_on = 1,       /* An issue has been discovered and an alert has been triggered */
  alert_off = 2,      /* A previous alert has been fixed */
  alert_permanent = 3 /* Alert that can't be fixed (e.g. a flow with an anomaly) */
} AlertStatus;

typedef enum {
  no_refresh_needed = 0,
  refresh_after_delete,
  refresh_all_after_delete,
  refresh_after_init,
} AlertRefresh;

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

struct zmq_msg_hdr {
  char url[32];
  u_int32_t version;
  u_int32_t size;
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

typedef struct zmq_flow {
  IpAddress src_ip, dst_ip;
  u_int32_t deviceIP;
  u_int16_t src_port, dst_port, l7_proto, inIndex, outIndex;
  u_int16_t vlan_id, pkt_sampling_rate;
  u_int8_t l4_proto, tcp_flags;
  u_int32_t in_pkts, in_bytes, out_pkts, out_bytes;
  struct {
    u_int32_t ooo_in_pkts, ooo_out_pkts;
    u_int32_t retr_in_pkts, retr_out_pkts;
    u_int32_t lost_in_pkts, lost_out_pkts;
  } tcp;
  u_int32_t first_switched, last_switched;
  json_object *additional_fields;
  u_int8_t src_mac[6], dst_mac[6], direction, source_id;
  char *http_url, *http_site, *dns_query, *ssl_server_name, *bittorrent_hash;
  /* Process Extensions */
  ProcessInfo src_process, dst_process;
} ZMQ_Flow;

struct vm_ptree {
  lua_State* vm;
  patricia_tree_t *ptree;
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
  - Utils.cpp      Utils::flowstatus2str()
  - lua_utils.lua  getFlowStatus(status)
 */
typedef enum {
  status_normal = 0,
  status_slow_tcp_connection /* 1 */,
  status_slow_application_header /* 2 */,
  status_slow_data_exchange /* 3 */,
  status_low_goodput /* 4 */,
  status_suspicious_tcp_syn_probing /* 5 */,
  status_connection_reset /* 6 */,
  status_suspicious_tcp_probing /* 7 */,
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
  column_local_network_id,
  column_country,
  column_mac,
  column_os,
  /* column_thpt, */
  column_traffic,
  /* sort criteria */
  column_uploaders,
  column_downloaders,
  column_unknowers,
  column_incomingflows,
  column_outgoingflows,
} sortField;

typedef struct {
  u_int32_t deviceIP, ifIndex, ifType, ifSpeed;
  bool ifFullDuplex, ifAdminStatus, ifOperStatus, ifPromiscuousMode;
  u_int64_t ifInOctets, ifInPackets, ifInErrors,
    ifOutOctets, ifOutPackets, ifOutErrors;
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
  user_activity_other = 0,
  user_activity_web,
  user_activity_media,
  user_activity_vpn,
  user_activity_mail_sync,
  user_activity_mail_send,
  user_activity_file_sharing,
  user_activity_file_transfer,
  user_activity_chat,
  user_activity_game,
  user_activity_remote_control,
  user_activity_social_network,

  UserActivitiesN /* Unused as value but useful to
		     getting the number of elements
		     in this datastructure
		  */
} UserActivityID;

typedef enum {
  ifa_facebook_stats = 0,
  ifa_twitter_stats,
  IFA_STATS_PROTOS_N
} InterFlowActivityProtos;

typedef enum {
  walker_hosts = 0,
  walker_flows,
  walker_macs
} WalkerType;


#endif /* _NTOP_TYPEDEFS_H_ */

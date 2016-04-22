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
  alert_host_attacker
} AlertType;

typedef enum {
  alert_level_info = 0,
  alert_level_warning,
  alert_level_error,
} AlertLevel;

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
  u_int16_t src_port, dst_port, l7_proto;
  u_int16_t vlan_id, pkt_sampling_rate;
  u_int8_t l4_proto, tcp_flags;
  u_int32_t in_pkts, in_bytes, out_pkts, out_bytes;
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

#endif /* _NTOP_TYPEDEFS_H_ */

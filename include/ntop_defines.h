/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _NTOP_DEFINES_H_
#define _NTOP_DEFINES_H_

#include "ntop_flow.h"

#define NUM_ROOTS 512

/* ***************************************************** */

#ifndef ETHERTYPE_IP
#define	ETHERTYPE_IP		0x0800	/* IP protocol */
#endif

#ifndef ETHERTYPE_IPV6
#define	ETHERTYPE_IPV6		0x86DD	/* IPv6 protocol */
#endif

#ifndef ETHERTYPE_MPLS
#define	ETHERTYPE_MPLS		0x8847	/* MPLS protocol */
#endif

#ifndef ETHERTYPE_MPLS_MULTI
#define ETHERTYPE_MPLS_MULTI	0x8848	/* MPLS multicast packet */
#endif

#ifndef ETHERTYPE_ARP
#define	ETHERTYPE_ARP		0x0806	/* Address Resolution Protocol */
#endif

#ifndef ETHERTYPE_PPOE
#define ETHERTYPE_PPOE          0x8864
#endif

#ifndef ETHERTYPE_BATMAN
#define ETHERTYPE_BATMAN        0x4305
#endif

#ifndef IPPROTO_ICMPV6
#define IPPROTO_ICMPV6          58 /* ICMPv6 */
#endif



/* BSD AF_ values. */
#define BSD_AF_INET             2
#define BSD_AF_INET6_BSD        24      /* OpenBSD (and probably NetBSD), BSD/OS */
#define BSD_AF_INET6_FREEBSD    28
#define BSD_AF_INET6_DARWIN     30

/* ***************************************************** */

#ifndef min_val
#define min_val(a, b) ((a > b) ? b : a)
#endif

#ifndef max_val
#define max_val(a, b) ((a > b) ? a : b)
#endif

/* ***************************************************** */

#ifdef WIN32
#undef PACKAGE_OSNAME
#ifdef _WIN64
#define PACKAGE_OSNAME            "Win64"
#else
#define PACKAGE_OSNAME            "Win32"
#endif
#endif

#define MSG_VERSION               0
#define LOGIN_URL                 "/lua/login.lua"
#define AUTHORIZE_URL             "/authorize.html"
#define HTTP_SESSION_DURATION     43200
#define CONST_HTTPS_CERT_NAME     "ntopng-cert.pem"

#define NO_NDPI_PROTOCOL          ((u_int)-1)
#define NDPI_MIN_NUM_PACKETS      10
#define GTP_U_V1_PORT             2152
#define MAX_NUM_INTERFACE_HOSTS   131072
#define MAX_NUM_INTERFACES        48
#define MAX_INTERFACE_NAME_LEN    8

#define HOST_FAMILY_ID            ((u_int16_t)-1)
#define FLOW_PURGE_FREQUENCY      1 /* sec */
#define HOST_PURGE_FREQUENCY      1 /* sec */
#define MAX_TCP_FLOW_IDLE         3 /* sec - how long to delete a flow where the 3wh termination has been seen */
#define MAX_FLOW_IDLE            60 /* sec */
#define MAX_LOCAL_HOST_IDLE     300 /* sec */
#define MAX_REMOTE_HOST_IDLE     60 /* sec */
#define INTF_RRD_RAW_DAYS        1
#define INTF_RRD_1MIN_DAYS       30
#define INTF_RRD_1H_DAYS         100
#define INTF_RRD_1D_DAYS         365
#define OTHER_RRD_RAW_DAYS       1
#define OTHER_RRD_1MIN_DAYS      30
#define OTHER_RRD_1H_DAYS        100
#define OTHER_RRD_1D_DAYS        365
#define PURGE_FRACTION           32 /* check 1/32 of hashes per iteration */
#define MAX_NUM_QUEUED_ADDRS    500 /* Maximum number of queued address for resolution */
#define MAX_NUM_QUEUED_CONTACTS 25000
#define NTOP_COPYRIGHT          "(C) 1998-15 ntop.org"
#define DEFAULT_PID_PATH        "/var/tmp/ntopng.pid"
#define DOMAIN_CATEGORY         "ntopng.domain.category"
#define DOMAIN_TO_CATEGORIZE    "ntopng.domain.tocategorize"
#define DNS_CACHE               "ntopng.dns.cache"
#define DNS_TO_RESOLVE          "ntopng.dns.toresolve"
#define HTTPBL_CACHE            "ntopng.httpbl.cache"
#define HTTPBL_TO_RESOLVE       "ntopng.httpbl.toresolve"
#define DROP_HOST_TRAFFIC       "ntopng.prefs.drop_host_traffic"
#define DUMP_HOST_TRAFFIC       "ntopng.prefs.dump_host_traffic"
#define HOST_TRAFFIC_QUOTA      "ntopng.prefs.hosts_quota"
#define HTTPBL_CACHE_DURATIION  43200 /* 12 h */
#define DNS_CACHE_DURATION      3600  /*  1 h */
#define HOST_LABEL_NAMES        "ntopng.host_labels"
#define NTOP_HOSTS_SERIAL       "ntopng.host_serial"
#define DUMMY_IFACE_ID          (-1)
#define MAX_CSRF_DURATION       300 /* 5 mins */
#define NTOP_NOLOGIN_USER	"nologin"

#define CONST_SAVE_HTTP_FLOWS_TRAFFIC "ntopng.prefs.http_traffic_dump"

#define CONST_ADMINISTRATOR_USER  "administrator"
#define CONST_UNPRIVILEGED_USER   "unprivileged"
#define CONST_STR_NTOPNG_LICENSE  "ntopng.license"
#define CONST_STR_USER_GROUP      "ntopng.user.%s.group"
#define CONST_STR_USER_FULL_NAME  "ntopng.user.%s.full_name"
#define CONST_STR_USER_PASSWORD   "ntopng.user.%s.password"
#define CONST_STR_USER_NETS       "ntopng.user.%s.allowed_nets"
#define CONST_ALLOWED_NETS        "allowed_nets"
#define CONST_USER                "user"
#define CONST_ES_QUEUE_NAME       "ntopng.es"

#define CONST_INTERFACE_TYPE_PCAP      "pcap"
#define CONST_INTERFACE_TYPE_PCAP_DUMP "pcap dump"
#define CONST_INTERFACE_TYPE_ZMQ       "zmq"
#define CONST_INTERFACE_TYPE_SQLITE    "sqlite"
#define CONST_INTERFACE_TYPE_PF_RING   "PF_RING"
#define CONST_INTERFACE_TYPE_NETFILTER "netfilter"
#define CONST_INTERFACE_TYPE_UNKNOWN   "unknown"

#define CONST_DEMO_MODE_DURATION       600 /* 10 min */
#define CONST_MAX_DUMP_DURATION        300 /* 5 min */
#define CONST_DUMP_SAMPLING_RATE       1000 /* 1/ */
#define CONST_MAX_NUM_PACKETS_PER_DUMP 1000000
#define CONST_MAX_DUMP                 500000000

#define CONST_EST_MAX_FLOWS            200000
#define CONST_EST_MAX_HOSTS            200000

#define BATADV_COMPAT_VERSION_15 15
#define BATADV_COMPAT_VERSION_14 14

//batman-adv compat version 14 packet types
#define BATADV14_IV_OGM		 0x01
#define BATADV14_ICMP		 0x02
#define BATADV14_UNICAST	 0x03
#define BATADV14_BCAST		 0x04
#define BATADV14_VIS		 0x05
#define BATADV14_UNICAST_FRAG	 0x06
#define BATADV14_TT_QUERY	 0x07 
#define BATADV14_ROAM_ADV	 0x08 
#define BATADV14_UNICAST_4ADDR	 0x09
#define BATADV14_CODED		 0x0a


// batman-adv compat version 15 packet types
#define BATADV15_IV_OGM          0x00
#define BATADV15_BCAST           0x01
#define BATADV15_CODED           0x02
#define BATADV15_UNICAST_MIN     0x40
#define BATADV15_UNICAST         0x40
#define BATADV15_UNICAST_FRAG    0x41
#define BATADV15_UNICAST_4ADDR   0x42
#define BATADV15_ICMP            0x43
#define BATADV15_UNICAST_TVLV    0x44
#define BATADV15_UNICAST_MAX     0x7f


#ifndef TH_FIN
#define	TH_FIN	0x01
#endif
#ifndef TH_SYN
#define	TH_SYN	0x02
#endif
#ifndef TH_RST
#define	TH_RST	0x04
#endif
#ifndef TH_PUSH
#define	TH_PUSH	0x08
#endif
#ifndef TH_ACK
#define	TH_ACK	0x10
#endif
#ifndef TH_URG
#define	TH_URG	0x20
#endif

#define MAX_NUM_DEFINED_INTERFACES 32
#define MAX_NUM_DB_SPINS            5 /* sec */

#ifndef MAX_PATH
#define MAX_PATH                  256
#endif

//#define DEMO_WIN32                   1
#define MAX_NUM_PACKETS             5000

#define MAX_NUM_VLAN                4096
#define DEFAULT_SHAPER_ID              0
#define NUM_TRAFFIC_SHAPERS           10
#define MAX_SHAPER_RATE_KBPS       10240
#define HOUSEKEEPING_FREQUENCY         5
#define MAX_NUM_HOST_CONTACTS         16
#define CONST_DEFAULT_NTOP_PORT     3000
#define CONST_DB_DUMP_FREQUENCY      300
#define CONST_MAX_NUM_NETWORKS       255
#define CONST_MAX_NUM_COMMUNITIES    255
#define CONST_NUM_OPEN_DB_CACHE        8
#define CONST_NUM_CONTACT_DBS          8
#define CONST_MAX_NUM_ZMQ_SUBSCRIBERS 32
#define CONST_MAX_NUM_FIND_HITS       10
#ifdef WIN32
#define ntop_mkdir(a, b) _mkdir(a)
#define CONST_PATH_SEP                    '\\'
#else
#define ntop_mkdir(a, b) mkdir(a, b)
#define CONST_PATH_SEP                    '/'
#endif

#define CONST_MAX_LEN_REDIS_KEY      256
#define CONST_MAX_LEN_REDIS_VALUE   4096

#define NTOPNG_NDPI_OS_PROTO_ID      (NDPI_LAST_IMPLEMENTED_PROTOCOL+NDPI_MAX_NUM_CUSTOM_PROTOCOLS-2)
#define CONST_DEFAULT_HOME_NET       "192.168.1.0/24"
#define CONST_DEFAULT_DATA_DIR       "/var/tmp/ntopng"
#define CONST_DEFAULT_DOCS_DIR       "httpdocs"
#define CONST_DEFAULT_SCRIPTS_DIR    "scripts"
#define CONST_DEFAULT_CALLBACKS_DIR  "scripts/callbacks"
#define CONST_DEFAULT_USERS_FILE     "ntopng-users.conf"
#define CONST_DEFAULT_WRITABLE_DIR   "/var/tmp"
#define CONST_DEFAULT_INSTALL_DIR    (DATA_DIR "/ntopng")
#define CONST_ALT_INSTALL_DIR        "/usr/share/ntopng"
#define CONST_HTTP_PREFIX_STRING     "@HTTP_PREFIX@"
#define CONST_DEFAULT_NTOP_USER      "nobody"
#define CONST_TOO_EARLY              "(Too Early)"
#define CONST_HTTP_CONN              "http.conn"
#define CONST_LUA_OK                  1
#define CONST_LUA_ERROR               0
#define CONST_LUA_PARAM_ERROR         -1
#define CONST_MAX_NUM_SYN_PER_SECOND  8192
#define CONST_MAX_NUM_HOST_ACTIVE_FLOWS 32768
#define CONST_MAX_NEW_FLOWS_SECOND    25
#define CONST_ALERT_GRACE_PERIOD      60 /* No more than 1 alert/min */
#define CONST_CONTACTED_BY            "contacted_by"
#define CONST_CONTACTS                "contacted_peers" /* Peers contacted by this host */

#define CONST_HISTORICAL_OK               1
#define CONST_HISTORICAL_FILE_ERROR       0
#define CONST_HISTORICAL_OPEN_ERROR      -1
#define CONST_HISTORICAL_ROWS_LIMIT       20960

#define CONST_AGGREGATIONS            "aggregations"
#define CONST_HOST_CONTACTS           "host_contacts"

#define CONST_ALERT_MSG_QUEUE         "ntopng.alert_queue"
#define CONST_ALERT_PREFS             "ntopng.prefs.alerts"
#define CONST_IFACE_ID_PREFS          "ntopng.prefs.iface_id"
#define CONST_LOCAL_HOST_IDLE_PREFS   "ntopng.prefs.local_host_max_idle"
#define CONST_REMOTE_HOST_IDLE_PREFS  "ntopng.prefs.non_local_host_max_idle"
#define CONST_FLOW_MAX_IDLE_PREFS     "ntopng.prefs.flow_max_idle"
#define CONST_MAX_NEW_FLOWS_PREFS     "ntopng.prefs.host_max_new_flows_sec_threshold"
#define CONST_MAX_NUM_SYN_PREFS       "ntopng.prefs.host_max_num_syn_sec_threshold"
#define CONST_MAX_NUM_FLOWS_PREFS     "ntopng.prefs.host_max_num_active_flows"
#define CONST_INTF_RRD_RAW_DAYS       "ntopng.prefs.intf_rrd_raw_days"
#define CONST_INTF_RRD_1MIN_DAYS      "ntopng.prefs.intf_rrd_1min_days"
#define CONST_INTF_RRD_1H_DAYS        "ntopng.prefs.intf_rrd_1h_days"
#define CONST_INTF_RRD_1D_DAYS        "ntopng.prefs.intf_rrd_1d_days"
#define CONST_OTHER_RRD_RAW_DAYS      "ntopng.prefs.other_rrd_raw_days"
#define CONST_OTHER_RRD_1MIN_DAYS     "ntopng.prefs.other_rrd_1min_days"
#define CONST_OTHER_RRD_1H_DAYS       "ntopng.prefs.other_rrd_1h_days"
#define CONST_OTHER_RRD_1D_DAYS       "ntopng.prefs.other_rrd_1d_days"

#define CONST_RUNTIME_PREFS_HOST_RRD_CREATION        "ntopng.prefs.host_rrd_creation" /* 0 / 1 */
#define CONST_RUNTIME_PREFS_HOST_NDPI_RRD_CREATION   "ntopng.prefs.host_ndpi_rrd_creation" /* 0 / 1 */
#define CONST_RUNTIME_PREFS_THPT_CONTENT             "ntopng.prefs.thpt_content"  /* bps / pps */
#define CONST_RUNTIME_PREFS_ALERT_SYSLOG             "ntopng.prefs.alerts_syslog"  /* 0 / 1 */
#ifdef NTOPNG_PRO
#define CONST_RUNTIME_PREFS_DAILY_REPORTS            "ntopng.prefs.daily_reports"  /* 0 / 1 */
#endif

#define CONST_MAX_ALERT_MSG_QUEUE_LEN 8192
#define CONST_MAX_ES_MSG_QUEUE_LEN    8192
#define CONST_MAX_NUM_READ_ALERTS     32
#define CONST_MAX_THRESHOLD_CROSS_DURATION 3
#define CONST_MAX_ACTIVITY_DURATION    86400 /* sec */
#define CONST_TREND_TIME_GRANULARITY   1 /* sec */
#define CONST_DEFAULT_PRIVATE_NETS     "192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,127.0.0.0/8"
#define CONST_DEFAULT_LOCAL_NETS       "0.0.0.0/32,224.0.0.0/8,239.0.0.0/8,255.255.255.255/32,127.0.0.0/8"

#define CONST_NUM_RESOLVERS            2

#define PAGE_NOT_FOUND     "<html><head><title>ntop</title></head><body><center><img src=/img/warning.png> Page &quot;%s&quot; was not found</body></html>"
#define PAGE_ERROR         "<html><head><title>ntop</title></head><body><img src=/img/warning.png> Script &quot;%s&quot; returned an error:<p>\n<pre>%s</pre></body></html>"
#define DENIED             "<html><head><title>Access denied</title></head><body>Access denied</body></html>"
#define ACCESS_FORBIDDEN   "<html><head><title>Access forbidden</title></head><body>Access forbidden</body></html>"

#define CONST_DB_DAY_FORMAT            "%y%m%d"

#define CONST_ANY_ADDRESS              "" /* Good for v4 and v6 */
#define CONST_LOOPBACK_ADDRESS         "127.0.0.1"

#define CONST_EPP_MAX_CMD_NUM          34

#define HTTPBL_DOMAIN                  "dnsbl.httpbl.org"
#define NULL_BL                        "''"
//#define DEBUG_HTTPBL

#define CATEGORIZATION_URL             "https://sb-ssl.google.com/safebrowsing/api/lookup"
#define CATEGORIZATION_CLIENT          "ntopng"
#define CATEGORIZATION_APPVER          "1.0"
#define CATEGORIZATION_PVER            "3.0"
#define CATEGORIZATION_NULL_CATEGORY   "''"
#define CATEGORIZATION_SAFE_SITE       "safe"

#ifdef __cplusplus
#define EXTERNC extern "C"
#else
#define EXTERNC
#endif

#ifdef WIN32

#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif

// internal name of the service
#define SZSERVICENAME        "ntopng"

// displayed name of the service
#define SZSERVICEDISPLAYNAME "ntopng"

  // Service TYPE Permissable values:
  //		SERVICE_AUTO_START
  //		SERVICE_DEMAND_START
  //		SERVICE_DISABLED
#define SERVICESTARTTYPE SERVICE_AUTO_START

#define EVENT_GENERIC_INFORMATION        0x40000001L

  // =========================================================
  // You should not need any changes below this line
  // =========================================================

  // Value name for app parameters
#define SZAPPPARAMS "AppParameters"

  // list of service dependencies - "dep1\0dep2\0\0"
  // If none, use ""
#define SZDEPENDENCIES ""
#endif

#ifndef min_val
#define min_val(a,b) ((a < b) ? a : b)
#endif

#ifndef max_val
#define max_val(a,b) ((a > b) ? a : b)
#endif

#define ifdot(a) ((a == '.') ? '_' : a)

#ifdef WIN32
#define unlink(a) _unlink(a)
#endif

#if defined(__arm__) || defined(__mips__) 
#define NTOPNG_EMBEDDED_EDITION         1
#endif

#endif /* _NTOP_DEFINES_H_ */

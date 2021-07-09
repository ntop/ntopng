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

#ifndef ETHERTYPE_PPPoE
#define ETHERTYPE_PPPoE         0x8864
#endif

#ifndef IPPROTO_ICMPV6
#define IPPROTO_ICMPV6          58 /* ICMPv6 */
#endif

/* should be defined in linux/if_ether.h */
#ifndef ETH_P_ERSPAN2
#define ETH_P_ERSPAN2           0x22EB  /* ERSPAN version 2 (type III) */
#endif
#ifndef ETH_P_ERSPAN
#define ETH_P_ERSPAN            0x88BE  /* ERSPAN type II */
#endif

#ifndef IPPROTO_IP_IN_IP
#define IPPROTO_IP_IN_IP          0x04
#endif

/* BSD AF_ values. */
#define BSD_AF_INET             2
#define BSD_AF_INET6_BSD        24      /* OpenBSD (and probably NetBSD), BSD/OS */
#define BSD_AF_INET6_FREEBSD    28
#define BSD_AF_INET6_DARWIN     30

#ifndef SPEED_UNKNOWN
#define SPEED_UNKNOWN           -1
#endif

/* ***************************************************** */

#ifndef min_val
#define min_val(a, b) ((a > b) ? b : a)
#endif

#ifndef max_val
#define max_val(a, b) ((a > b) ? a : b)
#endif

/* ********************************************* */

#ifdef WIN32
#define likely(x)       (x)
#define unlikely(x)     (x)
#else
#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)
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

#define ZMQ_COMPATIBILITY_MSG_VERSION 1
#define ZMQ_MSG_VERSION           2
#define ZMQ_MSG_VERSION_TLV       3
#define LOGIN_URL                 "/lua/login.lua"
#define LOGOUT_URL                "/lua/logout.lua"
#define CAPTIVE_PORTAL_URL        "/lua/captive_portal.lua"
#define CAPTIVE_PORTAL_INFO_URL   "/lua/info_portal.lua"
#define PLEASE_WAIT_URL           "/lua/please_wait.lua"
#define AUTHORIZE_URL             "/authorize.html"
#define AUTHORIZE_CAPTIVE_LUA_URL "/lua/authorize_captive.lua"
#define HOTSPOT_DETECT_URL        "/hotspot-detect.html"       /* iOS    */
#define KINDLE_WIFISTUB_URL       "/kindle-wifi/wifistub.html" /* Kindle */
#define HOTSPOT_DETECT_LUA_URL    "/lua/hotspot-detect.lua"
#define CHANGE_PASSWORD_ULR       "/lua/change_password.lua"
#define GRAFANA_URL               "/lua/modules/grafana"
#define LIVE_TRAFFIC_URL          "/lua/live_traffic.lua"
#define POOL_MEMBERS_ASSOC_URL    "/lua/admin/manage_pool_members.lua"
#define REST_API_PREFIX           "/lua/rest/"
#define REST_API_PRO_PREFIX       "/lua/pro/rest/"
#define INTERFACE_DATA_URL        "/lua/rest/get/interface/data.lua"
#define MAX_PASSWORD_LEN          32 + 1 /* \0 */
#define HTTP_SESSION_DURATION              43200  // 12h
#define HTTP_SESSION_MIDNIGHT_EXPIRATION   false
#define EXTENDED_HTTP_SESSION_DURATION     604800 // 7d
#define CONST_HTTPS_CERT_NAME     "ntopng-cert.pem"
#define CONST_HTTPS_AUTHCA_FILE   "ntopng-ca.crt"
#define CONST_NTOP_INTERFACE      "ntop_interface"

#define PCAP_MAGIC                0xa1b2c3d4
#define NO_UID                    ((u_int32_t)-1)
#define NO_PID                    ((u_int32_t)-1)
#define NO_NDPI_PROTOCOL          ((u_int)-1)
#define NDPI_MIN_NUM_PACKETS      12
#define GTP_U_V1_PORT             2152
#define TZSP_PORT                 37008
#define VXLAN_PORT                4789
#define CAPWAP_DATA_PORT          5247
#define MAX_NUM_INTERFACE_HOSTS   131072
#define MAX_NUM_VIEW_INTERFACES   8

#define LIMITED_NUM_INTERFACES    8
#define LIMITED_NUM_HOST_POOLS    4 /* 3 pools plus the NO_HOST_POOL_ID */
#define LIMITED_NUM_PROFILES      16
#define LIMITED_NUM_POOL_MEMBERS  8
#define UNLIMITED_NUM_INTERFACES  32
#define UNLIMITED_NUM_HOST_POOLS  128
#define UNLIMITED_NUM_PROFILES    128
#ifndef NTOPNG_PRO
#define MAX_NUM_DEFINED_INTERFACES  LIMITED_NUM_INTERFACES
#define MAX_NUM_HOST_POOLS          LIMITED_NUM_HOST_POOLS
#define MAX_NUM_PROFILES            LIMITED_NUM_PROFILES
#define MAX_NUM_POOL_MEMBERS        LIMITED_NUM_POOL_MEMBERS
#endif

#define MAX_INTERFACE_NAME_LEN    512
#define MAX_USER_NETS_VAL_LEN     255
#define NUM_HOSTS_RESOLVED_BITS   2 << 19 /* ~1 million */
#define HOST_FAMILY_ID            ((u_int16_t)-1)
#define FLOW_PURGE_FREQUENCY      1 /* sec */
#define HOST_PURGE_FREQUENCY      3 /* sec */
#define OTHER_PURGE_FREQUENCY     5 /* sec - Other = ASs, MAC, Countries, VLANs */
#define MAX_TCP_FLOW_IDLE        15 /* sec - how long to wait before idling a TCP flow with FIN/RST set or with incomplete TWH */
#define MAX_FLOW_IDLE            60 /* sec */
#define MAX_LOCAL_HOST_IDLE     300 /* sec */
#define MAX_REMOTE_HOST_IDLE     60 /* sec */
#define MAX_HASH_ENTRY_IDLE      60 /* sec - Generic idle time for hash entries different from hosts and flows (i.e., ASes and Macs) */
#define MAX_RRD_QUEUE_LEN        200000 /* timeseries in the queue */
#define MIN_NUM_IDLE_ENTRIES_IF  5000
#define INTF_RRD_RAW_DAYS        1
#define INTF_RRD_1MIN_DAYS       30
#define INTF_RRD_1H_DAYS         100
#define INTF_RRD_1D_DAYS         365
#define OTHER_RRD_RAW_DAYS       1
#define OTHER_RRD_1MIN_DAYS      30
#define OTHER_RRD_1H_DAYS        100
#define OTHER_RRD_1D_DAYS        365
#define CONST_DEFAULT_TOP_TALKERS_ENABLED        false
#define PURGE_FRACTION           60 /* check 1/60 of hashes per iteration */
#define MIN_NUM_VISITED_ENTRIES  1024
#define MAX_NUM_QUEUED_ADDRS    500 /* Maximum number of queued address for resolution */
#define MAX_NUM_QUEUED_CONTACTS 25000
#define NTOP_COPYRIGHT          "(C) 1998-21 ntop.org"
#define DEFAULT_PID_PATH        "/var/run/ntopng.pid"
#define SYSTEM_INTERFACE_NAME   "__system__"
#define SYSTEM_INTERFACE_ID     -1
#define INVALID_INTERFACE_ID    -2
#define DOMAIN_CATEGORY         "ntopng.domain.category"
#define DOMAIN_TO_CATEGORIZE    "ntopng.domain.tocategorize"
#define DOMAIN_WHITELIST_CAT    "ntopng.domain.whitelist"
#define DNS_CACHE               "ntopng.dns.cache"
#define DHCP_CACHE              "ntopng.dhcp.%d.cache.%s"
#define NTOPNG_TRACE            "ntopng.trace"
#define TRACES_PER_LOG_FILE_HIGH_WATERMARK 10000
#define MAX_NUM_NTOPNG_LOG_FILES           5
#define MAX_NUM_NTOPNG_TRACES              32
#define PCAP_DUMP_INTERFACES_DELETE_HASH   "ntopng.prefs.delete_pcap_dump_interfaces_data"
#define CUSTOM_NDPI_PROTOCOLS_ASSOCIATIONS_HASH "ntop.prefs.custom_nDPI_proto_categories"
#define TRAFFIC_FILTERING_CACHE            "ntopng.trafficfiltering.cache"
#define TRAFFIC_FILTERING_TO_RESOLVE       "ntopng.trafficfiltering.toresolve"
#define PREFS_CHANGED            "ntopng.cache.prefs_changed"
#define DROP_HOST_TRAFFIC        "ntopng.prefs.drop_host_traffic"
#define DROP_HOST_POOL_NAME      "Jailed hosts pool"
#define DROP_HOST_POOL_LIST      "ntopng.cache.drop_host_list"
#define DROP_TMP_ADD_HOST_LIST   "ntopng.cache.tmp_add_host_list"
#define DROP_HOST_POOL_EXPIRATION_TIME    1800 /*  30 m */
#define HOST_TRAFFIC_QUOTA       "ntopng.prefs.hosts_quota"
#define HTTP_ACL_MANAGEMENT_PORT "ntopng.prefs.http_acl_management_port"
#define TEMP_ADMIN_PASSWORD      "ntopng.prefs.temp_admin_password"
#define LAST_RESET_TIME          "ntopng.prefs.last_reset_time"

#define TRAFFIC_FILTERING_CACHE_DURATION  43200 /* 12 h */
#define DNS_CACHE_DURATION                 3600  /*  1 h */
#define LOCAL_HOSTS_CACHE_DURATION         3600  /*  1 h */
#define HOST_LABEL_NAMES_KEY    "ntopng.cache.host_labels.%s"
#define IFACE_DHCP_RANGE_KEY    "ntopng.prefs.ifid_%u.dhcp_ranges"
#define HOST_SERIALIZED_KEY     "ntopng.serialized_hosts.ifid_%u__%s@%d"
#define MAC_SERIALIZED_KEY      "ntopng.serialized_macs.ifid_%u__%s"
#define IP_MAC_ASSOCIATION      "ntopng.ip_to_mac.ifid_%u__%s@%d"
#define HOST_PREF_MUD_RECORDING "ntopng.prefs.iface_%d.mud.recording.%s"
#define MUD_RECORDING_GENERAL_PURPOSE "general_purpose"
#define MUD_RECORDING_SPECIAL_PURPOSE "special_purpose"
#define MUD_RECORDING_DISABLED        "disabled"
#define MUD_RECORDING_DEFAULT         "default"
#define HOST_BY_MAC_SERIALIZED_KEY "ntopng.serialized_hostsbymac.ifid_%u__%s"
#define HOST_POOL_SERIALIZED_KEY "ntopng.serialized_host_pools.ifid_%u"
#define VLAN_SERIALIZED_KEY     "ntopng.serialized_vlan.ifid_%u_vlan_%u"
#define AS_SERIALIZED_KEY       "ntopng.serialized_as.ifid_%u_as_%u"
#define COUNTRY_SERIALIZED_KEY  "ntopng.serialized_as.ifid_%u_country_%s"
#define SYSLOG_PRODUCERS_MAP_KEY "ntopng.syslog.ifid_%u.producers_map"
#define NTOPNG_PREFS_PREFIX     "ntopng.prefs"
#define NTOPNG_CACHE_PREFIX     "ntopng.cache"
#define NTOPNG_USER_PREFIX      "ntopng.user"
#define NTOPNG_API_TOKEN_PREFIX "ntopng.api_tokens"
#define MAC_CUSTOM_DEVICE_TYPE  NTOPNG_PREFS_PREFIX".device_types.%s"
#define NTOP_HOSTS_SERIAL       "ntopng.host_serial"
#define MAX_NUM_INTERFACE_IDS   256
#define DUMMY_BRIDGE_INTERFACE_ID       1 /* Anything but zero */
#define MAX_FAILED_LOGIN_ATTEMPTS       5
#define FAILED_LOGIN_ATTEMPTS_INTERVAL  300 /* seconds */
#define CONST_STR_FAILED_LOGIN_KEY     "ntopng.cache.failed_logins.%s"
#define CONST_STR_RELOAD_LISTS  "ntopng.cache.reload_lists_utils" /* sync with lists_utils.lua */
#define NTOP_NOLOGIN_USER	"nologin"
#define NTOP_DEFAULT_USER_LANG  "en"
#define MAX_OPTIONS             24
#define CONST_ADMINISTRATOR_USER       "administrator"
#define CONST_UNPRIVILEGED_USER        "unprivileged"
#define CONST_DEFAULT_PASSWORD_CHANGED NTOPNG_PREFS_PREFIX".admin_password_changed"
#define CONST_STR_NEDGE_LICENSE        "nedge.license"
#define CONST_STR_NEDGE_KEY            "nedge.key"
#define CONST_STR_NTOPNG_LICENSE       "ntopng.license"
#define CONST_STR_NTOPNG_KEY           "ntopng.key"
#define CONST_STR_PRODUCT_NAME_KEY     "ntopng.product_name"
#define CONST_STR_USER_GROUP           NTOPNG_USER_PREFIX".%s.group"
#define CONST_STR_USER_ID              NTOPNG_USER_PREFIX".%s.user_id"
#define CONST_STR_USER_FULL_NAME       NTOPNG_USER_PREFIX".%s.full_name"
#define CONST_STR_USER_PASSWORD        NTOPNG_USER_PREFIX".%s.password"
#define CONST_STR_USER_THEME           NTOPNG_USER_PREFIX".%s.theme"
#define CONST_STR_USER_NETS            NTOPNG_USER_PREFIX".%s.allowed_nets"
#define CONST_STR_USER_ALLOWED_IFNAME  NTOPNG_USER_PREFIX".%s.allowed_ifname"
#define CONST_STR_USER_HOST_POOL_ID    NTOPNG_USER_PREFIX".%s.host_pool_id"
#define CONST_STR_USER_LANGUAGE        NTOPNG_USER_PREFIX".%s.language"
#define CONST_STR_USER_ALLOW_PCAP      NTOPNG_USER_PREFIX".%s.allow_pcap"
#define CONST_STR_USER_EXPIRE          NTOPNG_USER_PREFIX".%s.expire"
#define CONST_STR_USER_CAPABILITIES    NTOPNG_USER_PREFIX".%s.capabilities"
#define CONST_STR_USER_API_TOKEN       NTOPNG_USER_PREFIX".%s.api_token"
#define CONST_ALLOWED_NETS             "allowed_nets"
#define CONST_ALLOWED_IFNAME           "allowed_ifname"
#define CONST_USER_LANGUAGE            "language"
#define CONST_USER                     "user"

#define CONST_INTERFACE_TYPE_PCAP      "pcap"
#define CONST_INTERFACE_TYPE_PCAP_DUMP "pcap dump"
#define CONST_INTERFACE_TYPE_ZMQ       "zmq"
#define CONST_INTERFACE_TYPE_SYSLOG    "syslog"
#define CONST_INTERFACE_TYPE_VLAN      "Dynamic VLAN"
#define CONST_INTERFACE_TYPE_FLOW      "Dynamic Flow Collection"
#define CONST_INTERFACE_TYPE_VIEW      "view"
#define CONST_INTERFACE_TYPE_PF_RING   "PF_RING"
#define CONST_INTERFACE_TYPE_NETFILTER "netfilter"
#define CONST_INTERFACE_TYPE_DIVERT    "divert"
#define CONST_INTERFACE_TYPE_DUMMY     "dummy"
#define CONST_INTERFACE_TYPE_ZC_FLOW   "ZC-flow"
#define CONST_INTERFACE_TYPE_CUSTOM    "custom"
#define CONST_INTERFACE_TYPE_UNKNOWN   "unknown"

#define CONST_DEMO_MODE_DURATION       600 /* 10 min */
#define CONST_MAX_DUMP_DURATION        300 /* 5 min */
#define CONST_MAX_NUM_PACKETS_PER_LIVE 100000 /* live captures via HTTP */
#define CONST_MAX_DUMP                 500000000

#define CONST_MAX_NUM_LIVE_EXTRACTIONS 2

#define CONST_MAX_EXTR_PCAP_BYTES NTOPNG_PREFS_PREFIX".max_extracted_pcap_bytes"
#define CONST_DEFAULT_MAX_EXTR_PCAP_BYTES (100*1024*1024)

#define MIN_CONNTRACK_UPDATE           3  /* sec */
#define MIN_NETFILTER_UPDATE           30 /* sec */

#define CONST_EST_MAX_FLOWS            200000
#define CONST_EST_MAX_HOSTS            200000
#define MIN_HOST_RESOLUTION_FREQUENCY  60  /* 1 min */
#define NDPI_TRAFFIC_BEHAVIOR_REFRESH  60  /* 1 min */
#define HOST_SITES_REFRESH             300 /* 5 min */
#define IFACE_BEHAVIOR_REFRESH         300 /* 5 min */
#define ASES_BEHAVIOR_REFRESH          300 /* 5 min */
#define NETWORK_BEHAVIOR_REFRESH       300 /* 5 min */
#define TRAFFIC_MAP_REFRESH            30  /* 30 sec */
#define HOST_SITES_TOP_NUMBER          10
#define HOST_MAX_SERIALIZED_LEN        1048576 /* 1MB, use only when allocating memory in the heap */
#define POOL_MAX_SERIALIZED_LEN        32768   /* bytes */
#define POOL_MAX_NAME_LEN              33      /* Characters */
#define HOST_MAX_SCORE                 500
#define FLOW_MAX_SCORE_BREAKDOWN       8 /* Maximum number of alerts for the flow score breadkown. Additional alerts will fall under 'other' */

#define CONST_MAX_NUM_NETWORKS         255
#define CONST_MAX_NUM_CHECKPOINTS      4

#define HOST_IS_DHCP_SERVER            0x01
#define HOST_IS_DNS_SERVER             0x02
#define HOST_IS_NTP_SERVER             0x03
#define HOST_IS_SMTP_SERVER            0x04

#define MAX_DYNAMIC_STATS_VALUES       12

// ICMP
#ifndef ICMP_TIMESTAMP
#define ICMP_TIMESTAMP 13
#endif
#ifndef ICMP_TIMESTAMPREPLY
#define ICMP_TIMESTAMPREPLY 14
#endif
#ifndef ICMP_INFO_REQUEST
#define ICMP_INFO_REQUEST 15
#endif
#ifndef ICMP_INFO_REPLY
#define ICMP_INFO_REPLY 16
#endif
#ifndef ICMP_HOST_UNREACH
#define ICMP_HOST_UNREACH 1
#endif
#ifndef ICMP_PORT_UNREACH
#define ICMP_PORT_UNREACH 3
#endif
#ifndef ICMP_DEST_UNREACH
#define ICMP_DEST_UNREACH 3
#endif

// ICMP6
#ifndef ICMP6_WRUREQUEST
#define ICMP6_WRUREQUEST 139
#endif
#ifndef ICMP6_WRUREPLY
#define ICMP6_WRUREPLY 140
#endif
#ifndef ICMP6_DEST_UNREACH
#define ICMP6_DEST_UNREACH 1
#endif
#ifndef ICMP6_PORT_UNREACH
#define ICMP6_PORT_UNREACH 4
#endif

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
#ifndef TH_ECE
#define	TH_ECE	0x40
#endif
#ifndef TH_CWR
#define	TH_CWR	0x80
#endif

/* Prepare a mask to only consider flags SYN-ACK-FIN-RST-PSH-URG as certain scanners
   set higher bits such as ECE or CRW. For example we have seen scans with SYN set along with ECE and CWR */
#define TCP_SCAN_MASK 0xFF & (TH_FIN | TH_SYN | TH_RST | TH_PUSH | TH_ACK | TH_URG)
/* Prepare a mask used when analyzing tcp twh. Currently, it is necessary to exclude ECE and CWR
   bits as they may be contained in the handshake as explained in 
   https://github.com/ntop/ntopng/issues/3255 */
#define TCP_3WH_MASK  0xFF & ~(TH_ECE | TH_CWR)

#define MAX_NUM_DB_SPINS            5 /* sec */

#ifdef WIN32
#define ICMP_ECHO		     8	/* Echo Request			*/
#define ICMP_ECHOREPLY	   	 0	/* Echo Reply			*/

/*
#ifndef ICMP6_ECHO_REQUEST
#define ICMP6_ECHO_REQUEST   128
#endif

#ifndef ICMP6_ECHO_REPLY
#define ICMP6_ECHO_REPLY     129
#endif
*/
#endif

#ifndef MAX_PATH
#define MAX_PATH                  256
#endif

//#define DEMO_WIN32                   1
#define MAX_NUM_PACKETS             5000

/* Hanldes ad most 4096 interfaces across all sFlow devices.
   Considering 48 devices with 48 interfaces each as an upper bound,
   this number is reasonable. */
#define NUM_IFACE_STATS_HASH        4096
#define MAX_NUM_VLAN                4096
#define MAX_NUM_VIRTUAL_INTERFACES    32
#define PASS_ALL_SHAPER_ID             0
#define DROP_ALL_SHAPER_ID             1
#define DEFAULT_SHAPER_ID              PASS_ALL_SHAPER_ID
#define NEDGE_USER_DEFAULT_POLICY_SHAPER_ID  4 /* see shaper_utils.nedge_shapers default */
#define NO_ROUTING_TABLE_ID            0
#define DEFAULT_ROUTING_TABLE_ID       1
#define NUM_TRAFFIC_SHAPERS           16
#define NUM_TC_TRAFFIC_SHAPERS         8
#define MAX_SHAPER_RATE_KBPS       10240
#define HOUSEKEEPING_FREQUENCY         5
#define MAX_NUM_HOST_CONTACTS         16
#define CONST_DEFAULT_NTOP_PORT     3000
#define CONST_DEFAULT_MYSQL_PORT    3306
#define CONST_DB_DUMP_FREQUENCY      300
#define CONST_MAX_NUM_NETWORKS       255
#define CONST_NUM_OPEN_DB_CACHE        8
#define CONST_NUM_CONTACT_DBS          8
#define MAX_ZMQ_SUBSCRIBERS           32
#define MAX_SYSLOG_SUBSCRIBERS         8
#define MAX_ZMQ_POLL_WAIT_MS        1000 /* 1 sec */
#define MAX_ZMQ_POLLS_BEFORE_PURGE  1000
#define MAX_SYSLOG_POLL_WAIT_MS        MAX_ZMQ_POLL_WAIT_MS
#define MAX_SYSLOG_POLLS_BEFORE_PURGE  MAX_ZMQ_POLLS_BEFORE_PURGE
#define CONST_MAX_NUM_FIND_HITS       10
#define CONST_MAX_NUM_HITS         32768 /* Decrease it for small installations */

/* Controls for periodic_stats_update (avoid executing it too often, or when not necessary) */
#define PERIODIC_STATS_UPDATE_MIN_REFRESH_BYTES   10 * (2 << 19 /* MB */)
#define PERIODIC_STATS_UPDATE_MIN_REFRESH_MS      5000

#define SCANNERS_ADDRESS_TREE_HIGH_WATERMARK  1024
#define SCANNERS_ADDRESS_TREE_LOW_WATERMARK    512

/* NOTE: keep in sync with nf_config.lua */
#define DNS_MAPPING_PORT            3003
#define CAPTIVE_PORTAL_PORT         3004

#define CONST_LUA_FLOW_CREATE       "flowCreate"
#define CONST_LUA_FLOW_DELETE       "flowDelete"
#define CONST_LUA_FLOW_UPDATE       "flowUpdate"
#define CONST_LUA_FLOW_NDPI_DETECT  "flowProtocolDetected"

#ifdef WIN32
#define CONST_PATH_SEP              '\\'
#else
#define CONST_PATH_SEP              '/'
#endif

#define CONST_DEFAULT_FILE_MODE      0600 /* rw */
#define CONST_DEFAULT_DIR_MODE       0700 /* rwx */
#define CONST_MAX_REDIS_CONN_RETRIES 16
#define CONST_MAX_LEN_REDIS_KEY      256
#define CONST_MAX_LEN_REDIS_VALUE    2*65526

#define NTOPNG_NDPI_OS_PROTO_ID      (NDPI_LAST_IMPLEMENTED_PROTOCOL+NDPI_MAX_NUM_CUSTOM_PROTOCOLS-2)
#define CONST_DEFAULT_HOME_NET       "192.168.1.0/24"
#define CONST_OLD_DEFAULT_DATA_DIR   "/var/tmp/ntopng"
#define CONST_DEFAULT_MAX_UI_STRLEN  24
#define CONST_DEFAULT_IS_AUTOLOGOUT_ENABLED               1
#define CONST_DEFAULT_IS_IDLE_LOCAL_HOSTS_CACHE_ENABLED   1
#define CONST_DEFAULT_PACKETS_DROP_PERCENTAGE_ALERT       5
#define CONST_DEFAULT_IS_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED 0
#define CONST_DEFAULT_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL   3600 /* Every hour by default */
#define HASHKEY_LOCAL_HOSTS_TOP_SITES_KEYS                "ntopng.cache.top_sites"
#define HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED    "ntopng.cache.top_sites_hour_done"
#define HASHKEY_LOCAL_HOSTS_TOP_SITES_DAY_KEYS_PUSHED     "ntopng.cache.top_sites_day_done"
#define HASHKEY_LOCAL_HOSTS_TOP_SITES_RESET               "ntopng.cache.top_sites.reset"
#define HASHKEY_IFACE_TOP_OS                              "ntopng.cache.top_os"
#define HASHKEY_IFACE_TOP_OS_HOUR_KEYS_PUSHED             "ntopng.cache.top_os_hour_done"
#define HASHKEY_IFACE_TOP_OS_DAY_KEYS_PUSHED              "ntopng.cache.top_os_day_done"
#define CONST_DEFAULT_DOCS_DIR       "httpdocs"
#define CONST_DEFAULT_SCRIPTS_DIR    "scripts"
#define CONST_DEFAULT_CALLBACKS_DIR  "scripts/callbacks"
#define CONST_DEFAULT_USERS_FILE     "ntopng-users.conf"
#define CONST_DEFAULT_INSTALL_DIR    (DATA_DIR "/ntopng")
#if defined(__FreeBSD__)
#define CONST_BIN_DIR                "/usr/local/bin"
#define CONST_SHARE_DIR              "/usr/local/share"
#define CONST_SHARE_DIR_2            "/usr/share"
#define CONST_ETC_DIR                "/usr/local/etc"
#define CONST_DEFAULT_DATA_DIR       "/var/db/ntopng"
#else
#define CONST_BIN_DIR                "/usr/bin"
#define CONST_SHARE_DIR              "/usr/share"
#define CONST_SHARE_DIR_2            "/usr/local/share"
#define CONST_ETC_DIR                "/etc"
#define CONST_DEFAULT_DATA_DIR       "/var/lib/ntopng"
#endif
#define CONST_ALT_INSTALL_DIR        CONST_SHARE_DIR   "/ntopng"
#define CONST_ALT2_INSTALL_DIR       CONST_SHARE_DIR_2 "/usr/share/ntopng"
#define CONST_HTTP_PREFIX_STRING     "@HTTP_PREFIX@"
#define CONST_NTOP_STARTUP_EPOCH     "@NTOP_STARTUP_EPOCH@"
#define CONST_NTOP_PRODUCT_NAME      "@NTOP_PRODUCT_NAME@"
#define CONST_OLD_DEFAULT_NTOP_USER  "nobody"
#define CONST_DEFAULT_NTOP_USER      "ntopng"
#define CONST_TOO_EARLY              "TooEarly"

#define CONST_LUA_OK                  1
#define CONST_LUA_ERROR               0
#define CONST_LUA_PARAM_ERROR         -1
#define CONST_MAX_NUM_SYN_PER_SECOND     25 /* keep in sync with alert_utils.lua */
#define CONST_MAX_NEW_FLOWS_SECOND       25 /* keep in sync with alert_utils.lua */
#define CONST_ALERT_GRACE_PERIOD      60 /* No more than 1 alert/min */
#define CONST_CONTACTED_BY            "contacted_by"
#define CONST_CONTACTS                "contacted_peers" /* Peers contacted by this host */

#define CONST_HISTORICAL_OK               1
#define CONST_HISTORICAL_FILE_ERROR       0
#define CONST_HISTORICAL_OPEN_ERROR      -1
#define CONST_HISTORICAL_ROWS_LIMIT       20960

#define CONST_AGGREGATIONS            "aggregations"
#define CONST_HOST_CONTACTS           "host_contacts"

#define USER_SCRIPTS_RUN_CALLBACK             "runScripts"
#define USER_SCRIPTS_RELEASE_ALERTS_CALLBACK  "releaseAlerts"

/* Maximum line lenght for the line protocol to write timeseries */
#define LINE_PROTOCOL_MAX_LINE             512

#define CONST_IEC104_LEARNING_TIME         21600 /* 6 hours */
#define CONST_INFLUXDB_FILE_QUEUE          "ntopng.influx_file_queue"
#define CONST_INFLUXDB_FLUSH_TIME          10 /* sec */
#define CONST_INFLUXDB_MAX_DUMP_SIZE       4194304 /* 4 MB */
#define CONST_FLOW_ALERT_EVENT_QUEUE       "ntopng.cache.ifid_%d.flow_alerts_events_queue"
#define SQLITE_ALERTS_QUEUE_SIZE           8192
#define ALERTS_NOTIFICATIONS_QUEUE_SIZE    8192
#define MAX_NUM_RECIPIENTS                 64 /* keep in sync with Recipients.lua recipients.MAX_NUM_RECIPIENTS */
#define INTERNAL_ALERTS_QUEUE_SIZE         1024
#define CONST_REMOTE_TO_REMOTE_MAX_QUEUE   32
#define CONST_SQL_QUEUE                        "ntopng.sql_queue"
#define CONST_SQL_BATCH_SIZE                      32
#define CONST_MAX_SQL_QUERY_LEN                 8192
#define CONST_DEFAULT_MIRRORED_TRAFFIC         false
#define CONST_DEFAULT_SHOW_DYN_IFACE_TRAFFIC   false
#define CONST_DEFAULT_LBD_SERIALIZE_AS_MAC     false
#define CONST_DEFAULT_DISCARD_PROBING_TRAFFIC  false
#define CONST_DEFAULT_FLOWS_ONLY_INTERFACE     false
#define CONST_ALERT_DISABLED_PREFS         NTOPNG_PREFS_PREFIX".disable_alerts_generation"
#define CONST_PREFS_ENABLE_ACCESS_LOG      NTOPNG_PREFS_PREFIX".enable_access_log"
#define CONST_PREFS_ENABLE_SQL_LOG         NTOPNG_PREFS_PREFIX".enable_sql_log"
#define CONST_TOP_TALKERS_ENABLED          NTOPNG_PREFS_PREFIX".host_top_sites_creation"
#define CONST_FLOW_TABLE_TIME              NTOPNG_PREFS_PREFIX".flow_table_time"
#define CONST_MIRRORED_TRAFFIC_PREFS       NTOPNG_PREFS_PREFIX".ifid_%d.is_traffic_mirrored"
#define CONST_SHOW_DYN_IFACE_TRAFFIC_PREFS NTOPNG_PREFS_PREFIX".ifid_%d.show_dynamic_interface_traffic"
#define CONST_DISABLED_FLOW_DUMP_PREFS     NTOPNG_PREFS_PREFIX".ifid_%d.is_flow_dump_disabled"
#define CONST_LBD_SERIALIZATION_PREFS      NTOPNG_PREFS_PREFIX".ifid_%d.serialize_local_broadcast_hosts_as_macs"
#define CONST_DISCARD_PROBING_TRAFFIC      NTOPNG_PREFS_PREFIX".ifid_%d.discard_probing_traffic"
#define CONST_FLOWS_ONLY_INTERFACE         NTOPNG_PREFS_PREFIX".ifid_%d.debug.flows_only_interface"
#define CONST_USE_NINDEX                   NTOPNG_PREFS_PREFIX".use_nindex"
#define CONST_NBOX_USER                     NTOPNG_PREFS_PREFIX".nbox_user"
#define CONST_NBOX_PASSWORD                 NTOPNG_PREFS_PREFIX".nbox_password"
#define CONST_IFACE_ID_PREFS                NTOPNG_PREFS_PREFIX".iface_id"
#define CONST_IFACE_SCALING_FACTOR_PREFS    NTOPNG_PREFS_PREFIX".iface_%d.scaling_factor"
#define CONST_IFACE_HIDE_FROM_TOP_PREFS     NTOPNG_PREFS_PREFIX".iface_%d.hide_from_top"
#define CONST_IFACE_GW_MACS_PREFS           NTOPNG_PREFS_PREFIX".iface_%d.gw_macs"
#define CONST_IFACE_COMPANIONS_SET          NTOPNG_PREFS_PREFIX".companion_interface.ifid_%d.companion_of"
#define CONST_IFACE_DYN_IFACE_MODE_PREFS    NTOPNG_PREFS_PREFIX".dynamic_sub_interfaces.ifid_%d.mode"
#define CONST_REMOTE_HOST_IDLE_PREFS        NTOPNG_PREFS_PREFIX".non_local_host_max_idle"
#define CONST_FLOW_MAX_IDLE_PREFS           NTOPNG_PREFS_PREFIX".flow_max_idle"
#define CONST_INTF_RRD_RAW_DAYS             NTOPNG_PREFS_PREFIX".intf_rrd_raw_days"
#define CONST_INTF_RRD_1MIN_DAYS            NTOPNG_PREFS_PREFIX".intf_rrd_1min_days"
#define CONST_INTF_RRD_1H_DAYS              NTOPNG_PREFS_PREFIX".intf_rrd_1h_days"
#define CONST_INTF_RRD_1D_DAYS              NTOPNG_PREFS_PREFIX".intf_rrd_1d_days"
#define CONST_OTHER_RRD_RAW_DAYS            NTOPNG_PREFS_PREFIX".other_rrd_raw_days"
#define CONST_OTHER_RRD_1MIN_DAYS           NTOPNG_PREFS_PREFIX".other_rrd_1min_days"
#define CONST_OTHER_RRD_1H_DAYS             NTOPNG_PREFS_PREFIX".other_rrd_1h_days"
#define CONST_OTHER_RRD_1D_DAYS             NTOPNG_PREFS_PREFIX".other_rrd_1d_days"
#define CONST_SAFE_SEARCH_DNS               NTOPNG_PREFS_PREFIX".safe_search_dns"
#define CONST_GLOBAL_DNS                    NTOPNG_PREFS_PREFIX".global_dns"
#define CONST_SECONDARY_DNS                 NTOPNG_PREFS_PREFIX".secondary_dns"
#define CONST_MAX_NUM_SECS_ALERTS_BEFORE_DEL NTOPNG_PREFS_PREFIX".max_num_secs_before_delete_alert"
#define CONST_MAX_ENTITY_ALERTS     NTOPNG_PREFS_PREFIX".max_entity_alerts"
#define CONST_PROFILES_PREFS                NTOPNG_PREFS_PREFIX".profiles"
#define CONST_PROFILES_COUNTERS             "ntopng.profiles_counters.ifid_%i"
#define CONST_PREFS_CAPTIVE_PORTAL          NTOPNG_PREFS_PREFIX".enable_captive_portal"
#define CONST_PREFS_VLAN_TRUNK_MODE_ENABLED NTOPNG_PREFS_PREFIX".enable_vlan_trunk_bridge"
#define CONST_PREFS_MAC_CAPTIVE_PORTAL      NTOPNG_PREFS_PREFIX".mac_based_captive_portal"
#define CONST_PREFS_INFORM_CAPTIVE_PORTAL   NTOPNG_PREFS_PREFIX".enable_informative_captive_portal"
#define CONST_PREFS_DEFAULT_L7_POLICY       NTOPNG_PREFS_PREFIX".default_l7_policy"
#define CONST_PREFS_GLOBAL_DNS_FORGING_ENABLED NTOPNG_PREFS_PREFIX".global_dns_forging"
#define HOST_POOL_IDS_KEY                   NTOPNG_PREFS_PREFIX".host_pools.pool_ids"
#define HOST_POOL_MEMBERS_KEY               NTOPNG_PREFS_PREFIX".host_pools.members.%s"
#define HOST_POOL_SHAPERS_KEY               NTOPNG_PREFS_PREFIX".%u.l7_policies.%s"
#define HOST_POOL_DETAILS_KEY               NTOPNG_PREFS_PREFIX".host_pools.details.%u"
#define CONST_SUBINTERFACES_PREFS           NTOPNG_PREFS_PREFIX".%u.sub_interfaces"
#define CONST_PREFS_CLIENT_X509_AUTH        NTOPNG_PREFS_PREFIX".is_client_x509_auth_enabled"
#define CONST_PREFS_EMIT_FLOW_ALERTS        NTOPNG_PREFS_PREFIX".emit_flow_alerts"
#define CONST_PREFS_EMIT_HOST_ALERTS        NTOPNG_PREFS_PREFIX".emit_host_alerts"


#define CONST_PREFS_ASN_BEHAVIOR_ANALYSIS              NTOPNG_PREFS_PREFIX".is_asn_behavior_analysis_enabled"
#define CONST_PREFS_NETWORK_BEHAVIOR_ANALYSIS          NTOPNG_PREFS_PREFIX".is_network_behavior_analysis_enabled"
#define CONST_PREFS_IFACE_L7_BEHAVIOR_ANALYSIS         NTOPNG_PREFS_PREFIX".is_iface_l7_behavior_analysis_enabled"
#define CONST_PREFS_BEHAVIOUR_ANALYSIS                  NTOPNG_PREFS_PREFIX".is_behaviour_analysis_enabled"
#define CONST_PREFS_BEHAVIOUR_ANALYSIS_LEARNING_PERIOD  NTOPNG_PREFS_PREFIX".behaviour_analysis_learning_period"
#define CONST_PREFS_BEHAVIOUR_ANALYSIS_STATUS_DURING_LEARNING  NTOPNG_PREFS_PREFIX".behaviour_analysis_learning_status_during_learning"
#define CONST_PREFS_BEHAVIOUR_ANALYSIS_STATUS_POST_LEARNING  NTOPNG_PREFS_PREFIX".behaviour_analysis_learning_status_post_learning"

#define CONST_PREFS_IEC60870_ANALYSIS_LEARNING_PERIOD   NTOPNG_PREFS_PREFIX".iec60870_learning_period"

#define CONST_DEFAULT_BEHAVIOUR_ANALYSIS_LEARNING_PERIOD  7200 // 2 hours by default

#define CONST_USER_GROUP_ADMIN             "administrator"
#define CONST_USER_GROUP_UNPRIVILEGED      "unprivileged"
#define CONST_USER_GROUP_CAPTIVE_PORTAL    "captive_portal"
#define CONST_CAPTIVE_PORTAL_INFORM_SECS   86400
#define CONST_AUTH_SESSION_DURATION_PREFS      NTOPNG_PREFS_PREFIX".auth_session_duration"
#define CONST_AUTH_SESSION_MIDNIGHT_EXP_PREFS  NTOPNG_PREFS_PREFIX".auth_session_midnight_expiration"
#define CONST_LOCAL_HOST_CACHE_DURATION_PREFS  NTOPNG_PREFS_PREFIX".local_host_cache_duration"
#define CONST_LOCAL_HOST_IDLE_PREFS            NTOPNG_PREFS_PREFIX".local_host_max_idle"

#define CONST_RUNTIME_MAX_UI_STRLEN                    NTOPNG_PREFS_PREFIX".max_ui_strlen"
#define CONST_RUNTIME_PREFS_TS_DRIVER                  NTOPNG_PREFS_PREFIX".timeseries_driver"
#define CONST_RUNTIME_IS_AUTOLOGOUT_ENABLED            NTOPNG_PREFS_PREFIX".is_autologon_enabled"
#define CONST_RUNTIME_IDLE_LOCAL_HOSTS_CACHE_ENABLED   NTOPNG_PREFS_PREFIX".is_local_host_cache_enabled"
#define CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED NTOPNG_PREFS_PREFIX".is_active_local_host_cache_enabled"
#define CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL NTOPNG_PREFS_PREFIX".active_local_host_cache_interval"
#define CONST_RUNTIME_PREFS_LOG_TO_FILE                NTOPNG_PREFS_PREFIX".log_to_file"
#define CONST_RUNTIME_PREFS_HOUSEKEEPING_FREQUENCY     NTOPNG_PREFS_PREFIX".housekeeping_frequency"
#define CONST_RUNTIME_PREFS_FLOW_DEVICE_PORT_RRD_CREATION     NTOPNG_PREFS_PREFIX".flow_device_port_rrd_creation" /* 0 / 1 */
#define CONST_RUNTIME_PREFS_THPT_CONTENT               NTOPNG_PREFS_PREFIX".thpt_content"     /* bps / pps */
#define CONST_RUNTIME_PREFS_HOSTS_ALERTS_CONFIG        NTOPNG_PREFS_PREFIX".alerts_global.min.local_hosts"
#define CONST_PREFS_ENABLE_DEVICE_PROTOCOL_POLICIES    NTOPNG_PREFS_PREFIX".device_protocols_policing"
#define CONST_PREFS_ENABLE_RUNTIME_FLOWS_DUMP          NTOPNG_PREFS_PREFIX".enable_runtime_flows_dump"
#define CONST_HOST_SYN_ATTACKER_ALERT_THRESHOLD_KEY    "syn_attacker_threshold"
#define CONST_HOST_SYN_VICTIM_ALERT_THRESHOLD_KEY      "syn_victim_threshold"
#define CONST_HOST_FLOW_ATTACKER_ALERT_THRESHOLD_KEY   "flow_attacker_threshold"
#define CONST_HOST_FLOW_VICTIM_ALERT_THRESHOLD_KEY     "flow_victim_threshold"
#define CONST_RUNTIME_PREFS_NBOX_INTEGRATION           NTOPNG_PREFS_PREFIX".nbox_integration" /* 0 / 1 */
#define CONST_RUNTIME_PREFS_LOGGING_LEVEL              NTOPNG_PREFS_PREFIX".logging_level"
#define CONST_RUNTIME_PREFS_SNMP_PROTO_VERSION         NTOPNG_PREFS_PREFIX".default_snmp_version"
#define CONST_RUNTIME_PREFS_IFACE_FLOW_COLLECTION      NTOPNG_PREFS_PREFIX".dynamic_flow_collection_mode" /* {"none", "vlan", "probe_ip","ingress_iface_idx"} */
#define CONST_RUNTIME_PREFS_IGNORED_INTERFACES         NTOPNG_PREFS_PREFIX".ignored_interfaces"
#define CONST_RUNTIME_PREFS_ENABLE_MAC_NDPI_STATS      NTOPNG_PREFS_PREFIX".l2_device_ndpi_timeseries_creation"
#define DISAGGREGATION_PROBE_IP                        "probe_ip"
#define DISAGGREGATION_IFACE_ID                        "iface_idx"
#define DISAGGREGATION_INGRESS_IFACE_ID                "ingress_iface_idx"
#define DISAGGREGATION_INGRESS_PROBE_IP_AND_IFACE_ID   "probe_ip_and_ingress_iface_idx"
#define DISAGGREGATION_INGRESS_VRF_ID                  "ingress_vrf_id"
#define DISAGGREGATION_VLAN                            "vlan"
#define DISAGGREGATION_NONE                            "none"
#define CONST_ACTIVITIES_DEBUG_ENABLED                 NTOPNG_PREFS_PREFIX".periodic_activities_stats_to_stdout"
#define CONST_FIELD_MAP_CACHE_KEY                      NTOPNG_CACHE_PREFIX".ifid_%d.field_map.pen_%u"
#define CONST_FIELD_VALUE_MAP_CACHE_KEY                NTOPNG_CACHE_PREFIX".ifid_%d.field_value_map.pen_%u.field_%u"
#ifdef NTOPNG_PRO
#define MAX_NUM_CUSTOM_APPS  128
#define CONST_RUNTIME_PREFS_DAILY_REPORTS            NTOPNG_PREFS_PREFIX".daily_reports"    /* 0 / 1 */
#endif
#define CONST_RUNTIME_PREFS_HOSTMASK  NTOPNG_PREFS_PREFIX".host_mask"
#define CONST_RUNTIME_PREFS_AUTO_ASSIGNED_POOL_ID      NTOPNG_PREFS_PREFIX".auto_assigned_pool_id"


#define CONST_MAX_ALERT_MSG_QUEUE_LEN 8192
#define CONST_MAX_ES_MSG_QUEUE_LEN    8192
#define CONST_MAX_MYSQL_QUEUE_LEN     8192
#define CONST_MAX_NUM_READ_ALERTS     32
#define CONST_MAX_ACTIVITY_DURATION    86400 /* sec */
#define CONST_TREND_TIME_GRANULARITY   1 /* sec */
#define CONST_DEFAULT_PRIVATE_NETS     "192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,127.0.0.0/8,169.254.0.0/16"
#define CONST_DEFAULT_LOCAL_NETS       "127.0.0.0/8,fe80::/10"
#define CONST_DEFAULT_ALL_NETS         "0.0.0.0/0,::/0"

#define CONST_NUM_RESOLVERS            2

#define PAGE_NOT_FOUND     "<html><head><title>ntop</title></head><body><center><img src=/img/warning.png> Page &quot;%s&quot; was not found</body></html>"
#define PAGE_ERROR         "<html><head><title>ntop</title></head><body><img src=/img/warning.png> Script &quot;%s&quot; returned an error:\n<p><H3>%s</H3></body></html>"
#define DENIED             "<html><head><title>Access denied</title></head><body>Access denied</body></html>"
#define ACCESS_FORBIDDEN   "<html><head><title>Access forbidden</title></head><body>Access forbidden</body></html>"
#define ACCESS_DENIED_INTERFACES "<html><head><title>Access denied</title></head><body>This user login is temporary denied due to network interface initialization. Please retry again later.</body></html>"

#define CONST_DB_DAY_FORMAT            "%y%m%d"

#define CONST_ANY_ADDRESS              "" /* Good for v4 and v6 */
#define CONST_LOOPBACK_ADDRESS         "127.0.0.1"
#define CONST_EPP_MAX_CMD_NUM          34
#define CONST_DEFAULT_MAX_PACKET_SIZE  1522

/* ARP matrix generation preferences */
#define CONST_DEFAULT_ARP_MATRIX_GENERATION         NTOPNG_PREFS_PREFIX".arp_matrix_generation"

/* SRC/DST override for ZMQ interfaces */
#define CONST_DEFAULT_OVERRIDE_SRC_WITH_POST_NAT    NTOPNG_PREFS_PREFIX".override_src_with_post_nat_src"
#define CONST_DEFAULT_OVERRIDE_DST_WITH_POST_NAT    NTOPNG_PREFS_PREFIX".override_dst_with_post_nat_dst"

/* Flow Lua Calls */
#define FLOW_LUA_CALL_PROTOCOL_DETECTED_FN_NAME  "protocolDetected"
#define FLOW_LUA_CALL_PERIODIC_UPDATE_FN_NAME    "periodicUpdate"
#define FLOW_LUA_CALL_IDLE_FN_NAME               "flowEnd"
#define FLOW_LUA_CALL_PERIODIC_UPDATE_SECS       60 /* One minute */

/* Tiny Flows */
#define CONST_DEFAULT_IS_TINY_FLOW_EXPORT_ENABLED        true  /* disabled by default */
#define CONST_DEFAULT_MAX_NUM_PACKETS_PER_TINY_FLOW 3
#define CONST_DEFAULT_MAX_NUM_BYTES_PER_TINY_FLOW   64 /* Empty TCP */
#define CONST_IS_TINY_FLOW_EXPORT_ENABLED          NTOPNG_PREFS_PREFIX".tiny_flows_export_enabled"
#define CONST_MAX_NUM_PACKETS_PER_TINY_FLOW        NTOPNG_PREFS_PREFIX".max_num_packets_per_tiny_flow"
#define CONST_MAX_NUM_BYTES_PER_TINY_FLOW          NTOPNG_PREFS_PREFIX".max_num_bytes_per_tiny_flow"

/* Exponentially Weighted Moving Average alpha config. */
#define CONST_EWMA_ALPHA_PERCENT            NTOPNG_PREFS_PREFIX".ewma_alpha_percent"
#define CONST_DEFAULT_EWMA_ALPHA_PERCENT    15 /* 15% */

#define CONST_DEFAULT_NBOX_HOST      "localhost"
#define CONST_DEFAULT_NBOX_USER      "nbox"
#define CONST_DEFAULT_NBOX_PASSWORD  "nbox"

/* Sha-1 */
#define BLOCK_LEN 64  // In bytes
#define STATE_LEN 5  // In words

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

#define NUM_MINUTES_PER_DAY   1440 // == 60 * 24

#define DUMP_MAC_SIZE	6
#define MAC_SIZE	DUMP_MAC_SIZE
#define DUMP_IFNAMSIZ	16
#define MACSTR_SIZE     32
#define DUMP_MTU	16384

#if !defined(WIN32) && !defined(closesocket)
#define closesocket(c)		close(c)
#endif

#ifndef DLT_IPV4
#define DLT_IPV4  228
#endif

#define MAX_NUM_CATEGORIES         3
#define NTOP_UNKNOWN_CATEGORY_STR  "???"
#define NTOP_UNKNOWN_CATEGORY_ID   0
// MySQL-related defined
#define MYSQL_MAX_NUM_FIELDS  255
#define MYSQL_MAX_NUM_ROWS    1000
#define MYSQL_MAX_QUEUE_LEN   2048
// nIndex-related
#ifdef HAVE_NINDEX
#define NINDEX_MAX_NUM_INTERFACES 16
#endif

#ifdef NTOPNG_PRO
#define MYSQL_TOP_TALKERS_CONSOLIDATION_FREQ 20
#define MYSQL_TOP_TALKERS_TRIGGER_NAME "trigger_talkersv4"
#define MYSQL_TOP_TALKERS_CACHE_TABLE  "cache_talkersv4"
#define MYSQL_TOP_TALKERS_5MIN_TABLE   "talkersv4"
#define MYSQL_TOP_TALKERS_HOUR_TABLE   "talkersv4_hour"
#define MYSQL_TOP_TALKERS_DAY_TABLE    "talkersv4_day"

#define MYSQL_INSERT_PROFILE ",PROFILE"
#define MYSQL_PROFILE_VALUE ",'%s'"
#else
#define MYSQL_INSERT_PROFILE ""
#define MYSQL_PROFILE_VALUE ""
#endif

#define MYSQL_DROP_NPROBE_VIEW "DROP VIEW IF EXISTS `flowsv%hu`"
#define MYSQL_CREATE_NPROBE_VIEW \
"CREATE VIEW `flowsv%hu` AS " \
"SELECT idx, "\
"SRC_VLAN AS VLAN_ID, L7_PROTO, "\
"IPV%hu_SRC_ADDR AS IP_SRC_ADDR, L4_SRC_PORT, "\
"IPV%hu_DST_ADDR AS IP_DST_ADDR, L4_DST_PORT, "\
"PROTOCOL, IN_BYTES, OUT_BYTES, (IN_PKTS+OUT_PKTS) AS PACKETS, "\
"FIRST_SWITCHED, LAST_SWITCHED, "\
"'' AS INFO, '' AS `JSON`, '' AS `PROFILE`, NULL AS NTOPNG_INSTANCE_NAME, %u AS INTERFACE_ID "\
"FROM `%sflows` "\
"WHERE IP_PROTOCOL_VERSION=%hu "

#define MYSQL_INSERT_FIELDS "(VLAN_ID,L7_PROTO,IP_SRC_ADDR,L4_SRC_PORT,IP_DST_ADDR,L4_DST_PORT,PROTOCOL," \
  "IN_BYTES,OUT_BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,INFO,JSON,NTOPNG_INSTANCE_NAME,INTERFACE_ID" \
  MYSQL_INSERT_PROFILE ")"
#define MYSQL_INSERT_VALUES_V4 "('%u','%u','%u','%u','%u','%u','%u'," \
  "'%ju','%ju','%u','%u','%u','%s',COMPRESS('%s'), '%s', '%u'" MYSQL_PROFILE_VALUE ")"
#define MYSQL_INSERT_VALUES_V6 "('%u','%u','%s','%u','%s','%u','%u'," \
  "'%ju','%ju','%u','%u','%u','%s',COMPRESS('%s'), '%s', '%u'" MYSQL_PROFILE_VALUE ")"


#define NSERIES_DATA_RETENTION             365 /* 1 year */
#define NSERIES_ID_SECOND                    0
#define NSERIES_ID_MINUTE                    1
#define NSERIES_ID_5_MINUTES                 2
#define NUM_NSERIES                          (NSERIES_ID_5_MINUTES+1)

// sqlite (StoreManager and subclasses) related fields
#define STORE_MANAGER_MAX_QUERY              2048
#define STORE_MANAGER_MAX_KEY                20
#define DEFAULT_GLOBAL_DNS                   ""
#define DEFAULT_SAFE_SEARCH_DNS              "208.67.222.123" /* OpenDNS Family Shield */

#define ALERTS_MANAGER_MAX_AGGR_SECS         300 /* Aggregate equal alerts if generated within this interval */

/* A cache key used to look for the alert before going into sqlite. The rowid of an inserted
   alert is stored in the value of this cache key. Cache key is:
   <prefix>.ifid_<ifid>.alerts.aggregation_cache.<alert_type>_<alert_subtype>_<granularity>_<entity>_<entity_val>_<severity> */
#define ALERTS_MANAGER_AGGR_CACHE_KEY        NTOPNG_CACHE_PREFIX ".ifid_%d.alerts.aggregation_cache.%i_%s_%i_%i_%s_%i"

#define ALERTS_MANAGER_MAX_ENTITY_ALERTS     1000000
#define ALERTS_MANAGER_MAX_FLOW_ALERTS       16384
#define ALERTS_MAX_SECS_BEFORE_PURGE         (365*24*60*60) /* This is seconds! */
#define ALERTS_MANAGER_FLOWS_TABLE_NAME      "flows_alerts"
#define ALERTS_MANAGER_TABLE_NAME            "alerts"
#define ALERTS_MANAGER_STORE_NAME            "alerts_v30.db"
#define ALERTS_MANAGER_QUEUE_NAME            "ntopng.alerts.ifid_%i.queue"
#define ALERTS_MANAGER_MAKE_ROOM_ALERTS      "ntopng.cache.alerts.ifid_%i.make_room_closed_alerts"
#define ALERTS_MANAGER_MAKE_ROOM_FLOW_ALERTS "ntopng.cache.alerts.ifid_%i.make_room_flow_alerts"
#define ALERTS_MANAGER_TYPE_FIELD            "alert_type"
#define ALERTS_MANAGER_SEVERITY_FIELD        "alert_severity"
#define STATS_MANAGER_STORE_NAME             "top_talkers.db"

#define ALERTS_STORE_SCHEMA_FILE_NAME        "alert_store_schema.sql"
#define ALERTS_STORE_DB_FILE_NAME            "alert_store_v11.db"

#define NTOPNG_DATASOURCE_KEY                "ntopng.datasources"
#define NTOPNG_DATASOURCE_URL                "/datasources/"
#define NTOPNG_WIDGET_KEY                    "ntopng.widgets"
#define NTOPNG_WIDGET_URL                    "/widgets/"

#define CONST_MAX_NUM_THREADED_ACTIVITIES 64
#define STARTUP_SCRIPT_PATH                  "startup.lua"
#define BOOT_SCRIPT_PATH                     "boot.lua" /* Executed as root before networking is setup */
#define SHUTDOWN_SCRIPT_PATH                 "shutdown.lua"
#define HOUSEKEEPING_SCRIPT_PATH             "housekeeping.lua"
#define DISCOVER_SCRIPT_PATH                 "discover.lua"
#define TIMESERIES_SCRIPT_PATH               "timeseries.lua"
#define NOTIFICATIONS_SCRIPT_PATH            "notifications.lua"
#define UPGRADE_SCRIPT_PATH                  "upgrade.lua"
#define PINGER_SCRIPT_PATH                   "pinger.lua"
#define SECOND_SCRIPT_PATH                   "second.lua"
#define MINUTE_SCRIPT_PATH                   "minute.lua"
#define STATS_UPDATE_SCRIPT_PATH             "stats_update.lua"
#define PERIODIC_CHECKS_PATH           "periodic_checks.lua"
#define THIRTY_SECONDS_SCRIPT_PATH           "30sec.lua"
#define FIVE_MINUTES_SCRIPT_PATH             "5min.lua"
#define HOURLY_SCRIPT_PATH                   "hourly.lua"
#define DAILY_SCRIPT_PATH                    "daily.lua"

#define CHECKS_CONFIG                        "ntopng.prefs.checks.configset_v1"  /* Sync with checks.lua CONFIGSET_KEY  */
#define SYSLOG_SCRIPT_PATH                   "callbacks/system/syslog.lua"
#define SYSLOG_SCRIPT_CALLBACK_EVENT         "handleEvent"

/* GRE (Generic Route Encapsulation) */
#ifndef IPPROTO_GRE
#define IPPROTO_GRE 47
#endif

/* 6-in-4 Tunnels */
#ifndef IPPROTO_IPV6
#define IPPROTO_IPV6 41
#endif

#define GRE_HEADER_CHECKSUM      0x8000 /* 32 bit */
#define GRE_HEADER_ROUTING       0x4000 /* 32 bit */
#define GRE_HEADER_KEY           0x2000 /* 32 bit */
#define GRE_HEADER_SEQ_NUM       0x1000 /* 32 bit */

#define HOST_LOW_GOODPUT_THRESHOLD  25 /* No more than X low goodput flows per host */

#define NTOP_MAX_NUM_USERS          63 /* Maximum number of ntopng users */
#define NTOP_USERNAME_MAXLEN        33 /* NOTE: do not change, is this bound to mg_md5 ? */
#define NTOP_GROUP_MAXLEN           33
#define NTOP_SESSION_ID_LENGTH      33
#define NTOP_CSRF_TOKEN_LENGTH      33
#define NTOP_CSRF_TOKEN_NO_SESSION  "CSRF_TOKEN_NO_SESSION"
#define NTOP_UNKNOWN_GROUP "unknown"
#define PREF_NTOP_USER_IDS            NTOPNG_PREFS_PREFIX".user_ids"
#define PREF_NTOP_LDAP_AUTH           NTOPNG_PREFS_PREFIX".ldap.auth_enabled"
#define PREF_LDAP_ACCOUNT_TYPE        NTOPNG_PREFS_PREFIX".ldap.account_type"
#define PREF_LDAP_SERVER              NTOPNG_PREFS_PREFIX".ldap.ldap_server_address"
#define PREF_LDAP_BIND_ANONYMOUS      NTOPNG_PREFS_PREFIX".ldap.anonymous_bind"
#define PREF_LDAP_BIND_DN             NTOPNG_PREFS_PREFIX".ldap.bind_dn"
#define PREF_LDAP_BIND_PWD            NTOPNG_PREFS_PREFIX".ldap.bind_pwd"
#define PREF_LDAP_SEARCH_PATH         NTOPNG_PREFS_PREFIX".ldap.search_path"
#define PREF_LDAP_USER_GROUP          NTOPNG_PREFS_PREFIX".ldap.user_group"
#define PREF_LDAP_ADMIN_GROUP         NTOPNG_PREFS_PREFIX".ldap.admin_group"
#define PREF_LDAP_FOLLOW_REFERRALS    NTOPNG_PREFS_PREFIX".ldap.follow_referrals"
#ifdef HAVE_LDAP
#define MAX_LDAP_LEN     256  /* Keep it in sync with lua preferences file prefs.lua */
#endif
#define PREF_NTOP_RADIUS_AUTH           NTOPNG_PREFS_PREFIX".radius.auth_enabled"
#define PREF_RADIUS_SERVER              NTOPNG_PREFS_PREFIX".radius.radius_server_address"
#define PREF_RADIUS_SECRET              NTOPNG_PREFS_PREFIX".radius.radius_secret"
#define PREF_RADIUS_ADMIN_GROUP         NTOPNG_PREFS_PREFIX".radius.radius_admin_group"
#ifdef HAVE_RADIUS
#define MAX_RADIUS_LEN   256
#endif
#define PREF_NTOP_HTTP_AUTH           NTOPNG_PREFS_PREFIX".http_authenticator.auth_enabled"
#define PREF_HTTP_AUTHENTICATOR_URL   NTOPNG_PREFS_PREFIX".http_authenticator.http_auth_url"
#define MAX_HTTP_AUTHENTICATOR_LEN    256
#define MAX_HTTP_AUTHENTICATOR_RETURN_DATA_LEN      4096
#define PREF_NTOP_LOCAL_AUTH          NTOPNG_PREFS_PREFIX".local.auth_enabled"

#define NTOP_API_TOKENS               "ntopng.api_tokens"

/* Elastic Search */
#define NTOP_ES_TEMPLATE              "ntopng_template_elk.json"
#define NTOP_ES6_TEMPLATE             "ntopng_template_elk6.json"
#define NTOP_ES7_TEMPLATE             "ntopng_template_elk7.json"
#define ES_MAX_QUEUE_LEN              32768
#define ES_BULK_BUFFER_SIZE           1*1024*1024
#define ES_BULK_MAX_DELAY             5

/* Logstash */
#define LS_MAX_QUEUE_LEN              32768
/* Unknown values for host groups */
#define UNKNOWN_CONTINENT     ""
#define UNKNOWN_COUNTRY       ""
#define UNKNOWN_CITY          ""
#define UNKNOWN_OS            ""
#define UNKNOWN_ASN           "Private ASN"
#define UNKNOWN_LOCAL_NETWORK "Remote Networks"

/* Macros */
#define COUNT_OF(x) ((sizeof(x)/sizeof(0[x])) / ((size_t)(!(sizeof(x) % sizeof(0[x])))))

#ifndef _STATIC_ASSERT
#define _STATIC_ASSERT(COND,MSG) typedef char static_assertion_##MSG[(!!(COND))*2-1]
#endif
#define _COMPILE_TIME_ASSERT3(X,L) _STATIC_ASSERT(X,static_assertion_at_line_##L)
#define _COMPILE_TIME_ASSERT2(X,L) _COMPILE_TIME_ASSERT3(X,L)
#define COMPILE_TIME_ASSERT(X)     _COMPILE_TIME_ASSERT2(X,__LINE__)

#define MAX_NUM_HTTP_REPLACEMENTS                    4

#define CACHE_LINE_LEN                  64

#define BITMAP_NUM_BITS                128 /* This must be a multiple of 64 */

#define TLS_HANDSHAKE_PACKET          0x16
#define TLS_PAYLOAD_PACKET            0x17
#define TLS_CLIENT_HELLO              0x01
#define TLS_SERVER_HELLO              0x02
#define TLS_CLIENT_KEY_EXCHANGE       0x10
#define TLS_SERVER_CHANGE_CIPHER_SPEC 0x14
#define TLS_NEW_SESSION_TICKET        0x04

#define TLS_MAX_HANDSHAKE_PCKS          15
#define TLS_MIN_PACKET_SIZE             10

#define HTTP_MAX_CONTENT_TYPE_LENGTH    63
#define HTTP_MAX_HEADER_LINES           20
#define HTTP_MAX_POST_DATA_LEN          (1<<17) /* 128K */
#define HTTP_CONTENT_TYPE_HEADER        "Content-Type: "
#define CONST_HELLO_HOST                "hello"

#define CONST_CHILDREN_SAFE                    "children_safe"
#define CONST_FORGE_GLOBAL_DNS                 "forge_global_dns"
#define CONST_ROUTING_POLICY_ID                "routing_policy_id"
#define CONST_POOL_SHAPER_ID                   "pool_shaper_id"
#define CONST_SCHEDULE_BITMAP                  "daily_schedule"
#define CONST_ENFORCE_QUOTAS_PER_POOL_MEMBER   "enforce_quotas_per_pool_member"
#define CONST_ENFORCE_SHAPERS_PER_POOL_MEMBER  "enforce_shapers_per_pool_member"
#define CONST_ENFORCE_CROSS_APPLICATION_QUOTAS "enforce_cross_application_quotas"

#define DEFAULT_TIME_SCHEDULE                0xFFFFFFFF

#define CACHED_ENTRIES_THRESHOLD        1024
#define MAX_CATEGORY_CACHE_DURATION     300 /* Purge entries more than 5 mins old */

#define MARKER_NO_ACTION                0 /* Pass when a verdict is not yet reached */
#define MARKER_PASS                     1
#define MARKER_DROP                     2

#define NO_HOST_POOL_ID                 0          /* Keep in sync with pools.lua pools.DEFAULT_POOL_ID   */
#define DEFAULT_POOL_NAME               "Default"  /* Keep in sync with pools.lua pools.DEFAULT_POOL_NAME */

extern struct ntopngLuaContext* getUserdata(struct lua_State *vm);
#define getLuaVMContext(a)      (a ? getUserdata(a) : NULL)
#define getLuaVMUserdata(a,b)   (a ? getUserdata(a)->b : NULL)
#define getLuaVMUservalue(a,b)  getUserdata(a)->b

/*
   We assume that a host with more than CONST_MAX_NUM_HOST_USES
   MACs associated is a router
*/
#define CONST_MAX_NUM_HOST_USES    8

#define MAX_CHECKPOINT_COMPRESSION_BUFFER_SIZE 1024

/* Keep in sync with nProbe */
#define MAX_ZMQ_FLOW_BUF             8192
#define DEFAULT_ZMQ_TCP_KEEPALIVE       1  /* Keepalive ON */
#define DEFAULT_ZMQ_TCP_KEEPALIVE_IDLE  30 /* Keepalive after 30 seconds */
#define DEFAULT_ZMQ_TCP_KEEPALIVE_CNT   3  /* Keepalive send 3 probes */
#define DEFAULT_ZMQ_TCP_KEEPALIVE_INTVL 3  /* Keepalive probes sent every 3 seconds */

#define MAX_NUM_ASYNC_SNMP_ENGINES   8
#define MIN_NUM_HASH_WALK_ELEMS      512

#define COMPANION_QUEUE_LEN          4096

/*
  Queue lengths for flow-dump-related queues
 */
#define MAX_IDLE_FLOW_QUEUE_LEN      131072
#define MAX_ACTIVE_FLOW_QUEUE_LEN    131072

/*
  Queue lengths for user-script queues
 */
#define MAX_FLOW_CHECKS_QUEUE_LEN       131072
#define MAX_HOST_CHECKS_QUEUE_LEN       131072

/*
  user-script lua engine lifetime 
 */
#define HOOKS_ENGINE_LIFETIME              600    /* Seconds */

/*
  Queue length for view interfaces
 */

#define MAX_VIEW_INTERFACE_QUEUE_LEN       131072

#ifdef NTOPNG_EMBEDDED_EDITION
#define DEFAULT_THREAD_POOL_SIZE     1
#define MAX_THREAD_POOL_SIZE         1
#else
#define DEFAULT_THREAD_POOL_SIZE     2
#define MAX_THREAD_POOL_SIZE        32
#endif

#define DONT_NOT_EXPIRE_BEFORE_SEC        15 /* sec */
#define MAX_NDPI_IDLE_TIME_BEFORE_GUESS   5 /* sec */
#define MAX_NUM_PCAP_CAPTURES             4
#define MAX_NUM_COMPANION_INTERFACES      4
#define MAX_NUM_FINGERPRINT               25

#define MAX_ENTROPY_BYTES                 4096
#define MAX_NUM_OBSERVATION_POINTS        256

#define ALERT_ACTION_ENGAGE           "engage"
#define ALERT_ACTION_RELEASE          "release"
#define ALERT_ACTION_STORE            "store"

#define SCORE_LEVEL_INFO                1
#define SCORE_LEVEL_NOTICE              NDPI_SCORE_RISK_LOW
#define SCORE_LEVEL_WARNING             NDPI_SCORE_RISK_MEDIUM
#define SCORE_LEVEL_ERROR               NDPI_SCORE_RISK_HIGH
#define SCORE_LEVEL_SEVERE              NDPI_SCORE_RISK_SEVERE

#define SCORE_MAX_VALUE                 SCORE_LEVEL_SEVERE /* Maximum client/server score. Flow score is 2 * SCORE_MAX_VALUE. */

#ifndef WIN32
#define CONST_DEFAULT_DUMP_SYSLOG_FACILITY LOG_DAEMON
#endif

#define UNKNOWN_FLOW_DIRECTION          2

//#define PROFILING
#ifdef PROFILING
#define PROFILING_DECLARE(n) \
        ticks __profiling_sect_start[n]; \
        const char *__profiling_sect_label[n]; \
        ticks __profiling_sect_tot[n]; \
	u_int64_t __profiling_sect_counter[n];
#define PROFILING_INIT() memset(__profiling_sect_tot, 0, sizeof(__profiling_sect_tot)), memset(__profiling_sect_label, 0, sizeof(__profiling_sect_label)), memset(__profiling_sect_counter, 0, sizeof(__profiling_sect_counter))
#define PROFILING_SECTION_ENTER(l,i) __profiling_sect_start[i] = Utils::getticks(), __profiling_sect_label[i] = l, __profiling_sect_counter[i]++
#define PROFILING_SECTION_EXIT(i)    __profiling_sect_tot[i] += Utils::getticks() - __profiling_sect_start[i]
#define PROFILING_SUB_SECTION_ENTER(f, l, i) f->profiling_section_enter(l, i)
#define PROFILING_SUB_SECTION_EXIT(f, i)     f->profiling_section_exit(i)
#define PROFILING_NUM_SECTIONS (sizeof(__profiling_sect_tot)/sizeof(ticks))
#define PROFILING_SECTION_AVG(i,n) (__profiling_sect_tot[i] / (n + 1))
#define PROFILING_SECTION_TICKS(i) (__profiling_sect_tot[i] / (__profiling_sect_counter[i] + 1))
#define PROFILING_SECTION_LABEL(i) __profiling_sect_label[i]
#else
#define PROFILING_DECLARE(n)
#define PROFILING_INIT()
#define PROFILING_SECTION_ENTER(l, i)
#define PROFILING_SECTION_EXIT(i)
#define PROFILING_SUB_SECTION_ENTER(f, l, i)
#define PROFILING_SUB_SECTION_EXIT(f, i)
#endif

#endif /* _NTOP_DEFINES_H_ */

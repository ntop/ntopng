/*
 *
 * (C) 2013-24 - ntop.org
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

/*
 *  ntop includes sFlow(TM), freely available from http://www.inmon.com/".
 *
 * Some code has been copied from the InMon sflowtool
 */

/* #define DEBUG_FLOWS     1 */
/* #define DEBUG_UPSCALING 1 */


/* sFlow Counter Fields (keep this in sync with ntopng */
#define SFLOW_DEVICE_IP                 0
#define SFLOW_SAMPLES_GENERATED         1
#define SFLOW_IF_INDEX                  2
#define SFLOW_IF_NAME                   3
#define SFLOW_IF_TYPE                   4
#define SFLOW_IF_SPEED                  5
#define SFLOW_IF_DIRECTION              6
#define SFLOW_IF_ADMIN_STATUS           7
#define SFLOW_IF_OPER_STATUS            8
#define SFLOW_IF_IN_OCTETS              9
#define SFLOW_IF_IN_PACKETS             10
#define SFLOW_IF_IN_ERRORS              11
#define SFLOW_IF_OUT_OCTETS             12
#define SFLOW_IF_OUT_PACKETS            13
#define SFLOW_IF_OUT_ERRORS             14
#define SFLOW_IF_PROMISCUOUS_MODE       15


#define INET6 1

#define MAX_NUM_SFLOW_POOLMAP_ENTRIES  32768

u_int32_t numsFlowsV2Rcvd = 0, numsFlowsV4Rcvd = 0, numsFlowsV5Rcvd = 0, numBadsFlowsVersionsRcvd = 0;

typedef struct {
  u_int32_t addr;
} SFLIPv4;

typedef struct {
  u_char addr[16];
} SFLIPv6;

typedef union _SFLAddress_value {
  SFLIPv4 ip_v4;
  SFLIPv6 ip_v6;
} SFLAddress_value;

enum SFLAddress_type {
  SFLADDRESSTYPE_UNDEFINED = 0,
  SFLADDRESSTYPE_IP_V4 = 1,
  SFLADDRESSTYPE_IP_V6 = 2
};

typedef struct _SFLAddress {
  u_int32_t type;           /* enum SFLAddress_type */
  SFLAddress_value address;
} SFLAddress;

/* Packet header data */

#define SFL_DEFAULT_HEADER_SIZE 128
#define SFL_DEFAULT_COLLECTOR_PORT 6343
#define SFL_DEFAULT_SAMPLING_RATE 400

/* The header protocol describes the format of the sampled header */
enum SFLHeader_protocol {
  SFLHEADER_ETHERNET_ISO8023     = 1,
  SFLHEADER_ISO88024_TOKENBUS    = 2,
  SFLHEADER_ISO88025_TOKENRING   = 3,
  SFLHEADER_FDDI                 = 4,
  SFLHEADER_FRAME_RELAY          = 5,
  SFLHEADER_X25                  = 6,
  SFLHEADER_PPP                  = 7,
  SFLHEADER_SMDS                 = 8,
  SFLHEADER_AAL5                 = 9,
  SFLHEADER_AAL5_IP              = 10, /* e.g. Cisco AAL5 mux */
  SFLHEADER_IPv4                 = 11,
  SFLHEADER_IPv6                 = 12,
  SFLHEADER_MPLS                 = 13,
  SFLHEADER_POS                  = 14,
  SFLHEADER_IEEE80211MAC         = 15,
  SFLHEADER_IEEE80211_AMPDU      = 16,
  SFLHEADER_IEEE80211_AMSDU_SUBFRAME = 17
};

/* raw sampled header */

typedef struct _SFLSampled_header {
  u_int32_t header_protocol;            /* (enum SFLHeader_protocol) */
  u_int32_t frame_length;               /* Original length of packet before sampling */
  u_int32_t stripped;                   /* header/trailer bytes stripped by sender */
  u_int32_t header_length;              /* length of sampled header bytes to follow */
  u_int8_t *header_bytes;               /* Header bytes */
} SFLSampled_header;

/* decoded ethernet header */

typedef struct _SFLSampled_ethernet {
  u_int32_t eth_len;       /* The length of the MAC packet excluding
			      lower layer encapsulations */
  u_int8_t src_mac[8];    /* 6 bytes + 2 pad */
  u_int8_t dst_mac[8];
  u_int32_t eth_type;
} SFLSampled_ethernet;

/* decoded IP version 4 header */

typedef struct _SFLSampled_ipv4 {
  u_int32_t length;      /* The length of the IP packet
			    excluding lower layer encapsulations */
  u_int32_t protocol;    /* IP Protocol type (for example, TCP = 6, UDP = 17) */
  SFLIPv4 src_ip; /* Source IP Address */
  SFLIPv4 dst_ip; /* Destination IP Address */
  u_int32_t src_port;    /* TCP/UDP source port number or equivalent */
  u_int32_t dst_port;    /* TCP/UDP destination port number or equivalent */
  u_int32_t tcp_flags;   /* TCP flags */
  u_int32_t tos;         /* IP type of service */
} SFLSampled_ipv4;

/* decoded IP version 6 data */

typedef struct _SFLSampled_ipv6 {
  u_int32_t length;       /* The length of the IP packet
			     excluding lower layer encapsulations */
  u_int32_t protocol;     /* IP Protocol type (for example, TCP = 6, UDP = 17) */
  SFLIPv6 src_ip; /* Source IP Address */
  SFLIPv6 dst_ip; /* Destination IP Address */
  u_int32_t src_port;     /* TCP/UDP source port number or equivalent */
  u_int32_t dst_port;     /* TCP/UDP destination port number or equivalent */
  u_int32_t tcp_flags;    /* TCP flags */
  u_int32_t priority;     /* IP priority */
} SFLSampled_ipv6;

/* Extended data types */

/* Extended switch data */

typedef struct _SFLExtended_switch {
  u_int32_t src_vlan;       /* The 802.1Q VLAN id of incomming frame */
  u_int32_t src_priority;   /* The 802.1p priority */
  u_int32_t dst_vlan;       /* The 802.1Q VLAN id of outgoing frame */
  u_int32_t dst_priority;   /* The 802.1p priority */
} SFLExtended_switch;

/* Extended router data */

typedef struct _SFLExtended_router {
  SFLAddress nexthop;               /* IP address of next hop router */
  u_int32_t src_mask;               /* Source address prefix mask bits */
  u_int32_t dst_mask;               /* Destination address prefix mask bits */
} SFLExtended_router;

/* Extended gateway data */
enum SFLExtended_as_path_segment_type {
  SFLEXTENDED_AS_SET = 1,      /* Unordered set of ASs */
  SFLEXTENDED_AS_SEQUENCE = 2  /* Ordered sequence of ASs */
};

typedef struct _SFLExtended_as_path_segment {
  u_int32_t type;   /* enum SFLExtended_as_path_segment_type */
  u_int32_t length; /* number of AS numbers in set/sequence */
  union {
    u_int32_t *set;
    u_int32_t *seq;
  } as;
} SFLExtended_as_path_segment;

typedef struct _SFLExtended_gateway {
  SFLAddress nexthop;                       /* Address of the border router that should
                                               be used for the destination network */
  u_int32_t as;                             /* AS number for this gateway */
  u_int32_t src_as;                         /* AS number of source (origin) */
  u_int32_t src_peer_as;                    /* AS number of source peer */
  u_int32_t dst_as_path_segments;           /* number of segments in path */
  SFLExtended_as_path_segment *dst_as_path; /* list of seqs or sets */
  u_int32_t communities_length;             /* number of communities */
  u_int32_t *communities;                   /* set of communities */
  u_int32_t localpref;                      /* LocalPref associated with this route */
} SFLExtended_gateway;

typedef struct _SFLString {
  u_int32_t len;
  char *str;
} SFLString;

/* Extended user data */

typedef struct _SFLExtended_user {
  u_int32_t src_charset;  /* MIBEnum value of character set used to encode a string - See RFC 2978
			     Where possible UTF-8 encoding (MIBEnum=106) should be used. A value
			     of zero indicates an unknown encoding. */
  SFLString src_user;
  u_int32_t dst_charset;
  SFLString dst_user;
} SFLExtended_user;

/* Extended URL data */

enum SFLExtended_url_direction {
  SFLEXTENDED_URL_SRC = 1, /* URL is associated with source address */
  SFLEXTENDED_URL_DST = 2  /* URL is associated with destination address */
};

typedef struct _SFLExtended_url {
  u_int32_t direction;   /* enum SFLExtended_url_direction */
  SFLString url;         /* URL associated with the packet flow.
			    Must be URL encoded */
  SFLString host;        /* The host field from the HTTP header */
} SFLExtended_url;

/* Extended MPLS data */

typedef struct _SFLLabelStack {
  u_int32_t depth;
  u_int32_t *stack; /* first entry is top of stack - see RFC 3032 for encoding */
} SFLLabelStack;

typedef struct _SFLExtended_mpls {
  SFLAddress nextHop;        /* Address of the next hop */
  SFLLabelStack in_stack;
  SFLLabelStack out_stack;
} SFLExtended_mpls;

/* Extended NAT data
   Packet header records report addresses as seen at the sFlowDataSource.
   The extended_nat structure reports on translated source and/or destination
   addesses for this packet. If an address was not translated it should
   be equal to that reported for the header. */

typedef struct _SFLExtended_nat {
  SFLAddress src;    /* Source address */
  SFLAddress dst;    /* Destination address */
} SFLExtended_nat;

/* additional Extended MPLS stucts */

typedef struct _SFLExtended_mpls_tunnel {
  SFLString tunnel_lsp_name;  /* Tunnel name */
  u_int32_t tunnel_id;        /* Tunnel ID */
  u_int32_t tunnel_cos;       /* Tunnel COS value */
} SFLExtended_mpls_tunnel;

typedef struct _SFLExtended_mpls_vc {
  SFLString vc_instance_name; /* VC instance name */
  u_int32_t vll_vc_id;        /* VLL/VC instance ID */
  u_int32_t vc_label_cos;     /* VC Label COS value */
} SFLExtended_mpls_vc;

/* Extended MPLS FEC
   - Definitions from MPLS-FTN-STD-MIB mplsFTNTable */

typedef struct _SFLExtended_mpls_FTN {
  SFLString mplsFTNDescr;
  u_int32_t mplsFTNMask;
} SFLExtended_mpls_FTN;

/* Extended MPLS LVP FEC
   - Definition from MPLS-LDP-STD-MIB mplsFecTable
   Note: mplsFecAddrType, mplsFecAddr information available
   from packet header */

typedef struct _SFLExtended_mpls_LDP_FEC {
  u_int32_t mplsFecAddrPrefixLength;
} SFLExtended_mpls_LDP_FEC;

/* Extended VLAN tunnel information
   Record outer VLAN encapsulations that have
   been stripped. extended_vlantunnel information
   should only be reported if all the following conditions are satisfied:
   1. The packet has nested vlan tags, AND
   2. The reporting device is VLAN aware, AND
   3. One or more VLAN tags have been stripped, either
   because they represent proprietary encapsulations, or
   because switch hardware automatically strips the outer VLAN
   encapsulation.
   Reporting extended_vlantunnel information is not a substitute for
   reporting extended_switch information. extended_switch data must
   always be reported to describe the ingress/egress VLAN information
   for the packet. The extended_vlantunnel information only applies to
   nested VLAN tags, and then only when one or more tags has been
   stripped. */

typedef SFLLabelStack SFLVlanStack;
typedef struct _SFLExtended_vlan_tunnel {
  SFLVlanStack stack;  /* List of stripped 802.1Q TPID/TCI layers. Each
			  TPID,TCI pair is represented as a single 32 bit
			  integer. Layers listed from outermost to
			  innermost. */
} SFLExtended_vlan_tunnel;

////////////////// IEEE 802.11 Extension structs ////////////////////

/* The 4-byte cipher_suite identifier follows the format of the cipher suite
   selector value from the 802.11i (TKIP/CCMP amendment to 802.11i)
   The most significant three bytes contain the OUI and the least significant
   byte contains the Suite Type.

   The currently assigned values are:

   OUI        |Suite type  |Meaning
   ----------------------------------------------------
   00-0F-AC   | 0          | Use group cipher suite
   00-0F-AC   | 1          | WEP-40
   00-0F-AC   | 2          | TKIP
   00-0F-AC   | 3          | Reserved
   00-0F-AC   | 4          | CCMP
   00-0F-AC   | 5          | WEP-104
   00-0F-AC   | 6-255      | Reserved
   Vendor OUI | Other      | Vendor specific
   Other      | Any        | Reserved
   ----------------------------------------------------
*/

typedef u_int32_t SFLCipherSuite;

/* Extended wifi Payload
   Used to provide unencrypted version of 802.11 MAC data. If the
   MAC data is not encrypted then the agent must not include an
   extended_wifi_payload structure.
   If 802.11 MAC data is encrypted then the sampled_header structure
   should only contain the MAC header (since encrypted data cannot
   be decoded by the sFlow receiver). If the sFlow agent has access to
   the unencrypted payload, it should add an extended_wifi_payload
   structure containing the unencrypted data bytes from the sampled
   packet header, starting at the beginning of the 802.2 LLC and not
   including any trailing encryption footers.  */
/* opaque = flow_data; enterprise = 0; format = 1013 */

typedef struct _SFLExtended_wifi_payload {
  SFLCipherSuite cipherSuite;
  SFLSampled_header header;
} SFLExtended_wifi_payload;

typedef enum  {
  IEEE80211_A=1,
  IEEE80211_B=2,
  IEEE80211_G=3,
  IEEE80211_N=4,
} SFL_IEEE80211_version;

/* opaque = flow_data; enterprise = 0; format = 1014 */

#define SFL_MAX_SSID_LEN 256

typedef struct _SFLExtended_wifi_rx {
  u_int32_t ssid_len;
  char *ssid;
  char bssid[6];    /* BSSID */
  SFL_IEEE80211_version version;  /* version */
  u_int32_t channel;       /* channel number */
  u_int64_t speed;
  u_int32_t rsni;          /* received signal to noise ratio, see dot11FrameRprtRSNI */
  u_int32_t rcpi;          /* received channel power, see dot11FrameRprtLastRCPI */
  u_int32_t packet_duration_us; /* amount of time that the successfully received pkt occupied RF medium.*/
} SFLExtended_wifi_rx;

/* opaque = flow_data; enterprise = 0; format = 1015 */

typedef struct _SFLExtended_wifi_tx {
  u_int32_t ssid_len;
  char *ssid;              /* SSID string */
  char  bssid[6];             /* BSSID */
  SFL_IEEE80211_version version;    /* version */
  u_int32_t transmissions;   /* number of transmissions for sampled
				packet.
				0 = unkown
				1 = packet was successfully transmitted
				on first attempt
				n > 1 = n - 1 retransmissions */
  u_int32_t packet_duration_us;  /* amount of time that the successfully
                                    transmitted packet occupied the
                                    RF medium */
  u_int32_t retrans_duration_us; /* amount of time that failed transmission
                                    attempts occupied the RF medium */
  u_int32_t channel;         /* channel number */
  u_int64_t speed;
  u_int32_t power_mw;           /* transmit power in mW. */
} SFLExtended_wifi_tx;

/* Extended 802.11 Aggregation Data */
/* A flow_sample of an aggregated frame would consist of a packet
   header for the whole frame + any other extended structures that
   apply (e.g. 80211_tx/rx etc.) + an extended_wifi_aggregation
   structure which would contain an array of pdu structures (one
   for each PDU in the aggregate). A pdu is simply an array of
   flow records, in the simplest case a packet header for each PDU,
   but extended structures could be included as well. */

/* opaque = flow_data; enterprise = 0; format = 1016 */

struct _SFLFlow_Pdu; // forward decl

typedef struct _SFLExtended_aggregation {
  u_int32_t num_pdus;
  struct _SFFlow_Pdu *pdus;
} SFLExtended_aggregation;

/* Extended socket information,
   Must be filled in for all application transactions associated with a network socket
   Omit if transaction associated with non-network IPC  */

/* IPv4 Socket */
/* opaque = flow_data; enterprise = 0; format = 2100 */
typedef struct _SFLExtended_socket_ipv4 {
  u_int32_t protocol;     /* IP Protocol (e.g. TCP = 6, UDP = 17) */
  SFLIPv4 local_ip;      /* local IP address */
  SFLIPv4 remote_ip;     /* remote IP address */
  u_int32_t local_port;   /* TCP/UDP local port number or equivalent */
  u_int32_t remote_port;  /* TCP/UDP remote port number of equivalent */
} SFLExtended_socket_ipv4;

#define XDRSIZ_SFLEXTENDED_SOCKET4 20

/* IPv6 Socket */
/* opaque = flow_data; enterprise = 0; format = 2101 */
typedef struct _SFLExtended_socket_ipv6 {
  u_int32_t protocol;     /* IP Protocol (e.g. TCP = 6, UDP = 17) */
  SFLIPv6 local_ip;      /* local IP address */
  SFLIPv6 remote_ip;     /* remote IP address */
  u_int32_t local_port;   /* TCP/UDP local port number or equivalent */
  u_int32_t remote_port;  /* TCP/UDP remote port number of equivalent */
} SFLExtended_socket_ipv6;

#define XDRSIZ_SFLEXTENDED_SOCKET6 44

typedef enum  {
  MEMCACHE_PROT_OTHER   = 0,
  MEMCACHE_PROT_ASCII   = 1,
  MEMCACHE_PROT_BINARY  = 2,
} SFLMemcache_prot;

typedef enum  {
  MEMCACHE_CMD_OTHER    = 0,
  MEMCACHE_CMD_SET      = 1,
  MEMCACHE_CMD_ADD      = 2,
  MEMCACHE_CMD_REPLACE  = 3,
  MEMCACHE_CMD_APPEND   = 4,
  MEMCACHE_CMD_PREPEND  = 5,
  MEMCACHE_CMD_CAS      = 6,
  MEMCACHE_CMD_GET      = 7,
  MEMCACHE_CMD_GETS     = 8,
} SFLMemcache_cmd;

enum SFLMemcache_operation_status {
  MEMCACHE_OP_UNKNOWN      = 0,
  MEMCACHE_OP_OK           = 1,
  MEMCACHE_OP_ERROR        = 2,
  MEMCACHE_OP_CLIENT_ERROR = 3,
  MEMCACHE_OP_SERVER_ERROR = 4,
  MEMCACHE_OP_STORED       = 5,
  MEMCACHE_OP_NOT_STORED   = 6,
  MEMCACHE_OP_EXISTS       = 7,
  MEMCACHE_OP_NOT_FOUND    = 8,
  MEMCACHE_OP_DELETED      = 9,
};

#define SFL_MAX_MEMCACHE_KEY 255

typedef struct _SFLSampled_memcache {
  u_int32_t protocol;    /* SFLMemcache_prot */
  u_int32_t command;     /* SFLMemcache_cmd */
  SFLString key;        /* up to 255 chars */
  u_int32_t nkeys;
  u_int32_t value_bytes;
  u_int32_t duration_uS;
  u_int32_t status;      /* SFLMemcache_operation_status */
} SFLSampled_memcache;

typedef enum {
  SFHTTP_OTHER    = 0,
  SFHTTP_OPTIONS  = 1,
  SFHTTP_GET      = 2,
  SFHTTP_HEAD     = 3,
  SFHTTP_POST     = 4,
  SFHTTP_PUT      = 5,
  SFHTTP_DELETE   = 6,
  SFHTTP_TRACE    = 7,
  SFHTTP_CONNECT  = 8,
} SFLHTTP_method;

#define SFL_MAX_HTTP_URI 255
#define SFL_MAX_HTTP_HOST 32
#define SFL_MAX_HTTP_REFERRER 255
#define SFL_MAX_HTTP_USERAGENT 64
#define SFL_MAX_HTTP_AUTHUSER 32
#define SFL_MAX_HTTP_MIMETYPE 32

typedef struct _SFLSampled_http {
  SFLHTTP_method method;
  u_int32_t protocol;      /* 1.1=1001 */
  SFLString uri;           /* URI exactly as it came from the client (up to 255 bytes) */
  SFLString host;          /* Host value from request header (<= 32 bytes) */
  SFLString referrer;      /* Referer value from request header (<=255 bytes) */
  SFLString useragent;     /* User-Agent value from request header (<= 64 bytes)*/
  SFLString authuser;      /* RFC 1413 identity of user (<=32 bytes)*/
  SFLString mimetype;      /* Mime-Type (<=32 bytes) */
  u_int64_t bytes;          /* Content-Length of document transferred */
  u_int32_t uS;             /* duration of the operation (microseconds) */
  u_int32_t status;         /* HTTP status code */
} SFLSampled_http;


typedef enum {
  SFLOW_CAL_TRANSACTION_OTHER=0,
  SFLOW_CAL_TRANSACTION_START,
  SFLOW_CAL_TRANSACTION_END,
  SFLOW_CAL_TRANSACTION_ATOMIC,
  SFLOW_CAL_TRANSACTION_EVENT,
  SFLOW_CAL_NUM_TRANSACTION_TYPES
}  EnumSFLCALTransaction;

static const char *CALTransactionNames[] = {"OTHER", "START", "END","ATOMIC", "EVENT" };

typedef struct _SFLSampled_CAL {
  EnumSFLCALTransaction type;
  u_int32_t depth;
  SFLString pool;
  SFLString transaction;
  SFLString operation;
  SFLString status;
  u_int64_t duration_uS;
} SFLSampled_CAL;

#define SFLCAL_MAX_POOL_LEN 32
#define SFLCAL_MAX_TRANSACTION_LEN 128
#define SFLCAL_MAX_OPERATION_LEN 128
#define SFLCAL_MAX_STATUS_LEN 64

enum SFLFlow_type_tag {
  /* enterprise = 0, format = ... */
  SFLFLOW_HEADER    = 1,      /* Packet headers are sampled */
  SFLFLOW_ETHERNET  = 2,      /* MAC layer information */
  SFLFLOW_IPV4      = 3,      /* IP version 4 data */
  SFLFLOW_IPV6      = 4,      /* IP version 6 data */
  SFLFLOW_EX_SWITCH    = 1001,      /* Extended switch information */
  SFLFLOW_EX_ROUTER    = 1002,      /* Extended router information */
  SFLFLOW_EX_GATEWAY   = 1003,      /* Extended gateway router information */
  SFLFLOW_EX_USER      = 1004,      /* Extended TACAS/RADIUS user information */
  SFLFLOW_EX_URL       = 1005,      /* Extended URL information */
  SFLFLOW_EX_MPLS      = 1006,      /* Extended MPLS information */
  SFLFLOW_EX_NAT       = 1007,      /* Extended NAT information */
  SFLFLOW_EX_MPLS_TUNNEL  = 1008,   /* additional MPLS information */
  SFLFLOW_EX_MPLS_VC      = 1009,
  SFLFLOW_EX_MPLS_FTN     = 1010,
  SFLFLOW_EX_MPLS_LDP_FEC = 1011,
  SFLFLOW_EX_VLAN_TUNNEL  = 1012,   /* VLAN stack */
  SFLFLOW_EX_80211_PAYLOAD = 1013,
  SFLFLOW_EX_80211_RX      = 1014,
  SFLFLOW_EX_80211_TX      = 1015,
  SFLFLOW_EX_AGGREGATION   = 1016,
  SFLFLOW_EX_SOCKET4       = 2100,
  SFLFLOW_EX_SOCKET6       = 2101,
  SFLFLOW_MEMCACHE         = 2200,
  SFLFLOW_HTTP             = 2201,
  SFLFLOW_CAL             = (4300 << 12) + 5,  /* 4300 is InMon enterprise no. */
};

typedef union _SFLFlow_type {
  SFLSampled_header header;
  SFLSampled_ethernet ethernet;
  SFLSampled_ipv4 ipv4;
  SFLSampled_ipv6 ipv6;
  SFLSampled_memcache memcache;
  SFLSampled_http http;
  SFLSampled_CAL cal;
  SFLExtended_switch sw;
  SFLExtended_router router;
  SFLExtended_gateway gateway;
  SFLExtended_user user;
  SFLExtended_url url;
  SFLExtended_mpls mpls;
  SFLExtended_nat nat;
  SFLExtended_mpls_tunnel mpls_tunnel;
  SFLExtended_mpls_vc mpls_vc;
  SFLExtended_mpls_FTN mpls_ftn;
  SFLExtended_mpls_LDP_FEC mpls_ldp_fec;
  SFLExtended_vlan_tunnel vlan_tunnel;
  SFLExtended_wifi_payload wifi_payload;
  SFLExtended_wifi_rx wifi_rx;
  SFLExtended_wifi_tx wifi_tx;
  SFLExtended_aggregation aggregation;
  SFLExtended_socket_ipv4 socket4;
  SFLExtended_socket_ipv6 socket6;
} SFLFlow_type;

typedef struct _SFLFlow_sample_element {
  struct _SFLFlow_sample_element *nxt;
  u_int32_t tag;  /* SFLFlow_type_tag */
  u_int32_t length;
  SFLFlow_type flowType;
} SFLFlow_sample_element;

enum SFL_sample_tag {
  SFLFLOW_SAMPLE = 1,              /* enterprise = 0 : format = 1 */
  SFLCOUNTERS_SAMPLE = 2,          /* enterprise = 0 : format = 2 */
  SFLFLOW_SAMPLE_EXPANDED = 3,     /* enterprise = 0 : format = 3 */
  SFLCOUNTERS_SAMPLE_EXPANDED = 4  /* enterprise = 0 : format = 4 */
};

typedef struct _SFLFlow_Pdu {
  struct _SFLFlow_Pdu *nxt;
  u_int32_t num_elements;
  SFLFlow_sample_element *elements;
} SFLFlow_Pdu;


/* Format of a single flow sample */

typedef struct _SFLFlow_sample {
  /* u_int32_t tag;    */         /* SFL_sample_tag -- enterprise = 0 : format = 1 */
  /* u_int32_t length; */
  u_int32_t sequence_number;      /* Incremented with each flow sample
				     generated */
  u_int32_t source_id;            /* fsSourceId */
  u_int32_t sampling_rate;        /* fsPacketSamplingRate */
  u_int32_t sample_pool;          /* Total number of packets that could have been
				     sampled (i.e. packets skipped by sampling
				     process + total number of samples) */
  u_int32_t drops;                /* Number of times a packet was dropped due to
				     lack of resources */
  u_int32_t input;                /* SNMP ifIndex of input interface.
				     0 if interface is not known. */
  u_int32_t output;               /* SNMP ifIndex of output interface,
				     0 if interface is not known.
				     Set most significant bit to indicate
				     multiple destination interfaces
				     (i.e. in case of broadcast or multicast)
				     and set lower order bits to indicate
				     number of destination interfaces.
				     Examples:
				     0x00000002  indicates ifIndex = 2
				     0x00000000  ifIndex unknown.
				     0x80000007  indicates a packet sent
				     to 7 interfaces.
				     0x80000000  indicates a packet sent to
				     an unknown number of
				     interfaces greater than 1.*/
  u_int32_t num_elements;
  SFLFlow_sample_element *elements;
} SFLFlow_sample;

/* same thing, but the expanded version (for full 32-bit ifIndex numbers) */

typedef struct _SFLFlow_sample_expanded {
  /* u_int32_t tag;    */         /* SFL_sample_tag -- enterprise = 0 : format = 1 */
  /* u_int32_t length; */
  u_int32_t sequence_number;      /* Incremented with each flow sample
				     generated */
  u_int32_t ds_class;             /* EXPANDED */
  u_int32_t ds_index;             /* EXPANDED */
  u_int32_t sampling_rate;        /* fsPacketSamplingRate */
  u_int32_t sample_pool;          /* Total number of packets that could have been
				     sampled (i.e. packets skipped by sampling
				     process + total number of samples) */
  u_int32_t drops;                /* Number of times a packet was dropped due to
				     lack of resources */
  u_int32_t inputFormat;          /* EXPANDED */
  u_int32_t input;                /* SNMP ifIndex of input interface.
				     0 if interface is not known. */
  u_int32_t outputFormat;         /* EXPANDED */
  u_int32_t output;               /* SNMP ifIndex of output interface,
				     0 if interface is not known. */
  u_int32_t num_elements;
  SFLFlow_sample_element *elements;
} SFLFlow_sample_expanded;

/* Counter types */

/* Generic interface counters - see RFC 1573, 2233 */

typedef struct _SFLIf_counters {
  u_int32_t ifIndex;
  u_int32_t ifType;
  u_int64_t ifSpeed;
  u_int32_t ifDirection;        /* Derived from MAU MIB (RFC 2668)
				   0 = unknown, 1 = full-duplex,
				   2 = half-duplex, 3 = in, 4 = out */
  u_int32_t ifStatus;           /* bit field with the following bits assigned:
				   bit 0 = ifAdminStatus (0 = down, 1 = up)
				   bit 1 = ifOperStatus (0 = down, 1 = up) */
  u_int64_t ifInOctets;
  u_int32_t ifInUcastPkts;
  u_int32_t ifInMulticastPkts;
  u_int32_t ifInBroadcastPkts;
  u_int32_t ifInDiscards;
  u_int32_t ifInErrors;
  u_int32_t ifInUnknownProtos;
  u_int64_t ifOutOctets;
  u_int32_t ifOutUcastPkts;
  u_int32_t ifOutMulticastPkts;
  u_int32_t ifOutBroadcastPkts;
  u_int32_t ifOutDiscards;
  u_int32_t ifOutErrors;
  u_int32_t ifPromiscuousMode;
} SFLIf_counters;

/* Ethernet interface counters - see RFC 2358 */
typedef struct _SFLEthernet_counters {
  u_int32_t dot3StatsAlignmentErrors;
  u_int32_t dot3StatsFCSErrors;
  u_int32_t dot3StatsSingleCollisionFrames;
  u_int32_t dot3StatsMultipleCollisionFrames;
  u_int32_t dot3StatsSQETestErrors;
  u_int32_t dot3StatsDeferredTransmissions;
  u_int32_t dot3StatsLateCollisions;
  u_int32_t dot3StatsExcessiveCollisions;
  u_int32_t dot3StatsInternalMacTransmitErrors;
  u_int32_t dot3StatsCarrierSenseErrors;
  u_int32_t dot3StatsFrameTooLongs;
  u_int32_t dot3StatsInternalMacReceiveErrors;
  u_int32_t dot3StatsSymbolErrors;
} SFLEthernet_counters;

/* Token ring counters - see RFC 1748 */

typedef struct _SFLTokenring_counters {
  u_int32_t dot5StatsLineErrors;
  u_int32_t dot5StatsBurstErrors;
  u_int32_t dot5StatsACErrors;
  u_int32_t dot5StatsAbortTransErrors;
  u_int32_t dot5StatsInternalErrors;
  u_int32_t dot5StatsLostFrameErrors;
  u_int32_t dot5StatsReceiveCongestions;
  u_int32_t dot5StatsFrameCopiedErrors;
  u_int32_t dot5StatsTokenErrors;
  u_int32_t dot5StatsSoftErrors;
  u_int32_t dot5StatsHardErrors;
  u_int32_t dot5StatsSignalLoss;
  u_int32_t dot5StatsTransmitBeacons;
  u_int32_t dot5StatsRecoverys;
  u_int32_t dot5StatsLobeWires;
  u_int32_t dot5StatsRemoves;
  u_int32_t dot5StatsSingles;
  u_int32_t dot5StatsFreqErrors;
} SFLTokenring_counters;

/* 100 BaseVG interface counters - see RFC 2020 */

typedef struct _SFLVg_counters {
  u_int32_t dot12InHighPriorityFrames;
  u_int64_t dot12InHighPriorityOctets;
  u_int32_t dot12InNormPriorityFrames;
  u_int64_t dot12InNormPriorityOctets;
  u_int32_t dot12InIPMErrors;
  u_int32_t dot12InOversizeFrameErrors;
  u_int32_t dot12InDataErrors;
  u_int32_t dot12InNullAddressedFrames;
  u_int32_t dot12OutHighPriorityFrames;
  u_int64_t dot12OutHighPriorityOctets;
  u_int32_t dot12TransitionIntoTrainings;
  u_int64_t dot12HCInHighPriorityOctets;
  u_int64_t dot12HCInNormPriorityOctets;
  u_int64_t dot12HCOutHighPriorityOctets;
} SFLVg_counters;

typedef struct _SFLVlan_counters {
  u_int32_t vlan_id;
  u_int64_t octets;
  u_int32_t ucastPkts;
  u_int32_t multicastPkts;
  u_int32_t broadcastPkts;
  u_int32_t discards;
} SFLVlan_counters;

typedef struct _SFLWifi_counters {
  u_int32_t dot11TransmittedFragmentCount;
  u_int32_t dot11MulticastTransmittedFrameCount;
  u_int32_t dot11FailedCount;
  u_int32_t dot11RetryCount;
  u_int32_t dot11MultipleRetryCount;
  u_int32_t dot11FrameDuplicateCount;
  u_int32_t dot11RTSSuccessCount;
  u_int32_t dot11RTSFailureCount;
  u_int32_t dot11ACKFailureCount;
  u_int32_t dot11ReceivedFragmentCount;
  u_int32_t dot11MulticastReceivedFrameCount;
  u_int32_t dot11FCSErrorCount;
  u_int32_t dot11TransmittedFrameCount;
  u_int32_t dot11WEPUndecryptableCount;
  u_int32_t dot11QoSDiscardedFragmentCount;
  u_int32_t dot11AssociatedStationCount;
  u_int32_t dot11QoSCFPollsReceivedCount;
  u_int32_t dot11QoSCFPollsUnusedCount;
  u_int32_t dot11QoSCFPollsUnusableCount;
  u_int32_t dot11QoSCFPollsLostCount;
} SFLWifi_counters;

/* Processor Information */
/* opaque = counter_data; enterprise = 0; format = 1001 */

typedef struct _SFLProcessor_counters {
  u_int32_t five_sec_cpu;  /* 5 second average CPU utilization */
  u_int32_t one_min_cpu;   /* 1 minute average CPU utilization */
  u_int32_t five_min_cpu;  /* 5 minute average CPU utilization */
  u_int64_t total_memory;  /* total memory (in bytes) */
  u_int64_t free_memory;   /* free memory (in bytes) */
} SFLProcessor_counters;

typedef struct _SFLRadio_counters {
  u_int32_t elapsed_time;         /* elapsed time in ms */
  u_int32_t on_channel_time;      /* time in ms spent on channel */
  u_int32_t on_channel_busy_time; /* time in ms spent on channel and busy */
} SFLRadio_counters;

/* host sflow */

enum SFLMachine_type {
  SFLMT_unknown = 0,
  SFLMT_other   = 1,
  SFLMT_x86     = 2,
  SFLMT_x86_64  = 3,
  SFLMT_ia64    = 4,
  SFLMT_sparc   = 5,
  SFLMT_alpha   = 6,
  SFLMT_powerpc = 7,
  SFLMT_m68k    = 8,
  SFLMT_mips    = 9,
  SFLMT_arm     = 10,
  SFLMT_hppa    = 11,
  SFLMT_s390    = 12
};

enum SFLOS_name {
  SFLOS_unknown   = 0,
  SFLOS_other     = 1,
  SFLOS_linux     = 2,
  SFLOS_windows   = 3,
  SFLOS_darwin    = 4,
  SFLOS_hpux      = 5,
  SFLOS_aix       = 6,
  SFLOS_dragonfly = 7,
  SFLOS_freebsd   = 8,
  SFLOS_netbsd    = 9,
  SFLOS_openbsd   = 10,
  SFLOS_osf       = 11,
  SFLOS_solaris   = 12
};

typedef struct _SFLMacAddress {
  u_int8_t mac[8];
} SFLMacAddress;

typedef struct _SFLAdaptor {
  u_int32_t ifIndex;
  u_int32_t num_macs;
  SFLMacAddress macs[1];
} SFLAdaptor;

typedef struct _SFLAdaptorList {
  u_int32_t capacity;
  u_int32_t num_adaptors;
  SFLAdaptor **adaptors;
} SFLAdaptorList;

typedef struct _SFLHost_parent {
  u_int32_t dsClass;       /* sFlowDataSource class */
  u_int32_t dsIndex;       /* sFlowDataSource index */
} SFLHost_parent;


#define SFL_MAX_HOSTNAME_LEN 64
#define SFL_MAX_OSRELEASE_LEN 32

typedef struct _SFLHostId {
  SFLString hostname;
  u_char uuid[16];
  u_int32_t machine_type; /* enum SFLMachine_type */
  u_int32_t os_name;      /* enum SFLOS_name */
  SFLString os_release;  /* max len 32 bytes */
} SFLHostId;

typedef struct _SFLHost_nio_counters {
  u_int64_t bytes_in;
  u_int32_t pkts_in;
  u_int32_t errs_in;
  u_int32_t drops_in;
  u_int64_t bytes_out;
  u_int32_t pkts_out;
  u_int32_t errs_out;
  u_int32_t drops_out;
} SFLHost_nio_counters;

typedef struct _SFLHost_cpu_counters {
  float load_one;      /* 1 minute load avg. */
  float load_five;     /* 5 minute load avg. */
  float load_fifteen;  /* 15 minute load avg. */
  u_int32_t proc_run;   /* running threads */
  u_int32_t proc_total; /* total threads */
  u_int32_t cpu_num;    /* # CPU cores */
  u_int32_t cpu_speed;  /* speed in MHz of CPU */
  u_int32_t uptime;     /* seconds since last reboot */
  u_int32_t cpu_user;   /* time executing in user mode processes (ms) */
  u_int32_t cpu_nice;   /* time executing niced processs (ms) */
  u_int32_t cpu_system; /* time executing kernel mode processes (ms) */
  u_int32_t cpu_idle;   /* idle time (ms) */
  u_int32_t cpu_wio;    /* time waiting for I/O to complete (ms) */
  u_int32_t cpu_intr;   /* time servicing interrupts (ms) */
  u_int32_t cpu_sintr;  /* time servicing softirqs (ms) */
  u_int32_t interrupts; /* interrupt count */
  u_int32_t contexts;   /* context switch count */
} SFLHost_cpu_counters;

typedef struct _SFLHost_mem_counters {
  u_int64_t mem_total;    /* total bytes */
  u_int64_t mem_free;     /* free bytes */
  u_int64_t mem_shared;   /* shared bytes */
  u_int64_t mem_buffers;  /* buffers bytes */
  u_int64_t mem_cached;   /* cached bytes */
  u_int64_t swap_total;   /* swap total bytes */
  u_int64_t swap_free;    /* swap free bytes */
  u_int32_t page_in;      /* page in count */
  u_int32_t page_out;     /* page out count */
  u_int32_t swap_in;      /* swap in count */
  u_int32_t swap_out;     /* swap out count */
} SFLHost_mem_counters;

typedef struct _SFLHost_dsk_counters {
  u_int64_t disk_total;
  u_int64_t disk_free;
  u_int32_t part_max_used;   /* as percent * 100, so 100==1% */
  u_int32_t reads;           /* reads issued */
  u_int64_t bytes_read;      /* bytes read */
  u_int32_t read_time;       /* read time (ms) */
  u_int32_t writes;          /* writes completed */
  u_int64_t bytes_written;   /* bytes written */
  u_int32_t write_time;      /* write time (ms) */
} SFLHost_dsk_counters;

/* Virtual Node Statistics */
/* opaque = counter_data; enterprise = 0; format = 2100 */

typedef struct _SFLHost_vrt_node_counters {
  u_int32_t mhz;           /* expected CPU frequency */
  u_int32_t cpus;          /* the number of active CPUs */
  u_int64_t memory;        /* memory size in bytes */
  u_int64_t memory_free;   /* unassigned memory in bytes */
  u_int32_t num_domains;   /* number of active domains */
} SFLHost_vrt_node_counters;

/* Virtual Domain Statistics */
/* opaque = counter_data; enterprise = 0; format = 2101 */

/* virDomainState imported from libvirt.h */
enum SFLVirDomainState {
  SFL_VIR_DOMAIN_NOSTATE = 0, /* no state */
  SFL_VIR_DOMAIN_RUNNING = 1, /* the domain is running */
  SFL_VIR_DOMAIN_BLOCKED = 2, /* the domain is blocked on resource */
  SFL_VIR_DOMAIN_PAUSED  = 3, /* the domain is paused by user */
  SFL_VIR_DOMAIN_SHUTDOWN= 4, /* the domain is being shut down */
  SFL_VIR_DOMAIN_SHUTOFF = 5, /* the domain is shut off */
  SFL_VIR_DOMAIN_CRASHED = 6  /* the domain is crashed */
};

typedef struct _SFLHost_vrt_cpu_counters {
  u_int32_t state;       /* virtDomainState */
  u_int32_t cpuTime;     /* the CPU time used in mS */
  u_int32_t cpuCount;    /* number of virtual CPUs for the domain */
} SFLHost_vrt_cpu_counters;

/* Virtual Domain Memory statistics */
/* opaque = counter_data; enterprise = 0; format = 2102 */

typedef struct _SFLHost_vrt_mem_counters {
  u_int64_t memory;      /* memory in bytes used by domain */
  u_int64_t maxMemory;   /* memory in bytes allowed */
} SFLHost_vrt_mem_counters;

/* Virtual Domain Disk statistics */
/* opaque = counter_data; enterprise = 0; format = 2103 */

typedef struct _SFLHost_vrt_dsk_counters {
  u_int64_t capacity;   /* logical size in bytes */
  u_int64_t allocation; /* current allocation in bytes */
  u_int64_t available;  /* remaining free bytes */
  u_int32_t rd_req;     /* number of read requests */
  u_int64_t rd_bytes;   /* number of read bytes */
  u_int32_t wr_req;     /* number of write requests */
  u_int64_t wr_bytes;   /* number of  written bytes */
  u_int32_t errs;        /* read/write errors */
} SFLHost_vrt_dsk_counters;

/* Virtual Domain Network statistics */
/* opaque = counter_data; enterprise = 0; format = 2104 */

typedef struct _SFLHost_vrt_nio_counters {
  u_int64_t bytes_in;
  u_int32_t pkts_in;
  u_int32_t errs_in;
  u_int32_t drops_in;
  u_int64_t bytes_out;
  u_int32_t pkts_out;
  u_int32_t errs_out;
  u_int32_t drops_out;
} SFLHost_vrt_nio_counters;

typedef struct _SFLMemcache_counters {
  u_int32_t uptime;     /* Number of seconds this server has been running */
  u_int32_t rusage_user;    /* Accumulated user time for this process (ms)*/
  u_int32_t rusage_system;  /* Accumulated system time for this process (ms)*/
  u_int32_t curr_connections; /* Number of open connections */
  u_int32_t total_connections; /* Total number of connections opened since
				  the server started running */
  u_int32_t connection_structures; /* Number of connection structures
				      allocated by the server */
  u_int32_t cmd_get;        /* Cumulative number of retrieval requests */
  u_int32_t cmd_set;        /* Cumulative number of storage requests */
  u_int32_t cmd_flush;      /* */
  u_int32_t get_hits;       /* Number of keys that have been requested and
			       found present */
  u_int32_t get_misses;     /* Number of items that have been requested
			       and not found */
  u_int32_t delete_misses;
  u_int32_t delete_hits;
  u_int32_t incr_misses;
  u_int32_t incr_hits;
  u_int32_t decr_misses;
  u_int32_t decr_hits;
  u_int32_t cas_misses;
  u_int32_t cas_hits;
  u_int32_t cas_badval;
  u_int32_t auth_cmds;
  u_int32_t auth_errors;
  u_int64_t bytes_read;
  u_int64_t bytes_written;
  u_int32_t limit_maxbytes;
  u_int32_t accepting_conns;
  u_int32_t listen_disabled_num;
  u_int32_t threads;
  u_int32_t conn_yields;
  u_int64_t bytes;
  u_int32_t curr_items;
  u_int32_t total_items;
  u_int32_t evictions;
} SFLMemcache_counters;

typedef struct _SFLHTTP_counters {
  u_int32_t method_option_count;
  u_int32_t method_get_count;
  u_int32_t method_head_count;
  u_int32_t method_post_count;
  u_int32_t method_put_count;
  u_int32_t method_delete_count;
  u_int32_t method_trace_count;
  u_int32_t methd_connect_count;
  u_int32_t method_other_count;
  u_int32_t status_1XX_count;
  u_int32_t status_2XX_count;
  u_int32_t status_3XX_count;
  u_int32_t status_4XX_count;
  u_int32_t status_5XX_count;
  u_int32_t status_other_count;
} SFLHTTP_counters;


typedef struct _SFLCAL_counters {
  u_int32_t transactions;
  u_int32_t errors;
  u_int64_t duration_uS;
} SFLCAL_counters;

/* Counters data */

enum SFLCounters_type_tag {
  /* enterprise = 0, format = ... */
  SFLCOUNTERS_GENERIC      = 1,
  SFLCOUNTERS_ETHERNET     = 2,
  SFLCOUNTERS_TOKENRING    = 3,
  SFLCOUNTERS_VG           = 4,
  SFLCOUNTERS_VLAN         = 5,
  SFLCOUNTERS_80211        = 6,
  SFLCOUNTERS_PROCESSOR    = 1001,
  SFLCOUNTERS_RADIO        = 1002,
  SFLCOUNTERS_HOST_HID     = 2000, /* host id */
  SFLCOUNTERS_ADAPTORS     = 2001, /* host adaptors */
  SFLCOUNTERS_HOST_PAR     = 2002, /* host parent */
  SFLCOUNTERS_HOST_CPU     = 2003, /* host cpu  */
  SFLCOUNTERS_HOST_MEM     = 2004, /* host memory  */
  SFLCOUNTERS_HOST_DSK     = 2005, /* host storage I/O  */
  SFLCOUNTERS_HOST_NIO     = 2006, /* host network I/O */
  SFLCOUNTERS_HOST_VRT_NODE = 2100, /* host virt node */
  SFLCOUNTERS_HOST_VRT_CPU  = 2101, /* host virt cpu */
  SFLCOUNTERS_HOST_VRT_MEM  = 2102, /* host virt mem */
  SFLCOUNTERS_HOST_VRT_DSK  = 2103, /* host virt storage */
  SFLCOUNTERS_HOST_VRT_NIO  = 2104, /* host virt network I/O */
  SFLCOUNTERS_MEMCACHE      = 2200, /* memcached */
  SFLCOUNTERS_HTTP          = 2201, /* http */
  SFLCOUNTERS_CAL          = (4300 << 12) + 5,
};

typedef union _SFLCounters_type {
  SFLIf_counters generic;
  SFLEthernet_counters ethernet;
  SFLTokenring_counters tokenring;
  SFLVg_counters vg;
  SFLVlan_counters vlan;
  SFLWifi_counters wifi;
  SFLProcessor_counters processor;
  SFLRadio_counters radio;
  SFLHostId hostId;
  SFLAdaptorList *adaptors;
  SFLHost_parent host_par;
  SFLHost_cpu_counters host_cpu;
  SFLHost_mem_counters host_mem;
  SFLHost_dsk_counters host_dsk;
  SFLHost_nio_counters host_nio;
  SFLHost_vrt_node_counters host_vrt_node;
  SFLHost_vrt_cpu_counters host_vrt_cpu;
  SFLHost_vrt_mem_counters host_vrt_mem;
  SFLHost_vrt_dsk_counters host_vrt_dsk;
  SFLHost_vrt_nio_counters host_vrt_nio;
  SFLMemcache_counters memcache;
  SFLHTTP_counters http;
  SFLCAL_counters cal;
} SFLCounters_type;

typedef struct _SFLCounters_sample_element {
  struct _SFLCounters_sample_element *nxt; /* linked list */
  u_int32_t tag; /* SFLCounters_type_tag */
  u_int32_t length;
  SFLCounters_type counterBlock;
} SFLCounters_sample_element;

typedef struct _SFLCounters_sample {
  /* u_int32_t tag;    */       /* SFL_sample_tag -- enterprise = 0 : format = 2 */
  /* u_int32_t length; */
  u_int32_t sequence_number;    /* Incremented with each counters sample
				   generated by this source_id */
  u_int32_t source_id;          /* fsSourceId */
  u_int32_t num_elements;
  SFLCounters_sample_element *elements;
} SFLCounters_sample;

/* same thing, but the expanded version, so ds_index can be a full 32 bits */
typedef struct _SFLCounters_sample_expanded {
  /* u_int32_t tag;    */       /* SFL_sample_tag -- enterprise = 0 : format = 2 */
  /* u_int32_t length; */
  u_int32_t sequence_number;    /* Incremented with each counters sample
				   generated by this source_id */
  u_int32_t ds_class;           /* EXPANDED */
  u_int32_t ds_index;           /* EXPANDED */
  u_int32_t num_elements;
  SFLCounters_sample_element *elements;
} SFLCounters_sample_expanded;

#define SFLADD_ELEMENT(_sm, _el) do { (_el)->nxt = (_sm)->elements; (_sm)->elements = (_el); } while(0)

/* Format of a sample datagram */

enum SFLDatagram_version {
  SFLDATAGRAM_VERSION2 = 2,
  SFLDATAGRAM_VERSION4 = 4,
  SFLDATAGRAM_VERSION5 = 5
};

typedef struct _SFLSample_datagram_hdr {
  u_int32_t datagram_version;      /* (enum SFLDatagram_version) = VERSION5 = 5 */
  SFLAddress agent_address;        /* IP address of sampling agent */
  u_int32_t sub_agent_id;          /* Used to distinguishing between datagram
                                      streams from separate agent sub entities
                                      within an device. */
  u_int32_t sequence_number;       /* Incremented with each sample datagram
				      generated */
  u_int32_t uptime;                /* Current time (in milliseconds since device
				      last booted). Should be set as close to
				      datagram transmission time as possible.*/
  u_int32_t num_records;           /* Number of tag-len-val flow/counter records to follow */
} SFLSample_datagram_hdr;

#define SFL_MAX_DATAGRAM_SIZE 1500
#define SFL_MIN_DATAGRAM_SIZE 200
#define SFL_DEFAULT_DATAGRAM_SIZE 1400

#define SFL_DATA_PAD 400

enum INMAddress_type {
  INMADDRESSTYPE_IP_V4 = 1,
  INMADDRESSTYPE_IP_V6 = 2
};

typedef union _INMAddress_value {
  SFLIPv4 ip_v4;
  SFLIPv6 ip_v6;
} INMAddress_value;

typedef struct _INMAddress {
  u_int32_t type;           /* enum INMAddress_type */
  INMAddress_value address;
} INMAddress;

/* Packet header data */

#define INM_MAX_HEADER_SIZE 256   /* The maximum sampled header size. */
#define INM_DEFAULT_HEADER_SIZE 128
#define INM_DEFAULT_COLLECTOR_PORT 6343
#define INM_DEFAULT_SAMPLING_RATE 400

/* The header protocol describes the format of the sampled header */
enum INMHeader_protocol {
  INMHEADER_ETHERNET_ISO8023     = 1,
  INMHEADER_ISO88024_TOKENBUS    = 2,
  INMHEADER_ISO88025_TOKENRING   = 3,
  INMHEADER_FDDI                 = 4,
  INMHEADER_FRAME_RELAY          = 5,
  INMHEADER_X25                  = 6,
  INMHEADER_PPP                  = 7,
  INMHEADER_SMDS                 = 8,
  INMHEADER_AAL5                 = 9,
  INMHEADER_AAL5_IP              = 10, /* e.g. Cisco AAL5 mux */
  INMHEADER_IPv4                 = 11,
  INMHEADER_IPv6                 = 12
};

typedef struct _INMSampled_header {
  u_int32_t header_protocol;            /* (enum INMHeader_protocol) */
  u_int32_t frame_length;               /* Original length of packet before sampling */
  u_int32_t header_length;              /* length of sampled header bytes to follow */
  u_int8_t header[INM_MAX_HEADER_SIZE]; /* Header bytes */
} INMSampled_header;

/* Packet IP version 4 data */

typedef struct _INMSampled_ipv4 {
  u_int32_t length;      /* The length of the IP packet
			    excluding lower layer encapsulations */
  u_int32_t protocol;    /* IP Protocol type (for example, TCP = 6, UDP = 17) */
  SFLIPv4 src_ip; /* Source IP Address */
  SFLIPv4 dst_ip; /* Destination IP Address */
  u_int32_t src_port;    /* TCP/UDP source port number or equivalent */
  u_int32_t dst_port;    /* TCP/UDP destination port number or equivalent */
  u_int32_t tcp_flags;   /* TCP flags */
  u_int32_t tos;         /* IP type of service */
} INMSampled_ipv4;

/* Packet IP version 6 data */

typedef struct _INMSampled_ipv6 {
  u_int32_t length;       /* The length of the IP packet
			     excluding lower layer encapsulations */
  u_int32_t protocol;     /* IP Protocol type (for example, TCP = 6, UDP = 17) */
  SFLIPv6 src_ip; /* Source IP Address */
  SFLIPv6 dst_ip; /* Destination IP Address */
  u_int32_t src_port;     /* TCP/UDP source port number or equivalent */
  u_int32_t dst_port;     /* TCP/UDP destination port number or equivalent */
  u_int32_t tcp_flags;    /* TCP flags */
  u_int32_t tos;          /* IP type of service */
} INMSampled_ipv6;


/* Packet data */

enum INMPacket_information_type {
  INMPACKETTYPE_HEADER  = 1,      /* Packet headers are sampled */
  INMPACKETTYPE_IPV4    = 2,      /* IP version 4 data */
  INMPACKETTYPE_IPV6    = 3       /* IP version 4 data */
};

typedef union _INMPacket_data_type {
  INMSampled_header header;
  INMSampled_ipv4 ipv4;
  INMSampled_ipv6 ipv6;
} INMPacket_data_type;

/* Extended data types */

/* Extended switch data */

typedef struct _INMExtended_switch {
  u_int32_t src_vlan;       /* The 802.1Q VLAN id of incomming frame */
  u_int32_t src_priority;   /* The 802.1p priority */
  u_int32_t dst_vlan;       /* The 802.1Q VLAN id of outgoing frame */
  u_int32_t dst_priority;   /* The 802.1p priority */
} INMExtended_switch;

/* Extended router data */

typedef struct _INMExtended_router {
  INMAddress nexthop;               /* IP address of next hop router */
  u_int32_t src_mask;               /* Source address prefix mask bits */
  u_int32_t dst_mask;               /* Destination address prefix mask bits */
} INMExtended_router;

/* Extended gateway data */

enum INMExtended_as_path_segment_type {
  INMEXTENDED_AS_SET = 1,      /* Unordered set of ASs */
  INMEXTENDED_AS_SEQUENCE = 2  /* Ordered sequence of ASs */
};

typedef struct _INMExtended_as_path_segment {
  u_int32_t type;   /* enum INMExtended_as_path_segment_type */
  u_int32_t length; /* number of AS numbers in set/sequence */
  union {
    u_int32_t *set;
    u_int32_t *seq;
  } as;
} INMExtended_as_path_segment;

/* note: the INMExtended_gateway structure has changed between v2 and v4.
   Here is the old version first... */

typedef struct _INMExtended_gateway_v2 {
  u_int32_t as;                             /* AS number for this gateway */
  u_int32_t src_as;                         /* AS number of source (origin) */
  u_int32_t src_peer_as;                    /* AS number of source peer */
  u_int32_t dst_as_path_length;             /* number of AS numbers in path */
  u_int32_t *dst_as_path;
} INMExtended_gateway_v2;

/* now here is the new version... */

typedef struct _INMExtended_gateway_v4 {
  u_int32_t as;                             /* AS number for this gateway */
  u_int32_t src_as;                         /* AS number of source (origin) */
  u_int32_t src_peer_as;                    /* AS number of source peer */
  u_int32_t dst_as_path_segments;           /* number of segments in path */
  INMExtended_as_path_segment *dst_as_path; /* list of seqs or sets */
  u_int32_t communities_length;             /* number of communities */
  u_int32_t *communities;                   /* set of communities */
  u_int32_t localpref;                      /* LocalPref associated with this route */
} INMExtended_gateway_v4;

/* Extended user data */
typedef struct _INMExtended_user {
  u_int32_t src_user_len;
  char *src_user;
  u_int32_t dst_user_len;
  char *dst_user;
} INMExtended_user;
enum INMExtended_url_direction {
  INMEXTENDED_URL_SRC = 1, /* URL is associated with source address */
  INMEXTENDED_URL_DST = 2  /* URL is associated with destination address */
};

typedef struct _INMExtended_url {
  u_int32_t direction; /* enum INMExtended_url_direction */
  u_int32_t url_len;
  char *url;
} INMExtended_url;

/* Extended data */

enum INMExtended_information_type {
  INMEXTENDED_SWITCH    = 1,      /* Extended switch information */
  INMEXTENDED_ROUTER    = 2,      /* Extended router information */
  INMEXTENDED_GATEWAY   = 3,      /* Extended gateway router information */
  INMEXTENDED_USER      = 4,      /* Extended TACAS/RADIUS user information */
  INMEXTENDED_URL       = 5       /* Extended URL information */
};

/* Format of a single sample */

typedef struct _INMFlow_sample {
  u_int32_t sequence_number;      /* Incremented with each flow sample
				     generated */
  u_int32_t source_id;            /* fsSourceId */
  u_int32_t sampling_rate;        /* fsPacketSamplingRate */
  u_int32_t sample_pool;          /* Total number of packets that could have been
				     sampled (i.e. packets skipped by sampling
				     process + total number of samples) */
  u_int32_t drops;                /* Number of times a packet was dropped due to
				     lack of resources */
  u_int32_t input;                /* SNMP ifIndex of input interface.
				     0 if interface is not known. */
  u_int32_t output;               /* SNMP ifIndex of output interface,
				     0 if interface is not known.
				     Set most significant bit to indicate
				     multiple destination interfaces
				     (i.e. in case of broadcast or multicast)
				     and set lower order bits to indicate
				     number of destination interfaces.
				     Examples:
				     0x00000002  indicates ifIndex = 2
				     0x00000000  ifIndex unknown.
				     0x80000007  indicates a packet sent
				     to 7 interfaces.
				     0x80000000  indicates a packet sent to
				     an unknown number of
				     interfaces greater than 1.*/
  u_int32_t packet_data_tag;       /* enum INMPacket_information_type */
  INMPacket_data_type packet_data; /* Information about sampled packet */

  /* in the sFlow packet spec the next field is the number of extended objects
     followed by the data for each one (tagged with the type).  Here we just
     provide space for each one, and flags to enable them.  The correct format
     is then put together by the serialization code */
  int gotSwitch;
  INMExtended_switch switchDevice;
  int gotRouter;
  INMExtended_router router;
  int gotGateway;
  union {
    INMExtended_gateway_v2 v2;  /* make the version explicit so that there is */
    INMExtended_gateway_v4 v4;  /* less danger of mistakes when upgrading code */
  } gateway;
  int gotUser;
  INMExtended_user user;
  int gotUrl;
  INMExtended_url url;
} INMFlow_sample;

/* Counter types */

/* Generic interface counters - see RFC 1573, 2233 */

typedef struct _INMIf_counters {
  u_int32_t ifIndex;
  u_int32_t ifType;
  u_int64_t ifSpeed;
  u_int32_t ifDirection;        /* Derived from MAU MIB (RFC 2239)
				   0 = unknown, 1 = full-duplex,
				   2 = half-duplex, 3 = in, 4 = out */
  u_int32_t ifStatus;           /* bit field with the following bits assigned:
				   bit 0 = ifAdminStatus (0 = down, 1 = up)
				   bit 1 = ifOperStatus (0 = down, 1 = up) */
  u_int64_t ifInOctets;
  u_int32_t ifInUcastPkts;
  u_int32_t ifInMulticastPkts;
  u_int32_t ifInBroadcastPkts;
  u_int32_t ifInDiscards;
  u_int32_t ifInErrors;
  u_int32_t ifInUnknownProtos;
  u_int64_t ifOutOctets;
  u_int32_t ifOutUcastPkts;
  u_int32_t ifOutMulticastPkts;
  u_int32_t ifOutBroadcastPkts;
  u_int32_t ifOutDiscards;
  u_int32_t ifOutErrors;
  u_int32_t ifPromiscuousMode;
} INMIf_counters;

/* Ethernet interface counters - see RFC 2358 */
typedef struct _INMEthernet_specific_counters {
  u_int32_t dot3StatsAlignmentErrors;
  u_int32_t dot3StatsFCSErrors;
  u_int32_t dot3StatsSingleCollisionFrames;
  u_int32_t dot3StatsMultipleCollisionFrames;
  u_int32_t dot3StatsSQETestErrors;
  u_int32_t dot3StatsDeferredTransmissions;
  u_int32_t dot3StatsLateCollisions;
  u_int32_t dot3StatsExcessiveCollisions;
  u_int32_t dot3StatsInternalMacTransmitErrors;
  u_int32_t dot3StatsCarrierSenseErrors;
  u_int32_t dot3StatsFrameTooLongs;
  u_int32_t dot3StatsInternalMacReceiveErrors;
  u_int32_t dot3StatsSymbolErrors;
} INMEthernet_specific_counters;

typedef struct _INMEthernet_counters {
  INMIf_counters generic;
  INMEthernet_specific_counters ethernet;
} INMEthernet_counters;

/* FDDI interface counters - see RFC 1512 */
typedef struct _INMFddi_counters {
  INMIf_counters generic;
} INMFddi_counters;

/* Token ring counters - see RFC 1748 */

typedef struct _INMTokenring_specific_counters {
  u_int32_t dot5StatsLineErrors;
  u_int32_t dot5StatsBurstErrors;
  u_int32_t dot5StatsACErrors;
  u_int32_t dot5StatsAbortTransErrors;
  u_int32_t dot5StatsInternalErrors;
  u_int32_t dot5StatsLostFrameErrors;
  u_int32_t dot5StatsReceiveCongestions;
  u_int32_t dot5StatsFrameCopiedErrors;
  u_int32_t dot5StatsTokenErrors;
  u_int32_t dot5StatsSoftErrors;
  u_int32_t dot5StatsHardErrors;
  u_int32_t dot5StatsSignalLoss;
  u_int32_t dot5StatsTransmitBeacons;
  u_int32_t dot5StatsRecoverys;
  u_int32_t dot5StatsLobeWires;
  u_int32_t dot5StatsRemoves;
  u_int32_t dot5StatsSingles;
  u_int32_t dot5StatsFreqErrors;
} INMTokenring_specific_counters;

typedef struct _INMTokenring_counters {
  INMIf_counters generic;
  INMTokenring_specific_counters tokenring;
} INMTokenring_counters;

/* 100 BaseVG interface counters - see RFC 2020 */

typedef struct _INMVg_specific_counters {
  u_int32_t dot12InHighPriorityFrames;
  u_int64_t dot12InHighPriorityOctets;
  u_int32_t dot12InNormPriorityFrames;
  u_int64_t dot12InNormPriorityOctets;
  u_int32_t dot12InIPMErrors;
  u_int32_t dot12InOversizeFrameErrors;
  u_int32_t dot12InDataErrors;
  u_int32_t dot12InNullAddressedFrames;
  u_int32_t dot12OutHighPriorityFrames;
  u_int64_t dot12OutHighPriorityOctets;
  u_int32_t dot12TransitionIntoTrainings;
  u_int64_t dot12HCInHighPriorityOctets;
  u_int64_t dot12HCInNormPriorityOctets;
  u_int64_t dot12HCOutHighPriorityOctets;
} INMVg_specific_counters;

typedef struct _INMVg_counters {
  INMIf_counters generic;
  INMVg_specific_counters vg;
} INMVg_counters;

/* WAN counters */

typedef struct _INMWan_counters {
  INMIf_counters generic;
} INMWan_counters;

typedef struct _INMVlan_counters {
  u_int32_t vlan_id;
  u_int64_t octets;
  u_int32_t ucastPkts;
  u_int32_t multicastPkts;
  u_int32_t broadcastPkts;
  u_int32_t discards;
} INMVlan_counters;

/* Counters data */

enum INMCounters_version {
  INMCOUNTERSVERSION_GENERIC      = 1,
  INMCOUNTERSVERSION_ETHERNET     = 2,
  INMCOUNTERSVERSION_TOKENRING    = 3,
  INMCOUNTERSVERSION_FDDI         = 4,
  INMCOUNTERSVERSION_VG           = 5,
  INMCOUNTERSVERSION_WAN          = 6,
  INMCOUNTERSVERSION_VLAN         = 7
};

typedef union _INMCounters_type {
  INMIf_counters generic;
  INMEthernet_counters ethernet;
  INMTokenring_counters tokenring;
  INMFddi_counters fddi;
  INMVg_counters vg;
  INMWan_counters wan;
  INMVlan_counters vlan;
} INMCounters_type;

typedef struct _INMCounters_sample_hdr {
  u_int32_t sequence_number;    /* Incremented with each counters sample
				   generated by this source_id */
  u_int32_t source_id;          /* fsSourceId */
  u_int32_t sampling_interval;  /* fsCounterSamplingInterval */
} INMCounters_sample_hdr;

typedef struct _INMCounters_sample {
  INMCounters_sample_hdr hdr;
  u_int32_t counters_type_tag;  /* Enum INMCounters_version */
  INMCounters_type counters;    /* Counter set for this interface type */
} INMCounters_sample;

/* when I turn on optimisation with the Microsoft compiler it seems to change
   the values of these enumerated types and break the program - not sure why */
enum INMSample_types {
  FLOWSAMPLE  = 1,
  COUNTERSSAMPLE = 2
};

typedef union _INMSample_type {
  INMFlow_sample flowsample;
  INMCounters_sample counterssample;
} INMSample_type;

/* Format of a sample datagram */

enum INMDatagram_version {
  INMDATAGRAM_VERSION2 = 2,
  INMDATAGRAM_VERSION4 = 4
};

typedef struct _INMSample_datagram_hdr {
  u_int32_t datagram_version;      /* (enum INMDatagram_version) = VERSION4 */
  INMAddress agent_address;        /* IP address of sampling agent */
  u_int32_t sequence_number;       /* Incremented with each sample datagram
				      generated */
  u_int32_t uptime;                /* Current time (in milliseconds since device
				      last booted). Should be set as close to
				      datagram transmission time as possible.*/
  u_int32_t num_samples;           /* Number of flow and counters samples to follow */
} INMSample_datagram_hdr;

#define INM_MAX_DATAGRAM_SIZE 1500
#define INM_MIN_DATAGRAM_SIZE 200
#define INM_DEFAULT_DATAGRAM_SIZE 1400

#define INM_DATA_PAD 400

#if 0
/* just do it in a portable way... */
static u_int32_t MyByteSwap32(u_int32_t n) {
  return (((n & 0x000000FF)<<24) +
	  ((n & 0x0000FF00)<<8) +
	  ((n & 0x00FF0000)>>8) +
	  ((n & 0xFF000000)>>24));
}
static u_int16_t MyByteSwap16(u_int16_t n) {
  return ((n >> 8) | (n << 8));
}
#endif

#ifndef PRIu64
# ifdef WIN32
#  define PRIu64 "I64u"
# else
#  define PRIu64 "llu"
# endif
#endif

#define YES 1
#define NO 0

/* define my own IP header struct - to ease portability */
struct myiphdr
{
  u_int8_t version_and_headerLen;
  u_int8_t tos;
  u_int16_t tot_len;
  u_int16_t id;
  u_int16_t frag_off;
  u_int8_t ttl;
  u_int8_t protocol;
  u_int16_t check;
  u_int32_t saddr;
  u_int32_t daddr;
};

/* same for tcp */
struct mytcphdr
{
  u_int16_t th_sport;		/* source port */
  u_int16_t th_dport;		/* destination port */
  u_int32_t th_seq;		/* sequence number */
  u_int32_t th_ack;		/* acknowledgement number */
  u_int8_t th_off_and_unused;
  u_int8_t th_flags;
  u_int16_t th_win;		/* window */
  u_int16_t th_sum;		/* checksum */
  u_int16_t th_urp;		/* urgent pointer */
};

/* and UDP */
struct myudphdr {
  u_int16_t uh_sport;           /* source port */
  u_int16_t uh_dport;           /* destination port */
  u_int16_t uh_ulen;            /* udp length */
  u_int16_t uh_sum;             /* udp checksum */
};

/* and ICMP */
struct myicmphdr
{
  u_int8_t type;		/* message type */
  u_int8_t code;		/* type sub-code */
  /* ignore the rest */
};

#ifdef SPOOFSOURCE
#define SPOOFSOURCE_SENDPACKET_SIZE 2000
struct mySendPacket {
  struct myiphdr ip;
  struct myudphdr udp;
  u_char data[SPOOFSOURCE_SENDPACKET_SIZE];
};
#endif

typedef struct _SFForwardingTarget {
  struct _SFForwardingTarget *nxt;
  struct in_addr host;
  u_int32_t port;
  struct sockaddr_in addr;
  int sock;
} SFForwardingTarget;

typedef enum { SFLFMT_FULL=0, SFLFMT_PCAP, SFLFMT_LINE, SFLFMT_NETFLOW, SFLFMT_FWD, SFLFMT_CLF } EnumSFLFormat;

typedef struct _SFConfig {
  /* sflow(R) options */
  u_int16_t sFlowInputPort;
  /* netflow(TM) options */
  u_int16_t netFlowOutputPort;
  struct in_addr netFlowOutputIP;
  int netFlowOutputSocket;
  u_int16_t netFlowPeerAS;
  int disableNetFlowScale;

  EnumSFLFormat outputFormat;
  u_int32_t tcpdumpHdrPad;
  u_char zeroPad[100];
  int pcapSwap;

  SFForwardingTarget *forwardingTargets;

  /* vlan filtering */
  int gotVlanFilter;
#define FILTER_MAX_VLAN 4096
  u_char vlanFilter[FILTER_MAX_VLAN + 1];

  /* content stripping */
  int removeContent;

  /* options to restrict IP socket / bind */
  int listen4;
  int listen6;
  int listenControlled;
} SFConfig;

/* define a separate global we can use to construct the common-log-file format */
typedef struct _SFCommonLogFormat {
#define SFLFMT_CLF_MAX_LINE 2000
  int valid;
  char client[64];
  char http_log[SFLFMT_CLF_MAX_LINE];
} SFCommonLogFormat;

static SFCommonLogFormat sfCLF;
#if 0
static const char *SFHTTP_method_names[] = { "-", "OPTIONS", "GET", "HEAD", "POST", "PUT", "DELETE", "TRACE", "CONNECT" };
#endif

typedef struct _SFSample {
  struct in_addr sourceIP;
  struct in6_addr sourceIP6;
  SFLAddress agent_addr;
  u_int32_t agentSubId;

  /* the raw pdu */
  u_char *rawSample;
  u_int32_t rawSampleLen;
  u_char *endp;
  time_t pcapTimestamp;

  /* decode cursor */
  u_char  *datap;

  u_int32_t datagramVersion;
  u_int32_t sampleType;
  u_int32_t ds_class;
  u_int32_t ds_index;

  /* generic interface counter sample */
  SFLIf_counters ifCounters;

  /* sample stream info */
  u_int32_t sysUpTime;
  u_int32_t sequenceNo;
  u_int32_t sampledPacketSize;
  u_int32_t samplesGenerated;
  u_int32_t meanSkipCount;
  u_int32_t samplePool;
  u_int32_t dropEvents;

  /* the sampled header */
  u_int32_t packet_data_tag;
  u_int32_t headerProtocol;
  u_char *header;
  int headerLen;
  u_int32_t stripped;

  /* NTOP */
  u_char *pkt_header;
  int pkt_headerLen;


  /* header decode */
  int gotIPV4;
  int gotIPV4Struct;
  int offsetToIPV4;
  int gotIPV6;
  int gotIPV6Struct;
  int offsetToIPV6;
  int offsetToPayload;
  SFLAddress ipsrc;
  SFLAddress ipdst;
  u_int32_t dcd_ipProtocol;
  u_int32_t dcd_ipTos;
  u_int32_t dcd_ipTTL;
  u_int32_t dcd_sport;
  u_int32_t dcd_dport;
  u_int32_t dcd_tcpFlags;
  u_int32_t ip_fragmentOffset;
  u_int32_t udp_pduLen;

  /* ports */
  u_int32_t inputPortFormat;
  u_int32_t outputPortFormat;
  u_int32_t inputPort;
  u_int32_t outputPort;

  /* ethernet */
  u_int32_t eth_type;
  u_int32_t eth_len;
  u_char eth_src[8];
  u_char eth_dst[8];

  /* vlan */
  u_int32_t in_vlan;
  u_int32_t in_priority;
  u_int32_t internalPriority;
  u_int32_t out_vlan;
  u_int32_t out_priority;
  int vlanFilterReject;

  /* extended data fields */
  u_int32_t num_extended;
  u_int32_t extended_data_tag;
#define SASAMPLE_EXTENDED_DATA_SWITCH 1
#define SASAMPLE_EXTENDED_DATA_ROUTER 4
#define SASAMPLE_EXTENDED_DATA_GATEWAY 8
#define SASAMPLE_EXTENDED_DATA_USER 16
#define SASAMPLE_EXTENDED_DATA_URL 32
#define SASAMPLE_EXTENDED_DATA_MPLS 64
#define SASAMPLE_EXTENDED_DATA_NAT 128
#define SASAMPLE_EXTENDED_DATA_MPLS_TUNNEL 256
#define SASAMPLE_EXTENDED_DATA_MPLS_VC 512
#define SASAMPLE_EXTENDED_DATA_MPLS_FTN 1024
#define SASAMPLE_EXTENDED_DATA_MPLS_LDP_FEC 2048
#define SASAMPLE_EXTENDED_DATA_VLAN_TUNNEL 4096

  /* IP forwarding info */
  SFLAddress nextHop;
  u_int32_t srcMask;
  u_int32_t dstMask;

  /* BGP info */
  SFLAddress bgp_nextHop;
  u_int32_t my_as;
  u_int32_t src_as;
  u_int32_t src_peer_as;
  u_int32_t dst_as_path_len;
  u_int32_t *dst_as_path;
  /* note: version 4 dst as path segments just get printed, not stored here, however
   * the dst_peer and dst_as are filled in, since those are used for netflow encoding
   */
  u_int32_t dst_peer_as;
  u_int32_t dst_as;

  u_int32_t communities_len;
  u_int32_t *communities;
  u_int32_t localpref;

  /* user id */
#define SA_MAX_EXTENDED_USER_LEN 200
  u_int32_t src_user_charset;
  u_int32_t src_user_len;
  char src_user[SA_MAX_EXTENDED_USER_LEN+1];
  u_int32_t dst_user_charset;
  u_int32_t dst_user_len;
  char dst_user[SA_MAX_EXTENDED_USER_LEN+1];

  /* url */
#define SA_MAX_EXTENDED_URL_LEN 200
#define SA_MAX_EXTENDED_HOST_LEN 200
  u_int32_t url_direction;
  u_int32_t url_len;
  char url[SA_MAX_EXTENDED_URL_LEN+1];
  u_int32_t host_len;
  char host[SA_MAX_EXTENDED_HOST_LEN+1];

  /* mpls */
  SFLAddress mpls_nextHop;

  /* nat */
  SFLAddress nat_src;
  SFLAddress nat_dst;

  /* counter blocks */
  u_int32_t statsSamplingInterval;
  u_int32_t counterBlockVersion;

# define SFABORT(s, r) ;

#define SF_ABORT_EOS 1
#define SF_ABORT_DECODE_ERROR 2
#define SF_ABORT_LENGTH_ERROR 3

} SFSample;

/*_________________---------------------------__________________
  _________________   read data fns           __________________
  -----------------___________________________------------------
*/

/* Function modified by Luca */
static u_int32_t getData32_nobswap(SFSample *sample) {
  u_int32_t *ans = (u_int32_t*)sample->datap;
  u_int32_t val;

  memcpy(&val, ans, 4);

  sample->datap += 4;
  // make sure we didn't run off the end of the datagram.  Thanks to
  // Sven Eschenberg for spotting a bug/overrun-vulnerabilty that was here before.
  if((u_char *)sample->datap > sample->endp) {
    SFABORT(sample, SF_ABORT_EOS);
  }
  return val;
}

static u_int32_t getData32(SFSample *sample) {
  return ntohl(getData32_nobswap(sample));
}

static float getFloat(SFSample *sample) {
  float fl;
  u_int32_t reg = getData32(sample);
  memcpy(&fl, &reg, 4);
  return fl;
}

static u_int64_t getData64(SFSample *sample) {
  u_int64_t tmpLo, tmpHi;
  tmpHi = getData32(sample);
  tmpLo = getData32(sample);
  return (tmpHi << 32) + tmpLo;
}

/* Function modified by Luca */
static void skipBytes(SFSample *sample, u_int32_t skip) {

  /* Luca: align to 4 bytes */
  skip = (skip + 3) & ~3; /* Align */

  /* ntop->getTrace()->traceEvent(TRACE_WARNING, "===>> skipBytes(%d)", skip); */

  sample->datap += skip;
  if(skip > sample->rawSampleLen || (u_char *)sample->datap > sample->endp) {
    SFABORT(sample, SF_ABORT_EOS);
  }
}

void sf_log(const char *fmt, ...)
{
#ifdef DEBUG_FLOWS
  va_list args;
  
  va_start(args, fmt);
  vprintf(fmt, args);
#endif
}

static u_int32_t sf_log_next32(SFSample *sample, const char *fieldName) {
  u_int32_t val = getData32(sample);
  sf_log("%s %u\n", fieldName, val);
  return val;
}

static u_int64_t sf_log_next64(SFSample *sample, const char *fieldName) {
  u_int64_t val64 = getData64(sample);
  sf_log("%s %" PRIu64 "\n", fieldName, val64);
  return val64;
}

void sf_log_percentage(SFSample *sample, const char *fieldName)
{
  u_int32_t hundredths = getData32(sample);
  if(hundredths == (u_int32_t)-1) sf_log("%s unknown\n", fieldName);
  else {
    float percent = (float)hundredths / (float)100.0;
    sf_log("%s %.1f\n", fieldName, percent);
  }
}

static float sf_log_nextFloat(SFSample *sample, const char *fieldName) {
  float val = getFloat(sample);
  sf_log("%s %.3f\n", fieldName, val);
  return val;
}

static u_int32_t getString(SFSample *sample, char *buf, u_int32_t bufLen) {
  u_int32_t len, read_len;
  len = getData32(sample);
  // truncate if too long
  read_len = (len >= bufLen) ? (bufLen - 1) : len;
  memcpy(buf, sample->datap, read_len);
  buf[read_len] = '\0';   // null terminate
  skipBytes(sample, len);
  return len;
}

static u_int32_t getAddress(SFSample *sample, SFLAddress *address) {
  address->type = getData32(sample);
  if(address->type == SFLADDRESSTYPE_IP_V4)
    address->address.ip_v4.addr = getData32_nobswap(sample);
  else {
    memcpy(&address->address.ip_v6.addr, sample->datap, 16);
    skipBytes(sample, 16);
  }
  return address->type;
}

static char *printTag(u_int32_t tag, char *buf, int bufLen) {
  // should really be: snprintf(buf, buflen,...) but snprintf() is not always available
  snprintf(buf, bufLen, "%u:%u", (tag >> 12), (tag & 0x00000FFF));
  return buf;
}

static void skipTLVRecord(SFSample *sample, u_int32_t tag, u_int32_t len, const char *description) {
  char buf[51];
  sf_log("skipping unknown %s: %s len=%d\n", description, printTag(tag, buf, 50), len);
  skipBytes(sample, len);
}

/*_________________---------------------------__________________
  _________________    readExtendedSwitch     __________________
  -----------------___________________________------------------
*/

static void readExtendedSwitch(SFSample *sample)
{
  sf_log("extendedType SWITCH\n");
  sample->in_vlan = getData32(sample);
  sample->in_priority = getData32(sample);
  sample->out_vlan = getData32(sample);
  sample->out_priority = getData32(sample);

  /* Validate vlan_ids */
  if(sample->in_vlan  > 4095) sample->in_vlan = 0;
  if(sample->out_vlan > 4095) sample->out_vlan = 0;
  
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_SWITCH;

  sf_log("in_vlan %u\n", sample->in_vlan);
  sf_log("in_priority %u\n", sample->in_priority);
  sf_log("out_vlan %u\n", sample->out_vlan);
  sf_log("out_priority %u\n", sample->out_priority);
}

/*_________________---------------------------__________________
  _________________        printHex           __________________
  -----------------___________________________------------------
*/

static u_char bin2hex(int nib) { return (nib < 10) ? ('0' + nib) : ('A' - 10 + nib); }

int printHex(const u_char *a, int len, u_char *buf, int bufLen, int marker, int bytesPerOutputLine)
{
  int b = 0, i = 0;
  for(; i < len; i++) {
    u_char byte;
    if(b > (bufLen - 10)) break;
    if(marker > 0 && i == marker) {
      buf[b++] = '<';
      buf[b++] = '*';
      buf[b++] = '>';
      buf[b++] = '-';
    }
    byte = a[i];
    buf[b++] = bin2hex(byte >> 4);
    buf[b++] = bin2hex(byte & 0x0f);
    if(i > 0 && (i % bytesPerOutputLine) == 0) buf[b++] = '\n';
    else {
      // separate the bytes with a dash
      if(i < (len - 1)) buf[b++] = '-';
    }
  }
  buf[b] = '\0';
  return b;
}

/*_________________---------------------------__________________
  _________________      IP_to_a              __________________
  -----------------___________________________------------------
*/

char *IP_to_a(u_int32_t ipaddr, char *buf, int bufLen)
{
  u_char *ip = (u_char *)&ipaddr;
  snprintf(buf, bufLen, "%u.%u.%u.%u", ip[0], ip[1], ip[2], ip[3]);
  return buf;
}

static char *printAddress(SFLAddress *address, char *buf, int bufLen) {
  if(address->type == SFLADDRESSTYPE_IP_V4)
    IP_to_a(address->address.ip_v4.addr, buf, bufLen);
  else {
    u_char *b = address->address.ip_v6.addr;
    // should really be: snprintf(buf, buflen,...) but snprintf() is not always available
    snprintf(buf, bufLen,
	     "%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x",
	     b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15]);
  }
  return buf;
}

/*_________________---------------------------__________________
  _________________    readExtendedRouter     __________________
  -----------------___________________________------------------
*/

static void readExtendedRouter(SFSample *sample)
{
  char buf[51];
  sf_log("extendedType ROUTER\n");
  getAddress(sample, &sample->nextHop);
  sample->srcMask = getData32(sample);
  sample->dstMask = getData32(sample);

  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_ROUTER;

  sf_log("nextHop %s\n", printAddress(&sample->nextHop, buf, 50));
  sf_log("srcSubnetMask %u\n", sample->srcMask);
  sf_log("dstSubnetMask %u\n", sample->dstMask);
}

/*_________________---------------------------__________________
  _________________  readExtendedGateway_v2   __________________
  -----------------___________________________------------------
*/

static void readExtendedGateway_v2(SFSample *sample)
{
  sf_log("extendedType GATEWAY\n");

  sample->my_as = getData32(sample);
  sample->src_as = getData32(sample);
  sample->src_peer_as = getData32(sample);

  // clear dst_peer_as and dst_as to make sure we are not
  // remembering values from a previous sample - (thanks Marc Lavine)
  sample->dst_peer_as = 0;
  sample->dst_as = 0;

  sample->dst_as_path_len = getData32(sample);
  /* just point at the dst_as_path array */
  if(sample->dst_as_path_len > 0) {
    sample->dst_as_path = (u_int32_t*)sample->datap;
    /* and skip over it in the input */
    skipBytes(sample, sample->dst_as_path_len * 4);
    // fill in the dst and dst_peer fields too
    sample->dst_peer_as = ntohl(sample->dst_as_path[0]);
    sample->dst_as = ntohl(sample->dst_as_path[sample->dst_as_path_len - 1]);
  }

  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_GATEWAY;

  sf_log("my_as %u\n", sample->my_as);
  sf_log("src_as %u\n", sample->src_as);
  sf_log("src_peer_as %u\n", sample->src_peer_as);
  sf_log("dst_as %u\n", sample->dst_as);
  sf_log("dst_peer_as %u\n", sample->dst_peer_as);
  sf_log("dst_as_path_len %u\n", sample->dst_as_path_len);
  if(sample->dst_as_path_len > 0) {
    u_int32_t i = 0;
    for(; i < sample->dst_as_path_len; i++) {
      if(i == 0) sf_log("dst_as_path ");
      else sf_log("-");
      sf_log("%u", ntohl(sample->dst_as_path[i]));
    }
    sf_log("\n");
  }
}

/*_________________---------------------------__________________
  _________________  readExtendedGateway      __________________
  -----------------___________________________------------------
*/

static void readExtendedGateway(SFSample *sample)
{
  u_int32_t segments;
  u_int32_t seg;
  char buf[51];

  sf_log("extendedType GATEWAY\n");

  if(sample->datagramVersion >= 5) {
    getAddress(sample, &sample->bgp_nextHop);
    sf_log("bgp_nexthop %s\n", printAddress(&sample->bgp_nextHop, buf, 50));
  }

  sample->my_as = getData32(sample);
  sample->src_as = getData32(sample);
  sample->src_peer_as = getData32(sample);
  sf_log("my_as %u\n", sample->my_as);
  sf_log("src_as %u\n", sample->src_as);
  sf_log("src_peer_as %u\n", sample->src_peer_as);
  segments = getData32(sample);

  // clear dst_peer_as and dst_as to make sure we are not
  // remembering values from a previous sample - (thanks Marc Lavine)
  sample->dst_peer_as = 0;
  sample->dst_as = 0;

  if(segments > 0) {
    sf_log("dst_as_path ");
    for(seg = 0; seg < segments; seg++) {
      u_int32_t seg_type;
      u_int32_t seg_len;
      u_int32_t i;
      seg_type = getData32(sample);
      seg_len = getData32(sample);
      for(i = 0; i < seg_len; i++) {
	u_int32_t asNumber;
	asNumber = getData32(sample);
	/* mark the first one as the dst_peer_as */
	if(i == 0 && seg == 0) sample->dst_peer_as = asNumber;
	else sf_log("-");
	/* make sure the AS sets are in parentheses */
	if(i == 0 && seg_type == SFLEXTENDED_AS_SET) sf_log("(");
	sf_log("%u", asNumber);
	/* mark the last one as the dst_as */
	if(seg == (segments - 1) && i == (seg_len - 1)) sample->dst_as = asNumber;
      }
      if(seg_type == SFLEXTENDED_AS_SET) sf_log(")");
    }
    sf_log("\n");
  }
  sf_log("dst_as %u\n", sample->dst_as);
  sf_log("dst_peer_as %u\n", sample->dst_peer_as);

  sample->communities_len = getData32(sample);
  /* just point at the communities array */
  if(sample->communities_len > 0) sample->communities = (u_int32_t*)sample->datap;
  /* and skip over it in the input */
  skipBytes(sample, sample->communities_len * 4);

  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_GATEWAY;
  if(sample->communities_len > 0) {
    u_int32_t j = 0;
    for(; j < sample->communities_len; j++) {
      if(j == 0) sf_log("BGP_communities ");
      else sf_log("-");
      sf_log("%u", ntohl(sample->communities[j]));
    }
    sf_log("\n");
  }

  sample->localpref = getData32(sample);
  sf_log("BGP_localpref %u\n", sample->localpref);

}

/*_________________---------------------------__________________
  _________________    readExtendedUser       __________________
  -----------------___________________________------------------
*/

static void readExtendedUser(SFSample *sample)
{
  sf_log("extendedType USER\n");

  if(sample->datagramVersion >= 5) {
    sample->src_user_charset = getData32(sample);
    sf_log("src_user_charset %d\n", sample->src_user_charset);
  }

  sample->src_user_len = getString(sample, sample->src_user, SA_MAX_EXTENDED_USER_LEN);

  if(sample->datagramVersion >= 5) {
    sample->dst_user_charset = getData32(sample);
    sf_log("dst_user_charset %d\n", sample->dst_user_charset);
  }

  sample->dst_user_len = getString(sample, sample->dst_user, SA_MAX_EXTENDED_USER_LEN);

  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_USER;

  sf_log("src_user %s\n", sample->src_user);
  sf_log("dst_user %s\n", sample->dst_user);
}

/*_________________---------------------------__________________
  _________________    readExtendedUrl        __________________
  -----------------___________________________------------------
*/

static void readExtendedUrl(SFSample *sample)
{
  sf_log("extendedType URL\n");

  sample->url_direction = getData32(sample);
  sf_log("url_direction %u\n", sample->url_direction);
  sample->url_len = getString(sample, sample->url, SA_MAX_EXTENDED_URL_LEN);
  sf_log("url %s\n", sample->url);
  if(sample->datagramVersion >= 5) {
    sample->host_len = getString(sample, sample->host, SA_MAX_EXTENDED_HOST_LEN);
    sf_log("host %s\n", sample->host);
  }
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_URL;
}


/*_________________---------------------------__________________
  _________________       mplsLabelStack      __________________
  -----------------___________________________------------------
*/

static void mplsLabelStack(SFSample *sample, const char *fieldName)
{
  SFLLabelStack lstk;
  u_int32_t lab;
  lstk.depth = getData32(sample);
  /* just point at the lablelstack array */
  if(lstk.depth > 0) lstk.stack = (u_int32_t *)sample->datap;
  /* and skip over it in the input */
  skipBytes(sample, lstk.depth * 4);

  if(lstk.depth > 0) {
    u_int32_t j = 0;
    for(; j < lstk.depth; j++) {
      if(j == 0) sf_log("%s ", fieldName);
      else sf_log("-");
      lab = ntohl(lstk.stack[j]);
      sf_log("%u.%u.%u.%u",
	     (lab >> 12),     // label
	     (lab >> 9) & 7,  // experimental
	     (lab >> 8) & 1,  // bottom of stack
	     (lab &  255));   // TTL
    }
    sf_log("\n");
  }
}

/*_________________---------------------------__________________
  _________________    readExtendedMpls       __________________
  -----------------___________________________------------------
*/

static void readExtendedMpls(SFSample *sample)
{
  char buf[51];
  sf_log("extendedType MPLS\n");
  getAddress(sample, &sample->mpls_nextHop);
  sf_log("mpls_nexthop %s\n", printAddress(&sample->mpls_nextHop, buf, 50));

  mplsLabelStack(sample, "mpls_input_stack");
  mplsLabelStack(sample, "mpls_output_stack");

  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_MPLS;
}

/*_________________---------------------------__________________
  _________________    readExtendedNat        __________________
  -----------------___________________________------------------
*/

static void readExtendedNat(SFSample *sample)
{
  char buf[51];
  sf_log("extendedType NAT\n");
  getAddress(sample, &sample->nat_src);
  sf_log("nat_src %s\n", printAddress(&sample->nat_src, buf, 50));
  getAddress(sample, &sample->nat_dst);
  sf_log("nat_dst %s\n", printAddress(&sample->nat_dst, buf, 50));
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_NAT;
}


/*_________________---------------------------__________________
  _________________    readExtendedMplsTunnel __________________
  -----------------___________________________------------------
*/

static void readExtendedMplsTunnel(SFSample *sample)
{
#define SA_MAX_TUNNELNAME_LEN 100
  char tunnel_name[SA_MAX_TUNNELNAME_LEN+1];
  u_int32_t tunnel_id, tunnel_cos;

  if(getString(sample, tunnel_name, SA_MAX_TUNNELNAME_LEN) > 0)
    sf_log("mpls_tunnel_lsp_name %s\n", tunnel_name);
  tunnel_id = getData32(sample);
  sf_log("mpls_tunnel_id %u\n", tunnel_id);
  tunnel_cos = getData32(sample);
  sf_log("mpls_tunnel_cos %u\n", tunnel_cos);
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_MPLS_TUNNEL;
}

/*_________________---------------------------__________________
  _________________    readExtendedMplsVC     __________________
  -----------------___________________________------------------
*/

static void readExtendedMplsVC(SFSample *sample)
{
#define SA_MAX_VCNAME_LEN 100
  char vc_name[SA_MAX_VCNAME_LEN+1];
  u_int32_t vll_vc_id, vc_cos;
  if(getString(sample, vc_name, SA_MAX_VCNAME_LEN) > 0)
    sf_log("mpls_vc_name %s\n", vc_name);
  vll_vc_id = getData32(sample);
  sf_log("mpls_vll_vc_id %u\n", vll_vc_id);
  vc_cos = getData32(sample);
  sf_log("mpls_vc_cos %u\n", vc_cos);
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_MPLS_VC;
}

/*_________________---------------------------__________________
  _________________    readExtendedMplsFTN    __________________
  -----------------___________________________------------------
*/

static void readExtendedMplsFTN(SFSample *sample)
{
#define SA_MAX_FTN_LEN 100
  char ftn_descr[SA_MAX_FTN_LEN+1];
  u_int32_t ftn_mask;
  if(getString(sample, ftn_descr, SA_MAX_FTN_LEN) > 0)
    sf_log("mpls_ftn_descr %s\n", ftn_descr);
  ftn_mask = getData32(sample);
  sf_log("mpls_ftn_mask %u\n", ftn_mask);
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_MPLS_FTN;
}

/*_________________---------------------------__________________
  _________________  readExtendedMplsLDP_FEC  __________________
  -----------------___________________________------------------
*/

static void readExtendedMplsLDP_FEC(SFSample *sample)
{
  u_int32_t fec_addr_prefix_len = getData32(sample);
  sf_log("mpls_fec_addr_prefix_len %u\n", fec_addr_prefix_len);
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_MPLS_LDP_FEC;
}

/*_________________---------------------------__________________
  _________________  readExtendedVlanTunnel   __________________
  -----------------___________________________------------------
*/

static void readExtendedVlanTunnel(SFSample *sample)
{
  u_int32_t lab;
  SFLLabelStack lstk;
  lstk.depth = getData32(sample);
  /* just point at the lablelstack array */
  if(lstk.depth > 0) lstk.stack = (u_int32_t *)sample->datap;
  /* and skip over it in the input */
  skipBytes(sample, lstk.depth * 4);

  if(lstk.depth > 0) {
    u_int32_t j = 0;
    for(; j < lstk.depth; j++) {
      if(j == 0) sf_log("vlan_tunnel ");
      else sf_log("-");
      lab = ntohl(lstk.stack[j]);
      sf_log("0x%04x.%u.%u.%u",
	     (lab >> 16),       // TPI
	     (lab >> 13) & 7,   // priority
	     (lab >> 12) & 1,   // CFI
	     (lab & 4095));     // VLAN
    }
    sf_log("\n");
  }
  sample->extended_data_tag |= SASAMPLE_EXTENDED_DATA_VLAN_TUNNEL;
}

static void readFlowSample_header(SFSample *sample);
static int readFlowSample(SFSample *sample, int expanded);

/*_________________---------------------------__________________
  _________________  readExtendedWifiPayload  __________________
  -----------------___________________________------------------
*/

static void readExtendedWifiPayload(SFSample *sample)
{
  sf_log_next32(sample, "cipher_suite");
  readFlowSample_header(sample);
}

/*_________________---------------------------__________________
  _________________  readExtendedWifiRx       __________________
  -----------------___________________________------------------
*/

static void readExtendedWifiRx(SFSample *sample)
{
  u_int32_t i;
  u_char *bssid;
  char ssid[SFL_MAX_SSID_LEN+1];
  if(getString(sample, ssid, SFL_MAX_SSID_LEN) > 0) {
    sf_log("rx_SSID %s\n", ssid);
  }

  bssid = (u_char *)sample->datap;
  sf_log("rx_BSSID ");
  for(i = 0; i < 6; i++) sf_log("%02x", bssid[i]);
  sf_log("\n");
  skipBytes(sample, 6);

  sf_log_next32(sample, "rx_version");
  sf_log_next32(sample, "rx_channel");
  sf_log_next64(sample, "rx_speed");
  sf_log_next32(sample, "rx_rsni");
  sf_log_next32(sample, "rx_rcpi");
  sf_log_next32(sample, "rx_packet_uS");
}

/*_________________---------------------------__________________
  _________________  readExtendedWifiTx       __________________
  -----------------___________________________------------------
*/

static void readExtendedWifiTx(SFSample *sample)
{
  u_int32_t i;
  u_char *bssid;
  char ssid[SFL_MAX_SSID_LEN+1];
  if(getString(sample, ssid, SFL_MAX_SSID_LEN) > 0) {
    sf_log("tx_SSID %s\n", ssid);
  }

  bssid = (u_char *)sample->datap;
  sf_log("tx_BSSID ");
  for(i = 0; i < 6; i++) sf_log("%02x", bssid[i]);
  sf_log("\n");
  skipBytes(sample, 6);

  sf_log_next32(sample, "tx_version");
  sf_log_next32(sample, "tx_transmissions");
  sf_log_next32(sample, "tx_packet_uS");
  sf_log_next32(sample, "tx_retrans_uS");
  sf_log_next32(sample, "tx_channel");
  sf_log_next64(sample, "tx_speed");
  sf_log_next32(sample, "tx_power_mW");
}

/*_________________---------------------------__________________
  _________________  readExtendedAggregation  __________________
  -----------------___________________________------------------
*/

#if 0
/* No more used */
static void readExtendedAggregation(SFSample *sample)
{
  u_int32_t i, num_pdus = getData32(sample);
  sf_log("aggregation_num_pdus %u\n", num_pdus);
  for(i = 0; i < num_pdus; i++) {
    sf_log("aggregation_pdu %u\n", i);
    readFlowSample(sample, NO); // not sure if this the right one here $$$
  }
}
#endif

/*_________________---------------------------__________________
  _________________  readFlowSample_header    __________________
  -----------------___________________________------------------
*/

static void readFlowSample_header(SFSample *sample)
{
  sf_log("flowSampleType HEADER\n");
  sample->headerProtocol = getData32(sample);
  sf_log("headerProtocol %u\n", sample->headerProtocol);
  sample->sampledPacketSize = getData32(sample);
  sf_log("sampledPacketSize %u\n", sample->sampledPacketSize);
  if(sample->datagramVersion > 4) {
    // stripped count introduced in sFlow version 5
    sample->stripped = getData32(sample);
    sf_log("strippedBytes %u\n", sample->stripped);
  }
  sample->pkt_headerLen = sample->headerLen = getData32(sample);
  sf_log("headerLen %u\n", sample->headerLen);

  sample->pkt_header = sample->header = (u_char *)sample->datap; /* just point at the header */
  skipBytes(sample, sample->headerLen);
  {
    char scratch[2000];
    printHex(sample->header, sample->headerLen, (u_char *)scratch, 2000, 0, 2000);
    sf_log("headerBytes %s\n", scratch);
  }

  switch(sample->headerProtocol) {
    /* the header protocol tells us where to jump into the decode */
  case SFLHEADER_ETHERNET_ISO8023:
    // decodeLinkLayer(sample);
    break;
  case SFLHEADER_IPv4:
    sample->gotIPV4 = YES;
    sample->offsetToIPV4 = 0;
    break;
  case SFLHEADER_IPv6:
    sample->gotIPV6 = YES;
    sample->offsetToIPV6 = 0;
    break;
  case SFLHEADER_IEEE80211MAC:
    // decode80211MAC(sample);
    break;
  case SFLHEADER_ISO88024_TOKENBUS:
  case SFLHEADER_ISO88025_TOKENRING:
  case SFLHEADER_FDDI:
  case SFLHEADER_FRAME_RELAY:
  case SFLHEADER_X25:
  case SFLHEADER_PPP:
  case SFLHEADER_SMDS:
  case SFLHEADER_AAL5:
  case SFLHEADER_AAL5_IP:
  case SFLHEADER_MPLS:
  case SFLHEADER_POS:
  case SFLHEADER_IEEE80211_AMPDU:
  case SFLHEADER_IEEE80211_AMSDU_SUBFRAME:
    sf_log("NO_DECODE headerProtocol=%d\n", sample->headerProtocol);
    break;
  default:
    fprintf(stderr, "undefined headerProtocol = %u\n", sample->headerProtocol);
    // exit(-13);
    return;
  }

#if 0
  if(sample->gotIPV4) {
    // report the size of the original IPPdu (including the IP header)
    sf_log("IPSize %d\n",  sample->sampledPacketSize - sample->stripped - sample->offsetToIPV4);
    decodeIPV4(sample);
  }
  else if(sample->gotIPV6) {
    // report the size of the original IPPdu (including the IP header)
    sf_log("IPSize %d\n",  sample->sampledPacketSize - sample->stripped - sample->offsetToIPV6);
    decodeIPV6(sample);
  }
#endif
}

/*_________________---------------------------__________________
  _________________  readFlowSample_ethernet  __________________
  -----------------___________________________------------------
*/

static void readFlowSample_ethernet(SFSample *sample)
{
  u_char *p;
  sf_log("flowSampleType ETHERNET\n");
  sample->eth_len = getData32(sample);
  memcpy(sample->eth_src, sample->datap, 6);
  skipBytes(sample, 6);
  memcpy(sample->eth_dst, sample->datap, 6);
  skipBytes(sample, 6);
  sample->eth_type = getData32(sample);
  sf_log("ethernet_type %u\n", sample->eth_type);
  sf_log("ethernet_len %u\n", sample->eth_len);
  p = sample->eth_src;
  sf_log("ethernet_src %02x%02x%02x%02x%02x%02x\n", p[0], p[1], p[2], p[3], p[4], p[5]);
  p = sample->eth_dst;
  sf_log("ethernet_dst %02x%02x%02x%02x%02x%02x\n", p[0], p[1], p[2], p[3], p[4], p[5]);
}


/*_________________---------------------------__________________
  _________________    readFlowSample_IPv4    __________________
  -----------------___________________________------------------
*/

static void readFlowSample_IPv4(SFSample *sample)
{
  sf_log("flowSampleType IPV4\n");
  sample->headerLen = sizeof(SFLSampled_ipv4);
  sample->header = (u_char *)sample->datap; /* just point at the header */
  skipBytes(sample, sample->headerLen);
  {
    char buf[51];
    SFLSampled_ipv4 nfKey;
    memcpy(&nfKey, sample->header, sizeof(nfKey));
    sample->sampledPacketSize = ntohl(nfKey.length);
    sf_log("sampledPacketSize %u\n", sample->sampledPacketSize);
    sf_log("IPSize %u\n",  sample->sampledPacketSize);
    sample->ipsrc.type = SFLADDRESSTYPE_IP_V4;
    sample->ipsrc.address.ip_v4 = nfKey.src_ip;
    sample->ipdst.type = SFLADDRESSTYPE_IP_V4;
    sample->ipdst.address.ip_v4 = nfKey.dst_ip;
    sample->dcd_ipProtocol = ntohl(nfKey.protocol);
    sample->dcd_ipTos = ntohl(nfKey.tos);
    sf_log("srcIP %s\n", printAddress(&sample->ipsrc, buf, 50));
    sf_log("dstIP %s\n", printAddress(&sample->ipdst, buf, 50));
    sf_log("IPProtocol %u\n", sample->dcd_ipProtocol);
    sf_log("IPTOS %u\n", sample->dcd_ipTos);
    sample->dcd_sport = ntohl(nfKey.src_port);
    sample->dcd_dport = ntohl(nfKey.dst_port);
    switch(sample->dcd_ipProtocol) {
    case 1: /* ICMP */
      sf_log("ICMPType %u\n", sample->dcd_dport);
      /* not sure about the dest port being icmp type
	 - might be that src port is icmp type and dest
	 port is icmp code.  Still, have seen some
	 implementations where src port is 0 and dst
	 port is the type, so it may be safer to
	 assume that the destination port has the type */
      break;
    case 6: /* TCP */
      sf_log("TCPSrcPort %u\n", sample->dcd_sport);
      sf_log("TCPDstPort %u\n", sample->dcd_dport);
      sample->dcd_tcpFlags = ntohl(nfKey.tcp_flags);
      sf_log("TCPFlags %u\n", sample->dcd_tcpFlags);
      break;
    case 17: /* UDP */
      sf_log("UDPSrcPort %u\n", sample->dcd_sport);
      sf_log("UDPDstPort %u\n", sample->dcd_dport);
      break;
    default: /* some other protcol */
      break;
    }
  }
}

/*_________________---------------------------__________________
  _________________    readFlowSample_IPv6    __________________
  -----------------___________________________------------------
*/

static void readFlowSample_IPv6(SFSample *sample)
{
  sf_log("flowSampleType IPV6\n");
  sample->header = (u_char *)sample->datap; /* just point at the header */
  sample->headerLen = sizeof(SFLSampled_ipv6);
  skipBytes(sample, sample->headerLen);
  {
    char buf[51];
    SFLSampled_ipv6 nfKey6;
    memcpy(&nfKey6, sample->header, sizeof(nfKey6));
    sample->sampledPacketSize = ntohl(nfKey6.length);
    sf_log("sampledPacketSize %u\n", sample->sampledPacketSize);
    sf_log("IPSize %u\n", sample->sampledPacketSize);
    sample->ipsrc.type = SFLADDRESSTYPE_IP_V6;
    memcpy(&sample->ipsrc.address.ip_v6, &nfKey6.src_ip, 16);
    sample->ipdst.type = SFLADDRESSTYPE_IP_V6;
    memcpy(&sample->ipdst.address.ip_v6, &nfKey6.dst_ip, 16);
    sample->dcd_ipProtocol = ntohl(nfKey6.protocol);
    sf_log("srcIP6 %s\n", printAddress(&sample->ipsrc, buf, 50));
    sf_log("dstIP6 %s\n", printAddress(&sample->ipdst, buf, 50));
    sf_log("IPProtocol %u\n", sample->dcd_ipProtocol);
    sf_log("priority %u\n", ntohl(nfKey6.priority));
    sample->dcd_sport = ntohl(nfKey6.src_port);
    sample->dcd_dport = ntohl(nfKey6.dst_port);
    switch(sample->dcd_ipProtocol) {
    case 1: /* ICMP */
      sf_log("ICMPType %u\n", sample->dcd_dport);
      /* not sure about the dest port being icmp type
	 - might be that src port is icmp type and dest
	 port is icmp code.  Still, have seen some
	 implementations where src port is 0 and dst
	 port is the type, so it may be safer to
	 assume that the destination port has the type */
      break;
    case 6: /* TCP */
      sf_log("TCPSrcPort %u\n", sample->dcd_sport);
      sf_log("TCPDstPort %u\n", sample->dcd_dport);
      sample->dcd_tcpFlags = ntohl(nfKey6.tcp_flags);
      sf_log("TCPFlags %u\n", sample->dcd_tcpFlags);
      break;
    case 17: /* UDP */
      sf_log("UDPSrcPort %u\n", sample->dcd_sport);
      sf_log("UDPDstPort %u\n", sample->dcd_dport);
      break;
    default: /* some other protcol */
      break;
    }
  }
}

/*_________________----------------------------__________________
  _________________  readFlowSample_memcache   __________________
  -----------------____________________________------------------
*/

static void readFlowSample_memcache(SFSample *sample)
{
//  char key[SFL_MAX_MEMCACHE_KEY+1];
#define ENC_KEY_BYTES (SFL_MAX_MEMCACHE_KEY * 3) + 1
//  char enc_key[ENC_KEY_BYTES];
  sf_log("flowSampleType memcache\n");
  sf_log_next32(sample, "memcache_op_protocol");
  sf_log_next32(sample, "memcache_op_cmd");
#if 0
  if(getString(sample, key, SFL_MAX_MEMCACHE_KEY) > 0) {
    sf_log("memcache_op_key %s\n", URLEncode(key, enc_key, ENC_KEY_BYTES));
  }
#endif
  sf_log_next32(sample, "memcache_op_nkeys");
  sf_log_next32(sample, "memcache_op_value_bytes");
  sf_log_next32(sample, "memcache_op_duration_uS");
  sf_log_next32(sample, "memcache_op_status");
}

/*_________________----------------------------__________________
  _________________  readFlowSample_http       __________________
  -----------------____________________________------------------
*/

static void readFlowSample_http(SFSample *sample)
{
  char uri[SFL_MAX_HTTP_URI+1];
  char host[SFL_MAX_HTTP_HOST+1];
  char referrer[SFL_MAX_HTTP_REFERRER+1];
  char useragent[SFL_MAX_HTTP_USERAGENT+1];
  char authuser[SFL_MAX_HTTP_AUTHUSER+1];
  char mimetype[SFL_MAX_HTTP_MIMETYPE+1];

  sf_log("flowSampleType http\n");
  sf_log_next32(sample, "http_method");
  sf_log_next32(sample, "http_protocol");
  if(getString(sample, uri, SFL_MAX_HTTP_URI) > 0) {
    sf_log("http_uri %s\n", uri);
  }
  if(getString(sample, host, SFL_MAX_HTTP_HOST) > 0) {
    sf_log("http_host %s\n", host);
  }
  if(getString(sample, referrer, SFL_MAX_HTTP_REFERRER) > 0) {
    sf_log("http_referrer %s\n", referrer);
  }
  if(getString(sample, useragent, SFL_MAX_HTTP_USERAGENT) > 0) {
    sf_log("http_useragent %s\n", useragent);
  }
  if(getString(sample, authuser, SFL_MAX_HTTP_AUTHUSER) > 0) {
    sf_log("http_authuser %s\n", authuser);
  }
  if(getString(sample, mimetype, SFL_MAX_HTTP_MIMETYPE) > 0) {
    sf_log("http_mimetype %s\n", mimetype);
  }
  sf_log_next64(sample, "http_bytes");
  sf_log_next32(sample, "http_duration_uS");
  sf_log_next32(sample, "http_status");
}

/*_________________----------------------------__________________
  _________________  readFlowSample_memcache   __________________
  -----------------____________________________------------------
*/

static void readFlowSample_CAL(SFSample *sample)
{
  char pool[SFLCAL_MAX_POOL_LEN];
  char transaction[SFLCAL_MAX_TRANSACTION_LEN];
  char operation[SFLCAL_MAX_OPERATION_LEN];
  char status[SFLCAL_MAX_STATUS_LEN];

  // sf_log("flowSampleType CAL\n");

  u_int32_t ttype = getData32(sample);
  if(ttype < SFLOW_CAL_NUM_TRANSACTION_TYPES) {
    sf_log("transaction_type %s\n", CALTransactionNames[ttype]);
  }
  else {
    sf_log("transaction_type %u\n", ttype);
  }

  sf_log_next32(sample, "depth");
  if(getString(sample, pool, SFLCAL_MAX_POOL_LEN) > 0) {
    sf_log("pool %s\n", pool);
  }
  if(getString(sample, transaction, SFLCAL_MAX_TRANSACTION_LEN) > 0) {
    sf_log("transaction %s\n", transaction);
  }
  if(getString(sample, operation, SFLCAL_MAX_OPERATION_LEN) > 0) {
    sf_log("operation %s\n", operation);
  }
  if(getString(sample, status, SFLCAL_MAX_STATUS_LEN) > 0) {
    sf_log("status %s\n", status);
  }
  sf_log_next64(sample, "duration_uS");
}

/*_________________----------------------------__________________
  _________________   readExtendedSocket4      __________________
  -----------------____________________________------------------
*/

static void readExtendedSocket4(SFSample *sample)
{
  char buf[51];
  sf_log("extendedType socket4\n");
  sf_log_next32(sample, "socket4_ip_protocol");
  sample->ipsrc.type = SFLADDRESSTYPE_IP_V4;
  sample->ipsrc.address.ip_v4.addr = getData32_nobswap(sample);
  sample->ipdst.type = SFLADDRESSTYPE_IP_V4;
  sample->ipdst.address.ip_v4.addr = getData32_nobswap(sample);
  sf_log("socket4_local_ip %s\n", printAddress(&sample->ipsrc, buf, 50));
  sf_log("socket4_remote_ip %s\n", printAddress(&sample->ipdst, buf, 50));
  sf_log_next32(sample, "socket4_local_port");
  sf_log_next32(sample, "socket4_remote_port");
}

/*_________________----------------------------__________________
  _________________  readExtendedSocket6       __________________
  -----------------____________________________------------------
*/

static void readExtendedSocket6(SFSample *sample)
{
  char buf[51];
  sf_log("extendedType socket6\n");
  sf_log_next32(sample, "socket6_ip_protocol");
  sample->ipsrc.type = SFLADDRESSTYPE_IP_V6;
  memcpy(&sample->ipsrc.address.ip_v6, sample->datap, 16);
  skipBytes(sample, 16);
  sample->ipdst.type = SFLADDRESSTYPE_IP_V6;
  memcpy(&sample->ipdst.address.ip_v6, sample->datap, 16);
  skipBytes(sample, 16);
  sf_log("socket6_local_ip %s\n", printAddress(&sample->ipsrc, buf, 50));
  sf_log("socket6_remote_ip %s\n", printAddress(&sample->ipdst, buf, 50));
  sf_log_next32(sample, "socket6_local_port");
  sf_log_next32(sample, "socket6_remote_port");

}

/*_________________---------------------------__________________
  _________________    receiveError           __________________
  -----------------___________________________------------------
*/

static void receiveError(SFSample *sample, const char *errm, int hexdump)
{
//  char ipbuf[51];
  char scratch[6000];
#if(0)
  char *msg = "";
  char *hex = "";
#endif
  u_int32_t markOffset = (u_char *)sample->datap - sample->rawSample;
#if(0)
  if(errm) msg = errm;
#endif
  if(hexdump) {
    printHex(sample->rawSample, sample->rawSampleLen, (u_char *)scratch, 6000, markOffset, 16);
#if(0)
    hex = scratch;
#endif
  }

  SFABORT(sample, SF_ABORT_DECODE_ERROR);
}

/*_________________---------------------------__________________
  _________________    readFlowSample_v2v4    __________________
  -----------------___________________________------------------
*/

static int readFlowSample_v2v4(SFSample *sample)
{
  sf_log("sampleType FLOWSAMPLE\n");

  sample->samplesGenerated = getData32(sample);
  sf_log("sampleSequenceNo %u\n", sample->samplesGenerated);
  {
    u_int32_t samplerId = getData32(sample);
    sample->ds_class = samplerId >> 24;
    sample->ds_index = samplerId & 0x00ffffff;
    sf_log("sourceId %u:%u\n", sample->ds_class, sample->ds_index);
  }

  sample->meanSkipCount = getData32(sample);
  sample->samplePool = getData32(sample);
  sample->dropEvents = getData32(sample);
  sample->inputPort = getData32(sample);
  sample->outputPort = getData32(sample);
  sf_log("meanSkipCount %u\n", sample->meanSkipCount);
  sf_log("samplePool %u\n", sample->samplePool);
  sf_log("dropEvents %u\n", sample->dropEvents);
  sf_log("inputPort %u\n", sample->inputPort);
  if(sample->outputPort & 0x80000000) {
    u_int32_t numOutputs = sample->outputPort & 0x7fffffff;
    if(numOutputs > 0) sf_log("outputPort multiple %d\n", numOutputs);
    else sf_log("outputPort multiple >1\n");
  }
  else sf_log("outputPort %u\n", sample->outputPort);

  sample->packet_data_tag = getData32(sample);

  switch(sample->packet_data_tag) {

  case INMPACKETTYPE_HEADER: readFlowSample_header(sample); break;
  case INMPACKETTYPE_IPV4:
    sample->gotIPV4Struct = YES;
    readFlowSample_IPv4(sample);
    break;
  case INMPACKETTYPE_IPV6:
    sample->gotIPV6Struct = YES;
    readFlowSample_IPv6(sample);
    break;
  default:
    return(0);
  }

  sample->extended_data_tag = 0;
  {
    u_int32_t x;
    sample->num_extended = getData32(sample);
    for(x = 0; x < sample->num_extended; x++) {
      u_int32_t extended_tag;
      extended_tag = getData32(sample);
      switch(extended_tag) {
      case INMEXTENDED_SWITCH: readExtendedSwitch(sample); break;
      case INMEXTENDED_ROUTER: readExtendedRouter(sample); break;
      case INMEXTENDED_GATEWAY:
	if(sample->datagramVersion == 2) readExtendedGateway_v2(sample);
	else readExtendedGateway(sample);
	break;
      case INMEXTENDED_USER: readExtendedUser(sample); break;
      case INMEXTENDED_URL: readExtendedUrl(sample); break;
      default:
	receiveError(sample, "unrecognized extended data tag", YES);
	return(-1);
	break;
      }
    }
  }

  return(0);
}

/*_________________---------------------------__________________
  _________________    lengthCheck            __________________
  -----------------___________________________------------------
*/

static int lengthCheck(SFSample *sample, const char *description, u_char *start, u_int32_t len) {
  u_int32_t actualLen = (u_char *)sample->datap - start;

  if(actualLen != len)
  {
    /* Alignement helper by L.Deri as some sflow implementations are broken */
    int diff = actualLen-len;

    if((diff > 0) && (diff < 4)) {
      sample->datap -= diff, actualLen -= diff;
    }

    if(actualLen != len) {
      SFABORT(sample, SF_ABORT_LENGTH_ERROR);
      return(-1);
    }
  }

  return(0);
}

/*_________________---------------------------__________________
  _________________    readFlowSample         __________________
  -----------------___________________________------------------
*/

static int readFlowSample(SFSample *sample, int expanded)
{
  u_int32_t num_elements, sampleLength;
  u_char *sampleStart;

  sf_log("sampleType FLOWSAMPLE\n");
  sampleLength = getData32(sample);
  sampleStart = (u_char *)sample->datap;
  sample->samplesGenerated = getData32(sample);
  sf_log("sampleSequenceNo %u\n", sample->samplesGenerated);
  if(expanded) {
    sample->ds_class = getData32(sample);
    sample->ds_index = getData32(sample);
  }
  else {
    u_int32_t samplerId = getData32(sample);
    sample->ds_class = samplerId >> 24;
    sample->ds_index = samplerId & 0x00ffffff;
  }
  sf_log("sourceId %u:%u\n", sample->ds_class, sample->ds_index);

  sample->meanSkipCount = getData32(sample);
  sample->samplePool = getData32(sample);
  sample->dropEvents = getData32(sample);
  sf_log("meanSkipCount %u\n", sample->meanSkipCount);
  sf_log("samplePool %u\n", sample->samplePool);
  sf_log("dropEvents %u\n", sample->dropEvents);
  if(expanded) {
    sample->inputPortFormat = getData32(sample);
    sample->inputPort = getData32(sample);
    sample->outputPortFormat = getData32(sample);
    sample->outputPort = getData32(sample);
  }
  else {
    u_int32_t inp, outp;
    inp = getData32(sample);
    outp = getData32(sample);
    sample->inputPortFormat = inp >> 30;
    sample->outputPortFormat = outp >> 30;
    sample->inputPort = inp & 0x3fffffff;
    sample->outputPort = outp & 0x3fffffff;
  }

  switch(sample->inputPortFormat) {
  case 3: sf_log("inputPort format==3 %u\n", sample->inputPort); break;
  case 2: sf_log("inputPort multiple %u\n", sample->inputPort); break;
  case 1: sf_log("inputPort dropCode %u\n", sample->inputPort); break;
  case 0: sf_log("inputPort %u\n", sample->inputPort); break;
  }

  switch(sample->outputPortFormat) {
  case 3: sf_log("outputPort format==3 %u\n", sample->outputPort); break;
  case 2: sf_log("outputPort multiple %u\n", sample->outputPort); break;
  case 1: sf_log("outputPort dropCode %u\n", sample->outputPort); break;
  case 0: sf_log("outputPort %u\n", sample->outputPort); break;
  }

  // clear the CLF record
  sfCLF.valid = NO;
  sfCLF.client[0] = '\0';

  num_elements = getData32(sample);
  {
    u_int32_t el;
    for(el = 0; el < num_elements; el++) {
      u_int32_t tag, length;
      u_char *start;
      char buf[51];
      tag = getData32(sample);
      sf_log("flowBlock_tag %s\n", printTag(tag, buf, 50));
      length = getData32(sample);
      start = (u_char *)sample->datap;

      switch(tag) {
      case SFLFLOW_HEADER:     readFlowSample_header(sample); break;
      case SFLFLOW_ETHERNET:   readFlowSample_ethernet(sample); break;
      case SFLFLOW_IPV4:       readFlowSample_IPv4(sample); break;
      case SFLFLOW_IPV6:       readFlowSample_IPv6(sample); break;
      case SFLFLOW_MEMCACHE:   readFlowSample_memcache(sample); break;
      case SFLFLOW_HTTP:       readFlowSample_http(sample); break;
      case SFLFLOW_CAL:       readFlowSample_CAL(sample); break;
      case SFLFLOW_EX_SWITCH:  readExtendedSwitch(sample); break;
      case SFLFLOW_EX_ROUTER:  readExtendedRouter(sample); break;
      case SFLFLOW_EX_GATEWAY: readExtendedGateway(sample); break;
      case SFLFLOW_EX_USER:    readExtendedUser(sample); break;
      case SFLFLOW_EX_URL:     readExtendedUrl(sample); break;
      case SFLFLOW_EX_MPLS:    readExtendedMpls(sample); break;
      case SFLFLOW_EX_NAT:     readExtendedNat(sample); break;
      case SFLFLOW_EX_MPLS_TUNNEL:  readExtendedMplsTunnel(sample); break;
      case SFLFLOW_EX_MPLS_VC:      readExtendedMplsVC(sample); break;
      case SFLFLOW_EX_MPLS_FTN:     readExtendedMplsFTN(sample); break;
      case SFLFLOW_EX_MPLS_LDP_FEC: readExtendedMplsLDP_FEC(sample); break;
      case SFLFLOW_EX_VLAN_TUNNEL:  readExtendedVlanTunnel(sample); break;
      case SFLFLOW_EX_80211_PAYLOAD: readExtendedWifiPayload(sample); break;
      case SFLFLOW_EX_80211_RX: readExtendedWifiRx(sample); break;
      case SFLFLOW_EX_80211_TX: readExtendedWifiTx(sample); break;
	/* case SFLFLOW_EX_AGGREGATION: readExtendedAggregation(sample); break; */
      case SFLFLOW_EX_SOCKET4: readExtendedSocket4(sample); break;
      case SFLFLOW_EX_SOCKET6: readExtendedSocket6(sample); break;
      default: skipTLVRecord(sample, tag, length, "flow_sample_element"); break;
      }

      if(lengthCheck(sample, "flow_sample_element", start, length) != 0)
	return(-1);
    }
  }
  if(lengthCheck(sample, "flow_sample", sampleStart, sampleLength) != 0)
    return(-1);

  return(0);
}

/*_________________---------------------------__________________
  _________________  readCounters_generic     __________________
  -----------------___________________________------------------
*/

static void readCounters_generic(SFSample *sample)
{
  /* the first part of the generic counters block is really just more info about the interface. */
  sample->ifCounters.ifIndex = sf_log_next32(sample, "ifIndex");
  sample->ifCounters.ifType = sf_log_next32(sample, "networkType");
  sample->ifCounters.ifSpeed = sf_log_next64(sample, "ifSpeed");
  sample->ifCounters.ifDirection = sf_log_next32(sample, "ifDirection");
  sample->ifCounters.ifStatus = sf_log_next32(sample, "ifStatus");
  /* the generic counters always come first */
  sample->ifCounters.ifInOctets = sf_log_next64(sample, "ifInOctets");
  sample->ifCounters.ifInUcastPkts = sf_log_next32(sample, "ifInUcastPkts");
  sample->ifCounters.ifInMulticastPkts = sf_log_next32(sample, "ifInMulticastPkts");
  sample->ifCounters.ifInBroadcastPkts = sf_log_next32(sample, "ifInBroadcastPkts");
  sample->ifCounters.ifInDiscards = sf_log_next32(sample, "ifInDiscards");
  sample->ifCounters.ifInErrors = sf_log_next32(sample, "ifInErrors");
  sample->ifCounters.ifInUnknownProtos = sf_log_next32(sample, "ifInUnknownProtos");
  sample->ifCounters.ifOutOctets = sf_log_next64(sample, "ifOutOctets");
  sample->ifCounters.ifOutUcastPkts = sf_log_next32(sample, "ifOutUcastPkts");
  sample->ifCounters.ifOutMulticastPkts = sf_log_next32(sample, "ifOutMulticastPkts");
  sample->ifCounters.ifOutBroadcastPkts = sf_log_next32(sample, "ifOutBroadcastPkts");
  sample->ifCounters.ifOutDiscards = sf_log_next32(sample, "ifOutDiscards");
  sample->ifCounters.ifOutErrors = sf_log_next32(sample, "ifOutErrors");
  sample->ifCounters.ifPromiscuousMode = sf_log_next32(sample, "ifPromiscuousMode");
}

/*_________________---------------------------__________________
  _________________  readCounters_ethernet    __________________
  -----------------___________________________------------------
*/

static  void readCounters_ethernet(SFSample *sample)
{
  sf_log_next32(sample, "dot3StatsAlignmentErrors");
  sf_log_next32(sample, "dot3StatsFCSErrors");
  sf_log_next32(sample, "dot3StatsSingleCollisionFrames");
  sf_log_next32(sample, "dot3StatsMultipleCollisionFrames");
  sf_log_next32(sample, "dot3StatsSQETestErrors");
  sf_log_next32(sample, "dot3StatsDeferredTransmissions");
  sf_log_next32(sample, "dot3StatsLateCollisions");
  sf_log_next32(sample, "dot3StatsExcessiveCollisions");
  sf_log_next32(sample, "dot3StatsInternalMacTransmitErrors");
  sf_log_next32(sample, "dot3StatsCarrierSenseErrors");
  sf_log_next32(sample, "dot3StatsFrameTooLongs");
  sf_log_next32(sample, "dot3StatsInternalMacReceiveErrors");
  sf_log_next32(sample, "dot3StatsSymbolErrors");
}


/*_________________---------------------------__________________
  _________________  readCounters_tokenring   __________________
  -----------------___________________________------------------
*/

static void readCounters_tokenring(SFSample *sample)
{
  sf_log_next32(sample, "dot5StatsLineErrors");
  sf_log_next32(sample, "dot5StatsBurstErrors");
  sf_log_next32(sample, "dot5StatsACErrors");
  sf_log_next32(sample, "dot5StatsAbortTransErrors");
  sf_log_next32(sample, "dot5StatsInternalErrors");
  sf_log_next32(sample, "dot5StatsLostFrameErrors");
  sf_log_next32(sample, "dot5StatsReceiveCongestions");
  sf_log_next32(sample, "dot5StatsFrameCopiedErrors");
  sf_log_next32(sample, "dot5StatsTokenErrors");
  sf_log_next32(sample, "dot5StatsSoftErrors");
  sf_log_next32(sample, "dot5StatsHardErrors");
  sf_log_next32(sample, "dot5StatsSignalLoss");
  sf_log_next32(sample, "dot5StatsTransmitBeacons");
  sf_log_next32(sample, "dot5StatsRecoverys");
  sf_log_next32(sample, "dot5StatsLobeWires");
  sf_log_next32(sample, "dot5StatsRemoves");
  sf_log_next32(sample, "dot5StatsSingles");
  sf_log_next32(sample, "dot5StatsFreqErrors");
}


/*_________________---------------------------__________________
  _________________  readCounters_vg          __________________
  -----------------___________________________------------------
*/

static void readCounters_vg(SFSample *sample)
{
  sf_log_next32(sample, "dot12InHighPriorityFrames");
  sf_log_next64(sample, "dot12InHighPriorityOctets");
  sf_log_next32(sample, "dot12InNormPriorityFrames");
  sf_log_next64(sample, "dot12InNormPriorityOctets");
  sf_log_next32(sample, "dot12InIPMErrors");
  sf_log_next32(sample, "dot12InOversizeFrameErrors");
  sf_log_next32(sample, "dot12InDataErrors");
  sf_log_next32(sample, "dot12InNullAddressedFrames");
  sf_log_next32(sample, "dot12OutHighPriorityFrames");
  sf_log_next64(sample, "dot12OutHighPriorityOctets");
  sf_log_next32(sample, "dot12TransitionIntoTrainings");
  sf_log_next64(sample, "dot12HCInHighPriorityOctets");
  sf_log_next64(sample, "dot12HCInNormPriorityOctets");
  sf_log_next64(sample, "dot12HCOutHighPriorityOctets");
}



/*_________________---------------------------__________________
  _________________  readCounters_vlan        __________________
  -----------------___________________________------------------
*/

static void readCounters_vlan(SFSample *sample)
{
  sample->in_vlan = getData32(sample);
  sf_log("in_vlan %u\n", sample->in_vlan);
  sf_log_next64(sample, "octets");
  sf_log_next32(sample, "ucastPkts");
  sf_log_next32(sample, "multicastPkts");
  sf_log_next32(sample, "broadcastPkts");
  sf_log_next32(sample, "discards");
}

/*_________________---------------------------__________________
  _________________  readCounters_80211       __________________
  -----------------___________________________------------------
*/

static void readCounters_80211(SFSample *sample)
{
  sf_log_next32(sample, "dot11TransmittedFragmentCount");
  sf_log_next32(sample, "dot11MulticastTransmittedFrameCount");
  sf_log_next32(sample, "dot11FailedCount");
  sf_log_next32(sample, "dot11RetryCount");
  sf_log_next32(sample, "dot11MultipleRetryCount");
  sf_log_next32(sample, "dot11FrameDuplicateCount");
  sf_log_next32(sample, "dot11RTSSuccessCount");
  sf_log_next32(sample, "dot11RTSFailureCount");
  sf_log_next32(sample, "dot11ACKFailureCount");
  sf_log_next32(sample, "dot11ReceivedFragmentCount");
  sf_log_next32(sample, "dot11MulticastReceivedFrameCount");
  sf_log_next32(sample, "dot11FCSErrorCount");
  sf_log_next32(sample, "dot11TransmittedFrameCount");
  sf_log_next32(sample, "dot11WEPUndecryptableCount");
  sf_log_next32(sample, "dot11QoSDiscardedFragmentCount");
  sf_log_next32(sample, "dot11AssociatedStationCount");
  sf_log_next32(sample, "dot11QoSCFPollsReceivedCount");
  sf_log_next32(sample, "dot11QoSCFPollsUnusedCount");
  sf_log_next32(sample, "dot11QoSCFPollsUnusableCount");
  sf_log_next32(sample, "dot11QoSCFPollsLostCount");
}

/*_________________---------------------------__________________
  _________________  readCounters_processor   __________________
  -----------------___________________________------------------
*/

static void readCounters_processor(SFSample *sample)
{
  sf_log_percentage(sample, "5s_cpu");
  sf_log_percentage(sample, "1m_cpu");
  sf_log_percentage(sample, "5m_cpu");
  sf_log_next64(sample, "total_memory_bytes");
  sf_log_next64(sample, "free_memory_bytes");
}

/*_________________---------------------------__________________
  _________________  readCounters_radio       __________________
  -----------------___________________________------------------
*/

static void readCounters_radio(SFSample *sample)
{
  sf_log_next32(sample, "radio_elapsed_time");
  sf_log_next32(sample, "radio_on_channel_time");
  sf_log_next32(sample, "radio_on_channel_busy_time");
}

/*_________________---------------------------__________________
  _________________  readCounters_host_hid    __________________
  -----------------___________________________------------------
*/

static void readCounters_host_hid(SFSample *sample)
{
  u_int32_t i;
  u_char *uuid;
  char hostname[SFL_MAX_HOSTNAME_LEN+1];
  char os_release[SFL_MAX_OSRELEASE_LEN+1];
  if(getString(sample, hostname, SFL_MAX_HOSTNAME_LEN) > 0) {
    sf_log("hostname %s\n", hostname);
  }
  uuid = (u_char *)sample->datap;
  sf_log("UUID ");
  for(i = 0; i < 16; i++) sf_log("%02x", uuid[i]);
  sf_log("\n");
  skipBytes(sample, 16);
  sf_log_next32(sample, "machine_type");
  sf_log_next32(sample, "os_name");
  if(getString(sample, os_release, SFL_MAX_OSRELEASE_LEN) > 0) {
    sf_log("os_release %s\n", os_release);
  }
}

/*_________________---------------------------__________________
  _________________  readCounters_adaptors    __________________
  -----------------___________________________------------------
*/

static void readCounters_adaptors(SFSample *sample)
{
  u_char *mac;
  u_int32_t i, j, ifindex, num_macs, num_adaptors = getData32(sample);
  for(i = 0; i < num_adaptors; i++) {
    ifindex = getData32(sample);
    sf_log("adaptor_%u_ifIndex %u\n", i, ifindex);
    num_macs = getData32(sample);
    sf_log("adaptor_%u_MACs %u\n", i, num_macs);
    for(j = 0; j < num_macs; j++) {
      mac = (u_char *)sample->datap;
      sf_log("adaptor_%u_MAC_%u %02x%02x%02x%02x%02x%02x\n",
	     i, j,
	     mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
      skipBytes(sample, 8);
    }
  }
}


/*_________________----------------------------__________________
  _________________  readCounters_host_parent  __________________
  -----------------____________________________------------------
*/

static void readCounters_host_parent(SFSample *sample)
{
  sf_log_next32(sample, "parent_dsClass");
  sf_log_next32(sample, "parent_dsIndex");
}

/*_________________---------------------------__________________
  _________________  readCounters_host_cpu    __________________
  -----------------___________________________------------------
*/

static void readCounters_host_cpu(SFSample *sample)
{
  sf_log_nextFloat(sample, "cpu_load_one");
  sf_log_nextFloat(sample, "cpu_load_five");
  sf_log_nextFloat(sample, "cpu_load_fifteen");
  sf_log_next32(sample, "cpu_proc_run");
  sf_log_next32(sample, "cpu_proc_total");
  sf_log_next32(sample, "cpu_num");
  sf_log_next32(sample, "cpu_speed");
  sf_log_next32(sample, "cpu_uptime");
  sf_log_next32(sample, "cpu_user");
  sf_log_next32(sample, "cpu_nice");
  sf_log_next32(sample, "cpu_system");
  sf_log_next32(sample, "cpu_idle");
  sf_log_next32(sample, "cpu_wio");
  sf_log_next32(sample, "cpuintr");
  sf_log_next32(sample, "cpu_sintr");
  sf_log_next32(sample, "cpuinterrupts");
  sf_log_next32(sample, "cpu_contexts");
}

/*_________________---------------------------__________________
  _________________  readCounters_host_mem    __________________
  -----------------___________________________------------------
*/

static void readCounters_host_mem(SFSample *sample)
{
  sf_log_next64(sample, "mem_total");
  sf_log_next64(sample, "mem_free");
  sf_log_next64(sample, "mem_shared");
  sf_log_next64(sample, "mem_buffers");
  sf_log_next64(sample, "mem_cached");
  sf_log_next64(sample, "swap_total");
  sf_log_next64(sample, "swap_free");
  sf_log_next32(sample, "page_in");
  sf_log_next32(sample, "page_out");
  sf_log_next32(sample, "swap_in");
  sf_log_next32(sample, "swap_out");
}


/*_________________---------------------------__________________
  _________________  readCounters_host_dsk    __________________
  -----------------___________________________------------------
*/

static void readCounters_host_dsk(SFSample *sample)
{
  sf_log_next64(sample, "disk_total");
  sf_log_next64(sample, "disk_free");
  sf_log_next32(sample, "disk_partition_max_used");
  sf_log_next32(sample, "disk_reads");
  sf_log_next64(sample, "disk_bytes_read");
  sf_log_next32(sample, "disk_read_time");
  sf_log_next32(sample, "disk_writes");
  sf_log_next64(sample, "disk_bytes_written");
  sf_log_next32(sample, "disk_write_time");
}

/*_________________---------------------------__________________
  _________________  readCounters_host_nio    __________________
  -----------------___________________________------------------
*/

static void readCounters_host_nio(SFSample *sample)
{
  sf_log_next64(sample, "nio_bytes_in");
  sf_log_next32(sample, "nio_pkts_in");
  sf_log_next32(sample, "nio_errs_in");
  sf_log_next32(sample, "nio_drops_in");
  sf_log_next64(sample, "nio_bytes_out");
  sf_log_next32(sample, "nio_pkts_out");
  sf_log_next32(sample, "nio_errs_out");
  sf_log_next32(sample, "nio_drops_out");
}

/*_________________-----------------------------__________________
  _________________  readCounters_host_vnode    __________________
  -----------------_____________________________------------------
*/

static void readCounters_host_vnode(SFSample *sample)
{
  sf_log_next32(sample, "vnode_mhz");
  sf_log_next32(sample, "vnode_cpus");
  sf_log_next64(sample, "vnode_memory");
  sf_log_next64(sample, "vnode_memory_free");
  sf_log_next32(sample, "vnode_num_domains");
}

/*_________________----------------------------__________________
  _________________  readCounters_host_vcpu    __________________
  -----------------____________________________------------------
*/

static void readCounters_host_vcpu(SFSample *sample)
{
  sf_log_next32(sample, "vcpu_state");
  sf_log_next32(sample, "vcpu_cpu_mS");
  sf_log_next32(sample, "vcpu_cpuCount");
}

/*_________________----------------------------__________________
  _________________  readCounters_host_vmem    __________________
  -----------------____________________________------------------
*/

static void readCounters_host_vmem(SFSample *sample)
{
  sf_log_next64(sample, "vmem_memory");
  sf_log_next64(sample, "vmem_maxMemory");
}

/*_________________----------------------------__________________
  _________________  readCounters_host_vdsk    __________________
  -----------------____________________________------------------
*/

static void readCounters_host_vdsk(SFSample *sample)
{
  sf_log_next64(sample, "vdsk_capacity");
  sf_log_next64(sample, "vdsk_allocation");
  sf_log_next64(sample, "vdsk_available");
  sf_log_next32(sample, "vdsk_rd_req");
  sf_log_next64(sample, "vdsk_rd_bytes");
  sf_log_next32(sample, "vdsk_wr_req");
  sf_log_next64(sample, "vdsk_wr_bytes");
  sf_log_next32(sample, "vdsk_errs");
}

/*_________________----------------------------__________________
  _________________  readCounters_host_vnio    __________________
  -----------------____________________________------------------
*/

static void readCounters_host_vnio(SFSample *sample)
{
  sf_log_next64(sample, "vnio_bytes_in");
  sf_log_next32(sample, "vnio_pkts_in");
  sf_log_next32(sample, "vnio_errs_in");
  sf_log_next32(sample, "vnio_drops_in");
  sf_log_next64(sample, "vnio_bytes_out");
  sf_log_next32(sample, "vnio_pkts_out");
  sf_log_next32(sample, "vnio_errs_out");
  sf_log_next32(sample, "vnio_drops_out");
}

/*_________________----------------------------__________________
  _________________  readCounters_memcache     __________________
  -----------------____________________________------------------
*/

static void readCounters_memcache(SFSample *sample)
{
  sf_log_next32(sample, "memcache_uptime");
  sf_log_next32(sample, "memcache_rusage_user");
  sf_log_next32(sample, "memcache_rusage_system");
  sf_log_next32(sample, "memcache_curr_connections");
  sf_log_next32(sample, "memcache_total_connections");
  sf_log_next32(sample, "memcache_connection_structures");
  sf_log_next32(sample, "memcache_cmd_get");
  sf_log_next32(sample, "memcache_cmd_set");
  sf_log_next32(sample, "memcache_cmd_flush");
  sf_log_next32(sample, "memcache_get_hits");
  sf_log_next32(sample, "memcache_get_misses");
  sf_log_next32(sample, "memcache_delete_misses");
  sf_log_next32(sample, "memcache_delete_hits");
  sf_log_next32(sample, "memcache_incr_misses");
  sf_log_next32(sample, "memcache_incr_hits");
  sf_log_next32(sample, "memcache_decr_misses");
  sf_log_next32(sample, "memcache_decr_hits");
  sf_log_next32(sample, "memcache_cas_misses");
  sf_log_next32(sample, "memcache_cas_hits");
  sf_log_next32(sample, "memcache_cas_badval");
  sf_log_next32(sample, "memcache_auth_cmds");
  sf_log_next32(sample, "memcache_auth_errors");
  sf_log_next64(sample, "memcache_bytes_read");
  sf_log_next64(sample, "memcache_bytes_written");
  sf_log_next32(sample, "memcache_limit_maxbytes");
  sf_log_next32(sample, "memcache_accepting_conns");
  sf_log_next32(sample, "memcache_listen_disabled_num");
  sf_log_next32(sample, "memcache_threads");
  sf_log_next32(sample, "memcache_conn_yields");
  sf_log_next64(sample, "memcache_bytes");
  sf_log_next32(sample, "memcache_curr_items");
  sf_log_next32(sample, "memcache_total_items");
  sf_log_next32(sample, "memcache_evictions");
}

/*_________________----------------------------__________________
  _________________  readCounters_http         __________________
  -----------------____________________________------------------
*/

static void readCounters_http(SFSample *sample)
{
  sf_log_next32(sample, "http_method_option_count");
  sf_log_next32(sample, "http_method_get_count");
  sf_log_next32(sample, "http_method_head_count");
  sf_log_next32(sample, "http_method_post_count");
  sf_log_next32(sample, "http_method_put_count");
  sf_log_next32(sample, "http_method_delete_count");
  sf_log_next32(sample, "http_method_trace_count");
  sf_log_next32(sample, "http_methd_connect_count");
  sf_log_next32(sample, "http_method_other_count");
  sf_log_next32(sample, "http_status_1XX_count");
  sf_log_next32(sample, "http_status_2XX_count");
  sf_log_next32(sample, "http_status_3XX_count");
  sf_log_next32(sample, "http_status_4XX_count");
  sf_log_next32(sample, "http_status_5XX_count");
  sf_log_next32(sample, "http_status_other_count");
}

/*_________________----------------------------__________________
  _________________  readCounters_CAL          __________________
  -----------------____________________________------------------
*/

static void readCounters_CAL(SFSample *sample)
{
  sf_log_next32(sample, "transactions");
  sf_log_next32(sample, "errors");
  sf_log_next64(sample, "duration_uS");
}

/*_________________---------------------------__________________
  _________________  readCountersSample_v2v4  __________________
  -----------------___________________________------------------
*/

static void readCountersSample_v2v4(SFSample *sample)
{
  sf_log("sampleType COUNTERSSAMPLE\n");
  sample->samplesGenerated = getData32(sample);
  sf_log("sampleSequenceNo %u\n", sample->samplesGenerated);
  {
    u_int32_t samplerId = getData32(sample);
    sample->ds_class = samplerId >> 24;
    sample->ds_index = samplerId & 0x00ffffff;
  }
  sf_log("sourceId %u:%u\n", sample->ds_class, sample->ds_index);


  sample->statsSamplingInterval = getData32(sample);
  sf_log("statsSamplingInterval %u\n", sample->statsSamplingInterval);
  /* now find out what sort of counter blocks we have here... */
  sample->counterBlockVersion = getData32(sample);
  sf_log("counterBlockVersion %u\n", sample->counterBlockVersion);

  /* first see if we should read the generic stats */
  switch(sample->counterBlockVersion) {
  case INMCOUNTERSVERSION_GENERIC:
  case INMCOUNTERSVERSION_ETHERNET:
  case INMCOUNTERSVERSION_TOKENRING:
  case INMCOUNTERSVERSION_FDDI:
  case INMCOUNTERSVERSION_VG:
  case INMCOUNTERSVERSION_WAN: readCounters_generic(sample); break;
  case INMCOUNTERSVERSION_VLAN: break;
  default: receiveError(sample, "unknown stats version", YES); break;
  }

  /* now see if there are any specific counter blocks to add */
  switch(sample->counterBlockVersion) {
  case INMCOUNTERSVERSION_GENERIC: /* nothing more */ break;
  case INMCOUNTERSVERSION_ETHERNET: readCounters_ethernet(sample); break;
  case INMCOUNTERSVERSION_TOKENRING:readCounters_tokenring(sample); break;
  case INMCOUNTERSVERSION_FDDI: break;
  case INMCOUNTERSVERSION_VG: readCounters_vg(sample); break;
  case INMCOUNTERSVERSION_WAN: break;
  case INMCOUNTERSVERSION_VLAN: readCounters_vlan(sample); break;
  default: receiveError(sample, "unknown INMCOUNTERSVERSION", YES); break;
  }
  /* line-by-line output... */
}

/*_________________---------------------------__________________
  _________________   readCountersSample      __________________
  -----------------___________________________------------------
*/

static void readCountersSample(SFSample *sample, int expanded)
{
  u_int32_t sampleLength;
  u_int32_t num_elements;
  u_char *sampleStart;
  sf_log("sampleType COUNTERSSAMPLE\n");
  sampleLength = getData32(sample);
  sampleStart = (u_char *)sample->datap;
  sample->samplesGenerated = getData32(sample);

  sf_log("sampleSequenceNo %u\n", sample->samplesGenerated);
  if(expanded) {
    sample->ds_class = getData32(sample);
    sample->ds_index = getData32(sample);
  }
  else {
    u_int32_t samplerId = getData32(sample);
    sample->ds_class = samplerId >> 24;
    sample->ds_index = samplerId & 0x00ffffff;
  }
  sf_log("sourceId %u:%u\n", sample->ds_class, sample->ds_index);

  num_elements = getData32(sample);
  {
    u_int32_t el;
    for(el = 0; el < num_elements; el++) {
      u_int32_t tag, length;
      u_char *start;
      char buf[51];
      tag = getData32(sample);
      sf_log("counterBlock_tag %s\n", printTag(tag, buf, 50));
      length = getData32(sample);
      start = (u_char *)sample->datap;

      switch(tag) {
      case SFLCOUNTERS_GENERIC: readCounters_generic(sample); break;
      case SFLCOUNTERS_ETHERNET: readCounters_ethernet(sample); break;
      case SFLCOUNTERS_TOKENRING:readCounters_tokenring(sample); break;
      case SFLCOUNTERS_VG: readCounters_vg(sample); break;
      case SFLCOUNTERS_VLAN: readCounters_vlan(sample); break;
      case SFLCOUNTERS_80211: readCounters_80211(sample); break;
      case SFLCOUNTERS_PROCESSOR: readCounters_processor(sample); break;
      case SFLCOUNTERS_RADIO: readCounters_radio(sample); break;
      case SFLCOUNTERS_HOST_HID: readCounters_host_hid(sample); break;
      case SFLCOUNTERS_ADAPTORS: readCounters_adaptors(sample); break;
      case SFLCOUNTERS_HOST_PAR: readCounters_host_parent(sample); break;
      case SFLCOUNTERS_HOST_CPU: readCounters_host_cpu(sample); break;
      case SFLCOUNTERS_HOST_MEM: readCounters_host_mem(sample); break;
      case SFLCOUNTERS_HOST_DSK: readCounters_host_dsk(sample); break;
      case SFLCOUNTERS_HOST_NIO: readCounters_host_nio(sample); break;
      case SFLCOUNTERS_HOST_VRT_NODE: readCounters_host_vnode(sample); break;
      case SFLCOUNTERS_HOST_VRT_CPU: readCounters_host_vcpu(sample); break;
      case SFLCOUNTERS_HOST_VRT_MEM: readCounters_host_vmem(sample); break;
      case SFLCOUNTERS_HOST_VRT_DSK: readCounters_host_vdsk(sample); break;
      case SFLCOUNTERS_HOST_VRT_NIO: readCounters_host_vnio(sample); break;
      case SFLCOUNTERS_MEMCACHE: readCounters_memcache(sample); break;
      case SFLCOUNTERS_HTTP: readCounters_http(sample); break;
      case SFLCOUNTERS_CAL: readCounters_CAL(sample); break;
      default: skipTLVRecord(sample, tag, length, "counters_sample_element"); break;
      }
      lengthCheck(sample, "counters_sample_element", start, length);
    }
  }
  lengthCheck(sample, "counters_sample", sampleStart, sampleLength);
  /* line-by-line output... */
}

/* =============================================================== */

/* Handles Counters samples as found inside sFlow datagrams once the sample has been properly parsed and put into `sample` */
static void handleSflowCountersSample(SFSample *sample) {

}

/* =============================================================== */

static void handleSflowSample(sFlowPktInterface *iface,
			      SFSample *sample, int deviceId) {
  struct pcap_pkthdr pkthdr;
  u_int32_t msk = 0;
  
  msk = sample->meanSkipCount;

  if(msk == 0) msk = 1;

#ifdef DEBUG_UPSCALING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SAMPLING] [sample->samplePool: %u][sample->samplesGenerated: %u]",
			       sample->samplePool,
			       sample->samplesGenerated);
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SAMPLING] MeanSkipCount [computed: %u][expected: %u][average: %u]",
			       msk, sample->meanSkipCount, averageMsk);
#endif

  pkthdr.ts.tv_sec = (long)time(NULL), pkthdr.ts.tv_usec = 0;
  pkthdr.caplen = sample->pkt_headerLen;
  /* Always upscale the traffic */
  pkthdr.len = sample->sampledPacketSize * msk /* Scale data */;

#ifdef DEBUG_UPSCALING
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "[SAMPLING] [portIndex: %u][key: %u]"
			       "[sample->sampledPacketSize: %u]"
			       "[msk: %u][pkthdr.len: %u]",
			       sample->ds_index, key, sample->sampledPacketSize,
			       msk, pkthdr.len);
#endif

#ifdef DEBUG_FLOWS
  ntop->getTrace()->traceEvent(TRACE_INFO, "decodePacket(len=%d/%d)", pkthdr.caplen, pkthdr.len);
#endif

  u_int16_t p;
  Host *srcHost = NULL, *dstHost = NULL;
  Flow *flow = NULL;
  int datalink_type;
  
  switch(sample->headerProtocol) {
  case SFLHEADER_IPv4:
  case SFLHEADER_IPv6:
    datalink_type = DLT_RAW;
    break;

  default:
    datalink_type = DLT_EN10MB;
    break;
  }

  iface->dissectPacket(-1 /* unknown input idx */,
		       DUMMY_BRIDGE_INTERFACE_ID,
		       datalink_type,
		       true, /* ingress - TODO: see if we pass the real packet direction */		
		       NULL, &pkthdr, sample->pkt_header, &p,
		       &srcHost, &dstHost, &flow);
}  

/*_________________---------------------------__________________
  _________________      readSFlowDatagram    __________________
  -----------------___________________________------------------
*/

static void readSFlowDatagram(sFlowPktInterface *iface, SFSample *sample, int deviceId) {
  u_int32_t samplesInPacket;
  struct timeval now;
  char buf[51];

  /* log some datagram info */
  now.tv_sec = (long)time(NULL);
  now.tv_usec = 0;
  sf_log("datagramSourceIP %s\n", IP_to_a(ntohl(sample->sourceIP.s_addr), buf, sizeof(buf)));
  sf_log("datagramSize %u\n", sample->rawSampleLen);
  sf_log("unixSecondsUTC %u\n", now.tv_sec);
  if(sample->pcapTimestamp) sf_log("pcapTimestamp %s\n", ctime(&sample->pcapTimestamp)); // thanks to Richard Clayton for this bugfix

  /* check the version */
  sample->datagramVersion = getData32(sample);
  sf_log("datagramVersion %d\n", sample->datagramVersion);

  switch(sample->datagramVersion) {
  case 2:
    numsFlowsV2Rcvd++;
    break;
  case 4:
    numsFlowsV4Rcvd++;
    break;
  case 5:
    numsFlowsV5Rcvd++;
    break;
  default:
    numBadsFlowsVersionsRcvd++;
    break;
  }

  if(sample->datagramVersion != 2 &&
     sample->datagramVersion != 4 &&
     sample->datagramVersion != 5) {
    receiveError(sample,  "unexpected datagram version number\n", YES);
  }

  u_int32_t original_ip = sample->agent_addr.address.ip_v4.addr; /* Save the original IPv4 */
  
  /* get the agent address */
  getAddress(sample, &sample->agent_addr);

  if((sample->agent_addr.type == 1 /* IPv4 */) && (original_ip != 0)) {
    /* Restore the riginal IP as it might have been reforged via --collector-nf-reforge c*/
    sample->agent_addr.address.ip_v4.addr = original_ip;
  }
  
  /* version 5 has an agent sub-id as well */
  if(sample->datagramVersion >= 5) {
    sample->agentSubId = getData32(sample);
    sf_log("agentSubId %u\n", sample->agentSubId);
  }

  sample->sequenceNo = getData32(sample);  /* this is the packet sequence number */
  sample->sysUpTime = getData32(sample);
  samplesInPacket = getData32(sample);
  sf_log("agent %s\n", printAddress(&sample->agent_addr, buf, 50));
  sf_log("packetSequenceNo %u\n", sample->sequenceNo);
  sf_log("sysUpTime %u\n", sample->sysUpTime);
  sf_log("samplesInPacket %u\n", samplesInPacket);

  /* now iterate and pull out the flows and counters samples */
  {
    u_int32_t samp = 0, rc;

    for(; samp < samplesInPacket; samp++) {
      if((u_char *)sample->datap >= sample->endp) {
	fprintf(stderr, "unexpected end of datagram after sample %u of %u\n", samp, samplesInPacket);
	SFABORT(sample, SF_ABORT_EOS);
	break;
      }
      // just read the tag, then call the approriate decode fn
      rc = 0;
      sample->sampleType = getData32(sample);
      sf_log("startSample ----------------------\n");
      sf_log("sampleType_tag %s\n", printTag(sample->sampleType, buf, 50));
      if(sample->datagramVersion >= 5) {
	switch(sample->sampleType) {
	case SFLFLOW_SAMPLE: rc = readFlowSample(sample, NO); break;
	case SFLCOUNTERS_SAMPLE: readCountersSample(sample, NO); handleSflowCountersSample(sample); break;
	case SFLFLOW_SAMPLE_EXPANDED: readFlowSample(sample, YES); break;
	case SFLCOUNTERS_SAMPLE_EXPANDED: readCountersSample(sample, YES); handleSflowCountersSample(sample); break;
	default:
	  skipTLVRecord(sample, sample->sampleType, getData32(sample), "sample"); break;
	}
      }
      else {
	switch(sample->sampleType) {
	case FLOWSAMPLE: rc = readFlowSample_v2v4(sample); break;
	case COUNTERSSAMPLE: readCountersSample_v2v4(sample); handleSflowCountersSample(sample); break;
	default: receiveError(sample, "unexpected sample type", YES); break;
	}
      }
      sf_log("endSample   ----------------------\n");

      if((sample->sampleType == SFLFLOW_SAMPLE) || (sample->sampleType == SFLFLOW_SAMPLE_EXPANDED)) {

	if(rc == 0)
	  handleSflowSample(iface, sample, deviceId);
	else
	  break;
      }
    }
  }
}

/* ****************************************** */

void dissectSflow(sFlowPktInterface *iface,
		  u_char *buffer, uint buffer_len,
		  struct sockaddr_in *fromHost) {
  SFSample sample;
  
  memset(&sample, 0, sizeof(sample));
  sample.rawSample = buffer;
  sample.rawSampleLen = buffer_len;

  /* Read the IPv4 address from sFlow */
  if(sample.rawSample[3] == 0x5 /* sFlow v5 */)
    sample.sourceIP.s_addr = *((u_int32_t*)&sample.rawSample[8]);
  else {
    if(fromHost != NULL)
      sample.sourceIP = fromHost->sin_addr;
    else
      sample.sourceIP.s_addr = 0;
  }
  
  sample.datap = (u_char *)sample.rawSample;
  sample.endp = (u_char *)sample.rawSample + sample.rawSampleLen;

  readSFlowDatagram(iface, &sample, 0 /* deviceId */);
}

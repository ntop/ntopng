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

#ifndef _PARTIALIZABLE_FLOW_TRAFFIC_STATS_H_
#define _PARTIALIZABLE_FLOW_TRAFFIC_STATS_H_

#include "ntop_includes.h"


class PartializableFlowTrafficStats {
 private:
  ndpi_protocol ndpiDetectedProtocol;
  u_int32_t cli2srv_packets, srv2cli_packets;
  u_int64_t cli2srv_bytes, srv2cli_bytes;
  u_int64_t cli2srv_goodput_bytes, srv2cli_goodput_bytes;
  FlowTCPPacketStats cli2srv_tcp_stats, srv2cli_tcp_stats;
  u_int16_t cli_host_score[MAX_NUM_SCORE_CATEGORIES], srv_host_score[MAX_NUM_SCORE_CATEGORIES];
  bool is_flow_alerted; /* NOTE: only used by view interfaces. Potentially removed in the future after views rework */
  union {
    FlowHTTPStats http;
    FlowDNSStats dns;
  } protos;

 public:
  PartializableFlowTrafficStats();
  PartializableFlowTrafficStats(const PartializableFlowTrafficStats &fts);
  PartializableFlowTrafficStats operator-(const PartializableFlowTrafficStats &fts);
  virtual ~PartializableFlowTrafficStats();

  void setDetectedProtocol(const ndpi_protocol *ndpi_detected_protocol);

  void incTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive);

  void incScore(u_int16_t score, ScoreCategory score_category, bool as_client);
  void setFlowAlerted();

  inline void incHTTPReqPOST()  { protos.http.num_post++;  };
  inline void incHTTPReqPUT()   { protos.http.num_put++;   };
  inline void incHTTPReqGET()   { protos.http.num_get++;   };
  inline void incHTTPReqHEAD()  { protos.http.num_head++;  };
  inline void incHTTPReqOhter() { protos.http.num_other++; };
  inline void incHTTPResp1xx()  { protos.http.num_1xx++;   };
  inline void incHTTPResp2xx()  { protos.http.num_2xx++;   };
  inline void incHTTPResp3xx()  { protos.http.num_3xx++;   };
  inline void incHTTPResp4xx()  { protos.http.num_4xx++;   };
  inline void incHTTPResp5xx()  { protos.http.num_5xx++;   };

  void incDNSQuery(u_int16_t query_type);
  void incDNSResp(u_int16_t resp_code);

  virtual void incStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len);
  virtual void setStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len);

  void get_partial(PartializableFlowTrafficStats *dst, PartializableFlowTrafficStats *fts) const;
  inline const FlowHTTPStats *get_flow_http_stats() const { return &protos.http; };
  inline const FlowDNSStats *get_flow_dns_stats()   const { return &protos.dns;  };

  inline u_int32_t get_cli2srv_packets()       const { return cli2srv_packets;            };
  inline u_int32_t get_srv2cli_packets()       const { return srv2cli_packets;            };
  inline u_int64_t get_cli2srv_bytes()         const { return cli2srv_bytes;              };
  inline u_int64_t get_srv2cli_bytes()         const { return srv2cli_bytes;              };
  inline u_int64_t get_cli2srv_goodput_bytes() const { return cli2srv_goodput_bytes;      };
  inline u_int64_t get_srv2cli_goodput_bytes() const { return srv2cli_goodput_bytes;      };

  inline u_int32_t get_packets()               const { return get_cli2srv_packets() + get_srv2cli_packets(); };
  inline u_int64_t get_bytes()                 const { return get_cli2srv_bytes() + get_srv2cli_bytes();     };

  inline u_int32_t get_cli2srv_tcp_retr()      const { return cli2srv_tcp_stats.pktRetr;      };
  inline u_int32_t get_cli2srv_tcp_ooo()       const { return cli2srv_tcp_stats.pktOOO;       };
  inline u_int32_t get_cli2srv_tcp_lost()      const { return cli2srv_tcp_stats.pktLost;      };
  inline u_int32_t get_cli2srv_tcp_keepalive() const { return cli2srv_tcp_stats.pktKeepAlive; };

  inline u_int32_t get_srv2cli_tcp_retr()      const { return srv2cli_tcp_stats.pktRetr;      };
  inline u_int32_t get_srv2cli_tcp_ooo()       const { return srv2cli_tcp_stats.pktOOO;       };
  inline u_int32_t get_srv2cli_tcp_lost()      const { return srv2cli_tcp_stats.pktLost;      };
  inline u_int32_t get_srv2cli_tcp_keepalive() const { return srv2cli_tcp_stats.pktKeepAlive; };

  u_int16_t get_num_http_requests() const;
  u_int16_t get_num_dns_queries()   const;

  inline const u_int16_t get_cli_score(ScoreCategory score_category) const { return cli_host_score[score_category]; };
  inline const u_int16_t get_srv_score(ScoreCategory score_category) const { return srv_host_score[score_category]; };
  inline const bool      get_is_flow_alerted() const { return is_flow_alerted; };
};

#endif /* _PARTIALIZABLE_FLOW_TRAFFIC_STATS_H_ */

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

#ifndef _FLOW_TRAFFIC_STATS_H_
#define _FLOW_TRAFFIC_STATS_H_

#include "ntop_includes.h"

typedef struct {
  u_int32_t pktRetr, pktOOO, pktLost, pktKeepAlive;
} TCPPacketStats;

class FlowTrafficStats {
 private:
  u_int32_t cli2srv_packets, srv2cli_packets;
  u_int64_t cli2srv_bytes, srv2cli_bytes;
  u_int64_t cli2srv_goodput_bytes, srv2cli_goodput_bytes;
  TCPPacketStats cli2srv_tcp_stats, srv2cli_tcp_stats;
  ndpi_analyze_struct cli2srv_bytes_stats, srv2cli_bytes_stats;

 public:
  FlowTrafficStats();
  FlowTrafficStats(const FlowTrafficStats &fts);
  virtual ~FlowTrafficStats();

  void incTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive);
  void setTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive);
  void incStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len);
  void setStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len);

  const ndpi_analyze_struct* get_analize_struct(bool cli2srv_direction) const;
  void get_partial(FlowTrafficStats **dst, FlowTrafficStats *fts) const;

  inline u_int32_t get_cli2srv_packets()       const { return cli2srv_packets;            };
  inline u_int32_t get_srv2cli_packets()       const { return srv2cli_packets;            };
  inline u_int64_t get_cli2srv_bytes()         const { return cli2srv_bytes;              };
  inline u_int64_t get_srv2cli_bytes()         const { return srv2cli_bytes;              };
  inline u_int64_t get_cli2srv_goodput_bytes() const { return cli2srv_goodput_bytes;      };
  inline u_int64_t get_srv2cli_goodput_bytes() const { return srv2cli_goodput_bytes;      };

  inline u_int32_t get_cli2srv_tcp_retr()      const { return cli2srv_tcp_stats.pktRetr;      };
  inline u_int32_t get_cli2srv_tcp_ooo()       const { return cli2srv_tcp_stats.pktOOO;       };
  inline u_int32_t get_cli2srv_tcp_lost()      const { return cli2srv_tcp_stats.pktLost;      };
  inline u_int32_t get_cli2srv_tcp_keepalive() const { return cli2srv_tcp_stats.pktKeepAlive; };

  inline u_int32_t get_srv2cli_tcp_retr()      const { return srv2cli_tcp_stats.pktRetr;      };
  inline u_int32_t get_srv2cli_tcp_ooo()       const { return srv2cli_tcp_stats.pktOOO;       };
  inline u_int32_t get_srv2cli_tcp_lost()      const { return srv2cli_tcp_stats.pktLost;      };
  inline u_int32_t get_srv2cli_tcp_keepalive() const { return srv2cli_tcp_stats.pktKeepAlive; };
  
};

#endif /* FLOW_TRAFFIC_STATS_H_ */

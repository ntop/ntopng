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

#ifndef _NPROBE_STATS_H_
#define _NPROBE_STATS_H_

#include "ntop_includes.h"

typedef struct {
  u_int64_t collection_port;
  u_int64_t nf_ipfix_flows;
  u_int64_t sflow_samples;
} FlowCollection;

typedef struct {
  time_t time_last_used;
  u_int32_t num_sflow_flows;
  u_int32_t num_netflow_flows;
  u_int32_t num_drops;
  u_int32_t unique_source_id;
} ExporterStats;

class nProbeStats {
 public:
    char remote_ifname[32], remote_ifaddress[64];
    char remote_probe_address[64], remote_probe_public_address[64], uuid[36];
    char remote_probe_version[64], remote_probe_os[64];
    char remote_probe_license[64], remote_probe_edition[64];
    char remote_probe_maintenance[64];
    char mode[64];
    u_int32_t source_id, uuid_num, num_exporters;
    u_int64_t remote_bytes, remote_pkts, num_flow_exports;
    u_int32_t remote_ifspeed, remote_time, local_time, avg_bps, avg_pps;
    u_int32_t remote_lifetime_timeout, remote_idle_timeout,
        remote_collected_lifetime_timeout;
    u_int32_t export_queue_full, too_many_flows, elk_flow_drops,
        sflow_pkt_sample_drops, flow_collection_drops,
        flow_collection_udp_socket_drops;
    FlowCollection flow_collection; 
    
    std::map<u_int32_t, ExporterStats> exportersStats;
 public:
  nProbeStats();
  ~nProbeStats() {};
};

#endif /* _NPROBE_STATS_H_ */

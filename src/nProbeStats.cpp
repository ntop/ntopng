/*
 *
 * (C) 2013-26 - ntop.org
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

#include "ntop_includes.h"

nProbeStats::nProbeStats() {
  nprobe_source_id = num_exporters = remote_ifspeed = remote_time = local_time =
    avg_bps = avg_pps = remote_lifetime_timeout = remote_idle_timeout =
    remote_collected_lifetime_timeout = export_queue_full =
    too_many_flows = elk_flow_drops = sflow_pkt_sample_drops =
    flow_collection_drops = flow_collection_udp_socket_drops = 0;

  remote_collector_port = 0;
  last_update = remote_pkts = remote_pkt_drops = num_flow_exports = remote_active_flows = 0;
  remote_bytes = 0;
  memset(&flow_collection, 0, sizeof(flow_collection));

  system.available = false;
  system.cpu.num_cores = 0;
  system.cpu.load = system.cpu.capture_core_load = system.cpu.export_core_load = 0;
  system.cpu.capture_core = system.cpu.export_core = -1;
  memset(&system.memory, 0, sizeof(system.memory));

  remote_ifname[0] = remote_ifaddress[0] = remote_collector_address[0] =
    nprobe_address[0] =
    nprobe_public_address[0] = uuid[0] = nprobe_version[0] =
    nprobe_os[0] = nprobe_license[0] =
    nprobe_edition[0] = nprobe_maintenance[0] =
    nprobe_instance_name[0] =
    mode[0] = '\0';
}

/* *************************************** */

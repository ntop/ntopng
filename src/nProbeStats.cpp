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

#include "ntop_includes.h"

nProbeStats::nProbeStats() {
   source_id = uuid_num = num_exporters =
      remote_ifspeed = remote_time = local_time = avg_bps = avg_pps =
      remote_lifetime_timeout = remote_idle_timeout =
      remote_collected_lifetime_timeout = export_queue_full = 
      too_many_flows = elk_flow_drops = sflow_pkt_sample_drops =
      flow_collection_drops = flow_collection_udp_socket_drops = 0;
   
   remote_bytes = remote_pkts = num_flow_exports = 0;
}

/* *************************************** */
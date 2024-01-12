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

/* *************************************** */

FlowTrafficStats::FlowTrafficStats() : PartializableFlowTrafficStats() {
  ndpi_init_data_analysis(&cli2srv_bytes_stats, 0),
      ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
}

/* *************************************** */

FlowTrafficStats::FlowTrafficStats(const FlowTrafficStats& fts)
    : PartializableFlowTrafficStats(fts) {
  ndpi_init_data_analysis(&cli2srv_bytes_stats, 0),
      ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
}

/* *************************************** */

FlowTrafficStats::~FlowTrafficStats() {
  ndpi_free_data_analysis(&cli2srv_bytes_stats, 0),
      ndpi_free_data_analysis(&srv2cli_bytes_stats, 0);
}

/* *************************************** */

const ndpi_analyze_struct* FlowTrafficStats::get_analize_struct(
    bool cli2srv_direction) const {
  return cli2srv_direction ? &cli2srv_bytes_stats : &srv2cli_bytes_stats;
}

/* *************************************** */

void FlowTrafficStats::incStats(bool cli2srv_direction, u_int32_t num_pkts,
                                u_int64_t pkts_bytes, u_int64_t payloads_bytes) {
  PartializableFlowTrafficStats::incStats(cli2srv_direction, num_pkts, pkts_bytes,
                                          payloads_bytes);

  if (cli2srv_direction)
    ndpi_data_add_value(&cli2srv_bytes_stats, pkts_bytes);
  else
    ndpi_data_add_value(&srv2cli_bytes_stats, pkts_bytes);
}

/* *************************************** */

void FlowTrafficStats::setStats(bool cli2srv_direction, u_int32_t num_pkts,
                                u_int64_t pkts_bytes, u_int64_t payloads_bytes) {
  PartializableFlowTrafficStats::setStats(cli2srv_direction, num_pkts, pkts_bytes,
                                          payloads_bytes);

  if (cli2srv_direction) {
    ndpi_init_data_analysis(&cli2srv_bytes_stats, 0);
    ndpi_data_add_value(&cli2srv_bytes_stats, pkts_bytes);
  } else {
    ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
    ndpi_data_add_value(&srv2cli_bytes_stats, pkts_bytes);
  }
}

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

#include "ntop_includes.h"

/* *************************************** */

FlowTrafficStats::FlowTrafficStats() : PartializableFlowTrafficStats() {
  ndpi_init_data_analysis(&cli2srv_bytes_stats, 0),
    ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
}

/* *************************************** */

FlowTrafficStats::FlowTrafficStats(const FlowTrafficStats &fts) : PartializableFlowTrafficStats(fts) {
  ndpi_init_data_analysis(&cli2srv_bytes_stats, 0),
    ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
}

/* *************************************** */

FlowTrafficStats::~FlowTrafficStats() {
}

/* *************************************** */

const ndpi_analyze_struct* FlowTrafficStats::get_analize_struct(bool cli2srv_direction) const {
  return cli2srv_direction ? &cli2srv_bytes_stats : &srv2cli_bytes_stats;
}

/* *************************************** */

void FlowTrafficStats::incStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len) {
  PartializableFlowTrafficStats::incStats(cli2srv_direction, num_pkts, pkt_len, payload_len);

  if(cli2srv_direction)
    ndpi_data_add_value(&cli2srv_bytes_stats, pkt_len);
  else
    ndpi_data_add_value(&srv2cli_bytes_stats, pkt_len);
}

/* *************************************** */

void FlowTrafficStats::setStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len) {
  PartializableFlowTrafficStats::setStats(cli2srv_direction, num_pkts, pkt_len, payload_len);

  if(cli2srv_direction) {
    ndpi_init_data_analysis(&cli2srv_bytes_stats, 0);
    ndpi_data_add_value(&cli2srv_bytes_stats, pkt_len);
  } else {
    ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
    ndpi_data_add_value(&srv2cli_bytes_stats, pkt_len);
  }
}

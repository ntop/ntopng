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

#include "flow_alerts_includes.h"

ndpi_serializer* TCPIssuesAlert::getAlertJSON(ndpi_serializer* serializer) {
  Flow *f = getFlow();

  if (serializer) {
    FlowTrafficStats *stats = f->getTrafficStats();
    /*
    const ndpi_analyze_struct *cli2srv_bytes_stats, *srv2cli_bytes_stats;
    cli2srv_bytes_stats = stats->get_analize_struct(true), srv2cli_bytes_stats = stats->get_analize_struct(false);
    */

    ndpi_serialize_start_of_block(serializer,   "tcp_stats");
    ndpi_serialize_string_int64(serializer, "cli2srv.retransmissions", stats->get_cli2srv_tcp_retr());
    ndpi_serialize_string_int64(serializer, "cli2srv.out_of_order",    stats->get_cli2srv_tcp_ooo());
    ndpi_serialize_string_int64(serializer, "cli2srv.lost",            stats->get_cli2srv_tcp_lost());
    ndpi_serialize_string_int64(serializer, "srv2cli.retransmissions", stats->get_srv2cli_tcp_retr());
    ndpi_serialize_string_int64(serializer, "srv2cli.out_of_order",    stats->get_srv2cli_tcp_ooo());
    ndpi_serialize_string_int64(serializer, "srv2cli.lost",            stats->get_srv2cli_tcp_lost());
    ndpi_serialize_end_of_block(serializer);
  
    ndpi_serialize_string_int32(serializer,   "cli2srv_pkts",  f->get_packets_cli2srv());
    ndpi_serialize_string_int32(serializer,   "srv2cli_pkts",  f->get_packets_srv2cli());
    ndpi_serialize_string_boolean(serializer, "is_severe",     is_severe);
    ndpi_serialize_string_boolean(serializer, "client_issues", is_client);
    ndpi_serialize_string_boolean(serializer, "server_issues", is_server);
  }

  return serializer;
}


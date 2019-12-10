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

#include "ntop_includes.h"

/* *************************************** */

FlowTrafficStats::FlowTrafficStats() {
  cli2srv_packets = srv2cli_packets = 0;
  cli2srv_bytes = srv2cli_bytes = 0;
  cli2srv_goodput_bytes = srv2cli_goodput_bytes = 0;

  memset(&tcp_stats_s2d, 0, sizeof(tcp_stats_s2d));
  memset(&tcp_stats_d2s, 0, sizeof(tcp_stats_d2s));

  ndpi_init_data_analysis(&cli2srv_bytes_stats, 0),
    ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
}

/* *************************************** */

FlowTrafficStats::FlowTrafficStats(const FlowTrafficStats &fts) {
  cli2srv_packets = fts.cli2srv_packets;
  srv2cli_packets = fts.srv2cli_packets;
  cli2srv_bytes = fts.cli2srv_bytes;
  srv2cli_bytes = fts.srv2cli_bytes;
  cli2srv_goodput_bytes = fts.cli2srv_goodput_bytes;
  srv2cli_goodput_bytes = fts.srv2cli_goodput_bytes;

  memcpy(&tcp_stats_s2d, &fts.tcp_stats_s2d, sizeof(tcp_stats_s2d));
  memcpy(&tcp_stats_d2s, &fts.tcp_stats_d2s, sizeof(tcp_stats_d2s));

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

void FlowTrafficStats::incTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive) {
  TCPPacketStats * cur_stats;

  if(cli2srv_direction)
    cur_stats = &tcp_stats_s2d;
  else
    cur_stats = &tcp_stats_d2s;

  cur_stats->pktKeepAlive += keepalive;
  cur_stats->pktRetr += retr;
  cur_stats->pktOOO += ooo;
  cur_stats->pktLost += lost;
}


/* *************************************** */

void FlowTrafficStats::setTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive) {
  TCPPacketStats * cur_stats;

  if(cli2srv_direction)
    cur_stats = &tcp_stats_s2d;
  else
    cur_stats = &tcp_stats_d2s;

  cur_stats->pktKeepAlive = keepalive;
  cur_stats->pktRetr = retr;
  cur_stats->pktOOO = ooo;
  cur_stats->pktLost = lost;
}

/* *************************************** */

void FlowTrafficStats::incStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len) {
  if(cli2srv_direction) {
    cli2srv_packets += num_pkts, cli2srv_bytes += pkt_len, cli2srv_goodput_bytes += payload_len;
    ndpi_data_add_value(&cli2srv_bytes_stats, pkt_len);
  } else {
    srv2cli_packets += num_pkts, srv2cli_bytes += pkt_len, srv2cli_goodput_bytes += payload_len;
    ndpi_data_add_value(&srv2cli_bytes_stats, pkt_len);
  }
}

/* *************************************** */

void FlowTrafficStats::setStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len) {
  if(cli2srv_direction) {
    cli2srv_packets = num_pkts, cli2srv_bytes = pkt_len, cli2srv_goodput_bytes = payload_len;
    ndpi_init_data_analysis(&cli2srv_bytes_stats, 0);
    ndpi_data_add_value(&cli2srv_bytes_stats, pkt_len);
  } else {
    srv2cli_packets = num_pkts, srv2cli_bytes = pkt_len, srv2cli_goodput_bytes = payload_len;
    ndpi_init_data_analysis(&srv2cli_bytes_stats, 0);
    ndpi_data_add_value(&srv2cli_bytes_stats, pkt_len);
  }
}

/* *************************************** */

void FlowTrafficStats::get_partial(FlowTrafficStats **dst, FlowTrafficStats *fts) const {
  FlowTrafficStats tmp(*this); /* Set temp to the current value */

  fts->setStats(true,
		tmp.get_cli2srv_packets() - (*dst)->get_cli2srv_packets(),
		tmp.get_cli2srv_bytes() - (*dst)->get_cli2srv_bytes(),
		tmp.get_cli2srv_goodput_bytes() - (*dst)->get_cli2srv_goodput_bytes());

  fts->setStats(false,
		tmp.get_srv2cli_packets() - (*dst)->get_srv2cli_packets(),
		tmp.get_srv2cli_bytes() - (*dst)->get_srv2cli_bytes(),
		tmp.get_srv2cli_goodput_bytes() - (*dst)->get_srv2cli_goodput_bytes());

  fts->setTcpStats(true,
		   tmp.get_cli2srv_tcp_retr() - (*dst)->get_cli2srv_tcp_retr(),
		   tmp.get_cli2srv_tcp_ooo() - (*dst)->get_cli2srv_tcp_ooo(),
		   tmp.get_cli2srv_tcp_lost() - (*dst)->get_cli2srv_tcp_lost(),
		   tmp.get_cli2srv_tcp_keepalive() - (*dst)->get_cli2srv_tcp_keepalive());

  fts->setTcpStats(false,
		   tmp.get_srv2cli_tcp_retr() - (*dst)->get_srv2cli_tcp_retr(),
		   tmp.get_srv2cli_tcp_ooo() - (*dst)->get_srv2cli_tcp_ooo(),
		   tmp.get_srv2cli_tcp_lost() - (*dst)->get_srv2cli_tcp_lost(),
		   tmp.get_srv2cli_tcp_keepalive() - (*dst)->get_srv2cli_tcp_keepalive());

  **dst = tmp; /* Use the copy constructor to snapshot the value of tmp to dst */
}

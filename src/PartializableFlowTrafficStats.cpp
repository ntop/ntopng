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

PartializableFlowTrafficStats::PartializableFlowTrafficStats() {
  cli2srv_packets = srv2cli_packets = 0;
  cli2srv_bytes = srv2cli_bytes = 0;
  cli2srv_goodput_bytes = srv2cli_goodput_bytes = 0;

  memset(&cli2srv_tcp_stats, 0, sizeof(cli2srv_tcp_stats));
  memset(&srv2cli_tcp_stats, 0, sizeof(srv2cli_tcp_stats));
}

/* *************************************** */

PartializableFlowTrafficStats::PartializableFlowTrafficStats(const PartializableFlowTrafficStats &fts) {
  cli2srv_packets = fts.cli2srv_packets;
  srv2cli_packets = fts.srv2cli_packets;
  cli2srv_bytes = fts.cli2srv_bytes;
  srv2cli_bytes = fts.srv2cli_bytes;
  cli2srv_goodput_bytes = fts.cli2srv_goodput_bytes;
  srv2cli_goodput_bytes = fts.srv2cli_goodput_bytes;

  memcpy(&cli2srv_tcp_stats, &fts.cli2srv_tcp_stats, sizeof(cli2srv_tcp_stats));
  memcpy(&srv2cli_tcp_stats, &fts.srv2cli_tcp_stats, sizeof(srv2cli_tcp_stats));
}

/* *************************************** */

PartializableFlowTrafficStats::~PartializableFlowTrafficStats() {
}

/* *************************************** */

void PartializableFlowTrafficStats::incTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive) {
  TCPPacketStats * cur_stats;

  if(cli2srv_direction)
    cur_stats = &cli2srv_tcp_stats;
  else
    cur_stats = &srv2cli_tcp_stats;

  cur_stats->pktKeepAlive += keepalive;
  cur_stats->pktRetr += retr;
  cur_stats->pktOOO += ooo;
  cur_stats->pktLost += lost;
}


/* *************************************** */

void PartializableFlowTrafficStats::setTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive) {
  TCPPacketStats * cur_stats;

  if(cli2srv_direction)
    cur_stats = &cli2srv_tcp_stats;
  else
    cur_stats = &srv2cli_tcp_stats;

  cur_stats->pktKeepAlive = keepalive;
  cur_stats->pktRetr = retr;
  cur_stats->pktOOO = ooo;
  cur_stats->pktLost = lost;
}

/* *************************************** */

void PartializableFlowTrafficStats::incStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len) {
  if(cli2srv_direction)
    cli2srv_packets += num_pkts, cli2srv_bytes += pkt_len, cli2srv_goodput_bytes += payload_len;
  else
    srv2cli_packets += num_pkts, srv2cli_bytes += pkt_len, srv2cli_goodput_bytes += payload_len;
}

/* *************************************** */

void PartializableFlowTrafficStats::setStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len) {
  if(cli2srv_direction)
    cli2srv_packets = num_pkts, cli2srv_bytes = pkt_len, cli2srv_goodput_bytes = payload_len;
  else
    srv2cli_packets = num_pkts, srv2cli_bytes = pkt_len, srv2cli_goodput_bytes = payload_len;
}

/* *************************************** */

void PartializableFlowTrafficStats::get_partial(PartializableFlowTrafficStats **dst, PartializableFlowTrafficStats *fts) const {
  /* Set temp to the current value */
  PartializableFlowTrafficStats tmp(*this); 

  /* Compute the differences between the snapshot tmp and the values found in dst, and put them in the argument fts */
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

  /* Finally, update dst with the values snapshotted in tmp.
     Use the copy constructor to snapshot the value of tmp to dst
  */
  **dst = tmp;
}

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

PartializableFlowTrafficStats::PartializableFlowTrafficStats() {
  ndpiDetectedProtocol = Flow::ndpiUnknownProtocol;
  cli2srv_packets = srv2cli_packets = 0;
  cli2srv_bytes = srv2cli_bytes = 0;
  cli2srv_goodput_bytes = srv2cli_goodput_bytes = 0;

  memset(&cli2srv_tcp_stats, 0, sizeof(cli2srv_tcp_stats));
  memset(&srv2cli_tcp_stats, 0, sizeof(srv2cli_tcp_stats));

  memset(&cli_host_score, 0, sizeof(cli_host_score));
  memset(&srv_host_score, 0, sizeof(srv_host_score));

  is_flow_alerted = false;

  memset(&protos, 0, sizeof(protos));
}

/* *************************************** */

PartializableFlowTrafficStats::PartializableFlowTrafficStats(const PartializableFlowTrafficStats &fts) {
  memcpy(&ndpiDetectedProtocol, &fts.ndpiDetectedProtocol, sizeof(ndpiDetectedProtocol));
  cli2srv_packets = fts.cli2srv_packets;
  srv2cli_packets = fts.srv2cli_packets;
  cli2srv_bytes = fts.cli2srv_bytes;
  srv2cli_bytes = fts.srv2cli_bytes;
  cli2srv_goodput_bytes = fts.cli2srv_goodput_bytes;
  srv2cli_goodput_bytes = fts.srv2cli_goodput_bytes;

  memcpy(&cli2srv_tcp_stats, &fts.cli2srv_tcp_stats, sizeof(cli2srv_tcp_stats));
  memcpy(&srv2cli_tcp_stats, &fts.srv2cli_tcp_stats, sizeof(srv2cli_tcp_stats));

  memcpy(&cli_host_score, &fts.cli_host_score, sizeof(cli_host_score));
  memcpy(&srv_host_score, &fts.srv_host_score, sizeof(srv_host_score));

  is_flow_alerted = fts.is_flow_alerted;

  memcpy(&protos, &fts.protos, sizeof(protos));
}
/* *************************************** */

PartializableFlowTrafficStats PartializableFlowTrafficStats::operator-(const PartializableFlowTrafficStats &fts) {
  PartializableFlowTrafficStats cur(*this);
  static bool warn_once = true;

  /* Check flow counters (Debug) */
  if ((fts.cli2srv_bytes > cur.cli2srv_bytes || 
       fts.srv2cli_bytes > cur.srv2cli_bytes) &&
      warn_once) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Flow stats went backwards [c2s %ju -> %ju][s2c %ju -> %ju]",
      fts.cli2srv_bytes, cur.cli2srv_bytes, fts.srv2cli_bytes, cur.srv2cli_bytes);
    warn_once = false;
  }

  cur.cli2srv_bytes -= fts.cli2srv_bytes;
  cur.srv2cli_bytes -= fts.srv2cli_bytes;

  cur.cli2srv_packets -= fts.cli2srv_packets;
  cur.cli2srv_goodput_bytes -= fts.cli2srv_goodput_bytes;
  cur.srv2cli_packets -= fts.srv2cli_packets;
  cur.srv2cli_goodput_bytes -= fts.srv2cli_goodput_bytes;

  cur.cli2srv_tcp_stats.pktRetr -= fts.cli2srv_tcp_stats.pktRetr;
  cur.cli2srv_tcp_stats.pktOOO -= fts.cli2srv_tcp_stats.pktOOO;
  cur.cli2srv_tcp_stats.pktLost -= fts.cli2srv_tcp_stats.pktLost;
  cur.cli2srv_tcp_stats.pktKeepAlive -= fts.cli2srv_tcp_stats.pktKeepAlive;
  cur.srv2cli_tcp_stats.pktRetr -= fts.srv2cli_tcp_stats.pktRetr;
  cur.srv2cli_tcp_stats.pktOOO -= fts.srv2cli_tcp_stats.pktOOO;
  cur.srv2cli_tcp_stats.pktLost -= fts.srv2cli_tcp_stats.pktLost;
  cur.srv2cli_tcp_stats.pktKeepAlive -= fts.srv2cli_tcp_stats.pktKeepAlive;

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++)
    cur.cli_host_score[i] -= fts.cli_host_score[i],
      cur.srv_host_score[i] -= fts.srv_host_score[i];

  /*
    Even though is_flow_alerted is a boolean, we can still use operator -= to keep it consistent with other fields.
    Compilers know how to handle the boolean as 0, 1. 
   */
  cur.is_flow_alerted -= fts.is_flow_alerted;

  switch(ndpi_get_lower_proto(ndpiDetectedProtocol)) {
  case NDPI_PROTOCOL_HTTP:
    cur.protos.http.num_get   -= fts.protos.http.num_get;
    cur.protos.http.num_post  -= fts.protos.http.num_post;
    cur.protos.http.num_put   -= fts.protos.http.num_put;
    cur.protos.http.num_other -= fts.protos.http.num_other;
    cur.protos.http.num_1xx   -= fts.protos.http.num_1xx;
    cur.protos.http.num_2xx   -= fts.protos.http.num_2xx;
    cur.protos.http.num_3xx   -= fts.protos.http.num_3xx;
    cur.protos.http.num_4xx   -= fts.protos.http.num_4xx;
    cur.protos.http.num_5xx   -= fts.protos.http.num_5xx;
    break;
  case NDPI_PROTOCOL_DNS:
    cur.protos.dns.num_a     -= fts.protos.dns.num_a;
    cur.protos.dns.num_ns    -= fts.protos.dns.num_ns;
    cur.protos.dns.num_cname -= fts.protos.dns.num_cname;
    cur.protos.dns.num_soa   -= fts.protos.dns.num_soa;
    cur.protos.dns.num_ptr   -= fts.protos.dns.num_ptr;
    cur.protos.dns.num_mx    -= fts.protos.dns.num_mx;
    cur.protos.dns.num_txt   -= fts.protos.dns.num_txt;
    cur.protos.dns.num_aaaa  -= fts.protos.dns.num_aaaa;
    cur.protos.dns.num_any   -= fts.protos.dns.num_any;
    cur.protos.dns.num_other -= fts.protos.dns.num_other;
    cur.protos.dns.num_replies_ok    -= fts.protos.dns.num_replies_ok;
    cur.protos.dns.num_replies_error -= fts.protos.dns.num_replies_error;
    break;
  default:
    break;
  }

  return cur;
}

/* *************************************** */

PartializableFlowTrafficStats::~PartializableFlowTrafficStats() {
}

/* *************************************** */

void PartializableFlowTrafficStats::setDetectedProtocol(const ndpi_protocol *ndpi_detected_protocol) {
  memcpy(&ndpiDetectedProtocol, ndpi_detected_protocol, sizeof(ndpiDetectedProtocol));
}

/* *************************************** */

void PartializableFlowTrafficStats::incTcpStats(bool cli2srv_direction, u_int retr, u_int ooo, u_int lost, u_int keepalive) {
  FlowTCPPacketStats * cur_stats;

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

void PartializableFlowTrafficStats::incScore(u_int16_t score, ScoreCategory score_category, bool as_client) {
  u_int16_t *dst = as_client ? cli_host_score : srv_host_score;

  dst[score_category] += min_val(score, SCORE_MAX_VALUE);
}

/* *************************************** */

void PartializableFlowTrafficStats::setFlowAlerted() {
  is_flow_alerted = true;
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

void PartializableFlowTrafficStats::incDNSQuery(u_int16_t query_type) {
  switch(query_type) {
  case 0:
    /* Zero means we have not been able to decode the DNS message */
    break;
  case 1:
    /* A */
    protos.dns.num_a++;
    break;
  case 2:
    /* NS */
    protos.dns.num_ns++;
    break;
  case 5: 
    /* CNAME */ 
    protos.dns.num_cname++;
    break;
  case 6:
    /* SOA */ 
    protos.dns.num_soa++;
    break;
  case 12:
    /* PTR */ 
    protos.dns.num_ptr++;
    break;
  case 15:
    /* MX */
    protos.dns.num_mx++;
    break;
  case 16:
    /* TXT */
    protos.dns.num_txt++;
    break;
  case 28:
    /* AAAA */
    protos.dns.num_aaaa++;
    break;
  case 255:
    /* ANY */ 
    protos.dns.num_any++;
    break;
  default:
    protos.dns.num_other++;
    break;
  }
}

/* *************************************** */

void PartializableFlowTrafficStats::incDNSResp(u_int16_t resp_code) {
  switch(resp_code) {
  case 0:
    protos.dns.num_replies_ok++;
    break;
  default:
    protos.dns.num_replies_error++;
  }
}

/* *************************************** */

void PartializableFlowTrafficStats::get_partial(PartializableFlowTrafficStats *dst, PartializableFlowTrafficStats *fts) const {
  /* Set temp to the current value */
  PartializableFlowTrafficStats tmp(*this); 

  /* Compute the differences between the snapshot tmp and the values found in dst, and put them in the argument fts */
  *fts = tmp - *dst;

  /* Finally, update dst with the values snapshotted in tmp.
     Use the copy constructor to snapshot the value of tmp to dst
  */
  *dst = tmp;
}

/* *************************************** */

u_int16_t PartializableFlowTrafficStats::get_num_http_requests() const {
  return protos.http.num_get + protos.http.num_post + protos.http.num_head + protos.http.num_put + protos.http.num_other;
}

/* *************************************** */

u_int16_t PartializableFlowTrafficStats::get_num_dns_queries() const {
  return protos.dns.num_a + protos.dns.num_ns + protos.dns.num_cname + protos.dns.num_soa + protos.dns.num_ptr + protos.dns.num_mx + protos.dns.num_txt + protos.dns.num_aaaa + protos.dns.num_any + protos.dns.num_other;
}

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
#include "flow_checks_includes.h"

/* ***************************************************** */

void TCPPacketsIssues::checkTCPPacketsIssues(Flow *f) {
  FlowAlertType alert_type = TCPPacketsIssuesAlert::getClassType();
  u_int8_t c_score, s_score;
  risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;
  FlowTrafficStats* stats = f->getTrafficStats();
  u_int64_t retransmission = stats ? (stats->get_cli2srv_tcp_retr() + stats->get_srv2cli_tcp_retr()) : 0, 
            out_of_order = stats ? (stats->get_cli2srv_tcp_ooo() + stats->get_srv2cli_tcp_ooo()) : 0, 
            lost = stats ? (stats->get_cli2srv_tcp_lost() + stats->get_srv2cli_tcp_lost()) : 0;
  
  u_int8_t retransmission_pctg = (u_int8_t) retransmission * 100 / f->get_packets();
  u_int8_t out_of_order_pctg = (u_int8_t) out_of_order * 100 / f->get_packets();
  u_int8_t lost_pctg = (u_int8_t) lost * 100 / f->get_packets();
  
  if(retransmission_pctg <= retransmission_threshold
     && out_of_order_pctg <= out_of_order_threshold
     && lost_pctg <= lost_threshold)
    return; /* Thresholds not exceeded */

#ifdef DEBUG_PACKETS_ISSUES
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Retransmissions: %u | %u % | Threshold: %u %", retransmission, retransmission_pctg, retransmission_threshold);
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Out of Order: %u | %u % | Threshold: %u %", out_of_order, out_of_order_pctg, out_of_order_threshold);
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loss: %u | %u % | Threshold: %u %", lost, lost_pctg, lost_threshold);
#endif /* DEBUG_PACKETS_ISSUES */

  computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

  f->triggerAlertAsync(alert_type, c_score, s_score);
}

/* ***************************************************** */

void TCPPacketsIssues::periodicUpdate(Flow *f) {
  checkTCPPacketsIssues(f);
}

/* ***************************************************** */

void TCPPacketsIssues::flowEnd(Flow *f) {
  checkTCPPacketsIssues(f);
}

/* ***************************************************** */

FlowAlert *TCPPacketsIssues::buildAlert(Flow *f) {
  return new TCPPacketsIssuesAlert(this, f, retransmission_threshold, out_of_order_threshold, lost_threshold);
}

/* ***************************************************** */

bool TCPPacketsIssues::loadConfiguration(json_object *config) {
  bool enabled = false;
  json_object *json_table, *json_bytes;

  FlowCheck::loadConfiguration(config); /* Parse parameters in common */

  /* Retransmission threshold */
  if(json_object_object_get_ex(config, "retransmissions", &json_table)) {
    if(json_object_object_get_ex(json_table, "threshold", &json_bytes))
      retransmission_threshold = json_object_get_int64(json_bytes);
    if(json_object_object_get_ex(json_table, "enabled", &json_bytes))
      enabled = json_object_get_int64(json_bytes);

    if(!enabled) retransmission_threshold = (u_int64_t) -1;
  }

  /* Out of Order threshold */
  if(json_object_object_get_ex(config, "out_of_orders", &json_table)) {
    if(json_object_object_get_ex(json_table, "threshold", &json_bytes))
      out_of_order_threshold = json_object_get_int64(json_bytes);
    if(json_object_object_get_ex(json_table, "enabled", &json_bytes))
      enabled = json_object_get_int64(json_bytes);

    if(!enabled) out_of_order_threshold = (u_int64_t) -1;
  }

  /* Lost threshold */
  if(json_object_object_get_ex(config, "packet_loss", &json_table)) {
    if(json_object_object_get_ex(json_table, "threshold", &json_bytes))
      lost_threshold = json_object_get_int64(json_bytes);
    if(json_object_object_get_ex(json_table, "enabled", &json_bytes))
      enabled = json_object_get_int64(json_bytes);

    if(!enabled) lost_threshold = (u_int64_t) -1;
  }
    
  return(true);
}

/* ***************************************************** */

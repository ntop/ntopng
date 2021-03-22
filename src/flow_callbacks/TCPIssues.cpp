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
#include "flow_callbacks_includes.h"

static const u_int16_t min_pkt_threshold   = 10;
static const u_int16_t normal_issues_ratio = 10; // 1/10
static const u_int16_t severe_issues_ratio = 3;  // 1/3

/* ******************************************** */

bool TCPIssues::checkClientTCPIssues(Flow *f, bool *is_severe) {
  u_int64_t pkts = f->get_packets_cli2srv();

  if(f->getCliTcpIssues() < min_pkt_threshold)
    return false;
  
  if((f->getCliTcpIssues() * severe_issues_ratio) > pkts) {
    *is_severe = true;
    return true;
  } else if((f->getCliTcpIssues() * normal_issues_ratio) > pkts)
    return true;
  else 
    return false;
}

/* ******************************************** */

bool TCPIssues::checkServerTCPIssues(Flow *f, bool *is_severe) {
  u_int64_t pkts = f->get_packets_srv2cli();
	
  if(f->getSrvTcpIssues() < min_pkt_threshold) 
    return false;  
  
  if((f->getSrvTcpIssues() * severe_issues_ratio) > pkts) {
    *is_severe = true;
    return true;
  } else if((f->getSrvTcpIssues() * normal_issues_ratio) > pkts)
    return true;
  else
    return false;
}

/* ******************************************** */

void TCPIssues::checkFlow(Flow *f) {
  u_int16_t c_score = 0, s_score = 0;
  bool is_severe, has_issues = false;

  if(f->get_protocol() != IPPROTO_TCP)
    return; /* Non TCP traffic */

  is_severe = false;
  if (checkClientTCPIssues(f, &is_severe)) {
    if (is_severe) c_score = 20;
    else c_score = 10;
    has_issues = true;
  }

  is_severe = false;
  if (checkServerTCPIssues(f, &is_severe)) {
    if (is_severe) s_score = 20;
    else s_score = 10;
    has_issues = true;
  }

  if(has_issues)
    f->triggerAlertAsync(TCPIssuesAlert::getClassType(), c_score, s_score);
}

/* ******************************************** */

void TCPIssues::periodicUpdate(Flow *f) {
  checkFlow(f);
}

/* ******************************************** */

void TCPIssues::flowEnd(Flow *f) {
  checkFlow(f);
}

/* ******************************************** */

FlowAlert *TCPIssues::buildAlert(Flow *f) {
  bool is_client, is_server, is_severe = false;

  is_client = checkClientTCPIssues(f, &is_severe);
  is_server = checkServerTCPIssues(f, &is_severe);

  return new TCPIssuesAlert(this, f, getSeverity(), is_client, is_server, is_severe);
}

/* ***************************************************** */

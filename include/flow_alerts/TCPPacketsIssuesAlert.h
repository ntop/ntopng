/*
 *
 * (C) 2013-22 - ntop.org
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

#ifndef _TCP_PACKETS_ISSUES_ALERT_H_
#define _TCP_PACKETS_ISSUES_ALERT_H_

#include "ntop_includes.h"

class TCPPacketsIssuesAlert : public FlowAlert {
 private:
  u_int64_t retransmission, out_of_order, lost;

  ndpi_serializer *getAlertJSON(ndpi_serializer* serializer);

 public:
  static FlowAlertType getClassType() { return { flow_alert_tcp_packets_issues, alert_category_security }; }
  static u_int8_t      getDefaultScore() { return SCORE_LEVEL_ERROR; };

 TCPPacketsIssuesAlert(FlowCheck *c, Flow *f, u_int64_t _retransmission, u_int64_t _out_of_order, u_int64_t _lost) : FlowAlert(c, f) { 
    retransmission = _retransmission;
    out_of_order = _out_of_order;
    lost = _lost;
  };
  ~TCPPacketsIssuesAlert() { };

  FlowAlertType getAlertType() const { return getClassType(); }
};

#endif /* _TCP_PACKETS_ISSUES_ALERT_H_ */

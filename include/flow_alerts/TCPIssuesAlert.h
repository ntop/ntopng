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

#ifndef _TCP_ISSUES_ALERT_H_
#define _TCP_ISSUES_ALERT_H_

#include "ntop_includes.h"

class TCPIssuesAlert : public FlowAlert {
 private:
  bool is_client, is_server, is_severe;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  static FlowAlertType getClassType() { return { flow_alert_tcp_connection_issues, alert_category_network }; }

 TCPIssuesAlert(FlowCallback *c, Flow *f, bool _is_client, bool _is_server, bool _is_severe) : FlowAlert(c, f) {
    is_client = _is_client;
    is_server = _is_server;
    is_severe = _is_severe;
  };
  ~TCPIssuesAlert() {};

  FlowAlertType getAlertType() const { return getClassType(); }
  std::string getName() const { return std::string("tcp_issues_generic"); }
};

#endif /* _TCP_ISSUES_ALERT_H_ */

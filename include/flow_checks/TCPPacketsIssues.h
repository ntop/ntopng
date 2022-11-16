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

#ifndef _TCP_PACKETS_ISSUES_FLOW_H_
#define _TCP_PACKETS_ISSUES_FLOW_H_

#include "ntop_includes.h"

class TCPPacketsIssues : public FlowCheck {
 private:
  u_int64_t retransmission_threshold, out_of_order_threshold, lost_threshold;
  void checkTCPPacketsIssues(Flow *f);

 public:
 TCPPacketsIssues() : FlowCheck(ntopng_edition_pro,
			       false /* All interfaces */, false /* Don't exclude for nEdge */, false /* NOT only for nEdge */,
			       false /* has_protocol_detected */, true /* has_periodic_update */, true /* has_flow_end */) {
    retransmission_threshold = out_of_order_threshold = lost_threshold = (u_int64_t)-1 /* No threshold */;
  };
  ~TCPPacketsIssues() {};

  void periodicUpdate(Flow *f);
  void flowEnd(Flow *f);

  bool loadConfiguration(json_object *config);
  FlowAlert *buildAlert(Flow *f);

  std::string getName()        const { return(std::string("tcp_packets_issues"));  }
};

#endif /* _TCP_PACKETS_ISSUES_FLOW_H_ */

/*
 *
 * (C) 2013-24 - ntop.org
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

#ifndef _UNEXPECTED_DHCP_SERVER_H_
#define _UNEXPECTED_DHCP_SERVER_H_

#include "ntop_includes.h"

class UnexpectedDHCPServer : public UnexpectedServer {
 private:
  FlowAlertType getAlertType() const {
    return UnexpectedDHCPServerAlert::getClassType();
  }

 protected:
  bool isAllowedHost(Flow* f);
  bool isAllowedProto(Flow* f) {
    const IpAddress* server = f->get_dhcp_srv_ip_addr();

    /* Flows whose DHCP server is known (e.g. not a request to broadcast or
     * multicast) */
    return ((f->isDHCP() || f->isDHCPv6()) && server &&
            server->isNonEmptyUnicastAddress());
  }
  const IpAddress* getServerIP(Flow* f) { return (f->get_dhcp_srv_ip_addr()); }
  /* Whether the DHCP server of the flow has sent at least a packet (a reply) */
  bool serverReplied(Flow* f) {
    return (f->isDHCPServerClient() ? (f->get_packets_cli2srv() > 0)
                                    : (f->get_packets_srv2cli() > 0));
  }

 public:
  UnexpectedDHCPServer() : UnexpectedServer(true /* has_flow_end */) {};
  ~UnexpectedDHCPServer() {};

  /* A host is an unexpected DHCP server only when it replies: the flows are
   * checked as soon as the protocol is detected, if the server has already
   * replied (e.g. the reply is the first packet), and again when they end,
   * for the replies that follow a request (e.g. a renew). A flow alerted
   * twice keeps the first alert only (see Flow::triggerAlert()). */
  void protocolDetected(Flow* f) {
    if (serverReplied(f)) UnexpectedServer::protocolDetected(f);
  }
  void flowEnd(Flow* f) {
    if (serverReplied(f)) UnexpectedServer::protocolDetected(f);
  }

  FlowAlert* buildAlert(Flow* f) {
    UnexpectedDHCPServerAlert* alert = new UnexpectedDHCPServerAlert(this, f);

    /* The DHCP server is the one to blame, client or server of the flow */
    if (f->isDHCPServerClient())
      alert->setCliAttacker();
    else
      alert->setSrvAttacker();

    return alert;
  }

  std::string getName() const { return (std::string("unexpected_dhcp")); }
};

#endif /* _UNEXPECTED_DHCP_SERVER_H_ */

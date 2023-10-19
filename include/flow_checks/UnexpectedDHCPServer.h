/*
 *
 * (C) 2013-23 - ntop.org
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
  bool isAllowedProto(Flow *f) {
    return (f->isDHCP() && (f->get_srv_port() == 67 /* Server port */));
  }
  const IpAddress *getServerIP(Flow *f) { return (f->get_dhcp_srv_ip_addr()); }

 public:
  UnexpectedDHCPServer() : UnexpectedServer(){};
  ~UnexpectedDHCPServer(){};

  FlowAlert *buildAlert(Flow *f) {
    UnexpectedDHCPServerAlert *alert = new UnexpectedDHCPServerAlert(this, f);
    alert->setCliAttacker();
    return alert;
  }

  std::string getName() const { return (std::string("unexpected_dhcp")); }
};

#endif /* _UNEXPECTED_DHCP_SERVER_H_ */

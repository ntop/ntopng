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

#ifndef _UNEXPECTED_SERVER_CONNECTION_H_
#define _UNEXPECTED_SERVER_CONNECTION_H_

#include "ntop_includes.h"

class UnexpectedServerConnection : public UnexpectedServer {
 private:
  FlowAlertType getAlertType() const {
    return UnexpectedServerConnectionAlert::getClassType();
  }

 protected:
  bool isAllowedHost(Flow *f);
  bool isAllowedProto(Flow *f) { return (true); }

 public:
  UnexpectedServerConnection() : UnexpectedServer(){};
  ~UnexpectedServerConnection(){};

  FlowAlert *buildAlert(Flow *f) {
    UnexpectedServerConnectionAlert *alert = new UnexpectedServerConnectionAlert(this, f);
    alert->setCliAttacker();
    return alert;
  }

  std::string getName() const { return (std::string("unexpected_server_connection")); }
};

#endif /* _UNEXPECTED_SERVER_CONNECTION_H_ */

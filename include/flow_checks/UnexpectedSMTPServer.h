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

#ifndef _UNEXPECTED_SMTP_SERVER_H_
#define _UNEXPECTED_SMTP_SERVER_H_

#include "ntop_includes.h"

class UnexpectedSMTPServer : public UnexpectedServer {
private:
  FlowAlertType getAlertType() const { return UnexpectedSMTPServerAlert::getClassType(); }

protected:
  bool isAllowedProto(Flow *f)       { return(f->isSMTP());                  }
  
 public:
  UnexpectedSMTPServer() : UnexpectedServer() {};
  ~UnexpectedSMTPServer() {};

  FlowAlert *buildAlert(Flow *f) {
    UnexpectedSMTPServerAlert *alert = new UnexpectedSMTPServerAlert(this, f);
    alert->setCliAttacker();
    return alert;
  }

  std::string getName()          const { return(std::string("unexpected_smtp")); }
};

#endif /* _UNEXPECTED_SMTP_SERVER_H_ */

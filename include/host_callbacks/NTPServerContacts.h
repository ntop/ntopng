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

#ifndef _NTP_SERVER_CONTACTS_H_
#define _NTP_SERVER_CONTACTS_H_

#include "ntop_includes.h"

class NTPServerContacts : public ServerContacts {
private:
  u_int32_t getContactedServers(Host *h) const { return h->getNTPContactCardinality(); };
  HostAlertType getAlertType() const { return NTPServerContactsAlert::getClassType(); };
  HostAlert *allocAlert(HostCallback *c, Host *f, AlertLevel severity, u_int8_t cli_score, u_int8_t srv_score, u_int64_t _contacts, u_int64_t _contacts_threshold) { return new NTPServerContactsAlert(c, f, severity, cli_score, srv_score, _contacts, _contacts_threshold); };

 public:
  NTPServerContacts();
  ~NTPServerContacts() {};

  HostCallbackID getID() const { return host_callback_ntp_server_contacts; }
  std::string getName()        const { return(std::string("ntp_contacts")); }
};

#endif

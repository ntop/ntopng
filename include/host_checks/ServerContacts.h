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

#ifndef _SERVER_CONTACTS_H_
#define _SERVER_CONTACTS_H_

#include "ntop_includes.h"

class ServerContacts : public HostCheck {
protected:
  u_int64_t contacts_threshold;

private:
  /* Methods that must be overridden by subclasses to fetch subclass alert type and subclass valute to be checked against the threshold */
  virtual u_int32_t getContactedServers(Host *h) const = 0;
  virtual HostAlertType getAlertType() const = 0;
  virtual HostAlert *allocAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _contacts, u_int64_t _contacts_threshold) = 0;

 public:
  ServerContacts();
  ~ServerContacts() {};

  void periodicUpdate(Host *h, HostAlert *engaged_alert);

  bool loadConfiguration(json_object *config);  
};

#endif

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

#ifndef _SERVER_CONTACTS_ALERT_H_
#define _SERVER_CONTACTS_ALERT_H_


#include "ntop_includes.h"


class ServerContactsAlert : public HostAlert {
 private:
  u_int64_t contacts, contacts_threshold;
  
  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  ServerContactsAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _syns, u_int64_t _syns_threshold);
  ~ServerContactsAlert() {};

  u_int8_t getAlertScore() const { return SCORE_LEVEL_NOTICE; };
};

#endif /* _SERVER_CONTACTS_ALERT_H_ */

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

#ifndef _ASN_CONNECTION_H_
#define _ASN_CONNECTION_H_

#include "ntop_includes.h"

class ASNConnection : public HostCheck {

public:
  ASNConnection();
  ~ASNConnection() {};

  ASNConnectionAlert *allocAlert(HostCheck *c, Host *h, risk_percentage cli_pctg, double num_asn, double num_countries) {
    return new ASNConnectionAlert(c, h, cli_pctg, num_asn);
  };

  void periodicUpdate(Host *h, HostAlert *engaged_alert);

  HostCheckID getID() const { return host_check_asn_connection; }
  std::string getName()  const { return(std::string("asn_connection")); }

};

#endif /* _ASN_CONNECTION_H_ */

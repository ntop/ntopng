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

#ifndef _DOMAIN_NAMES_CONNECTION_H_
#define _DOMAIN_NAMES_CONNECTION_H_

#include "ntop_includes.h"

class DomainNamesConnection : public HostCheck {
private:
  u_int8_t domain_names_threshold;

  DomainNamesConnectionAlert *allocAlert(HostCheck *c, Host *h, risk_percentage cli_pctg, u_int32_t _num_domain_names, u_int8_t _domain_names_threshold) { 
    return new DomainNamesConnectionAlert(c, h, cli_pctg, _num_domain_names,_domain_names_threshold);
  }; 

public:
  DomainNamesConnection();
  ~DomainNamesConnection() {};

  void periodicUpdate(Host *h, HostAlert *engaged_alert);
  bool loadConfiguration(json_object *config); 

  HostCheckID getID() const { return host_check_domain_names_connection; }
  std::string getName()  const { return(std::string("domain_names_connection")); }

};

#endif /* _DOMAIN_NAMES_CONNECTION_H_ */

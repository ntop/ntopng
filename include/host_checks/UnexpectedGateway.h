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

#ifndef _UNEXPECTED_GATEWAY_H_
#define _UNEXPECTED_GATEWAY_H_

#include "ntop_includes.h"

class UnexpectedGateway : public HostCheck {
 public:
  UnexpectedGateway();
  ~UnexpectedGateway(){};

  UnexpectedGatewayAlert *allocAlert(HostCheck *c, Host *h,
                                    risk_percentage cli_pctg) {
    return new UnexpectedGatewayAlert(c, h, cli_pctg);
  };

  bool loadConfiguration(json_object *config);
  void periodicUpdate(Host *h, HostAlert *engaged_alert);

  HostCheckID getID() const { return host_check_unexpected_gateway; }
  std::string getName() const { return (std::string("unexpected_gateway")); }
};

#endif /* _UNEXPECTED_GATEWAY_H_ */

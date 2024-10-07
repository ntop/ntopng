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

#ifndef _UNEXPECTED_GATEWAY_ALERT_H_
#define _UNEXPECTED_GATEWAY_ALERT_H_

#include "ntop_includes.h"

class UnexpectedGatewayAlert : public HostAlert {
 private:
  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);
 protected:
  const IpAddress *getServerIP(Flow *f) { return (f->get_dns_srv_ip_addr()); }

 public:
  static HostAlertType getClassType() {
    return {host_alert_unexpected_gateway, alert_category_network};
  }

  UnexpectedGatewayAlert(HostCheck* c, Host* f, risk_percentage cli_pctg);
  ~UnexpectedGatewayAlert(){};

  HostAlertType getAlertType() const { return getClassType(); }
  u_int8_t getAlertScore() const { return SCORE_LEVEL_ERROR; };
};

#endif /* _UNEXPECTED_GATEWAY_ALERT_H_ */

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

#ifndef _DNS_TRAFFIC__ALERT_H_
#define _DNS_TRAFFIC__ALERT_H_


#include "ntop_includes.h"


class DNSTrafficAlert : public HostAlert {
 private:
  u_int64_t dns_bytes, dns_bytes_threshold;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);
  
 public:
  static HostAlertType getClassType() { return { host_alert_dns_traffic, alert_category_network }; }

  DNSTrafficAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _dns_bytes, u_int64_t _dns_bytes_threshold);
  ~DNSTrafficAlert() {};
  
  HostAlertType getAlertType() const { return getClassType(); }
  u_int8_t getAlertScore()     const { return SCORE_LEVEL_ERROR; };
};

#endif /* _DNS_TRAFFIC__ALERT_H_ */

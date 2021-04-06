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

#ifndef _REPLIES_REQUESTS_RATIO_ALERT_H_
#define _REPLIES_REQUESTS_RATIO_ALERT_H_


#include "ntop_includes.h"


class RepliesRequestsRatioAlert : public HostAlert {
 private:
  u_int8_t ratio_threshold;
  u_int8_t dns_sent_rcvd_ratio, dns_rcvd_sent_ratio;
  u_int8_t http_sent_rcvd_ratio, http_rcvd_sent_ratio;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);
  
 public:
  static HostAlertType getClassType() { return { host_alert_replies_requests_ratio, alert_category_network }; }

  RepliesRequestsRatioAlert(HostCallback *c, Host *f, u_int8_t _ratio_threshold);
  ~RepliesRequestsRatioAlert() {};
  
  inline void setRatios(u_int8_t _dns_sent_rcvd_ratio, u_int8_t _dns_rcvd_sent_ratio, u_int8_t _http_sent_rcvd_ratio, u_int8_t _http_rcvd_sent_ratio) {
    dns_sent_rcvd_ratio =_dns_sent_rcvd_ratio, dns_rcvd_sent_ratio = _dns_rcvd_sent_ratio;
    http_sent_rcvd_ratio = _http_sent_rcvd_ratio, http_rcvd_sent_ratio = _http_rcvd_sent_ratio;
  }

  HostAlertType getAlertType() const { return getClassType(); }
};

#endif /* _REPLIES_REQUESTS_RATIO_ALERT_H_ */

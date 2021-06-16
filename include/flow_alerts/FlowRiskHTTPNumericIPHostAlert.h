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

#ifndef _FR_HTTP_NUMERIC_IP_HOST_ALERT_H_
#define _FR_HTTP_NUMERIC_IP_HOST_ALERT_H_

#include "ntop_includes.h"

class FlowRiskHTTPNumericIPHostAlert : public FlowRiskAlert {
 public:
  static ndpi_risk_enum getClassRisk() { return NDPI_HTTP_NUMERIC_IP_HOST; }
  static FlowAlertType getClassType() { return { flow_alert_ndpi_http_numeric_ip_host, alert_category_security }; }
  static u_int8_t      getDefaultScore() { return Utils::getFlowRiskScore(getClassRisk()); }

 FlowRiskHTTPNumericIPHostAlert(FlowCheck *c, Flow *f) : FlowRiskAlert(c, f) { };
  ~FlowRiskHTTPNumericIPHostAlert() { };

  FlowAlertType getAlertType() const { return getClassType(); }
  ndpi_risk_enum getAlertRisk()  const { return getClassRisk();  }
  u_int8_t       getAlertScore() const { return getDefaultScore(); }
};

#endif /* _FR_HTTP_NUMERIC_IP_HOST_ALERT_H_ */

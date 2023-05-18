/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _FR_MALICIOUS_SHA1_CERTIFICATE_ALERT_H_
#define _FR_MALICIOUS_SHA1_CERTIFICATE_ALERT_H_

#include "ntop_includes.h"

class FlowRiskMaliciousSHA1CertificateAlert : public FlowRiskAlert {
 public:
  static ndpi_risk_enum getClassRisk() {
    return NDPI_MALICIOUS_SHA1_CERTIFICATE;
  }
  static FlowAlertType getClassType() {
    return FlowRiskAlerts::getFlowRiskAlertType(getClassRisk());
  }
  static u_int8_t getDefaultScore() {
    return FlowRiskAlerts::getFlowRiskScore(getClassRisk());
  }

  FlowRiskMaliciousSHA1CertificateAlert(FlowCheck *c, Flow *f)
      : FlowRiskAlert(c, f){};
  ~FlowRiskMaliciousSHA1CertificateAlert(){};

  FlowAlertType getAlertType() const { return getClassType(); }
  ndpi_risk_enum getAlertRisk() const { return getClassRisk(); }
  u_int8_t getAlertScore() const { return getDefaultScore(); }
};

#endif /* _FR_MALICIOUS_SHA1_CERTIFICATE_ALERT_H_ */

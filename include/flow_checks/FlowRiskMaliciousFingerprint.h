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

#ifndef _FLOW_RISK_MALICIOUS_JA3_H_
#define _FLOW_RISK_MALICIOUS_JA3_H_

#include "ntop_includes.h"

class FlowRiskMaliciousJA3 : public FlowRisk {
 private:
  FlowAlertType getAlertType() const {
    return FlowRiskMaliciousFingerprintAlert::getClassType();
  }

 public:
  FlowRiskMaliciousJA3(){};
  ~FlowRiskMaliciousJA3(){};

  FlowAlert *buildAlert(Flow *f) {
    return new FlowRiskMaliciousFingerprintAlert(this, f);
  }

  std::string getName() const {
    return (FlowRiskAlerts::getCheckName(
        FlowRiskMaliciousFingerprintAlert::getClassRisk()));
  }
  ndpi_risk_enum handledRisk() {
    return FlowRiskMaliciousFingerprintAlert::getClassRisk();
  }
};

#endif /* _FLOW_RISK_MALICIOUS_JA3_H_ */

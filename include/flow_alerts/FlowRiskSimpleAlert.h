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

#ifndef _FR_SIMPLE_ALERT_H_
#define _FR_SIMPLE_ALERT_H_

#include "ntop_includes.h"

class FlowRiskSimpleAlert : public FlowRiskAlert {
 private:
  ndpi_risk_enum risk;
  
 public:
 FlowRiskSimpleAlert(FlowCheck *c, Flow *f, ndpi_risk_enum _risk) : FlowRiskAlert(c, f) { risk = _risk; };
  ~FlowRiskSimpleAlert() { };

  FlowAlertType  getAlertType()  const { return FlowRiskAlerts::getFlowRiskAlertType(risk); }
  ndpi_risk_enum getAlertRisk()  const { return risk;}
  u_int8_t       getAlertScore() const { return FlowRiskAlerts::getFlowRiskScore(risk); }
};

#endif /* _FR_SIMPLE_ALERT_H_ */

/*
 *
 * (C) 2013-25 - ntop.org
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

#ifndef _FR_SLOW_DOS_ALERT_H_
#define _FR_SLOW_DOS_ALERT_H_

#include "ntop_includes.h"

class FlowRiskSlowDoSAlert : public FlowRiskAlert {
    private:
    public:
        // Replace with NDPI_SLOW_DOS once implemented.
        static ndpi_risk_enum getClassRisk() { return NDPI_SUSPICIOUS_ENTROPY; /*NDPI_SLOW_DOS;*/ }
        static FlowAlertType getClassType() {
            return FlowRiskAlerts::getFlowRiskAlertType(getClassRisk());
        }
        static u_int8_t getDefaultScore() {
            return FlowRiskAlerts::getFlowRiskScore(getClassRisk());
        }

        FlowRiskSlowDoSAlert(FlowCheck *c, Flow *f) : FlowRiskAlert(c, f){ setAlertScore(getDefaultScore());};
        ~FlowRiskSlowDoSAlert(){};

        FlowAlertType getAlertType() const { return getClassType(); }
        ndpi_risk_enum getAlertRisk() const { return getClassRisk(); }
};

#endif /* _FR_SLOW_DOS_ALERT_H_ */

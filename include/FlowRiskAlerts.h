/*
 *
 * (C) 2013-22 - ntop.org
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

#ifndef _FLOW_RISK_ALERTS_H_
#define _FLOW_RISK_ALERTS_H_

#include "ntop_includes.h"

class FlowRiskAlerts {
 private:
  static bool isRiskUnhanlded(ndpi_risk_enum risk);

 public:
  static inline u_int8_t getFlowRiskScore(ndpi_risk_enum risk) {
    if(risk < NDPI_MAX_RISK) {
      ndpi_risk r = 0; u_int16_t c, s;
      
      ndpi_risk2score(NDPI_SET_BIT(r, risk), &c, &s);

      return(c + s);
    } else
      return(0);
  }
  
  static FlowAlertType getFlowRiskAlertType(ndpi_risk_enum risk);  
  static const char * const getCheckName(ndpi_risk_enum risk);
  static void checkUnhandledRisks();
  static bool lua(lua_State* vm);
};

#endif /* _FLOW_RISK_ALERTS_H_ */

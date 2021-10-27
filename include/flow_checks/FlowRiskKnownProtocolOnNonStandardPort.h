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

#ifndef _FLOW_RISK_NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT_H_
#define _FLOW_RISK_NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT_H_

#include "ntop_includes.h"

class FlowRiskKnownProtocolOnNonStandardPort : public FlowRisk {
 private:
  FlowAlertType getAlertType() const { return FlowRiskKnownProtocolOnNonStandardPortAlert::getClassType();  }

 public:
  FlowRiskKnownProtocolOnNonStandardPort() : FlowRisk() {};
  ~FlowRiskKnownProtocolOnNonStandardPort() {};

  FlowAlert *buildAlert(Flow *f) {
    FlowRiskKnownProtocolOnNonStandardPortAlert *alert = new FlowRiskKnownProtocolOnNonStandardPortAlert(this, f);

    /* Client is an attacker, trying to use a server on a non-std port */
    alert->setCliAttacker();

    /*
      If the server responds, the server is also an attacker as it is offering a service on a non std-port.
      NOTE: Currently, we have decided to skip this condition as it may penalize legitimate servers.
            Discussion at https://github.com/ntop/ntopng/issues/5997.

    if(f->get_bytes_srv2cli() > 10)
      alert->setSrvAttacker();
    */

    return alert;
  }

  std::string getName()        const { return(FlowRiskAlerts::getCheckName(FlowRiskKnownProtocolOnNonStandardPortAlert::getClassRisk())); }
  ndpi_risk_enum handledRisk() { return FlowRiskKnownProtocolOnNonStandardPortAlert::getClassRisk(); }
};

#endif

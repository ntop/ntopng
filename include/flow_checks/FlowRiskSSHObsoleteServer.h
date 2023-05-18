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

#ifndef _FLOW_RISK_NDPI_SSH_OBSOLETE_SERVER_H_
#define _FLOW_RISK_NDPI_SSH_OBSOLETE_SERVER_H_

#include "ntop_includes.h"

class FlowRiskSSHObsoleteServer : public FlowRisk {
 private:
  FlowAlertType getAlertType() const {
    return FlowRiskSSHObsoleteServerAlert::getClassType();
  }

 public:
  FlowRiskSSHObsoleteServer() : FlowRisk(){};
  ~FlowRiskSSHObsoleteServer(){};

  FlowAlert *buildAlert(Flow *f) {
    return new FlowRiskSSHObsoleteServerAlert(this, f);
  }

  std::string getName() const {
    return (FlowRiskAlerts::getCheckName(
        FlowRiskSSHObsoleteServerAlert::getClassRisk()));
  }
  ndpi_risk_enum handledRisk() {
    return FlowRiskSSHObsoleteServerAlert::getClassRisk();
  }
};

#endif

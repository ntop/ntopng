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

#ifndef _FLOW_RISK_NDPI_BINARY_APPLICATION_TRANSFER_H_
#define _FLOW_RISK_NDPI_BINARY_APPLICATION_TRANSFER_H_

#include "ntop_includes.h"

class FlowRiskBinaryApplicationTransfer : public FlowRisk {
 private:
  ndpi_risk_enum handledRisk()       { return NDPI_BINARY_APPLICATION_TRANSFER; };
  FlowAlertType getAlertType() const { return FlowRiskBinaryApplicationTransferAlert::getClassType(); };

  /* Overriding the default scores */
  u_int16_t getClientScore() { return 200; }
  u_int16_t getServerScore() { return 200; }

  /* Overriding the default severity */
  AlertLevel getSeverity() { return alert_level_error; }
  
 public:
  FlowRiskBinaryApplicationTransfer() : FlowRisk() {};
  ~FlowRiskBinaryApplicationTransfer() {};

  FlowAlert *buildAlert(Flow *f) { return new FlowRiskBinaryApplicationTransferAlert(this, f); }

  std::string getName()        const { return(std::string("suspicious_file_transfer")); }
};

#endif

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

#ifndef _SCAN_DETECTION_H_
#define _SCAN_DETECTION_H_

#include "ntop_includes.h"

class ScanDetection : public HostCheck {
private:
  u_int32_t num_incomplete_flows_threshold;

  HostAlert *allocAlert(HostCheck *c, Host *f, risk_percentage cli_pctg,
			u_int32_t _num_incomplete_flows, u_int32_t _num_incomplete_flows_threshold) {
    return new ScanDetectionAlert(c, f, cli_pctg, _num_incomplete_flows, _num_incomplete_flows_threshold);
  };

 public:
  ScanDetection();
  ~ScanDetection() {};

  void periodicUpdate(Host *h, HostAlert *engaged_alert);

  bool loadConfiguration(json_object *config);  

  /* HostCheckID in ntop_typedefs.h */
  HostCheckID getID()   const { return(host_check_scan_detection);     }

  /* scripts/lua/modules/check_definitions/host/scan_detection.lua */
  std::string getName() const { return(std::string("scan_detection")); }
};

#endif

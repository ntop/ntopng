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

#ifndef _PKT_THRESHOLD_H_
#define _PKT_THRESHOLD_H_

#include "ntop_includes.h"

class PktThreshold : public HostCheck {
private:
  u_int64_t pkt_threshold;

  HostAlert *allocAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _pkt_count, u_int64_t _pkt_threshold) { return new PktThresholdAlert(c, f, cli_pctg, _pkt_count, _pkt_threshold); };

 public:
  PktThreshold();
  ~PktThreshold() {};

  void periodicUpdate(Host *h, HostAlert *engaged_alert);

  bool loadConfiguration(json_object *config);  

  HostCheckID getID() const { return host_check_pkt_threshold; }
  std::string getName()      const { return(std::string("pkt_threshold")); }
};

#endif

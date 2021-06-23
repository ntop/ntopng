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

#ifndef _P2P_TRAFFIC_H_
#define _P2P_TRAFFIC_H_

#include "ntop_includes.h"

class P2PTraffic : public HostCheck {
private:
  u_int64_t p2p_bytes_threshold;  

  HostAlert *allocAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _p2p_bytes, u_int64_t _p2p_bytes_threshold) {
    return new P2PTrafficAlert(c, f, cli_pctg, _p2p_bytes, _p2p_bytes_threshold);
  };
  
public:
  P2PTraffic();
  ~P2PTraffic() {};
  
  void periodicUpdate(Host *h, HostAlert *engaged_alert);

  bool loadConfiguration(json_object *config);  

  HostCheckID getID() const { return host_check_p2p_traffic; }
  std::string getName()  const { return(std::string("p2p")); }
};

#endif

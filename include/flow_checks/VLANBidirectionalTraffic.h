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

#ifndef _VLAN_BIDIRECTIONAL_TRAFFIC_H_
#define _VLAN_BIDIRECTIONAL_TRAFFIC_H_

#include "ntop_includes.h"

class VLANBidirectionalTraffic : public FlowCheck {
 private:
  Bitmask *vlans;

  void checkBidirectionalTraffic(Flow *f);
  bool checkVLAN(u_int16_t vlan_id);
  bool isServerNotLocal(Flow *f);

 public:
  VLANBidirectionalTraffic();
  ~VLANBidirectionalTraffic();

  void protocolDetected(Flow *f);
  FlowAlert *buildAlert(Flow *f);

  bool loadConfiguration(json_object *config);

  std::string getName() const {
    return (std::string("vlan_bidirectional_traffic"));
  }
};

#endif /* _VLAN_BIDIRECTIONAL_TRAFFIC_H_ */

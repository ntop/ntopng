/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _VLAN_H_
#define _VLAN_H_

#include "ntop_includes.h"

class Vlan : public GenericHashEntry, public GenericTrafficElement {
 private:
  inline void incSentStats(u_int64_t num_pkts, u_int64_t num_bytes)  {
    sent.incStats(num_pkts, num_bytes);
    if(first_seen == 0) first_seen = iface->getTimeLastPktRcvd();
    last_seen = iface->getTimeLastPktRcvd();
  }
  inline void incRcvdStats(u_int64_t num_pkts, u_int64_t num_bytes) {
    rcvd.incStats(num_pkts, num_bytes);
  }

 public:
  Vlan(NetworkInterface *_iface, u_int16_t _vlan_id);
  ~Vlan();

  inline u_int16_t getNumHosts()               { return getUses();            }
  inline u_int32_t key()                       { return(vlan_id);             }
  inline u_int16_t get_vlan_id()               { return(vlan_id);             }

  bool equal(u_int16_t _vlan_id);

  inline void incStats(u_int32_t when, u_int16_t proto_id,
		       u_int64_t sent_packets, u_int64_t sent_bytes,
		       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    if(ndpiStats || (ndpiStats = new nDPIStats()))
      ndpiStats->incStats(when, proto_id, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
    incSentStats(sent_packets, sent_bytes);
    incRcvdStats(rcvd_packets, rcvd_bytes);
  }

  bool idle();
  void lua(lua_State* vm, DetailsLevel details_level, bool asListElement);
};

#endif /* _VLAN_H_ */


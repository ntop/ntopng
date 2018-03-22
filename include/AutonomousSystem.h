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

#ifndef _AUTONOMOUS_SYSTEM_H_
#define _AUTONOMOUS_SYSTEM_H_

// #define AS_LATENCY_DEBUG 1

#include "ntop_includes.h"

class AutonomousSystem : public GenericHashEntry, public GenericTrafficElement {
 private:
  u_int32_t asn;
  char *asname;
  u_int32_t round_trip_time;

  inline void incSentStats(u_int64_t num_pkts, u_int64_t num_bytes)  {
    sent.incStats(num_pkts, num_bytes);
    if(first_seen == 0) first_seen = iface->getTimeLastPktRcvd();
    last_seen = iface->getTimeLastPktRcvd();
  }
  inline void incRcvdStats(u_int64_t num_pkts, u_int64_t num_bytes) {
    rcvd.incStats(num_pkts, num_bytes);
  }

 public:
  AutonomousSystem(NetworkInterface *_iface, IpAddress *ipa);
  ~AutonomousSystem();

  inline u_int16_t getNumHosts()               { return getUses();            }
  inline u_int32_t key()                       { return(asn);                 }
  inline u_int32_t get_asn()                   { return(asn);                 }
  inline char *get_asname()                    { return(asname);              }

  bool equal(u_int32_t asn);

  inline void incStats(u_int32_t when, u_int16_t proto_id,
		       u_int64_t sent_packets, u_int64_t sent_bytes,
		       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    if(ndpiStats || (ndpiStats = new nDPIStats()))
      ndpiStats->incStats(when, proto_id, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
    incSentStats(sent_packets, sent_bytes);
    incRcvdStats(rcvd_packets, rcvd_bytes);
  }

  void updateRoundTripTime(u_int32_t rtt_msecs);
  bool idle();
  void lua(lua_State* vm, DetailsLevel details_level, bool asListElement);
};

#endif /* _AUTONOMOUS_SYSTEM_H_ */


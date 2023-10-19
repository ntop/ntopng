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

#ifndef _HOST_CHECKS_STATUS_H_
#define _HOST_CHECKS_STATUS_H_

#include "ntop_includes.h"

class HostChecksStatus { /* Container to keep per-check status (e.g., traffic
                            delta between consecutive calls) */
 private:
  time_t last_call_min, /* The last time minute checks were executed  */
      last_call_5min;   /* The last time 5minute checks were executed */
  u_int64_t ntp_bytes;  /* Holds the NTP bytes and is used to compute the delta
                           of NTP bytes across consecutive check calls */
  u_int64_t p2p_bytes;  /* Holds the P2P bytes and is used to compute the delta
                           of P2P bytes across consecutive check calls */
  u_int64_t dns_bytes;  /* Holds the DNS bytes and is used to compute the delta
                           of DNS bytes across consecutive check calls */
  u_int64_t pkt_counter;

 public:
  HostChecksStatus() {
    last_call_min = last_call_5min = 0;
    /* Set members to their maximum values to discard the first delta */
    ntp_bytes = p2p_bytes = dns_bytes = pkt_counter = (u_int64_t)-1;
  }
  virtual ~HostChecksStatus(){};

  inline bool isTimeToRunMinChecks(time_t now) const {
    return last_call_min + 60 <= now;
  }
  inline bool isTimeToRun5MinChecks(time_t now) const {
    return last_call_5min + 300 <= now;
  }

  inline void setMinLastCallTime(time_t now) { last_call_min = now; }
  inline void set5MinLastCallTime(time_t now) { last_call_5min = now; }

  /* Checks status API */
  inline u_int64_t cb_status_delta_ntp_bytes(u_int64_t new_value) {
    return Utils::uintDiff(&ntp_bytes, new_value);
  };
  inline u_int64_t cb_status_delta_p2p_bytes(u_int64_t new_value) {
    return Utils::uintDiff(&p2p_bytes, new_value);
  };
  inline u_int64_t cb_status_delta_dns_bytes(u_int64_t new_value) {
    return Utils::uintDiff(&dns_bytes, new_value);
  };
  inline u_int64_t cb_status_delta_pkt_counter(u_int64_t new_value) {
    return Utils::uintDiff(&pkt_counter, new_value);
  };
};

#endif /* _HOST_CHECKS_STATUS_H_ */

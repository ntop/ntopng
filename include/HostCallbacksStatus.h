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

#ifndef _HOST_CALLBACKS_STATUS_H_
#define _HOST_CALLBACKS_STATUS_H_

#include "ntop_includes.h"

class HostCallbacksStatus { /* Container to keep per-callback status (e.g., traffic delta between consecutive calls) */
 private:
  time_t last_call_min, /* The last time minute callbacks were executed  */
    last_call_5min;     /* The last time 5minute callbacks were executed */
  u_int64_t p2p_bytes;  /* Holds the P2P bytes and is used to compute the delta of P2P bytes across consecutive callback calls */
  u_int64_t dns_bytes;  /* Holds the DNS bytes and is used to compute the delta of DNS bytes across consecutive callback calls */
  u_int32_t http_reqs_sent, http_reqs_rcvd;  /* Counters for HTTP requests sent/received */
  u_int32_t http_repls_sent, http_repls_rcvd;  /* Counters for HTTP replies sent/received */
  u_int32_t dns_reqs_sent, dns_reqs_rcvd;    /* Counters for DNS requests sent/received */
  u_int32_t dns_repls_sent, dns_repls_rcvd;    /* Counters for DNS replies sent/received */

 public:
  HostCallbacksStatus() {
    last_call_min = last_call_5min = 0;
    /* Set members to their maximum values to discard the first delta */
    p2p_bytes = dns_bytes = (u_int64_t)-1; 
    http_reqs_sent = http_reqs_rcvd = http_repls_sent = http_repls_rcvd = (u_int32_t)-1,
      dns_reqs_sent = dns_reqs_rcvd = dns_repls_sent = dns_repls_rcvd = (u_int32_t)-1;
  }
  virtual ~HostCallbacksStatus() {};

  inline bool isTimeToRunMinCallbacks(time_t now)  const { return last_call_min  +  60 <= now; }
  inline bool isTimeToRun5MinCallbacks(time_t now) const { return last_call_5min + 300 <= now; }

  inline void setMinLastCallTime(time_t now)  { last_call_min  = now; }
  inline void set5MinLastCallTime(time_t now) { last_call_5min = now; }

  /* Callbacks status API */
  inline u_int64_t cb_status_delta_p2p_bytes(u_int64_t new_value) { return Utils::uintDiff(&p2p_bytes, new_value); };
  inline u_int64_t cb_status_delta_dns_bytes(u_int64_t new_value) { return Utils::uintDiff(&dns_bytes, new_value); };

  inline u_int8_t cb_status_delta_http_ratio(u_int32_t new_reqs, u_int32_t new_repls, bool sent_vs_rcvd) {
    return sent_vs_rcvd
      ? Utils::uintDiff(&http_reqs_sent, new_reqs) * 100 / (Utils::uintDiff(&http_repls_rcvd, new_repls) + 1)
      : Utils::uintDiff(&http_reqs_rcvd, new_reqs) * 100 / (Utils::uintDiff(&http_repls_sent, new_repls) + 1);
  };
  inline u_int8_t cb_status_delta_dns_ratio(u_int32_t new_reqs, u_int32_t new_repls, bool sent_vs_rcvd) {
    return sent_vs_rcvd
      ? Utils::uintDiff(&dns_reqs_sent, new_reqs) * 100 / (Utils::uintDiff(&dns_repls_rcvd, new_repls) + 1)
      : Utils::uintDiff(&dns_reqs_rcvd, new_reqs) * 100 / (Utils::uintDiff(&dns_repls_sent, new_repls) + 1);
  };
};

#endif /* _HOST_CALLBACKS_STATUS_H_ */

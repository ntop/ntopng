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

#ifndef _TRAFFIC_COUNTER_H_
#define _TRAFFIC_COUNTER_H_

#include "ntop_includes.h"

class TrafficCounter {
 private:
  u_int64_t sent, rcvd;

 public:
  TrafficCounter() { resetStats(); }

  inline void resetStats()    { sent = 0, rcvd = 0;  }
  inline u_int64_t getTotal() { return(sent + rcvd); }
  inline u_int64_t getSent()  { return(sent);        }
  inline u_int64_t getRcvd()  { return(rcvd);        }
  inline void incStats(u_int64_t sent_bytes, u_int64_t rcvd_bytes)  {
    rcvd += rcvd_bytes, sent += sent_bytes;
  }
};

#endif /* _TRAFFIC_COUNTER_H_ */

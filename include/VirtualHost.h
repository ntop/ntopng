/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef _VIRTUAL_HOST_H_
#define _VIRTUAL_HOST_H_

#include "ntop_includes.h"

class Flow;
class HostHash;

class VirtualHost : public GenericHashEntry {
  HostHash *h;
  char *name;
  TrafficStats sent_stats, rcvd_stats, num_requests;
  u_int64_t last_num_requests;
  u_int32_t last_diff;
  u_int32_t vhost_key;
  ValueTrend trend;

 public:
  VirtualHost(HostHash *_h, char *_name);
  ~VirtualHost();

  u_int32_t key()            { return vhost_key; };
  inline char* get_name()    { return name;     };
  inline void incStats(time_t t, u_int32_t num_req, u_int32_t bytes_sent, u_int32_t bytes_rcvd) {
    updateSeen(t);
    sent_stats.incStats(t, 1, bytes_sent),
      rcvd_stats.incStats(t, 1, bytes_rcvd),
      num_requests.incStats(t, 1, num_req);
  }  
  inline u_int64_t  get_sent_bytes()   { return(sent_stats.getNumBytes());   };
  inline u_int64_t  get_rcvd_bytes()   { return(rcvd_stats.getNumBytes());   };
  inline u_int64_t  get_num_requests() { return(num_requests.getNumBytes()); };
  inline u_int64_t  get_diff_num_requests() { return(last_diff);             };
  inline ValueTrend get_trend()        { return(trend);                      };
  void update_stats();
};

#endif /* _VIRTUAL_HOST_H_ */

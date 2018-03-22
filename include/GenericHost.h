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

#ifndef _GENERIC_HOST_H_
#define _GENERIC_HOST_H_

#include "ntop_includes.h"

class NetworkInterface;
class Flow;

class GenericHost : public GenericHashEntry, public GenericTrafficElement {
 protected:
  bool localHost, systemHost;
  u_int32_t low_goodput_client_flows, low_goodput_server_flows;
  u_int32_t total_activity_time /* sec */, last_epoch_update; /* useful to avoid multiple updates */

  /* Throughput */
  float goodput_bytes_thpt, last_goodput_bytes_thpt, bytes_goodput_thpt_diff;
  ValueTrend bytes_goodput_thpt_trend;

 public:
  GenericHost(NetworkInterface *_iface);
  virtual ~GenericHost() {
    /* Pool counters are updated both in and outside the datapath.
       So decPoolNumHosts must stay in the destructor to preserve counters
       consistency (no thread outside the datapath will change the last pool id) */
    iface->decPoolNumHosts(get_host_pool(), true /* Host is deleted inline */);
  };

  inline bool isLocalHost()                { return(localHost || systemHost); };
  inline bool isSystemHost()               { return(systemHost);              };
  inline void setSystemHost()              { systemHost = true;               };

  inline nDPIStats* get_ndpi_stats()       { return(ndpiStats);               };

  void incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
		u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes);

  virtual char* get_string_key(char *buf, u_int buf_len) { return(NULL);   };
  virtual bool match(AddressTree *ptree)             { return(true);       };

  virtual void set_to_purge() { /* Saves 1 extra-step of purge idle */
    iface->decNumHosts(isLocalHost());
    GenericHashEntry::set_to_purge();
  };

  inline bool isChildSafe() {
#ifdef NTOPNG_PRO
    return(iface->getHostPools()->isChildrenSafePool(host_pool_id));
#else
    return(false);
#endif
  };

  inline bool forgeGlobalDns() {
#ifdef NTOPNG_PRO
    return(iface->getHostPools()->forgeGlobalDns(host_pool_id));
#else
    return(false);
#endif
  };
};

#endif /* _GENERIC_HOST_H_ */

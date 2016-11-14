/*
 *
 * (C) 2013-16 - ntop.org
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

class Flow;

class GenericHost : public GenericHashEntry, public GenericTrafficElement {
 protected:
  bool localHost, systemHost;
  u_int32_t host_serial, num_alerts_detected;
  nDPIStats *ndpiStats;
  ActivityStats activityStats;
  u_int32_t low_goodput_client_flows, low_goodput_server_flows;
  u_int8_t source_id;
  time_t last_activity_update;

  /* Throughput */
  float goodput_bytes_thpt, last_goodput_bytes_thpt, bytes_goodput_thpt_diff;
  ValueTrend bytes_goodput_thpt_trend;

  void dumpStats(bool forceDump);
  void readStats();

  virtual void computeHostSerial() { ; }

 public:
  GenericHost(NetworkInterface *_iface);
  ~GenericHost();

  inline double pearsonCorrelation(GenericHost *h) { return(activityStats.pearsonCorrelation(h->getActivityStats())); };
  inline bool isLocalHost()                { return(localHost || systemHost); };
  inline bool isSystemHost()               { return(systemHost); };
  inline void setSystemHost()              { systemHost = true;  };
  inline nDPIStats* get_ndpi_stats()       { return(ndpiStats); };
  inline ActivityStats* getActivityStats() { return(&activityStats); };  
  void incStats(u_int8_t l4_proto, u_int ndpi_proto, u_int64_t sent_packets, 
		u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes);
  inline u_int32_t get_host_serial()  { return(host_serial);               };
  inline void incNumAlerts()          { num_alerts_detected++;             };

  inline u_int64_t getPeriodicStats(void)    { return (last_bytes_periodic);	   };
  void resetPeriodicStats(void);
  void updateActivities();
  inline char* getJsonActivityMap()   { return(activityStats.serialize()); };
  inline u_int8_t getSourceId()       { return(source_id);                 };
  virtual char* get_string_key(char *buf, u_int buf_len) { return(NULL);   };
  virtual bool match(patricia_tree_t *ptree)             { return(true);   };
};

#endif /* _GENERIC_HOST_H_ */

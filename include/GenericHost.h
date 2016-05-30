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

class GenericHost : public GenericHashEntry {
 protected:
  bool localHost, systemHost;
  u_int32_t host_serial;
  u_int16_t vlan_id;
  nDPIStats *ndpiStats;
  TrafficStats sent, rcvd;
  ActivityStats activityStats;
  u_int32_t num_alerts_detected, low_goodput_client_flows, low_goodput_server_flows;
  u_int8_t source_id;

  /* Throughput */
  float bytes_thpt, goodput_bytes_thpt, pkts_thpt;
  float last_bytes_thpt, last_goodput_bytes_thpt, last_pkts_thpt;
  ValueTrend bytes_thpt_trend, bytes_goodput_thpt_trend, pkts_thpt_trend;
  float bytes_thpt_diff, bytes_goodput_thpt_diff;
  u_int64_t last_bytes, last_packets;
  u_int64_t last_bytes_periodic;
  struct timeval last_update_time;
  time_t last_activity_update;

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
  inline u_int16_t get_vlan_id()           { return(vlan_id);        };
  void incStats(u_int8_t l4_proto, u_int ndpi_proto, u_int64_t sent_packets, 
		u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes);
  inline u_int32_t get_host_serial()  { return(host_serial);               };
  inline void incNumAlerts()          { num_alerts_detected++;             };
  inline u_int32_t getNumAlerts()     { return(num_alerts_detected);       };
  void updateStats(struct timeval *tv);
  inline u_int64_t getPeriodicStats(void)    { return (last_bytes_periodic);	   };
  inline u_int64_t getNumBytes()      { return(sent.getNumBytes()+rcvd.getNumBytes()); };
  inline u_int64_t getNumBytesSent()  { return(sent.getNumBytes());                    };
  inline u_int64_t getNumBytesRcvd()  { return(rcvd.getNumBytes());                    };
  void resetPeriodicStats(void);
  void updateActivities();
  inline ValueTrend getThptTrend()    { return(bytes_thpt_trend);          };
  inline float getThptTrendDiff()     { return(bytes_thpt_diff);           };
  inline float getBytesThpt()         { return(bytes_thpt);                };
  inline float getPacketsThpt()       { return(pkts_thpt);                 };
  inline char* getJsonActivityMap()   { return(activityStats.serialize()); };
  inline u_int8_t getSourceId()       { return(source_id);                 };
  virtual char* get_string_key(char *buf, u_int buf_len) { return(NULL);   };
  virtual bool match(patricia_tree_t *ptree)             { return(true);   };
};

#endif /* _GENERIC_HOST_H_ */

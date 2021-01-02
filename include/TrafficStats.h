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

#ifndef _TRAFFIC_STATS_H_
#define _TRAFFIC_STATS_H_

#include "ntop_includes.h"

class TrafficStats {
 private:
  MonitoredCounter<u_int64_t> numPkts, numBytes;

 public:
  TrafficStats();
  TrafficStats(const TrafficStats &ts) {
    numPkts = MonitoredCounter<u_int64_t>(ts.numPkts),
      numBytes = MonitoredCounter<u_int64_t>(ts.numBytes);
  };
  
  inline void incStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    numPkts.inc(num_pkts), numBytes.inc(num_bytes);
    numPkts.computeAnomalyIndex(t), numBytes.computeAnomalyIndex(t);
  };  
  inline void resetStats()                   { numPkts.reset(), numBytes.reset(); };
  inline u_int64_t getNumPkts()      const   { return(numPkts.get());             };
  inline u_int64_t getNumBytes()     const   { return(numBytes.get());            };
  inline u_int64_t getPktsAnomaly()  const   { return(numPkts.getAnomalyIndex()); };
  inline u_int64_t getBytesAnomaly() const   { return(numBytes.getAnomalyIndex());};
  void printStats();

  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();
};

#endif /* _TRAFFIC_STATS_H_ */

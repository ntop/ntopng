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

#ifndef _PERIODIC_SCRIPT_H_
#define _PERIODIC_SCRIPT_H_

#include "ntop_includes.h"

class PeriodicScript {
 private: 
  const char *path;
  u_int32_t periodicity;
  u_int32_t max_duration_secs;
  ThreadPool *pool;
  bool align_to_localtime;  
  bool exclude_viewed_interfaces;
  bool exclude_pcap_dump_interfaces;

 public:
  PeriodicScript(const char* _path,		   
		   u_int32_t _periodicity_seconds = 0,
		   u_int32_t _max_duration_seconds = 0,
		   bool _align_to_localtime = false,
		   bool _exclude_viewed_interfaces = false,
		   bool _exclude_pcap_dump_interfaces = false,
		   ThreadPool* _pool = NULL);
  ~PeriodicScript();

  inline u_int32_t getPeriodicity() { return (periodicity); };
  inline bool excludeViewedIfaces() { return (exclude_viewed_interfaces); };
  inline bool excludePcap()         { return (exclude_pcap_dump_interfaces); };
  inline bool alignToLocalTime()    { return (align_to_localtime); };
  inline const char *getPath()      { return (path); };
  inline u_int32_t getMaxDuration() { return (max_duration_secs); };
  inline ThreadPool *getPool()      { return (pool); };
};

#endif /* _PERIODIC_SCRIPT_H_ */

/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _INFLUXDB_TS_EXPORTER_H_
#define _INFLUXDB_TS_EXPORTER_H_

#include "ntop_includes.h"

class InfluxDBTimeseriesExporter : public TimeseriesExporter {
 private:
  time_t flushTime;
  u_int32_t cursize;
  u_int32_t num_exports;
  FILE *fp;
  char fbase[PATH_MAX], fname[PATH_MAX+32];
  u_int num_cached_entries; 
  Mutex m;
  bool dbCreated;
  
  void createDump();
  
 public:
  InfluxDBTimeseriesExporter(NetworkInterface *_if);
  ~InfluxDBTimeseriesExporter();

  bool enqueueData(lua_State* vm, bool do_lock = true);
  char *dequeueData();
  void flush();
};

#endif /* _INFLUXDB_TS_EXPORTER_H_ */

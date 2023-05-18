/*
 *
 * (C) 2020-23 - ntop.org
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

#ifndef _RRD_TS_EXPORTER_H_
#define _RRD_TS_EXPORTER_H_

#include "ntop_includes.h"

class RRDTimeseriesExporter : public TimeseriesExporter {
 private:
  StringFifoQueue *ts_queue;

 public:
  RRDTimeseriesExporter(NetworkInterface *_if);
  ~RRDTimeseriesExporter();

  bool enqueueData(lua_State *vm, bool do_lock = true);
  char *dequeueData();
  u_int64_t queueLength() const;
  void flush();
};

#endif /* _RRD_TS_EXPORTER_H_ */

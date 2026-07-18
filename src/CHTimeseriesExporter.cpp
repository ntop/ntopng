/*
 *
 * (C) 2024-26 - ntop.org
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

#include "ntop_includes.h"

/* ******************************************************* */

CHTimeseriesExporter::CHTimeseriesExporter(NetworkInterface* _if)
    : TimeseriesExporter(_if) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  ts_queue = new (std::nothrow) StringFifoQueue(CH_TS_QUEUE_SIZE);
}

/* ******************************************************* */

CHTimeseriesExporter::~CHTimeseriesExporter() { delete ts_queue; }

/* ******************************************************* */

bool CHTimeseriesExporter::enqueueData(lua_State* vm, bool do_lock) {
  char data[LINE_PROTOCOL_MAX_LINE];

  if (line_protocol_write_line(vm, data, sizeof(data), escape_spaces) < 0) {
    qdrops++;
    return false;
  }
  
  return ts_queue->enqueue(data);
}

/* ******************************************************* */

char* CHTimeseriesExporter::dequeueData() {
  if (ts_queue->empty()) return NULL;
  return ts_queue->dequeue();
}

/* ******************************************************* */

u_int64_t CHTimeseriesExporter::queueLength() const {
  return ts_queue->getLength();
}

/* ******************************************************* */

void CHTimeseriesExporter::flush() {}

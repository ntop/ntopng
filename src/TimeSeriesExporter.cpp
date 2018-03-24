/*
 *
 * (C) 2018 - ntop.org
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

/*
  Enable it with:

  redis-cli set "ntopng.prefs.ts_post_data_url" "http://localhost:8086/write?db=ntopng" [InfluxDB]
*/
TimeSeriesExporter::TimeSeriesExporter(NetworkInterface *_if, char *_url) {
  fd = NULL, iface = _if, url = strdup(_url), num_cached_entries = 0;
  ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Exporting TS data to %s",
			       iface->get_name(), url);
}

/* ******************************************************* */

TimeSeriesExporter::~TimeSeriesExporter() {
  flush();
  free(url);
}

/* ******************************************************* */

void TimeSeriesExporter::createDump() {
  strcpy(fname, "/tmp/TimeSeriesExporter_XXXXXX");
  mkstemp(fname);

  fd = fopen(fname, "w");
  ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Dumping TS data onto tmp file %s",
			       iface->get_name(), fname);
  flushTime = time(NULL) + CONST_TS_FLUSH_TIME, num_cached_entries = 0;
}

/* ******************************************************* */

void TimeSeriesExporter::exportData(char *data) {
  m.lock(__FILE__, __LINE__);
  
  if(!fd) createDump();

  if(fd) {
    fwrite(data, strlen(data), 1, fd), num_cached_entries++;
    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s",
				 iface->get_name(), data);
  }
  
  m.unlock(__FILE__, __LINE__);

  if(time(NULL) > flushTime)
    flush(); /* Auto-flush data */
}

/* ******************************************************* */

void TimeSeriesExporter::flush() {
  if(!fd) return;
  
  m.lock(__FILE__, __LINE__);
  fclose(fd);
  fd = NULL;
  ntop->getRedis()->rpush(CONST_TS_FILE_QUEUE, fname, 0);
  ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Queueing tmp file %s [%u entries]",
			       iface->get_name(), fname, num_cached_entries);
  m.unlock(__FILE__, __LINE__);
}

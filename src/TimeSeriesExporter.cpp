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

  Start Influx
  $ influxd -config /usr/local/etc/influxdb.conf

  Initial database configuration
  $ influx
  Connected to http://localhost:8086 version v1.5.2
  InfluxDB shell version: v1.5.2
  > create database ntopng;
  > quit

  Start Chronograf
  $ chronograf
*/
TimeSeriesExporter::TimeSeriesExporter(NetworkInterface *_if, char *_url) {
  fd = -1, iface = _if, url = strdup(_url), num_cached_entries = 0;
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
#ifdef WIN32
	if(tmpnam_s(fname, sizeof(fname)))
		snprintf(fname, sizeof(fname), "%u", time(NULL));

	fd = open (fname, O_RDWR | O_CREAT | O_EXCL, _S_IREAD | _S_IWRITE);
#else
  strcpy(fname, "/tmp/TimeSeriesExporter_XXXXXX");
  fd = mkstemp(fname);
#endif

  if(fd == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "[%s] Unable to dump TS data onto %s: %s",
				 iface->get_name(), fname, strerror(errno));
  else
    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Dumping TS data onto %s",
				 iface->get_name(), fname);

  flushTime = time(NULL) + CONST_TS_FLUSH_TIME, num_cached_entries = 0;
}

/* ******************************************************* */

void TimeSeriesExporter::exportData(char *data) {
  m.lock(__FILE__, __LINE__);

  if(fd == -1)
    createDump();

  if(fd != -1) {
    int exp = strlen(data);
    int l = (int)write(fd, data, exp);

    num_cached_entries++;
    if(l == exp)
      ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s", iface->get_name(), data);
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[%s] Unable to append '%s' [written: %u][expected: %u]",
				   iface->get_name(), data, exp, l);
  }

  m.unlock(__FILE__, __LINE__);

  if(time(NULL) > flushTime)
    flush(); /* Auto-flush data */
}

/* ******************************************************* */

void TimeSeriesExporter::flush() {
  m.lock(__FILE__, __LINE__);

  if(fd != -1) {
    close(fd);
    fd = -1;
    ntop->getRedis()->rpush(CONST_TS_FILE_QUEUE, fname, 0);
    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Queueing TS file %s [%u entries]",
				 iface->get_name(), fname, num_cached_entries);
  }

  m.unlock(__FILE__, __LINE__);
}

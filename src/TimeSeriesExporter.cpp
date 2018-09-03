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
TimeSeriesExporter::TimeSeriesExporter(NetworkInterface *_if) {
  fd = -1, iface = _if, num_cached_entries = 0, dbCreated = false;
  cursize = num_exports = 0;

  snprintf(fbase, sizeof(fbase), "%s/%d/ts_export/", ntop->get_working_dir(), iface->get_id());
  ntop->fixPath(fbase);

  if(!Utils::mkdir_tree(fbase)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to create directory %s", fbase);
    throw 1;
  }
}

/* ******************************************************* */

TimeSeriesExporter::~TimeSeriesExporter() {
  flush();
}

/* ******************************************************* */

void TimeSeriesExporter::createDump() {
  flushTime = time(NULL) + CONST_INFLUXDB_FLUSH_TIME;
  cursize = 0;

  /* Use the flushTime as the fname */
  snprintf(fname, sizeof(fname), "%s%u_%lu", fbase, num_exports, flushTime);

#ifdef WIN32
  fd = open(fname, O_RDWR | O_CREAT | O_EXCL, _S_IREAD | _S_IWRITE);
#else
  fd = open(fname, O_RDWR | O_CREAT | O_EXCL | S_IREAD | S_IWRITE,
	    CONST_DEFAULT_FILE_MODE);
#endif

  if(fd == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "[%s] Unable to dump TS data onto %s: %s",
				 iface->get_name(), fname, strerror(errno));
  else
    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Dumping TS data onto %s",
				 iface->get_name(), fname);

  num_cached_entries = 0;

  if(!dbCreated) {
    dbCreated = true;
  }
}

/* ******************************************************* */

void TimeSeriesExporter::exportData(char *data, bool do_lock) {
  if(do_lock) m.lock(__FILE__, __LINE__);
  
  if(fd == -1)
    createDump();

  if(fd != -1) {
    int exp = strlen(data);
    int l = (int)write(fd, data, exp);

    cursize += l;

    num_cached_entries++;
    if(l == exp)
      ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s", iface->get_name(), data);
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[%s] Unable to append '%s' [written: %u][expected: %u]",
				   iface->get_name(), data, exp, l);
  }

  if(do_lock) m.unlock(__FILE__, __LINE__);

  if((time(NULL) > flushTime) || (cursize >= CONST_INFLUXDB_MAX_DUMP_SIZE))
    flush(); /* Auto-flush data */
}

/* ******************************************************* */

void TimeSeriesExporter::flush() {
  m.lock(__FILE__, __LINE__);

  if(fd != -1) {
    close(fd);
    fd = -1;
    char buf[32];
    snprintf(buf, sizeof(buf), "%d|%lu|%u", iface->get_id(), flushTime, num_exports);
    cursize = 0;
    num_exports++;

    ntop->getRedis()->rpush(CONST_INFLUXDB_FILE_QUEUE, buf, 0);
    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Queueing TS file %s [%u entries]",
				 iface->get_name(), fname, num_cached_entries);
  }

  m.unlock(__FILE__, __LINE__);
}

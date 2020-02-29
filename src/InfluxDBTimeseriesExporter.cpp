/*
 *
 * (C) 2018-20 - ntop.org
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
InfluxDBTimeseriesExporter::InfluxDBTimeseriesExporter(NetworkInterface *_if) : TimeseriesExporter(_if) {
  num_cached_entries = 0, dbCreated = false;
  cursize = num_exports = 0;
  fp = NULL;

  snprintf(fbase, sizeof(fbase), "%s/%d/ts_export/", ntop->get_working_dir(), iface->get_id());
  ntop->fixPath(fbase);

  if(!Utils::mkdir_tree(fbase)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to create directory %s", fbase);
    throw 1;
  }
}

/* ******************************************************* */

InfluxDBTimeseriesExporter::~InfluxDBTimeseriesExporter() {
  flush();
}

/* ******************************************************* */

void InfluxDBTimeseriesExporter::createDump() {
  flushTime = time(NULL) + CONST_INFLUXDB_FLUSH_TIME;
  cursize = 0;

  /* Use the flushTime as the fname */
  snprintf(fname, sizeof(fname), "%s%u_%lu", fbase, num_exports, flushTime);

  if(!(fp = fopen(fname, "w")))
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

bool InfluxDBTimeseriesExporter::exportData(lua_State* vm, bool do_lock) {
  char data[LINE_PROTOCOL_MAX_LINE];

  if(line_protocol_write_line(vm, data, sizeof(data), escape_spaces) < 0)
    return false;

  if(do_lock) m.lock(__FILE__, __LINE__);
  
  if(!fp)
    createDump();

  if(fp) {
    int exp = strlen(data);
    int l = fwrite(data, 1, strlen(data), fp); // (fd, data, exp);

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

  return true;
}

/* ******************************************************* */

void InfluxDBTimeseriesExporter::flush() {
  m.lock(__FILE__, __LINE__);

  if(fp) {
    fclose(fp);
    fp = NULL;
    char buf[32];
    snprintf(buf, sizeof(buf), "%d|%lu|%u|%u", iface->get_id(), flushTime,
				   num_exports, num_cached_entries);
    cursize = 0;
    num_exports++;

    ntop->getRedis()->rpush(CONST_INFLUXDB_FILE_QUEUE, buf, 0);
    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Queueing TS file %s [%u entries]",
				 iface->get_name(), fname, num_cached_entries);
  }

  m.unlock(__FILE__, __LINE__);
}

/*
 *
 * (C) 2018-23 - ntop.org
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

// #define TRACE_INFLUXDB_EXPORTS

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
InfluxDBTimeseriesExporter::InfluxDBTimeseriesExporter(NetworkInterface* _if)
    : TimeseriesExporter(_if) {
  num_cached_entries = 0;
  cursize = num_exports = 0;
  fp = NULL;

  /* All interfaces write files into the same directory (as with ClickHouse) */
  snprintf(fbase, sizeof(fbase), "%s/tmp/influxdb/", ntop->get_working_dir());
  ntop->fixPath(fbase);

  if (!Utils::mkdir_tree(fbase)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create directory %s",
                                 fbase);
    throw 1;
  }
}

/* ******************************************************* */

InfluxDBTimeseriesExporter::~InfluxDBTimeseriesExporter() { flush(); }

/* ******************************************************* */

void InfluxDBTimeseriesExporter::createDump() {
  flushTime = time(NULL) + CONST_INFLUXDB_FLUSH_TIME;
  cursize = 0;

  /* Use the flushTime as the fname */
  snprintf(fname, sizeof(fname), "%s%u_%u_%lu%s", fbase,
           (u_int16_t)iface->get_id(), num_exports, flushTime, TMP_TRAILER);

  if (!(fp = fopen(fname, "wb")))
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "[%s] Unable to dump TS data onto %s: %s",
                                 iface->get_name(), fname, strerror(errno));
  else {
#ifdef TRACE_INFLUXDB_EXPORTS
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "[InfluxDB] Dumping timeseries into File %s", fname);
#endif
    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] Dumping TS data onto %s",
                                 iface->get_name(), fname);
  }

  cursize = 0;
  num_cached_entries = 0;
}

/* ******************************************************* */

bool InfluxDBTimeseriesExporter::enqueueData(lua_State* vm, bool do_lock) {
  char data[LINE_PROTOCOL_MAX_LINE];

  if (line_protocol_write_line(vm, data, sizeof(data), escape_spaces) < 0)
    return false;

  if (do_lock) m.lock(__FILE__, __LINE__);

  if (!fp) createDump();

  if (fp) {
    int exp = strlen(data);
    int l = fwrite(data, 1, strlen(data), fp);  // (fd, data, exp);

    cursize += l;

    num_cached_entries++;
    if (l == exp)
      ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s", iface->get_name(),
                                   data);
    else
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "[%s] Unable to append '%s' [written: %u][expected: %u]",
          iface->get_name(), data, exp, l);
  }

  if (do_lock) m.unlock(__FILE__, __LINE__);

  if ((time(NULL) > flushTime) || (cursize >= CONST_INFLUXDB_MAX_DUMP_SIZE))
    flush(); /* Auto-flush data */

  return true;
}

/* ******************************************************* */

char* InfluxDBTimeseriesExporter::dequeueData() {
  /* Dequeued straigth from a Redis queue in influxdb.lua */
  return NULL;
}

/* ******************************************************* */

void InfluxDBTimeseriesExporter::flush() {
  m.lock(__FILE__, __LINE__);

  if (fp) {
    char buf[PATH_MAX + 32];
    u_int len;

    fclose(fp);
    fp = NULL;
    num_exports++;

    /* Remove .tmp trailer */
    snprintf(buf, sizeof(buf), "%s", fname);
    len = strlen(buf) - strlen(TMP_TRAILER);
    buf[len] = '\0';
    rename(fname, buf);

#ifdef TRACE_INFLUXDB_EXPORTS
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "[InfluxDB] File %s ready to import", buf);
#endif

    ntop->getRedis()->incr(CONST_INFLUXDB_KEY_EXPORTED_POINTS,
                           num_cached_entries);
  }

  m.unlock(__FILE__, __LINE__);
}

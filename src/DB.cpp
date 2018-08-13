/*
 *
 * (C) 2013-18 - ntop.org
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

/* ******************************************* */

DB::DB(NetworkInterface *_iface) {
  if((m = new(std::nothrow) Mutex()) == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mutex. Are you running out of memory?");

  iface = _iface;
  log_fd = NULL;

  open_log();
}

/* ******************************* */

void DB::open_log() {
  static char sql_log_path[MAX_PATH];

  if(ntop->getPrefs()->is_sql_log_enabled()) {
    snprintf(sql_log_path, sizeof(sql_log_path), "%s/%d/ntopng_sql.log",
	     ntop->get_working_dir(), iface->get_id());

    log_fd = fopen(sql_log_path, "a");

    if(!log_fd)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create log %s", sql_log_path);
    else
      chmod(sql_log_path, CONST_DEFAULT_FILE_MODE);
  }
}


/* ******************************************* */

DB::~DB() {
  if(m) delete m;
  if(log_fd) fclose(log_fd);
}

/* ******************************************* */

bool DB::dumpFlow(time_t when, Flow *f, char *json) {
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
  return(false);
}

/* ******************************************* */

int DB::exec_sql_query(lua_State *vm, char *sql, bool limit_rows, bool wait_for_db_created) {
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
  return(false);
}

/* ******************************************* */

void DB::startDBLoop() {
  ntop->getTrace()->traceEvent(TRACE_WARNING, "*** Internal error ***");
}

/* ******************************************* */

#ifdef NTOPNG_PRO
bool DB::dumpAggregatedFlow(AggregatedFlow *f) {
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
  return(false);
}
#endif


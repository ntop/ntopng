/*
 *
 * (C) 2013-16 - ntop.org
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
}

/* ******************************************* */

DB::~DB() {
  if(m) delete m;
}

/* ******************************************* */

bool DB::dumpFlow(time_t when, bool partial_dump, bool idle_flow, Flow *f, char *json) {
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
  return(false);
}

/* ******************************************* */

int DB::exec_sql_query(lua_State *vm, char *sql, bool limit_rows) {
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
  return(false);
}

/* ******************************************* */

void DB::startDBLoop() {
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
}

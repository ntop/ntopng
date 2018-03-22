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

StoreManager::StoreManager(int interface_id) {
    ifid = interface_id;
    iface = ntop->getInterfaceById(interface_id);
    db = NULL;
};

int StoreManager::init(const char *db_file_full_path) {
  if(sqlite3_open(db_file_full_path, &db)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to open %s: %s",
				 db_file_full_path, sqlite3_errmsg(db));
    db = NULL;
    return -1;
  }

  return 0;
}

NetworkInterface* StoreManager::getNetworkInterface() {
  if(!iface)
    iface = ntop->getInterfaceById(ifid);
  return iface;
}

StoreManager::~StoreManager() {
  if(db) sqlite3_close(db);
}

/**
 * @brief Executes a database query on an already opened SQLite3 DB
 * @brief This function implements handling of a direct query on
 *        a SQLite3 database, hiding DB-specific syntax and error
 *        handling.
 *
 * @param db_query A string keeping the query to be executed.
 * @param callback Callback to be executed by the DB in case the query
 *                 execution is successful.
 * @param payload A pointer to be passed to the callback in case it
 *                is actually executed.
 *
 * @return Zero in case of success, nonzero in case of failure.
 */
int StoreManager::exec_query(char *db_query,
                             int (*callback)(void *, int, char **, char **),
                             void *payload) {
  char *zErrMsg = 0;

  if(!db) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Database not initialized.");
    return(-1);
  }

  if(sqlite3_exec(db, db_query, callback, payload, &zErrMsg)) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: %s", zErrMsg);
    ntop->getTrace()->traceEvent(TRACE_INFO, "Query: %s", db_query);
    sqlite3_free(zErrMsg);
    return 1;
  }

  return 0;
}

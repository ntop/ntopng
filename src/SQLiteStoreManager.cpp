/*
 *
 * (C) 2013-26 - ntop.org
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

/* **************************************************** */

SQLiteStoreManager::SQLiteStoreManager(NetworkInterface* _iface) : DB(_iface) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  db = NULL;
};

/* **************************************************** */

int SQLiteStoreManager::init(const char* db_file_full_path) {
  if (sqlite3_open(db_file_full_path, &db)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to open %s: %s",
                                 db_file_full_path, sqlite3_errmsg(db));
    db = NULL;
    return -1;
  }

  return 0;
}

/* **************************************************** */

SQLiteStoreManager::~SQLiteStoreManager() {
  if (db) sqlite3_close(db);
}

/* **************************************************** */

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
int SQLiteStoreManager::exec_query(const char* db_query,
                                   int (*callback)(void*, int, char**, char**),
                                   void* payload) {
  char* zErrMsg = 0;

  if (!db) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Database not initialized.");
    return (-1);
  }

  if (sqlite3_exec(db, db_query, callback, payload, &zErrMsg)) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: %s", zErrMsg);
    ntop->getTrace()->traceEvent(TRACE_INFO, "Query: %s", db_query);
    sqlite3_free(zErrMsg);
    return 1;
  }

  return 0;
}

/* **************************************************** */
/*
  Executes a prepared statements and retries a fixed number of times upon
  certain errors. This allows some errors to be recovered such as SQLITE_BUSY
  (5)

  See https://www.sqlite.org/rescode.html
*/
int SQLiteStoreManager::exec_statement(sqlite3_stmt* stmt) {
  int rc;
  int max_retries = 5;
  bool retry = true;

  for (int cur_retries = 0; cur_retries < max_retries && retry; cur_retries++) {
    rc = sqlite3_step(stmt);

    switch (rc) {
      case SQLITE_ERROR:
      case SQLITE_ROW:
      case SQLITE_OK:
      case SQLITE_DONE:
        /* Stop immediately upon error or completion */
        retry = false;
        break;
    }
  }

  /*
    There are only a few non-error result codes:
    SQLITE_OK, SQLITE_ROW, and SQLITE_DONE.

    See https://www.sqlite.org/rescode.html#done
  */
  if (rc != SQLITE_OK && rc != SQLITE_DONE && rc != SQLITE_ROW)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: [%d][%s (%d)]",
                                 /* sqlite3_errstr(rc), */ rc,
                                 sqlite3_errmsg(db), sqlite3_errcode(db));

  return rc;
}

/* **************************************************** */
/*
  Reclaims unused disk space and defragments tables and indices.
  Should be called as disk space and defragmentation are not run
  automatically by sqlite.
*/
int SQLiteStoreManager::optimizeStore() {
  char query[STORE_MANAGER_MAX_QUERY];
  int step;
  bool rc = false;
  sqlite3_stmt* stmt = NULL;

  m.lock(__FILE__, __LINE__);

  snprintf(query, sizeof(query), "VACUUM");

  if (sqlite3_prepare_v2(db, query, -1, &stmt, 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s",
                                 sqlite3_errmsg(db));
    goto out;
  }

  if ((step = exec_statement(stmt)) != SQLITE_DONE) {
    if (step != SQLITE_ERROR) rc = true;
  }

  sqlite3_reset(stmt);

#ifndef WIN32
  sync();
#endif

out:
  if (stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return (rc);
}

/* **************************************************** */

int SQLiteStoreManager::execFile(const char* path) {
  char schema_path[MAX_PATH], *schema;
  int rc;

  /* Read the database schema file */
  snprintf(schema_path, sizeof(schema_path), "%s/misc/%s", ntop->get_docs_dir(),
           path);
  ntop->fixPath(schema_path);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Processing %s", schema_path);

  std::ifstream schema_file(schema_path);
  std::string schema_contents((std::istreambuf_iterator<char>(schema_file)),
                              std::istreambuf_iterator<char>());

  /* Make sure the database is accessible */
  rc = exec_query((char*)"SELECT 1", NULL, NULL);

  if (rc)
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Cannot perform SELECT on the database [%s]",
                                 sqlite3_errmsg(db));

  schema = strdup(schema_contents.c_str());

  if (schema) {
    char *tmp, *query = strtok_r(schema, "@", &tmp);

    while (query) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s", query);

      /* Initialize the database with its schema that has just been read */
      rc = exec_query(query, NULL, NULL);

      if (rc) {
        const char* msg = sqlite3_errmsg(db);

        if (strstr(msg, "duplicate column name"))
          rc = 0; /* Silence ALTER TABLE errors */
        else
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "Unable to create database schema [%s]", msg);
      }

      query = strtok_r(NULL, "@", &tmp);
    }

    free(schema);
  }

  if (schema_file.is_open()) schema_file.close();

  return (rc);
}

/* **************************************************** */

struct SQLiteDataRetriever {
  lua_State* vm;
  u_int32_t current_offset;
};

static int process_sqlite_row(void* data, int argc, char** argv,
                              char** azColName) {
  SQLiteDataRetriever* ar = (SQLiteDataRetriever*)data;
  lua_State* vm = ar->vm;

  lua_newtable(vm);

  for (int i = 0; i < argc; i++)
    lua_push_str_table_entry(vm, azColName[i], argv[i]);

  lua_pushinteger(vm, ++ar->current_offset);
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  return 0;
}

/* **************************************************** */

int SQLiteStoreManager::execSQLWrite(const char* sql) {
  m.lock(__FILE__, __LINE__);
  int rc = exec_query(sql, NULL, NULL);
  m.unlock(__FILE__, __LINE__);
  return rc;
}

/* **************************************************** */

int SQLiteStoreManager::execSQLQuery(lua_State* vm, const char* sql,
                                     bool limitRows, bool wait_for_db_created) {
  int rc = SQLITE_ERROR;
  SQLiteDataRetriever ar;
  char* zErrMsg = NULL;

  m.lock(__FILE__, __LINE__);

  lua_newtable(vm);

  ar.vm = vm, ar.current_offset = 0;
  rc = sqlite3_exec(db, sql, process_sqlite_row, (void*)&ar, &zErrMsg);

  if (rc != SQLITE_OK) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s\n%s", zErrMsg,
                                 sql);
    lua_pushstring(vm, zErrMsg ? zErrMsg : "unknown error");
    sqlite3_free(zErrMsg);
  } else {
    lua_pushnil(vm); /* no error */
  }

  m.unlock(__FILE__, __LINE__);

  return (rc == SQLITE_OK ? 0 : -1);
}

/* **************************************************** */

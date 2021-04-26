/*
 *
 * (C) 2013-21 - ntop.org
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

AlertStore::AlertStore(int interface_id, const char *filename) : StoreManager(interface_id) {
  char filePath[MAX_PATH];

  /* Create the directories needed to keep the alerts database */
  snprintf(filePath, sizeof(filePath), "%s/%d/alerts/", ntop->get_working_dir(), ifid);
  ntop->fixPath(filePath);
  Utils::mkdir_tree(filePath);

  /* Prepare the alert database path */
  snprintf(filePath, sizeof(filePath), "%s/%d/alerts/%s", ntop->get_working_dir(), ifid, filename);
  ntop->fixPath(filePath);

  /* Initialize the alert database */
  store_initialized = init(filePath) == 0 ? true : false;
  if(!store_initialized)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to initialize store %s", filePath);

  store_opened = openStore() == 0 ? true : false;
  if(!store_opened)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to open store %s", filePath);
}

/* **************************************************** */

AlertStore::~AlertStore() {
}

/* **************************************************** */

int AlertStore::openStore() {
  int rc;
  char schema_path[MAX_PATH];

  if(!store_initialized)
    return 1;

  /* Read the database schema file */
  snprintf(schema_path, sizeof(schema_path), "%s/misc/%s", ntop->get_docs_dir(), ALERTS_STORE_SCHEMA_FILE_NAME);
  ntop->fixPath(schema_path);

  std::ifstream schema_file(schema_path);
  std::string schema_contents((std::istreambuf_iterator<char>(schema_file)), std::istreambuf_iterator<char>());

  m.lock(__FILE__, __LINE__);

  /* Make sure the database is accessible */
  rc = exec_query((char*)"SELECT 1", NULL, NULL);

  if(rc) ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot perform SELECT on the database [%s]", sqlite3_errmsg(db));

  /* Initialize the database with its schema that has just been read */
  rc = exec_query(schema_contents.c_str(), NULL, NULL);

  if(rc) ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create database schema [%s]", sqlite3_errmsg(db));

  m.unlock(__FILE__, __LINE__);

  if(schema_file.is_open()) schema_file.close();

  return rc;
}

/* ******************************************* */

struct alertsRetriever {
  lua_State *vm;
  u_int32_t current_offset;
};

static int getAlertsCallback(void *data, int argc, char **argv, char **azColName){
  alertsRetriever *ar = (alertsRetriever*)data;
  lua_State *vm = ar->vm;

  lua_newtable(vm);

  for(int i = 0; i < argc; i++){
    lua_push_str_table_entry(vm, azColName[i], argv[i]);
  }

  lua_pushinteger(vm, ++ar->current_offset);
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  return 0;
}

/* **************************************************** */

bool AlertStore::alert_store_query(lua_State *vm, const char * const query) {
  int rc = SQLITE_ERROR;

  if(!ntop->getPrefs()->are_alerts_disabled()) {
    alertsRetriever ar;
    char *zErrMsg = NULL;

    m.lock(__FILE__, __LINE__);

    lua_newtable(vm);

    ar.vm = vm, ar.current_offset = 0;
    rc = sqlite3_exec(db, query, getAlertsCallback, (void*)&ar, &zErrMsg);

    iface->incNumAlertsQueries();

    if(rc != SQLITE_OK){
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s\n%s", zErrMsg, query);
      sqlite3_free(zErrMsg);
    }

    m.unlock(__FILE__, __LINE__);
  }

  return rc == SQLITE_OK;
}

/* **************************************************** */

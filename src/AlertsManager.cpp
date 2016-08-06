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


AlertsManager::AlertsManager(int interface_id, const char *filename) : StoreManager(interface_id) {
  char filePath[MAX_PATH], fileFullPath[MAX_PATH], fileName[MAX_PATH];

  snprintf(filePath, sizeof(filePath), "%s/%d/alerts/",
           ntop->get_working_dir(), ifid);
  strncpy(fileName, filename, sizeof(fileName));
  snprintf(fileFullPath, sizeof(fileFullPath), "%s/%d/alerts/%s",
	   ntop->get_working_dir(), ifid, filename);
  ntop->fixPath(filePath);
  ntop->fixPath(fileFullPath);

  if(!Utils::mkdir_tree(filePath)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to create directory %s", filePath);
    return;
  }

  store_initialized = init(fileFullPath) == 0 ? true : false;
  store_opened      = openStore()        == 0 ? true : false;

  if(!store_initialized)
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to initialize store %s",
				 fileFullPath);
  if(!store_opened)
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to open store %s",
				 fileFullPath);
}

/* **************************************************** */

int AlertsManager::openStore() {
  char create_query[STORE_MANAGER_MAX_QUERY];
  int rc;

  if(!store_initialized)
    return 1;

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "alert_tstamp   INTEGER NOT NULL, "
	   "alert_type     INTEGER NOT NULL, "
	   "alert_severity INTEGER NOT NULL, "
	   "alert_json     TEXT "
	   ");"  // no need to create a primary key, sqlite has the rowid
	   , ALERTS_MANAGER_TABLE_NAME);

  m.lock(__FILE__, __LINE__);

  rc = exec_query(create_query, NULL, NULL);

  m.unlock(__FILE__, __LINE__);

  return rc;
}

/* **************************************************** */

int AlertsManager::storeAlert(AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc = 0;
  u_int now = (u_int)time(NULL);
  now = now - (now % 60);  // reduce the cardinality by doing minute bins
  
  if(!store_initialized || !store_opened)
    return -1;

  if(alert_json == NULL)
    alert_json = (char*)"";
  
  snprintf(query, sizeof(query), "INSERT INTO %s "
	   "(alert_tstamp, alert_type, alert_severity, alert_json) "
	   "VALUES(?,?,?,?)",
	   ALERTS_MANAGER_TABLE_NAME);

  m.lock(__FILE__, __LINE__);

  if(sqlite3_prepare(db, query, -1, &stmt, 0)
     || sqlite3_bind_int64(stmt, 1, static_cast<long int>(now))
     || sqlite3_bind_int(stmt,   2, static_cast<int>(alert_type))
     || sqlite3_bind_int(stmt,   3, static_cast<int>(alert_severity))
     || sqlite3_bind_text(stmt,  4, alert_json, strlen(alert_json), SQLITE_TRANSIENT)) {
    rc = 1;
    goto out;
  }

  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
      rc = 1;
      goto out;
    }
  }

  rc = 0;
 out:
  if (stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return rc;
}

/* **************************************************** */

int AlertsManager::storeAlert(lua_State *L, int index) {
  /*
    See https://www.lua.org/ftp/refman-5.0.pdf for a detailed description
    of lua traversal of tables
  */
  AlertType alert_type;
  AlertLevel alert_severity;
  json_object *my_object;
  char *json_alert_str = NULL;
  bool good_alert = true;
  bool alert_type_read, alert_severity_read;  /* mandatory fields  */
  alert_type_read = alert_severity_read = false;
  int retval = 0;

  if((my_object = json_object_new_object()) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Can't allocate memory.");
    retval = -1;
    goto cleanup;
  }
  
  lua_pushnil(L);
  while(lua_next(L, index) != 0 && good_alert) {
    if (strcmp("alert_type", lua_tostring(L, -2)) == 0) {
      if(lua_type(L, -1) == LUA_TNUMBER) {
	alert_type = (AlertType)lua_tointeger(L, -1);
	alert_type_read = true;
      } else {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "'alert_type' value is NaN.");
	good_alert = false;
	goto next_iter;
      }
    } else if (strcmp("alert_severity", lua_tostring(L, -2)) == 0) {
      if(lua_type(L, -1) == LUA_TNUMBER) {
	alert_severity = (AlertLevel)lua_tointeger(L, -1);
	alert_severity_read = true;
      } else {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "'alert_severity' value is NaN.");
	good_alert = false;
	goto next_iter;
      }
    }

    /* put everything, including the non mandatory parameters, in a json string */
    if(lua_type(L, -1) == LUA_TNUMBER) {
      /* could compact mandatory parameters here but prefer to have a more verbose error handling */
      json_object_object_add(my_object,
			     lua_tostring(L, -2),
			     json_object_new_int(lua_tointeger(L, -1)));
    } else if (lua_type(L, -1) == LUA_TSTRING) {
      json_object_object_add(my_object,
			     lua_tostring(L, -2),
			     json_object_new_string(lua_tostring(L, -1)));
    } else if (lua_type(L, -1) == LUA_TBOOLEAN) {
      json_object_object_add(my_object,
			     lua_tostring(L, -2),
			     json_object_new_boolean(lua_toboolean(L, -1)));
    } else {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Lua type not processed for %s.",
				   lua_tostring(L, -2));
    }
  next_iter:
    lua_pop(L, 1);
  }

  /* post-lua table iteration checks */
  if (!good_alert) {
    retval = -2;
    goto cleanup; /* error message already print  */
  } else if (!alert_type_read || ! alert_severity_read) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "One or more mandatory alert keys are missing.");
    retval = -3;
    goto cleanup;
  }

  json_alert_str = strdup(json_object_to_json_string(my_object));
  retval = storeAlert(alert_type, alert_severity, json_alert_str);
  
 cleanup:
  /* Free memory */
  if(my_object) json_object_put(my_object);
  if(json_alert_str) free(json_alert_str);

  return retval;
};

/*
 *
 * (C) 2013-17 - ntop.org
 *
 *o
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

  /* clean old databases */
  int base_offset = strlen(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v2.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v3.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v4.db");
  unlink(filePath);
  filePath[base_offset] = 0;

  /* open the newest */
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

  snprintf(queue_name, sizeof(queue_name), ALERTS_MANAGER_QUEUE_NAME, ifid);

  refreshCachedNumAlerts();
}

/* **************************************************** */

int AlertsManager::openStore() {
  char create_query[STORE_MANAGER_MAX_QUERY * 3];
  int rc;

  if(!store_initialized)
    return 1;

  /* cleanup old database files */

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "alert_tstamp     INTEGER NOT NULL, "
	   "alert_tstamp_end INTEGER DEFAULT NULL, "
	   "alert_type       INTEGER NOT NULL, "
	   "alert_severity   INTEGER NOT NULL, "
	   "alert_entity     INTEGER NOT NULL, "
	   "alert_entity_val TEXT NOT NULL,    "
	   "alert_origin     TEXT DEFAULT NULL,"
	   "alert_target     TEXT DEFAULT NULL,"
	   "alert_json       TEXT DEFAULT NULL "
	   "); "  // no need to create a primary key, sqlite has the rowid
	   "CREATE INDEX IF NOT EXISTS t1i_tstamp   ON %s(alert_tstamp); "
	   "CREATE INDEX IF NOT EXISTS t1i_tstamp_e ON %s(alert_tstamp_end); "
	   "CREATE INDEX IF NOT EXISTS t1i_type     ON %s(alert_type); "
	   "CREATE INDEX IF NOT EXISTS t1i_severity ON %s(alert_severity); "
	   "CREATE INDEX IF NOT EXISTS t1i_origin   ON %s(alert_origin); "
	   "CREATE INDEX IF NOT EXISTS t1i_target   ON %s(alert_target); "
	   "CREATE INDEX IF NOT EXISTS t1i_entity   ON %s(alert_entity, alert_entity_val); ",
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME,
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME,
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME);
  m.lock(__FILE__, __LINE__);
  rc = exec_query(create_query, NULL, NULL);
  m.unlock(__FILE__, __LINE__);

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "alert_id         TEXT NOT NULL, "
	   "alert_engine     INTEGER NOT NULL, "
	   "alert_tstamp     INTEGER NOT NULL, "
	   "alert_type       INTEGER NOT NULL, "
	   "alert_severity   INTEGER NOT NULL, "
	   "alert_entity     INTEGER NOT NULL, "
	   "alert_entity_val TEXT NOT NULL,    "
	   "alert_origin     TEXT DEFAULT NULL,"
	   "alert_target     TEXT DEFAULT NULL,"
	   "alert_json       TEXT DEFAULT NULL "
	   ");"
	   "CREATE INDEX IF NOT EXISTS t2i_engine   ON %s(alert_engine); "
	   "CREATE INDEX IF NOT EXISTS t2i_tstamp   ON %s(alert_tstamp); "
	   "CREATE INDEX IF NOT EXISTS t2i_type     ON %s(alert_type); "
	   "CREATE INDEX IF NOT EXISTS t2i_severity ON %s(alert_severity); "
	   "CREATE INDEX IF NOT EXISTS t2i_origin   ON %s(alert_origin); "
	   "CREATE INDEX IF NOT EXISTS t2i_target   ON %s(alert_target); "
	   "CREATE UNIQUE INDEX IF NOT EXISTS t2i_u ON %s(alert_engine, alert_entity, alert_entity_val, alert_id); ",
	   ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME,
	   ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME,
	   ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME);
  m.lock(__FILE__, __LINE__);
  rc = exec_query(create_query, NULL, NULL);
  m.unlock(__FILE__, __LINE__);

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "alert_tstamp     INTEGER NOT NULL, "
	   "alert_type       INTEGER NOT NULL, "
	   "alert_severity   INTEGER NOT NULL, "
	   "alert_json       TEXT DEFAULT NULL, "
	   "vlan_id          INTEGER NOT NULL DEFAULT 0, "
	   "proto            INTEGER NOT NULL DEFAULT 0, "
	   "l7_proto         INTEGER NOT NULL DEFAULT %u, "
	   "first_switched   INTEGER NOT NULL DEFAULT 0, "
	   "last_switched    INTEGER NOT NULL DEFAULT 0, "
	   "cli_country      TEXT DEFAULT NULL, "
	   "srv_country      TEXT DEFAULT NULL, "
	   "cli_os           TEXT DEFAULT NULL, "
	   "srv_os           TEXT DEFAULT NULL, "
	   "cli_asn          TEXT DEFAULT NULL, "
	   "srv_asn          TEXT DEFAULT NULL, "
	   "cli_addr         TEXT DEFAULT NULL, "
	   "srv_addr         TEXT DEFAULT NULL, "
	   "cli_port         INTEGER NOT NULL DEFAULT 0, "
	   "srv_port         INTEGER NOT NULL DEFAULT 0, "
	   "cli2srv_bytes    INTEGER NOT NULL DEFAULT 0, "
	   "srv2cli_bytes    INTEGER NOT NULL DEFAULT 0, "
	   "cli2srv_packets  INTEGER NOT NULL DEFAULT 0, "
	   "srv2cli_packets  INTEGER NOT NULL DEFAULT 0, "
	   "cli2srv_tcpflags INTEGER DEFAULT NULL, "
	   "srv2cli_tcpflags INTEGER DEFAULT NULL, "
	   "cli_blacklisted  INTEGER NOT NULL DEFAULT 0, "
	   "srv_blacklisted  INTEGER NOT NULL DEFAULT 0, "
	   "cli_localhost    INTEGER NOT NULL DEFAULT 0, "
	   "srv_localhost    INTEGER NOT NULL DEFAULT 0 "
	   ");"
	   "CREATE INDEX IF NOT EXISTS t3i_tstamp    ON %s(alert_tstamp); "
	   "CREATE INDEX IF NOT EXISTS t3i_type      ON %s(alert_type); "
	   "CREATE INDEX IF NOT EXISTS t3i_severity  ON %s(alert_severity); "
	   "CREATE INDEX IF NOT EXISTS t3i_vlanid    ON %s(vlan_id); "
	   "CREATE INDEX IF NOT EXISTS t3i_proto     ON %s(proto); "
	   "CREATE INDEX IF NOT EXISTS t3i_l7proto   ON %s(l7_proto); "
	   "CREATE INDEX IF NOT EXISTS t3i_fswitched ON %s(first_switched); "
	   "CREATE INDEX IF NOT EXISTS t3i_lswitched ON %s(last_switched); "
	   "CREATE INDEX IF NOT EXISTS t3i_ccountry  ON %s(cli_country); "
	   "CREATE INDEX IF NOT EXISTS t3i_scountry  ON %s(srv_country); "
	   "CREATE INDEX IF NOT EXISTS t3i_cos       ON %s(cli_os); "
	   "CREATE INDEX IF NOT EXISTS t3i_sos       ON %s(srv_os); "
	   "CREATE INDEX IF NOT EXISTS t3i_casn      ON %s(cli_asn); "
	   "CREATE INDEX IF NOT EXISTS t3i_sasn      ON %s(srv_asn); "
	   "CREATE INDEX IF NOT EXISTS t3i_caddr     ON %s(cli_addr); "
	   "CREATE INDEX IF NOT EXISTS t3i_saddr     ON %s(srv_addr); "
	   "CREATE INDEX IF NOT EXISTS t3i_cport     ON %s(cli_port); "
	   "CREATE INDEX IF NOT EXISTS t3i_sport     ON %s(srv_port); "
	   "CREATE INDEX IF NOT EXISTS t3i_clocal    ON %s(cli_localhost); "
	   "CREATE INDEX IF NOT EXISTS t3i_slocal    ON %s(srv_localhost); ",
	   ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   NDPI_PROTOCOL_UNKNOWN,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME);
  m.lock(__FILE__, __LINE__);
  rc = exec_query(create_query, NULL, NULL);
  m.unlock(__FILE__, __LINE__);

  return rc;
}

/* **************************************************** */
#ifdef NOTUSED
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
     || sqlite3_bind_text(stmt,  4, alert_json, -1, SQLITE_STATIC)) {
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
  if(stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return rc;
}

/* **************************************************** */

int AlertsManager::storeAlert(lua_State *L, int index) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
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
      if(strcmp(ALERTS_MANAGER_TYPE_FIELD, lua_tostring(L, -2)) == 0) {
	if(lua_type(L, -1) == LUA_TNUMBER) {
	  alert_type = (AlertType)lua_tointeger(L, -1);
	  alert_type_read = true;
	} else {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "'%s' value is NaN.",
				       ALERTS_MANAGER_TYPE_FIELD);
	  good_alert = false;
	  goto next_iter;
	}
      } else if(strcmp(ALERTS_MANAGER_SEVERITY_FIELD, lua_tostring(L, -2)) == 0) {
	if(lua_type(L, -1) == LUA_TNUMBER) {
	  alert_severity = (AlertLevel)lua_tointeger(L, -1);
	  alert_severity_read = true;
	} else {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "'%s' value is NaN.",
				       ALERTS_MANAGER_SEVERITY_FIELD);
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
      } else if(lua_type(L, -1) == LUA_TSTRING) {
	json_object_object_add(my_object,
			       lua_tostring(L, -2),
			       json_object_new_string(lua_tostring(L, -1)));
      } else if(lua_type(L, -1) == LUA_TBOOLEAN) {
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
    if(!good_alert) {
      retval = -2;
      goto cleanup; /* error message already print  */
    } else if(!alert_type_read || ! alert_severity_read) {
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
  } else
    return(0);
};
#endif

/* **************************************************** */

bool AlertsManager::isAlertEngaged(AlertEngine alert_engine, AlertEntity alert_entity, const char *alert_entity_value, const char *engaged_alert_id,
		  AlertType *alert_type, AlertLevel *alert_severity, char **alert_json, char **alert_source, char **alert_target, time_t *alert_tstamp) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc;
  bool found = false;

  snprintf(query, sizeof(query),
	   "SELECT alert_type, alert_severity, alert_json, alert_origin, alert_target, alert_tstamp "
	   "FROM %s "
	   "WHERE alert_entity = ? AND alert_entity_val = ? AND alert_id = ? AND alert_engine = ? ",
           ALERTS_MANAGER_ENGAGED_TABLE_NAME);

  m.lock(__FILE__, __LINE__);
  if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare statement for query %s.", query);
    goto out;
  } else if(sqlite3_bind_int(stmt,   1, static_cast<int>(alert_entity))
	    || sqlite3_bind_text(stmt,  2, alert_entity_value, -1, SQLITE_STATIC)
	    || sqlite3_bind_text(stmt,  3, engaged_alert_id, -1, SQLITE_STATIC)
	    || sqlite3_bind_int(stmt,   4, static_cast<int>(alert_engine))
	    ) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind values to prepared statement for query %s.", query);
    goto out;
  }

  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if(rc == SQLITE_ROW) {
      if(found) {
        /* Already reached */
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Multiple results returned by SQLite, query='%s'", query);
        goto out;
      }

      found = true;
      if(alert_type)  *alert_type = (AlertType)sqlite3_column_int(stmt, 0);
      if(alert_severity) *alert_severity = (AlertLevel)sqlite3_column_int(stmt, 1);
      if(alert_json) *alert_json = strdup((char*)sqlite3_column_text(stmt, 2));
      if(alert_source) *alert_source = sqlite3_column_text(stmt, 3) ? strdup((char*)sqlite3_column_text(stmt, 3)) : NULL;
      if(alert_target) *alert_target = sqlite3_column_text(stmt, 4) ? strdup((char*)sqlite3_column_text(stmt, 4)) : NULL;
      if(alert_tstamp) *alert_tstamp = sqlite3_column_int64(stmt, 5);

#if 0
      printf("isAlertEngaged: entity=%d entity_val=%s alert_id=%s engine=%d"
            " -> type=%d severity=%d json='%s' source=%s target=%s tstamp=%lu\n",
            alert_entity, alert_entity_value, engaged_alert_id, alert_engine,
            *alert_type, *alert_severity, *alert_json, *alert_source, *alert_target, *alert_tstamp);
#endif
    } else if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
      rc = 1;
      goto out;
    }
  }

 out:
  if(stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return found;
}

/* **************************************************** */

void AlertsManager::markForMakeRoom(bool on_flows) {
  Redis *r = ntop->getRedis();
  char k[128], buf[512];

  if(!r) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to get a valid Redis instances");
    return;
  }

  if(on_flows)
    snprintf(k, sizeof(k), ALERTS_MANAGER_MAKE_ROOM_FLOW_ALERTS, ifid);
  else
    snprintf(k, sizeof(k), ALERTS_MANAGER_MAKE_ROOM_ALERTS, ifid);

  if(r->get(k, buf, sizeof(buf)) < 0 || buf[0] == 0) {
    snprintf(buf, sizeof(buf), (char*)"1");
    r->set(k, buf);
  } else {
    /* Already set */;
  }
}

/* **************************************************** */

int AlertsManager::engageAlert(AlertEngine alert_engine, AlertEntity alert_entity, const char *alert_entity_value,
			       const char *engaged_alert_id,
			       AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
			       const char *alert_origin, const char *alert_target) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc = 0;

    if(!store_initialized || !store_opened)
      return -1;

    if(isAlertEngaged(alert_engine, alert_entity, alert_entity_value, engaged_alert_id, NULL, NULL, NULL, NULL, NULL, NULL)) {
      rc = 1; /* Already engaged */
    } else {
      if(getNetworkInterface() && (alert_severity == alert_level_error))
	getNetworkInterface()->incAlertLevel();
      /* This alert is being engaged */

      snprintf(query, sizeof(query),
	       "REPLACE INTO %s "
	       "(alert_id, alert_engine, alert_tstamp, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json, "
	       "alert_origin, alert_target) "
	       "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?); ",
	       ALERTS_MANAGER_ENGAGED_TABLE_NAME);

      m.lock(__FILE__, __LINE__);

      if(sqlite3_prepare(db, query, -1,  &stmt, 0)
	 || sqlite3_bind_text(stmt,  1,  engaged_alert_id, -1, SQLITE_STATIC)
	 || sqlite3_bind_int(stmt,   2,  static_cast<int>(alert_engine))
	 || sqlite3_bind_int64(stmt, 3,  static_cast<long int>(time(NULL)))
	 || sqlite3_bind_int(stmt,   4,  static_cast<int>(alert_type))
	 || sqlite3_bind_int(stmt,   5,  static_cast<int>(alert_severity))
	 || sqlite3_bind_int(stmt,   6,  static_cast<int>(alert_entity))
	 || sqlite3_bind_text(stmt,  7,  alert_entity_value, -1, SQLITE_STATIC)
	 || sqlite3_bind_text(stmt,  8,  alert_json, -1, SQLITE_STATIC)
	 || sqlite3_bind_text(stmt,  9,  alert_origin, -1, SQLITE_STATIC)
	 || sqlite3_bind_text(stmt,  10, alert_target, -1, SQLITE_STATIC)) {
	rc = -2;
	goto out;
      }

      while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
	if(rc == SQLITE_ERROR) {
	  ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
	  rc = -3;
	  goto out;
	}
      }

      num_alerts_engaged++;
      rc = 0;
    out:
      if(stmt) sqlite3_finalize(stmt);
      m.unlock(__FILE__, __LINE__);

      notifySlack(alert_entity, alert_entity_value, engaged_alert_id,
		  alert_type, alert_severity, alert_json,
		  alert_origin, alert_target, true);
    }

    return rc;
  } else
    return 0;
}

/* **************************************************** */

int AlertsManager::releaseAlert(AlertEngine alert_engine,
				AlertEntity alert_entity, const char *alert_entity_value,
				const char *engaged_alert_id) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc = 0;
    time_t alert_tstamp;
    AlertType alert_type;
    AlertLevel alert_severity;
    char *alert_json, *alert_origin, *alert_target;

    if(!store_initialized || !store_opened)
      return -1;

    if(!isAlertEngaged(alert_engine, alert_entity, alert_entity_value, engaged_alert_id,
          &alert_type, &alert_severity, &alert_json, &alert_origin, &alert_target, &alert_tstamp)) {
      /* Cannot release an alert that has not been engaged */
      return 1;
    } else
      markForMakeRoom(false);

    if(getNetworkInterface())
      getNetworkInterface()->decAlertLevel();

    notifySlack(alert_entity, alert_entity_value, engaged_alert_id,
          alert_type, alert_severity, alert_json,
          alert_origin, alert_target, false);
  
    /* Move the alert from engaged to closed */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_tstamp, alert_tstamp_end, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json, "
	     "alert_origin, alert_target) "
       "VALUES (?, strftime('%%s','now'), ?, ?, ?, ?, ?, ?, ?)",
	     ALERTS_MANAGER_TABLE_NAME);

    m.lock(__FILE__, __LINE__);

    if(sqlite3_prepare(db, query, -1, &stmt, 0)
       || sqlite3_bind_int64(stmt, 1,  static_cast<long int>(alert_tstamp))
       || sqlite3_bind_int(stmt,   2,  static_cast<int>(alert_type))
       || sqlite3_bind_int(stmt,   3,  static_cast<int>(alert_severity))
       || sqlite3_bind_int(stmt,   4,  static_cast<int>(alert_entity))
       || sqlite3_bind_text(stmt,  5,  alert_entity_value, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  6,  alert_json, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  7,  alert_origin, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  8, alert_target, -1, SQLITE_STATIC)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind values to prepared statement for query %s.", query);
      rc = -1;
      goto out;
    }

    while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
      if(rc == SQLITE_ERROR) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
	rc = -2;
	goto out;
      }
    }
    m.unlock(__FILE__, __LINE__);


    /* remove the alert from those engaged */
    if(stmt) sqlite3_finalize(stmt);
    stmt = NULL;
    snprintf(query, sizeof(query),
	     "DELETE "
	     "FROM %s "
	     "WHERE alert_engine = ? AND alert_entity = ? AND alert_entity_val = ? AND alert_id = ? ",
	     ALERTS_MANAGER_ENGAGED_TABLE_NAME);

    m.lock(__FILE__, __LINE__);
    if(sqlite3_prepare(db, query, -1, &stmt, 0)
       || sqlite3_bind_int(stmt,   1, static_cast<int>(alert_engine))
       || sqlite3_bind_int(stmt,   2, static_cast<int>(alert_entity))
       || sqlite3_bind_text(stmt,  3, alert_entity_value, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  4, engaged_alert_id, -1, SQLITE_STATIC)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind values to prepared statement for query %s.", query);
      rc = -3;
      goto out;
    }

    while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
      if(rc == SQLITE_ERROR) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
	rc = -4;
	goto out;
      }
    }

    num_alerts_engaged--;
    rc = 0;
  
  out:
    /* Free data allocated into isAlertEngaged */
    if(alert_json) free(alert_json);
    if(alert_origin) free(alert_origin);
    if(alert_target) free(alert_target);

    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);
    return rc;
  } else
    return(0);
}

/* **************************************************** */

const char* AlertsManager::getAlertEntity(AlertEntity alert_entity) {
  switch (alert_entity) {
  case alert_entity_interface:   return("#interface");
  case alert_entity_host:        return("#host");
  case alert_entity_network:     return("#network");
  case alert_entity_snmp_device: return("#snmp");
  case alert_entity_flow:        return("#flow");
  }

  return(""); /* NOTREACHED */
}

/* **************************************************** */

const char* AlertsManager::getAlertLevel(AlertLevel alert_severity) {
  switch(alert_severity) {
  case alert_level_info:    return(":information_source:");
  case alert_level_warning: return(":warning:");
  case alert_level_error:   return(":exclamation:");
  }

  return(""); /* NOTREACHED */
}

/* **************************************************** */

/* Note: keep in sync with lua  */
const char* AlertsManager::getAlertType(AlertType alert_type) {
  switch(alert_type) {
  case alert_none:                   return("No alert");
  case alert_syn_flood:              return("TCP SYN Flood");
  case alert_flow_flood:             return("Flows Flood");
  case alert_threshold_exceeded:     return("Threshold Cross");
  case alert_dangerous_host:         return("Blacklisted Host");
  case alert_periodic_activity:      return("Periodic activity");
  case alert_quota:                  return("Quota Exceeded");
  case alert_malware_detection:      return("Malware Detected");
  case alert_host_under_attack:      return("Under Attack");
  case alert_host_attacker:          return("Ongoing Attacker");
  case alert_app_misconfiguration:   return("Misconfigured App");
  case alert_suspicious_activity:    return("Suspicious Activity");
  case alert_too_many_alerts:        return("Too Many Alerts");
  case alert_db_misconfiguration:    return("MySQL open_files_limit too small");
  case alert_interface_alerted:      return("Interface Alerted");
  case alert_flow_misbehaviour:      return("Flow Misbehaviour");
  }

  return(""); /* NOTREACHED */
}

/* **************************************************** */

SlackNotificationChoice AlertsManager::getSlackNotificationChoice(char* choice) {
  if(strcmp(choice, "only_errors") == 0)         return notify_errors_only;
  if(strcmp(choice, "errors_and_warnings") == 0) return notify_errors_and_warnings;

  return notify_all_alerts; /* default choice */
}

/* **************************************************** */

void AlertsManager::notifyAlert(AlertEntity alert_entity, const char *alert_entity_value,
				const char *engaged_alert_id,
				AlertType alert_type, AlertLevel alert_severity,
				const char *alert_json,
				const char *alert_origin, const char *alert_target,
        bool engage) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    json_object *notification;
    char alert_sender_name[64], message[1024], notification_username[96];
    const char *json_alert, *level;

    if((notification = json_object_new_object()) == NULL) return;

    json_object_object_add(notification, "channel",
			   json_object_new_string(getAlertEntity(alert_entity)));
    json_object_object_add(notification, "icon_emoji",
			   json_object_new_string(getAlertLevel(alert_severity)));

    if(ntop->getRedis()->get((char*)ALERTS_MANAGER_SENDER_USERNAME,
			     alert_sender_name, sizeof(alert_sender_name)) >= 0) {    
      switch(alert_severity) {
      case alert_level_error:   level = "ERROR";   break;
      case alert_level_warning: level = "WARNING"; break;
      case alert_level_info:    level = "INFO";    break;
      }

      snprintf(notification_username, sizeof(notification_username),
	       "%s [%s]", alert_sender_name, level);

      json_object_object_add(notification, "username",
			     json_object_new_string(notification_username));
    }

    /* Initial information */
    size_t len = snprintf(message, sizeof(message), "%s[%s] ",
       engaged_alert_id ? (engage ? "Alert Engaged " : "Alert Released ") : "",
       getAlertType(alert_type));

    if ((alert_json != NULL) && (alert_json[0] != '\0')) {
      /* A message has been provided - convert HTML characters to slack format */
      int open_tags = 0;
      int j = len;

      for (int i=0; (alert_json[i] != '\0') && (j < (int)sizeof(message)); i++) {
        if (alert_json[i] == '<')
          open_tags++;
        else if (alert_json[i] == '>')
          open_tags--;
        else if (! open_tags)
          message[j++] = alert_json[i];
      }

      message[j] = '\0';
    } else {
      /* Use a standard message */
      snprintf(&message[len], sizeof(message)-len, "[%s][%s][Origin: %s][Target: %s]",
        alert_entity_value ? alert_entity_value : "",
        engaged_alert_id ? engaged_alert_id : "",
        alert_origin ? alert_origin : "",
        alert_target ? alert_target : "");
    }

    json_object_object_add(notification, "text", json_object_new_string(message));

    json_alert = json_object_to_json_string(notification);

    if(ntop->getRedis()->lpush(ALERTS_MANAGER_NOTIFICATION_QUEUE_NAME,
			       (char*)json_alert, ALERTS_MANAGER_MAX_ENTITY_ALERTS) < 0)
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "An error occurred when pushing alert %s to redis list %s.",
				   json_alert, ALERTS_MANAGER_NOTIFICATION_QUEUE_NAME);

    /* Free memory */
    json_object_put(notification);
  }
}

/* **************************************************** */

void AlertsManager::notifySlack(AlertEntity alert_entity, const char *alert_entity_value,
				const char *engaged_alert_id,
				AlertType alert_type, AlertLevel alert_severity,
				const char *alert_json,
				const char *alert_origin, const char *alert_target,
				bool engage) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char choice[32];
    bool alert_to_be_notified = false;
    SlackNotificationChoice notification_choice;

    if(ntop->getPrefs()->are_slack_notification_enabled()) {
      ntop->getRedis()->get((char*) ALERTS_MANAGER_NOTIFICATION_SEVERITY, choice, sizeof(choice));

      notification_choice = getSlackNotificationChoice(choice);

      if(notification_choice == notify_all_alerts)
	alert_to_be_notified=true;
      else if(notification_choice == notify_errors_and_warnings) {
	if((alert_severity == alert_level_error) || (alert_severity == alert_level_warning))
	  alert_to_be_notified = true;
      } else {
	if((notification_choice == notify_errors_only) && (alert_severity == alert_level_error))
	  alert_to_be_notified = true;
      }

      if(alert_to_be_notified)
	notifyAlert(alert_entity, alert_entity_value, engaged_alert_id,
		    alert_type, alert_severity, alert_json,
		    alert_origin, alert_target, engage);
    }
  }
}

/* **************************************************** */

int AlertsManager::storeAlert(AlertEntity alert_entity, const char *alert_entity_value,
			      AlertType alert_type, AlertLevel alert_severity,
			      const char *alert_json,
			      const char *alert_origin, const char *alert_target,
			      bool check_maximum) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc = 0;

    if(!store_initialized || !store_opened)
      return(-1);
    else if(check_maximum)
      markForMakeRoom(false);

    /* This alert is being engaged */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_tstamp, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json, "
	     "alert_origin, alert_target) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_TABLE_NAME);

    m.lock(__FILE__, __LINE__);

    if(sqlite3_prepare(db, query, -1, &stmt, 0)
       || sqlite3_bind_int64(stmt, 1, static_cast<long int>(time(NULL)))
       || sqlite3_bind_int(stmt,   2, static_cast<int>(alert_type))
       || sqlite3_bind_int(stmt,   3, static_cast<int>(alert_severity))
       || sqlite3_bind_int(stmt,   4, static_cast<int>(alert_entity))
       || sqlite3_bind_text(stmt,  5, alert_entity_value, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  6, alert_json, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  7, alert_origin, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  8, alert_target, -1, SQLITE_STATIC)) {
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

    alerts_stored = true;
    rc = 0;

  out:
    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);

    return rc;
  } else
    return(-1);
}

/* **************************************************** */

int AlertsManager::storeFlowAlert(Flow *f, AlertType alert_type,
				  AlertLevel alert_severity,
				  const char *alert_json) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc = 0;
    Host *cli, *srv;
    char *cli_ip = NULL, *cli_ip_buf = NULL, *srv_ip = NULL, *srv_ip_buf = NULL;

    if(!store_initialized || !store_opened || !f)
      return(-1);

    markForMakeRoom(true);

    cli = f->get_cli_host(), srv = f->get_srv_host();
    if(cli && cli->get_ip() && (cli_ip_buf = (char*)malloc(sizeof(char) * 256)))
      cli_ip = cli->get_ip()->print(cli_ip_buf, 256);
    if(srv && srv->get_ip() && (srv_ip_buf = (char*)malloc(sizeof(char) * 256)))
      srv_ip = srv->get_ip()->print(srv_ip_buf, 256);

    notifySlack(alert_entity_flow, "flow", NULL,
		alert_type, alert_severity, alert_json,
		cli_ip, srv_ip, false);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s %s", cli_ip, srv_ip);
    /* TODO: implement check maximum for flow alerts
       else if(check_maximum && isMaximumReached(alert_entity, alert_entity_value, false))
       deleteOldestAlert(alert_entity, alert_entity_value, false);
    */

    /* This alert is being engaged */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_tstamp, alert_type, alert_severity, alert_json, "
	     "vlan_id, proto, l7_proto, first_switched, last_switched, "
	     "cli_country, srv_country, cli_os, srv_os, cli_asn, srv_asn, "
	     "cli_addr, srv_addr, cli_port, srv_port, "
	     "cli2srv_bytes, srv2cli_bytes, "
	     "cli2srv_packets, srv2cli_packets, "
	     "cli2srv_tcpflags, srv2cli_tcpflags, cli_blacklisted, srv_blacklisted, "
	     "cli_localhost, srv_localhost) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME);

    m.lock(__FILE__, __LINE__);

    if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare the statement for %s", query);
      rc = 3;
      goto out;
    }

    if(sqlite3_bind_int64(stmt, 1, static_cast<long int>(time(NULL)))
       || sqlite3_bind_int(stmt,   2, (int)(alert_type))
       || sqlite3_bind_int(stmt,   3, (int)(alert_severity))
       || sqlite3_bind_text(stmt,  4, alert_json, -1, SQLITE_STATIC)
       || sqlite3_bind_int(stmt,   5, f->get_vlan_id())
       || sqlite3_bind_int(stmt,   6, f->get_protocol())
       || sqlite3_bind_int(stmt,   7, f->get_detected_protocol().app_protocol)
       || sqlite3_bind_int(stmt,   8, f->get_first_seen())
       || sqlite3_bind_int(stmt,   9, f->get_last_seen())
       || sqlite3_bind_text(stmt, 10, cli ? cli->get_country() : NULL, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt, 11, srv ? srv->get_country() : NULL, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt, 12, cli ? cli->get_os() : NULL, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt, 13, srv ? srv->get_os() : NULL, -1, SQLITE_STATIC)
       || sqlite3_bind_int(stmt,  14, cli ? cli->get_asn() : 0)
       || sqlite3_bind_int(stmt,  15, srv ? srv->get_asn() : 0)
       || sqlite3_bind_text(stmt, 16, cli_ip, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt, 17, srv_ip, -1, SQLITE_STATIC)
       || sqlite3_bind_int(stmt,  18, f->get_cli_port())
       || sqlite3_bind_int(stmt,  19, f->get_srv_port())
       || sqlite3_bind_int64(stmt,20, f->get_bytes_cli2srv())
       || sqlite3_bind_int64(stmt,21, f->get_bytes_srv2cli())
       || sqlite3_bind_int64(stmt,22, f->get_packets_cli2srv())
       || sqlite3_bind_int64(stmt,23, f->get_packets_srv2cli())
       || sqlite3_bind_int(stmt,  24, f->getTcpFlagsCli2Srv())
       || sqlite3_bind_int(stmt,  25, f->getTcpFlagsSrv2Cli())
       || sqlite3_bind_int(stmt,  26, (cli && cli->isBlacklisted()) ? 1 : 0)
       || sqlite3_bind_int(stmt,  27, (srv && srv->isBlacklisted()) ? 1 : 0)
       || sqlite3_bind_int(stmt,  28, (cli && cli->isLocalHost()) ? 1 : 0)
       || sqlite3_bind_int(stmt,  29, (srv && srv->isLocalHost()) ? 1 : 0)
       ) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind to arguments to %s", query);
      rc = 2;
      goto out;
    }

    while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
      if(rc == SQLITE_ERROR) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: step [%s]", query);
	rc = 1;
	goto out;
      }
    }

    alerts_stored = true;
    rc = 0;
  out:
    if(cli_ip_buf) free(cli_ip_buf);
    if(srv_ip_buf) free(srv_ip_buf);

    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);

    f->setFlowAlerted();
  
    return rc;
  } else
    return(-1);
}

/* ******************************************* */

bool AlertsManager::isValidHost(Host *h, char *host_string, size_t host_string_len) {
  char ipbuf[256];

  if(!h) return false;

  IpAddress *ip = h->get_ip();
  if(!ip) return false;

  snprintf(host_string, host_string_len, "%s@%i", ip->print(ipbuf, sizeof(ipbuf)), h->get_vlan_id());

  return true;
}

/* ******************************************* */

int AlertsManager::engageReleaseHostAlert(const char *host_ip, u_int16_t host_vlan,
					  AlertEngine alert_engine,
					  const char *engaged_alert_id,
					  AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
					  const char *alert_origin, const char *alert_target,
					  bool engage) {
  char counters_key[64], ipbuf_id[64], rsp[16];
  int rc;
  Host *h;
  NetworkInterface *iface = getNetworkInterface();
  snprintf(ipbuf_id, sizeof(ipbuf_id), "%s@%d", host_ip, host_vlan);
  int num_alerts;

  if(engage) {
    rc = engageAlert(alert_engine, alert_entity_host, ipbuf_id,
		     engaged_alert_id, alert_type, alert_severity, alert_json,
		     alert_origin, alert_target);
  } else {
    rc = releaseAlert(alert_engine, alert_entity_host, ipbuf_id,
		      engaged_alert_id);
  }

  if (rc != 0)
    /* error */
    return rc;

  /* Read current value from redis */
  snprintf(counters_key, sizeof(counters_key), CONST_HOSTS_ALERT_COUNTERS, iface->get_id());

  if(ntop->getRedis()->hashGet(counters_key, ipbuf_id, rsp, sizeof(rsp)) == 0)
    num_alerts = atoi(rsp);
  else
    num_alerts = 0;

  if(engage)
    num_alerts++;
  else
    num_alerts--;

  if(num_alerts < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Internal error, negative engaged alerts counter detected [host: %s].",
				 ipbuf_id);

  /* Dump new value to redis */
  if (num_alerts > 0) {
    snprintf(rsp, sizeof(rsp), "%d", num_alerts);
    ntop->getRedis()->hashSet(counters_key, ipbuf_id, rsp);
  } else
    ntop->getRedis()->hashDel(counters_key, ipbuf_id);

  /* Update host */
  h = iface->getHost((char*)host_ip, host_vlan);
  if (h)
    h->setNumAlerts(num_alerts);

  return rc;
};

/* ******************************************* */

int AlertsManager::engageReleaseNetworkAlert(const char *cidr,
					     AlertEngine alert_engine,
					     const char *engaged_alert_id,
					     AlertType alert_type, AlertLevel alert_severity,
					     const char *alert_json, bool engage) {
  struct in_addr addr4;
  struct in6_addr addr6;
  char ip_buf[256];
  char *slash;

  if(!cidr) return -1;

  strncpy(ip_buf, cidr, sizeof(ip_buf));
  if((slash = strchr(ip_buf, '/')) == NULL) return -2;
  slash[0] = '\0';

  if(inet_pton(AF_INET, ip_buf, &addr4) != 1 && inet_pton(AF_INET6, ip_buf, &addr6) != 1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing network %s\n", cidr);
    return -2; /* not a valid network */
  }

  if(engage)
    return engageAlert(alert_engine, alert_entity_network, cidr,
		       engaged_alert_id, alert_type, alert_severity, alert_json, NULL, NULL);
  else
    return releaseAlert(alert_engine, alert_entity_network, cidr,
			engaged_alert_id);
};

/* ******************************************* */

int AlertsManager::engageReleaseInterfaceAlert(NetworkInterface *n,
					       AlertEngine alert_engine,
					       const char *engaged_alert_id,
					       AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
					       bool engage) {
  char id_buf[8];
  if(!n) return -1;

  snprintf(id_buf, sizeof(id_buf), "%u", n -> get_id());

  if(engage)
    return engageAlert(alert_engine, alert_entity_interface, id_buf,
		       engaged_alert_id, alert_type, alert_severity, alert_json, NULL, NULL);
  else
    return releaseAlert(alert_engine, alert_entity_interface, id_buf,
			engaged_alert_id);
};

/* ******************************************* */

int AlertsManager::storeHostAlert(Host *h,
				  AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
				  Host *alert_origin, Host *alert_target) {
  char ipbuf_id[256], ipbuf_origin[256], ipbuf_target[256];

  if(!isValidHost(h, ipbuf_id, sizeof(ipbuf_id)))
    return -1;

  return storeAlert(alert_entity_host, ipbuf_id, alert_type, alert_severity, alert_json,
		    isValidHost(alert_origin, ipbuf_origin, sizeof(ipbuf_origin)) ? ipbuf_origin : NULL,
		    isValidHost(alert_target, ipbuf_target, sizeof(ipbuf_target)) ? ipbuf_target : NULL,
		    true);
};

/* ******************************************* */

int AlertsManager::getHostAlerts(Host *h, lua_State* vm, AddressTree *allowed_hosts,
				 u_int32_t start_offset, u_int32_t end_offset,
				 bool engaged) {
  char ipbuf_id[256], wherebuf[256];
  if(!isValidHost(h, ipbuf_id, sizeof(ipbuf_id))) {
    lua_newtable(vm);
    return -1;
  }

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   " (alert_entity=%i AND alert_entity_val='%q') ",
		   static_cast<int>(alert_entity_host), ipbuf_id);

  return getAlerts(vm, allowed_hosts, start_offset, end_offset, engaged, wherebuf);
}

/* ******************************************* */

int AlertsManager::getHostAlerts(const char *host_ip, u_int16_t vlan_id,
				 lua_State* vm, AddressTree *allowed_hosts,
				 u_int32_t start_offset, u_int32_t end_offset,
				 bool engaged) {
  char wherebuf[256];
  if(!host_ip) {
    lua_newtable(vm);
    return -1;
  }

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   " (alert_entity=%i AND alert_entity_val='%q@%i') ",
		   static_cast<int>(alert_entity_host), host_ip, vlan_id);

  return getAlerts(vm, allowed_hosts, start_offset, end_offset, engaged, wherebuf);
}

/* ******************************************* */

int AlertsManager::getNumHostAlerts(const char *host_ip, u_int16_t vlan_id, bool engaged) {
  char wherebuf[256];
  if(!host_ip) {
    return -1;
  }

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   " (alert_entity=%i AND alert_entity_val='%q@%i') ",
		   static_cast<int>(alert_entity_host), host_ip, vlan_id);

  return getNumAlerts(engaged, static_cast<const char*>(wherebuf));
}

/* ******************************************* */

int AlertsManager::getNumHostAlerts(Host *h, bool engaged) {
  char wherebuf[256];
  char ipbuf_id[256];

  if(!isValidHost(h, ipbuf_id, sizeof(ipbuf_id)))
    return -1;

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   " (alert_entity=%i AND alert_entity_val='%q') ",
		   static_cast<int>(alert_entity_host), ipbuf_id);

  return getNumAlerts(engaged, static_cast<const char *>(wherebuf));
}

/* ******************************************* */

int AlertsManager::getNumHostFlowAlerts(const char *host_ip, u_int16_t vlan_id) {
  char wherebuf[256];

  if (! host_ip) return 0;

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   " (cli_addr='%q' OR srv_addr='%q') AND vlan_id=%i ",
		   host_ip, host_ip, vlan_id);

  return getNumFlowAlerts(wherebuf);
}

/* ******************************************* */

int AlertsManager::getNumHostFlowAlerts(Host *h) {
  char ipbuf_id[128], *ipaddr = (char*)"";

  if(!h)
    return -1;

  if(h->get_ip())
    ipaddr = h->get_ip()->print(ipbuf_id, sizeof(ipbuf_id));

  return getNumHostFlowAlerts(ipaddr, h->get_vlan_id());
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

  lua_pushnumber(vm, ++ar->current_offset);
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  return 0;
}

/* ******************************************* */

int AlertsManager::getAlerts(lua_State* vm, AddressTree *allowed_hosts,
			     u_int32_t start_offset, u_int32_t end_offset,
			     bool engaged, const char *sql_where_clause) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    alertsRetriever ar;
    char query[STORE_MANAGER_MAX_QUERY];
    char *zErrMsg = 0;
    int rc = 0;

    if(!store_initialized || !store_opened)
      return -1;

    snprintf(query, sizeof(query),
	     "SELECT rowid, alert_tstamp, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json %s "
	     "FROM %s "
	     "%s %s " /* optional where clause */
	     "ORDER BY alert_tstamp DESC LIMIT %u,%u",
	     engaged ? "" : ", alert_tstamp_end ",
	     engaged ? ALERTS_MANAGER_ENGAGED_TABLE_NAME : ALERTS_MANAGER_TABLE_NAME /* from */,
	     sql_where_clause ? (char*)"WHERE"  : "",
	     sql_where_clause ? sql_where_clause : "",
	     start_offset, end_offset - start_offset + 1);

    m.lock(__FILE__, __LINE__);

    lua_newtable(vm);

    ar.vm = vm, ar.current_offset = 0;
    rc = sqlite3_exec(db, query, getAlertsCallback, (void*)&ar, &zErrMsg);

    if( rc != SQLITE_OK ){
      rc = 1;
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s\n%s", zErrMsg, query);
      sqlite3_free(zErrMsg);
      goto out;
    }

    rc = 0;
  out:
    m.unlock(__FILE__, __LINE__);

    return rc;
  } else
    return(-1);
}

/* ******************************************* */

int AlertsManager::getFlowAlerts(lua_State* vm, AddressTree *allowed_hosts,
				 u_int32_t start_offset, u_int32_t end_offset,
				 const char *sql_where_clause) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    alertsRetriever ar;
    char query[STORE_MANAGER_MAX_QUERY];
    char *zErrMsg = 0;
    int rc = 0;

    if(!store_initialized || !store_opened)
      return -1;

    snprintf(query, sizeof(query),
	     "SELECT rowid, * "
	     "FROM %s "
	     "%s %s " /* optional where clause */
	     "ORDER BY alert_tstamp DESC LIMIT %u,%u",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME /* from */,
	     sql_where_clause ? (char*)"WHERE"  : "",
	     sql_where_clause ? sql_where_clause : "",
	     start_offset, end_offset - start_offset + 1);

    m.lock(__FILE__, __LINE__);

    lua_newtable(vm);

    ar.vm = vm, ar.current_offset = 0;
    rc = sqlite3_exec(db, query, getAlertsCallback, (void*)&ar, &zErrMsg);

    if( rc != SQLITE_OK ){
      rc = 1;
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s\n%s", zErrMsg, query);
      sqlite3_free(zErrMsg);
      goto out;
    }

    rc = 0;
  out:
    m.unlock(__FILE__, __LINE__);

    return rc;
  } else
    return(-1);
}

/* **************************************************** */

int AlertsManager::getNumAlerts(bool engaged, const char *sql_where_clause, bool ignore_disabled) {
  if(ignore_disabled || !ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc;
    int num = -1;

    snprintf(query, sizeof(query),
	     "SELECT count(*) "
	     "FROM %s "
	     "%s %s",
	     engaged ? ALERTS_MANAGER_ENGAGED_TABLE_NAME : ALERTS_MANAGER_TABLE_NAME,
	     sql_where_clause ? "WHERE"  : "",
	     sql_where_clause ? sql_where_clause : "");

    //  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Going to execute: %s", query);

    m.lock(__FILE__, __LINE__);
    if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare statement for query %s.", query);
      goto out;
    }

    while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
      if(rc == SQLITE_ROW) {
	num = sqlite3_column_int(stmt, 0);
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s\n", sqlite3_column_text(stmt, 0));
      } else if(rc == SQLITE_ERROR) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
	goto out;
      }
    }

  out:
    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);

    return num;
  } else
    return(0);
}

/* **************************************************** */

int AlertsManager::getNumFlowAlerts(const char *sql_where_clause) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc;
    int num = -1;

    snprintf(query, sizeof(query),
	     "SELECT count(*) "
	     "FROM %s "
	     "%s %s",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME,
	     sql_where_clause ? "WHERE"  : "",
	     sql_where_clause ? sql_where_clause : "");

    //  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Going to execute: %s", query);

    m.lock(__FILE__, __LINE__);
    if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare statement for query %s.", query);
      goto out;
    }

    while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
      if(rc == SQLITE_ROW) {
	num = sqlite3_column_int(stmt, 0);
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s\n", sqlite3_column_text(stmt, 0));
      } else if(rc == SQLITE_ERROR) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
	goto out;
      }
    }

  out:
    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);

    return num;
  } else
    return(0);
}

/* **************************************************** */

int AlertsManager::getCachedNumAlerts(lua_State *vm) {
  lua_newtable(vm);

  lua_push_int_table_entry(vm, "num_alerts_engaged", num_alerts_engaged);
  lua_push_bool_table_entry(vm, "alerts_stored", alerts_stored);

  return 0;
};

/* **************************************************** */

int AlertsManager::getNumAlerts(bool engaged, u_int64_t start_time) {
  char wherebuf[STORE_MANAGER_MAX_QUERY];
  int num_alerts, num_flow_alerts = 0;

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   "alert_tstamp >= %lu", start_time);

  num_alerts = getNumAlerts(engaged, static_cast<const char*>(wherebuf));

  if(!engaged) /* flow alerts are by definition not engageable */
    num_flow_alerts = getNumFlowAlerts(static_cast<const char*>(wherebuf));

  return num_alerts + num_flow_alerts;
}

/* **************************************************** */

int AlertsManager::getNumAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value) {
  char wherebuf[STORE_MANAGER_MAX_QUERY];

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   "alert_entity=%i AND alert_entity_val='%q'",
		   static_cast<int>(alert_entity),
		   alert_entity_value ? alert_entity_value : (char*)"");
  return getNumAlerts(engaged, static_cast<const char*>(wherebuf));
}

/* **************************************************** */

int AlertsManager::getNumAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value, AlertType alert_type) {
  char wherebuf[STORE_MANAGER_MAX_QUERY];

  sqlite3_snprintf(sizeof(wherebuf), wherebuf,
		   "alert_entity=%i AND alert_entity_val='%q' AND alert_type=%i",
		   static_cast<int>(alert_entity),
		   alert_entity_value ? alert_entity_value : (char*)"",
		   static_cast<int>(alert_type));
  return getNumAlerts(engaged, static_cast<const char*>(wherebuf));
}

/* **************************************************** */

int AlertsManager::deleteAlerts(bool engaged, AlertEntity alert_entity,
				const char *alert_entity_value, AlertType alert_type, time_t older_than) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc;

    snprintf(query, sizeof(query),
	     "DELETE FROM %s WHERE alert_entity = ? AND alert_entity_val = ? AND alert_type = ?",
	     engaged ? ALERTS_MANAGER_ENGAGED_TABLE_NAME : ALERTS_MANAGER_TABLE_NAME);

    if(older_than>0)
      sqlite3_snprintf(sizeof(query) - strlen(query) - 1,
		       &query[strlen(query)],
		       " AND alert_tstamp < %lu", older_than);

    m.lock(__FILE__, __LINE__);
    if(sqlite3_prepare(db, query, -1, &stmt, 0)
       || sqlite3_bind_int(stmt,   1, static_cast<int>(alert_entity))
       || sqlite3_bind_text(stmt,  2, alert_entity_value, -1, SQLITE_STATIC)
       || sqlite3_bind_int(stmt,   3, static_cast<int>(alert_type))) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare statement for query %s.", query);
      rc = -1;
      goto out;
    }

    while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
      if(rc == SQLITE_ERROR) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
	rc = -2;
	goto out;
      }
    }

    rc = 0;
  out:
    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);

    return rc;
  } else
    return(0);
}

/* ******************************************* */

int AlertsManager::queryAlertsRaw(lua_State *vm, const char *selection,
				  const char *clauses, const char *table_name, bool ignore_disabled) {
  if(!ntop->getPrefs()->are_alerts_disabled() || ignore_disabled) {
    alertsRetriever ar;
    char query[STORE_MANAGER_MAX_QUERY];
    char *zErrMsg = NULL;
    int rc;

    snprintf(query, sizeof(query),
	     "%s FROM %s %s ",
	     selection ? selection : "*",
	     table_name ? table_name : (char*)"",
	     clauses ? clauses : (char*)"");

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Going to execute: %s", query);

    m.lock(__FILE__, __LINE__);

    lua_newtable(vm);

    ar.vm = vm, ar.current_offset = 0;
    rc = sqlite3_exec(db, query, getAlertsCallback, (void*)&ar, &zErrMsg);

    if( rc != SQLITE_OK ){
      rc = 1;
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s\n%s", zErrMsg, query);
      sqlite3_free(zErrMsg);
      goto out;
    }

    rc = 0;
  out:
    m.unlock(__FILE__, __LINE__);

    return rc;
  } else {
    lua_pushnil(vm);
    return(0);
  }
}

/* ******************************************* */

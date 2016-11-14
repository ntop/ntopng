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

  snprintf(queue_name, sizeof(queue_name), ALERTS_MANAGER_QUEUE_NAME, ifid);
}

/* **************************************************** */

int AlertsManager::openStore() {
  char create_query[STORE_MANAGER_MAX_QUERY];
  int rc;

  if(!store_initialized)
    return 1;

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "alert_tstamp     INTEGER NOT NULL, "
	   "alert_tstamp_end INTEGER DEFAULT NULL, "
	   "alert_type       INTEGER NOT NULL, "
	   "alert_severity   INTEGER NOT NULL, "
	   "alert_entity     INTEGER NOT NULL, "
	   "alert_entity_val TEXT NOT NULL,    "
	   "alert_json       TEXT DEFAULT NULL "
	   "); "  // no need to create a primary key, sqlite has the rowid
	   "CREATE INDEX IF NOT EXISTS t1i_tstamp   ON %s(alert_tstamp); "
	   "CREATE INDEX IF NOT EXISTS t1i_tstamp_e ON %s(alert_tstamp_end); "
	   "CREATE INDEX IF NOT EXISTS t1i_type     ON %s(alert_type); "
	   "CREATE INDEX IF NOT EXISTS t1i_severity ON %s(alert_severity); "
	   "CREATE INDEX IF NOT EXISTS t1i_entity   ON %s(alert_entity, alert_entity_val); ",
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME,
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME);
  m.lock(__FILE__, __LINE__);
  rc = exec_query(create_query, NULL, NULL);
  m.unlock(__FILE__, __LINE__);

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "alert_id         TEXT NOT NULL, "
	   "alert_tstamp     INTEGER NOT NULL, "
	   "alert_type       INTEGER NOT NULL, "
	   "alert_severity   INTEGER NOT NULL, "
	   "alert_entity     INTEGER NOT NULL, "
	   "alert_entity_val TEXT NOT NULL,    "
	   "alert_json       TEXT DEFAULT NULL"
	   ");"
	   "CREATE INDEX IF NOT EXISTS t2i_tstamp   ON %s(alert_tstamp); "
	   "CREATE INDEX IF NOT EXISTS t2i_type     ON %s(alert_type); "
	   "CREATE INDEX IF NOT EXISTS t2i_severity ON %s(alert_severity); "
	   "CREATE UNIQUE INDEX IF NOT EXISTS t2i_u ON %s(alert_entity, alert_entity_val, alert_id); ",
	   ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME,
	   ALERTS_MANAGER_ENGAGED_TABLE_NAME, ALERTS_MANAGER_ENGAGED_TABLE_NAME);
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
    if (strcmp(ALERTS_MANAGER_TYPE_FIELD, lua_tostring(L, -2)) == 0) {
      if(lua_type(L, -1) == LUA_TNUMBER) {
	alert_type = (AlertType)lua_tointeger(L, -1);
	alert_type_read = true;
      } else {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "'%s' value is NaN.",
				     ALERTS_MANAGER_TYPE_FIELD);
	good_alert = false;
	goto next_iter;
      }
    } else if (strcmp(ALERTS_MANAGER_SEVERITY_FIELD, lua_tostring(L, -2)) == 0) {
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
#endif

/* **************************************************** */

bool AlertsManager::isAlertEngaged(AlertEntity alert_entity, const char *alert_entity_value, const char *engaged_alert_id) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc;
  bool found = false;

  snprintf(query, sizeof(query),
	   "SELECT 1 "
	   "FROM %s "
	   "WHERE alert_entity = ? AND alert_entity_val = ? AND alert_id = ? ",
           ALERTS_MANAGER_ENGAGED_TABLE_NAME);

  m.lock(__FILE__, __LINE__);
  if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare statement for query %s.", query);
    goto out;
  } else if(sqlite3_bind_int(stmt,   1, static_cast<int>(alert_entity))
	    || sqlite3_bind_text(stmt,  2, alert_entity_value, strlen(alert_entity_value), SQLITE_TRANSIENT)
	    || sqlite3_bind_text(stmt,  3, engaged_alert_id, strlen(engaged_alert_id), SQLITE_TRANSIENT)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind values to prepared statement for query %s.", query);
    goto out;
  }

  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if (rc == SQLITE_ROW) {
      found = true;
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s\n", sqlite3_column_text(stmt, 0));
    } else if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
      rc = 1;
      goto out;
    }
  }

 out:
  if (stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return found;
}

/* **************************************************** */

bool AlertsManager::isMaximumReached(AlertEntity alert_entity, const char *alert_entity_value, bool engaged) {
  int max_num = ntop->getPrefs()->get_max_num_alerts_per_entity(), num;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Maximum configured number of alerts per entity: %i", max_num);
  
  if(max_num < 0)
    return false; /* unlimited allowance */

  num = getNumAlerts(engaged, alert_entity, alert_entity_value);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Checking maximum %salerts for %s [got: %i]",
			       engaged ? (char*)"engaged " : (char*)"",
			       alert_entity_value ? alert_entity_value : (char*)"",
			       num);

  if(num >= max_num) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Maximum number of %salerts exceeded for %s",
				 engaged ? (char*)"engaged " : (char*)"",
				 alert_entity_value ? alert_entity_value : (char*)"");
    if(getNumAlerts(false /* too many alerts always go to not engaged table */,
		    alert_entity, alert_entity_value,
		    alert_too_many_alerts) == 0) {
      /* too many alerts has not yet been raised for this entity */
      storeAlert(alert_entity, alert_entity_value,
		 alert_too_many_alerts, alert_level_error,
		 "Too many alerts for this alarmed entity. New alerts will be lost "
		 "unless you delete some old alerts or "
		 "increase their maximum number.",
		 false /* force store alert, do not check maximum here */);
    }
    return true;
  }
  return false;
}

/* **************************************************** */

int AlertsManager::engageAlert(AlertEntity alert_entity, const char *alert_entity_value,
			       const char *engaged_alert_id,
			       AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc = 0;

  if(!store_initialized || !store_opened)
    return -1;

  if(isAlertEngaged(alert_entity, alert_entity_value, engaged_alert_id)) {
    // TODO: update the values
  } else if(isMaximumReached(alert_entity, alert_entity_value, true /* engaged */)) {
    // TODO: handle maximum
  } else {
    /* This alert is being engaged */
    snprintf(query, sizeof(query),
	     "REPLACE INTO %s "
	     "(alert_id, alert_tstamp, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_ENGAGED_TABLE_NAME);

    m.lock(__FILE__, __LINE__);

    if(sqlite3_prepare(db, query, -1, &stmt, 0)
       || sqlite3_bind_text(stmt,  1, engaged_alert_id, strlen(engaged_alert_id), SQLITE_TRANSIENT)
       || sqlite3_bind_int64(stmt, 2, static_cast<long int>(time(NULL)))
       || sqlite3_bind_int(stmt,   3, static_cast<int>(alert_type))
       || sqlite3_bind_int(stmt,   4, static_cast<int>(alert_severity))
       || sqlite3_bind_int(stmt,   5, static_cast<int>(alert_entity))
       || sqlite3_bind_text(stmt,  6, alert_entity_value, strlen(alert_entity_value), SQLITE_TRANSIENT)
       || sqlite3_bind_text(stmt,  7, alert_json, strlen(alert_json), SQLITE_TRANSIENT)) {
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
  }

  return rc;
}

/* **************************************************** */

int AlertsManager::releaseAlert(AlertEntity alert_entity, const char *alert_entity_value,
				const char *engaged_alert_id,
				AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc = 0;

  if(!store_initialized || !store_opened)
    return -1;

  if(!isAlertEngaged(alert_entity, alert_entity_value, engaged_alert_id)) {
    return 0;  // cannot release an alert that has not been engaged
  }

  if(!isMaximumReached(alert_entity, alert_entity_value, false /* not engaged */)) {
    /* move the alert from engaged to closed */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_tstamp, alert_tstamp_end, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json) "
	     "SELECT "
	     "alert_tstamp, strftime('%%s','now'), alert_type, alert_severity, alert_entity, alert_entity_val, alert_json "
	     "FROM %s "
	     "WHERE alert_entity = ? AND alert_entity_val = ? AND alert_id = ? "
	     "LIMIT 1;" /* limit not even needed as the where clause yields unique tuples */,
	     ALERTS_MANAGER_TABLE_NAME,
	     ALERTS_MANAGER_ENGAGED_TABLE_NAME);

    m.lock(__FILE__, __LINE__);
    if(sqlite3_prepare(db, query, -1, &stmt, 0)
       || sqlite3_bind_int(stmt,   1, static_cast<int>(alert_entity))
       || sqlite3_bind_text(stmt,  2, alert_entity_value, strlen(alert_entity_value), SQLITE_TRANSIENT)
       || sqlite3_bind_text(stmt,  3, engaged_alert_id, strlen(engaged_alert_id), SQLITE_TRANSIENT)) {
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
  }  else { /* maximum number of alerts reached */
    // TODO: handle
  }
  
  /* remove the alert from those engaged */
  if (stmt) sqlite3_finalize(stmt);
  stmt = NULL;
  snprintf(query, sizeof(query),
	   "DELETE "
	   "FROM %s "
	   "WHERE alert_entity = ? AND alert_entity_val = ? AND alert_id = ? ",
           ALERTS_MANAGER_ENGAGED_TABLE_NAME);

  m.lock(__FILE__, __LINE__);
  if(sqlite3_prepare(db, query, -1, &stmt, 0)
     || sqlite3_bind_int(stmt,   1, static_cast<int>(alert_entity))
     || sqlite3_bind_text(stmt,  2, alert_entity_value, strlen(alert_entity_value), SQLITE_TRANSIENT)
     || sqlite3_bind_text(stmt,  3, engaged_alert_id, strlen(engaged_alert_id), SQLITE_TRANSIENT)) {
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

  rc = 0;
  // TODO: consider updating with the new parameters (use rowid)
 out:
  if (stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);
  return rc;  
}

/* **************************************************** */

int AlertsManager::storeAlert(AlertEntity alert_entity, const char *alert_entity_value,
			      AlertType alert_type, AlertLevel alert_severity, const char *alert_json, bool check_maximum) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc = 0;

  if(!store_initialized || !store_opened)
    return -1;
  else if(check_maximum && isMaximumReached(alert_entity, alert_entity_value, false))
    return 0;

  /* This alert is being engaged */
  snprintf(query, sizeof(query),
	   "INSERT INTO %s "
	   "(alert_tstamp, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json) "
	   "VALUES (?, ?, ?, ?, ?, ?); ",
	   ALERTS_MANAGER_TABLE_NAME);

  m.lock(__FILE__, __LINE__);

  if(sqlite3_prepare(db, query, -1, &stmt, 0)
     || sqlite3_bind_int64(stmt, 1, static_cast<long int>(time(NULL)))
     || sqlite3_bind_int(stmt,   2, static_cast<int>(alert_type))
     || sqlite3_bind_int(stmt,   3, static_cast<int>(alert_severity))
     || sqlite3_bind_int(stmt,   4, static_cast<int>(alert_entity))
     || sqlite3_bind_text(stmt,  5, alert_entity_value, strlen(alert_entity_value), SQLITE_TRANSIENT)
     || sqlite3_bind_text(stmt,  6, alert_json, strlen(alert_json), SQLITE_TRANSIENT)) {
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

/* ******************************************* */

bool AlertsManager::isValidHost(Host *h, char *host_string, size_t host_string_len) {
  char ipbuf[256];

  if (!h) return false;

  IpAddress *ip = h->get_ip();
  if(!ip) return false;

  snprintf(host_string, host_string_len, "%s@%i", ip->print(ipbuf, sizeof(ipbuf)), h->get_vlan_id());

  return true;
}

/* ******************************************* */

int AlertsManager::engageReleaseHostAlert(Host *h,
					  const char *engaged_alert_id,
					  AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
					  bool engage) {
  char ipbuf_id[256];

  if (!isValidHost(h, ipbuf_id, sizeof(ipbuf_id)))
    return -1;

  if(!h->triggerAlerts() || !h->isLocalHost())
    return 0;

  if (engage) {
    h->incNumAlerts();
    return engageAlert(alert_entity_host, ipbuf_id,
		       engaged_alert_id, alert_type, alert_severity, alert_json);
  } else
    return releaseAlert(alert_entity_host, ipbuf_id,
			engaged_alert_id, alert_type, alert_severity, alert_json);
};

/* ******************************************* */

int AlertsManager::engageReleaseNetworkAlert(const char *cidr,
					     const char *engaged_alert_id,
					     AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
					     bool engage) {
  struct in_addr addr4;
  struct in6_addr addr6;
  char ip_buf[256];
  char *slash;

  if(!cidr) return -1;

  strncpy(ip_buf, cidr, sizeof(ip_buf));
  if ((slash = strchr(ip_buf, '/')) == NULL) return -2;
  slash[0] = '\0';

  if(inet_pton(AF_INET, ip_buf, &addr4) != 1 && inet_pton(AF_INET6, ip_buf, &addr6) != 1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing network %s\n", cidr);
    return -2; /* not a valid network */
  }

  if (engage)
    return engageAlert(alert_entity_network, cidr,
		       engaged_alert_id, alert_type, alert_severity, alert_json);
  else
    return releaseAlert(alert_entity_network, cidr,
			engaged_alert_id, alert_type, alert_severity, alert_json);
};

/* ******************************************* */

int AlertsManager::engageReleaseInterfaceAlert(NetworkInterface *n,
					       const char *engaged_alert_id,
					       AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
					       bool engage) {
  char id_buf[8];
  if(!n) return -1;

  snprintf(id_buf, sizeof(id_buf), "%u", n -> get_id());

  if (engage)
    return engageAlert(alert_entity_interface, id_buf,
		       engaged_alert_id, alert_type, alert_severity, alert_json);
  else
    return releaseAlert(alert_entity_interface, id_buf,
			engaged_alert_id, alert_type, alert_severity, alert_json);
};

/* ******************************************* */

int AlertsManager::storeHostAlert(Host *h,
				  AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
  char ipbuf_id[256];

  if (!isValidHost(h, ipbuf_id, sizeof(ipbuf_id)))
    return -1;

  if(!h->triggerAlerts() || !h->isLocalHost())
    return 0;

  h->incNumAlerts();
  
  return storeAlert(alert_entity_host, ipbuf_id, alert_type, alert_severity, alert_json, true);
};

/* ******************************************* */

int AlertsManager::getHostAlerts(Host *h, lua_State* vm, patricia_tree_t *allowed_hosts,
				 u_int32_t start_offset, u_int32_t end_offset,
				 bool engaged) {
  char ipbuf_id[256], wherebuf[256];
  if(!isValidHost(h, ipbuf_id, sizeof(ipbuf_id))) {
    lua_newtable(vm);
    return -1;
  }
  snprintf(wherebuf, sizeof(wherebuf),
	   "alert_entity=\"%i\" AND alert_entity_val=\"%s\"",
	   static_cast<int>(alert_entity_host), ipbuf_id);
  return getAlerts(vm, allowed_hosts, start_offset, end_offset, engaged, wherebuf);
}

/* ******************************************* */

int AlertsManager::getHostAlerts(const char *host_ip, u_int16_t vlan_id,
				 lua_State* vm, patricia_tree_t *allowed_hosts,
				 u_int32_t start_offset, u_int32_t end_offset,
				 bool engaged) {
  char wherebuf[256];
  if(!host_ip) {
    lua_newtable(vm);
    return -1;
  }
  snprintf(wherebuf, sizeof(wherebuf),
	   "alert_entity=\"%i\" AND alert_entity_val=\"%s@%i\"",
	   static_cast<int>(alert_entity_host), host_ip, vlan_id);
  return getAlerts(vm, allowed_hosts, start_offset, end_offset, engaged, wherebuf);
}

/* ******************************************* */

int AlertsManager::getNumHostAlerts(const char *host_ip, u_int16_t vlan_id, bool engaged) {
  char wherebuf[256];
  if(!host_ip) {
    return -1;
  }
  snprintf(wherebuf, sizeof(wherebuf),
	   "alert_entity=\"%i\" AND alert_entity_val=\"%s@%i\"",
	   static_cast<int>(alert_entity_host), host_ip, vlan_id);
  return getNumAlerts(engaged, wherebuf);
}

/* ******************************************* */

int AlertsManager::getNumHostAlerts(Host *h, bool engaged) {
  char wherebuf[256];
  char ipbuf_id[256];

  if (!isValidHost(h, ipbuf_id, sizeof(ipbuf_id)))
    return -1;

  snprintf(wherebuf, sizeof(wherebuf),
	   "alert_entity=\"%i\" AND alert_entity_val=\"%s\"",
	   static_cast<int>(alert_entity_host), ipbuf_id);
  return getNumAlerts(engaged, wherebuf);
}

/* ******************************************* */

int AlertsManager::storeFlowAlert(Flow *f, AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
  int ret = 0;
  ret = storeAlert(alert_entity_flow, (char*)"flow"/* TODO: possibly add an unique id for flows */,
		   alert_type, alert_severity, alert_json,
		   true /* perform check on maximum */);

  if(f->get_cli_host() && f->get_cli_host()->isLocalHost())
    ret |= storeHostAlert(f->get_cli_host(), alert_type, alert_severity, alert_json);

  if(f->get_srv_host() && f->get_srv_host()->isLocalHost())
    ret |= storeHostAlert(f->get_srv_host(), alert_type, alert_severity, alert_json);

  return ret;
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

int AlertsManager::getAlerts(lua_State* vm, patricia_tree_t *allowed_hosts,
			     u_int32_t start_offset, u_int32_t end_offset,
			     bool engaged, const char *sql_where_clause) {
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
}

/* **************************************************** */

int AlertsManager::getNumAlerts(bool engaged, const char *sql_where_clause) {
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

  m.lock(__FILE__, __LINE__);
  if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare statement for query %s.", query);
    goto out;
  }

  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if (rc == SQLITE_ROW) {
      num = sqlite3_column_int(stmt, 0);
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s\n", sqlite3_column_text(stmt, 0));
    } else if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
      goto out;
    }
  }

 out:
  if (stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return num;
}

/* **************************************************** */

int AlertsManager::getNumAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value) {
  char wherebuf[STORE_MANAGER_MAX_QUERY];
  
  snprintf(wherebuf, sizeof(wherebuf),
	   "alert_entity=\"%i\" AND alert_entity_val=\"%s\"",
	   static_cast<int>(alert_entity),
	   alert_entity_value ? alert_entity_value : (char*)"");
  return getNumAlerts(engaged, wherebuf);
}

/* **************************************************** */

int AlertsManager::getNumAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value, AlertType alert_type) {
  char wherebuf[STORE_MANAGER_MAX_QUERY];

  snprintf(wherebuf, sizeof(wherebuf),
	   "alert_entity=\"%i\" AND alert_entity_val=\"%s\" AND alert_type=\"%i\"",
	   static_cast<int>(alert_entity),
	   alert_entity_value ? alert_entity_value : (char*)"",
	   static_cast<int>(alert_type));
  return getNumAlerts(engaged, wherebuf);
}

/* **************************************************** */

int AlertsManager::deleteAlerts(bool engaged, const int *rowid) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc;

  snprintf(query, sizeof(query),
	   "DELETE FROM %s %s ",
	   engaged ? ALERTS_MANAGER_ENGAGED_TABLE_NAME : ALERTS_MANAGER_TABLE_NAME,
	   rowid ? "WHERE rowid = ?" : "");

  m.lock(__FILE__, __LINE__);
  if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare statement for query %s.", query);
    rc = -1;
    goto out;
  } else if(rowid && sqlite3_bind_int(stmt,   1, *rowid)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind values to prepared statement for query %s.", query);
    rc = -2;
    goto out;
  }

  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
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

int AlertsManager::deleteAlerts(bool engaged, AlertEntity alert_entity, const char *alert_entity_value) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc;

  snprintf(query, sizeof(query),
	   "DELETE FROM %s WHERE alert_entity = ? AND alert_entity_val = ? ",
	   engaged ? ALERTS_MANAGER_ENGAGED_TABLE_NAME : ALERTS_MANAGER_TABLE_NAME);

  m.lock(__FILE__, __LINE__);
  if(sqlite3_prepare(db, query, -1, &stmt, 0)
     || sqlite3_bind_int(stmt,   1, static_cast<int>(alert_entity))
     || sqlite3_bind_text(stmt,  2, alert_entity_value, strlen(alert_entity_value), SQLITE_TRANSIENT)) {
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
  if (stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return rc;
}

/* ******************************************* */
#ifdef NOTUSED
int AlertsManager::queueAlert(AlertLevel level, AlertStatus s, AlertType t, char *msg) {
  char what[1024];

  if(ntop->getPrefs()->are_alerts_disabled()) return 0;

  snprintf(what, sizeof(what), "%u|%u|%u|%u|%s",
	   (unsigned int)time(NULL), (unsigned int)level,
	   (unsigned int)s, (unsigned int)t, msg);

#ifndef WIN32
  // Print alerts into syslog
  if(ntop->getRuntimePrefs()->are_alerts_syslog_enabled()) {
    if(alert_level_info == level) syslog(LOG_INFO, "%s", what);
    else if(alert_level_warning == level) syslog(LOG_WARNING, "%s", what);
    else if(alert_level_error == level) syslog(LOG_ALERT, "%s", what);
  }
#endif

  if(ntop->getRedis()->lpush(queue_name, what, CONST_MAX_ALERT_MSG_QUEUE_LEN)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "An error occurred when pushing alert %s to redis list %s.",
				 what, queue_name);
  }
  return 0;
}

/* ******************************************* */

int AlertsManager::getQueuedAlerts(lua_State* vm, patricia_tree_t *allowed_hosts, int start_offset, int end_offset) {
  char **l_elements;
  Redis *redis = ntop->getRedis();
  int rc;

  // TODO: Filter events that belong to allowed_hosts only
  
  rc = redis->lrange(queue_name, &l_elements, start_offset, end_offset);

  if(rc > 0) {
    lua_newtable(vm);

    for(int i = 0; i < rc; i++) {
      lua_pushstring(vm, l_elements[i] ? l_elements[i] : "");
      lua_rawseti(vm, -2, i+1);
      if(l_elements[i]) free(l_elements[i]);
    }
    free(l_elements);
  } else
    lua_pushnil(vm);
  
  return rc;
}

/* ******************************************* */

int AlertsManager::getNumQueuedAlerts() {
  Redis *redis = ntop->getRedis();
  return redis->llen(queue_name);
}

/* ******************************************* */

int AlertsManager::deleteQueuedAlert(u_int32_t idx_to_delete) {
  Redis *redis = ntop->getRedis();

  redis->lset(queue_name, idx_to_delete, (char*)"__deleted__");
  return redis->lrem(queue_name, (char*)"__deleted__");

}

/* ******************************************* */

int AlertsManager::flushAllQueuedAlerts() {
  Redis *redis = ntop->getRedis();

  return redis->delKey(queue_name);

}
#endif

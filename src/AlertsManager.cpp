/*
 *
 * (C) 2013-18 - ntop.org
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
  /* Can't unlink version v5 as it was created with root privileges
  sprintf(&filePath[base_offset], "%s", "alerts_v5.db");
  unlink(filePath);
  */
  sprintf(&filePath[base_offset], "%s", "alerts_v6.db");
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
	   "srv_localhost    INTEGER NOT NULL DEFAULT 0, "
	   "cli_host_pool_id INTEGER NOT NULL DEFAULT 0, "
	   "srv_host_pool_id INTEGER NOT NULL DEFAULT 0, "
	   "flow_status      INTEGER NOT NULL DEFAULT 0  "
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
	   "CREATE INDEX IF NOT EXISTS t3i_slocal    ON %s(srv_localhost); "
	   "CREATE INDEX IF NOT EXISTS t3i_cpool     ON %s(cli_host_pool_id); "
	   "CREATE INDEX IF NOT EXISTS t3i_spool     ON %s(srv_host_pool_id); "
	   "CREATE INDEX IF NOT EXISTS t3i_status    ON %s(flow_status); ",
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
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME, ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   ALERTS_MANAGER_FLOWS_TABLE_NAME);
  m.lock(__FILE__, __LINE__);
  rc = exec_query(create_query, NULL, NULL);
  m.unlock(__FILE__, __LINE__);

  return rc;
}

/* **************************************************** */

bool AlertsManager::isAlertEngaged(AlertEngine alert_engine, AlertEntity alert_entity,
				   const char *alert_entity_value, const char *engaged_alert_id,
				   AlertType *alert_type, AlertLevel *alert_severity,
				   char **alert_json, char **alert_source,
				   char **alert_target, time_t *alert_tstamp) {
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
			       const char *alert_origin, const char *alert_target, bool ignore_disabled) {
  if(ignore_disabled || !ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc = 0;
    time_t now = time(NULL);

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
	 || sqlite3_bind_int64(stmt, 3,  static_cast<long int>(now))
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

      notifyAlert(alert_entity, alert_entity_value, engaged_alert_id,
		  alert_type, alert_severity, alert_json,
		  alert_origin, alert_target, true, now, NULL);

#ifndef WIN32
      if(ntop->getPrefs()->are_alerts_syslog_enabled())
	syslog(LOG_WARNING, "[Alert] [ENGAGED] %s", alert_json ? alert_json : (char*)"");
#endif
    }

    return rc;
  } else
    return 0;
}

/* **************************************************** */

int AlertsManager::releaseAlert(AlertEngine alert_engine,
				AlertEntity alert_entity, const char *alert_entity_value,
				const char *engaged_alert_id, bool ignore_disabled) {
  if(ignore_disabled || !ntop->getPrefs()->are_alerts_disabled()) {
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

#ifndef WIN32
    if(ntop->getPrefs()->are_alerts_syslog_enabled())
      syslog(LOG_WARNING, "[Alert] [RELEASED] %s", alert_json ? alert_json : (char*)"");
#endif

    notifyAlert(alert_entity, alert_entity_value, engaged_alert_id,
          alert_type, alert_severity, alert_json,
          alert_origin, alert_target, false, time(NULL), NULL);
  
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

bool AlertsManager::notifyAlert(AlertEntity alert_entity, const char *alert_entity_value,
				const char *engaged_alert_id,
				AlertType alert_type, AlertLevel alert_severity,
				const char *alert_json,
				const char *alert_origin, const char *alert_target,
				bool engage, time_t when, Flow *flow) {
  bool rv = false;

  if(!ntop->getPrefs()->are_alerts_disabled()
	  && ntop->getPrefs()->are_ext_alerts_notifications_enabled()) {
    json_object *notification;
    const char *json_alert;

    if((notification = json_object_new_object()) != NULL) {
      /* Mandatory information */
      json_object_object_add(notification, "ifid", json_object_new_int(iface->get_id()));
      json_object_object_add(notification, "entity_type", json_object_new_int(alert_entity));
      json_object_object_add(notification, "entity_value", json_object_new_string(alert_entity_value));
      json_object_object_add(notification, "type", json_object_new_int(alert_type));
      json_object_object_add(notification, "severity", json_object_new_int(alert_severity));
      json_object_object_add(notification, "message", json_object_new_string(alert_json));
      json_object_object_add(notification, "tstamp",  json_object_new_int64(when));
      json_object_object_add(notification, "action",
			     json_object_new_string(
						    engaged_alert_id ? (engage ? ALERT_ACTION_ENGAGE : ALERT_ACTION_RELEASE)
						    : ALERT_ACTION_STORE)
			     );
      
      /* optional */
      if(alert_origin) json_object_object_add(notification, "origin", json_object_new_string(alert_origin));
      if(alert_target) json_object_object_add(notification, "target", json_object_new_string(alert_target));
      if(engaged_alert_id) json_object_object_add(notification, "alert_key", json_object_new_string(engaged_alert_id));

      /* flow only - only put relevant information for message generation */
      if(flow) {
	json_object *flow_obj;

	if((flow_obj = json_object_new_object()) == NULL) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "json_object_new_object: Not enough memory");
	  goto notify_return;
	}

	char cli_ip_buf[64], srv_ip_buf[64];
	char *cli_ip = NULL, *srv_ip = NULL;
	Host *cli = flow->get_cli_host();
	Host *srv = flow->get_srv_host();

	if(cli && cli->get_ip())
	  cli_ip = cli->get_ip()->print(cli_ip_buf, sizeof(cli_ip_buf));
	if(srv && srv->get_ip())
	  srv_ip = srv->get_ip()->print(srv_ip_buf, sizeof(srv_ip_buf));

	/* mandatory */
	json_object_object_add(flow_obj, "cli_port", json_object_new_int(flow->get_cli_port()));
	json_object_object_add(flow_obj, "srv_port", json_object_new_int(flow->get_srv_port()));
	json_object_object_add(flow_obj, "cli_blacklisted", json_object_new_int((cli && cli->isBlacklisted()) ? 1 : 0));
	json_object_object_add(flow_obj, "srv_blacklisted", json_object_new_int((srv && srv->isBlacklisted()) ? 1 : 0));
	json_object_object_add(flow_obj, "vlan_id", json_object_new_int(flow->get_vlan_id()));
	json_object_object_add(flow_obj, "proto", json_object_new_int(flow->get_protocol()));
	json_object_object_add(flow_obj, "flow_status", json_object_new_int((int)flow->getFlowStatus()));
	json_object_object_add(flow_obj, "l7_proto", json_object_new_int(flow->get_detected_protocol().app_protocol));

	/* optional */
	if(cli_ip) json_object_object_add(flow_obj, "cli_addr", json_object_new_string(cli_ip));
	if(srv_ip) json_object_object_add(flow_obj, "srv_addr", json_object_new_string(srv_ip));

	json_object_object_add(notification, "flow", flow_obj);
      }

      json_alert = json_object_to_json_string(notification);

      if(ntop->getRedis()->rpush(ALERTS_MANAGER_NOTIFICATION_QUEUE_NAME,
				 (char*)json_alert, ALERTS_MANAGER_MAX_ENTITY_ALERTS) < 0)
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "An error occurred when pushing alert %s to redis list %s.",
				     json_alert, ALERTS_MANAGER_NOTIFICATION_QUEUE_NAME);
      else
	rv = true;

notify_return:

      /* Free memory */
      json_object_put(notification);
    } else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "json_object_new_object: Not enough memory");
  }

  return rv;
}

/* **************************************************** */

int AlertsManager::storeAlert(AlertEntity alert_entity, const char *alert_entity_value,
			      AlertType alert_type, AlertLevel alert_severity,
			      const char *alert_json,
			      const char *alert_origin, const char *alert_target,
			      bool check_maximum, time_t when) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc = 0;

    if(!store_initialized || !store_opened)
      return(-1);
    else if(check_maximum)
      markForMakeRoom(false);

    notifyAlert(alert_entity, alert_entity_value, NULL,
	  alert_type, alert_severity, alert_json,
	  NULL, NULL, false, when, NULL);

    /* This alert is being engaged */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_tstamp, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json, "
	     "alert_origin, alert_target) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_TABLE_NAME);

    m.lock(__FILE__, __LINE__);

    if(sqlite3_prepare(db, query, -1, &stmt, 0)
       || sqlite3_bind_int64(stmt, 1, static_cast<long int>(when))
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

#ifndef WIN32
    if(ntop->getPrefs()->are_alerts_syslog_enabled())
      syslog(LOG_WARNING, "[Alert] %s", alert_json ? alert_json : (char*)"");
#endif

    return rc;
  } else
    return(-1);
}

/* **************************************************** */

int AlertsManager::storeFlowAlert(Flow *f) {
  if(!ntop->getPrefs()->are_alerts_disabled()) {
    char alert_json[1024];
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;
    int rc = 0;
    Host *cli, *srv;
    char *cli_ip = NULL, *cli_ip_buf = NULL, *srv_ip = NULL, *srv_ip_buf = NULL,
      cb[64], cb1[64];
    const char *msg;
    AlertType alert_type;
    AlertLevel alert_severity;
    time_t now = time(NULL);

    if(!store_initialized || !store_opened || !f)
      return(-1);

    markForMakeRoom(true);

    msg = Utils::flowStatus2str(f->getFlowStatus(), &alert_type, &alert_severity);
    cli = f->get_cli_host(), srv = f->get_srv_host();
    if(cli && cli->get_ip() && (cli_ip_buf = (char*)malloc(sizeof(char) * 256)))
      cli_ip = cli->get_ip()->print(cli_ip_buf, 128);
    if(srv && srv->get_ip() && (srv_ip_buf = (char*)malloc(sizeof(char) * 256)))
      srv_ip = srv->get_ip()->print(srv_ip_buf, 128);

    if(snprintf(alert_json, sizeof(alert_json),
		"{\"info\":\"%s\"}",
		f->getFlowInfo() ? f->getFlowInfo() : (char*)"") >= (int)sizeof(alert_json))
      snprintf(alert_json, sizeof(alert_json), "{\"info\":\"\"}");

    notifyAlert(alert_entity_flow, "flow", NULL,
		alert_type, alert_severity, alert_json,
		cli_ip, srv_ip, false, now, f);

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
	     "cli_localhost, srv_localhost, cli_host_pool_id, srv_host_pool_id, flow_status) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME);

    m.lock(__FILE__, __LINE__);

    if(sqlite3_prepare(db, query, -1, &stmt, 0)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare the statement for %s", query);
      rc = 3;
      goto out;
    }

    if(sqlite3_bind_int64(stmt, 1, static_cast<long int>(now))
       || sqlite3_bind_int(stmt,   2, (int)(alert_type))
       || sqlite3_bind_int(stmt,   3, (int)(alert_severity))
       || sqlite3_bind_text(stmt,  4, alert_json, -1, SQLITE_STATIC)
       || sqlite3_bind_int(stmt,   5, f->get_vlan_id())
       || sqlite3_bind_int(stmt,   6, f->get_protocol())
       || sqlite3_bind_int(stmt,   7, f->get_detected_protocol().app_protocol)
       || sqlite3_bind_int(stmt,   8, f->get_first_seen())
       || sqlite3_bind_int(stmt,   9, f->get_last_seen())
       || sqlite3_bind_text(stmt, 10, cli ? cli->get_country(cb, sizeof(cb)) : NULL, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt, 11, srv ? srv->get_country(cb1, sizeof(cb1)) : NULL, -1, SQLITE_STATIC)
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
       || sqlite3_bind_int(stmt,  30, cli ? cli->get_host_pool() : 0)
       || sqlite3_bind_int(stmt,  31, srv ? srv->get_host_pool() : 0)
       || sqlite3_bind_int(stmt,  32, (int)f->getFlowStatus())
       ) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind to arguments to %s", query);
      rc = 2;
      goto out;
    }

    while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
      if(rc == SQLITE_ERROR) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: step [%s][%s]",
				     query, sqlite3_errmsg(db));
	rc = 1;
	goto out;
      }
    }

    alerts_stored = true;
    rc = 0;
  out:

    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);

    f->setFlowAlerted();
  
#ifndef WIN32
    char cli_name[64], srv_name[64];

    if(cli && cli_ip_buf
       && srv && srv_ip_buf
       && ntop->getPrefs()->are_alerts_syslog_enabled()) {


      snprintf(alert_json, sizeof(alert_json),
	       "%s: <A HREF='%s/lua/host_details.lua?host=%s@%d&ifid=%d&page=alerts'>%s</A> &gt; "
	       "<A HREF='%s/lua/host_details.lua?host=%s@%d&ifid=%d&page=alerts'>%s</A> [info: %s]",
	       msg, /* TODO: remove string and save numeric status */
	       ntop->getPrefs()->get_http_prefix(),
	       cli_ip_buf, f->get_vlan_id(), iface->get_id(),
	       cli->get_visual_name(cli_name, sizeof(cli_name)),
	       ntop->getPrefs()->get_http_prefix(),
	       srv_ip_buf, f->get_vlan_id(), iface->get_id(),
	       srv->get_visual_name(srv_name, sizeof(srv_name)),
	       f->getFlowInfo() ? f->getFlowInfo() : (char*)"");

      syslog(LOG_WARNING, "[Alert] %s", alert_json);
    }
#endif

    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s", msg, alert_json);

    if(cli_ip_buf) free(cli_ip_buf);
    if(srv_ip_buf) free(srv_ip_buf);

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
					  bool engage, bool ignore_disabled) {
  char counters_key[64], ipbuf_id[64], rsp[16];
  int rc;
  Host *h;
  NetworkInterface *iface = getNetworkInterface();
  snprintf(ipbuf_id, sizeof(ipbuf_id), "%s@%d", host_ip, host_vlan);
  int num_alerts;

  // If alerts are disabled, we must return now
  if(!ignore_disabled && ntop->getPrefs()->are_alerts_disabled())
    return 0;

  if(engage) {
    rc = engageAlert(alert_engine, alert_entity_host, ipbuf_id,
		     engaged_alert_id, alert_type, alert_severity, alert_json,
		     alert_origin, alert_target, ignore_disabled);
  } else {
    rc = releaseAlert(alert_engine, alert_entity_host, ipbuf_id,
		      engaged_alert_id, ignore_disabled);
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

int AlertsManager::storeHostAlert(Host *h,
				  AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
				  Host *alert_origin, Host *alert_target) {
  char ipbuf_id[256], ipbuf_origin[256], ipbuf_target[256];

  if(!isValidHost(h, ipbuf_id, sizeof(ipbuf_id)))
    return -1;

  return(storeAlert(alert_entity_host, ipbuf_id, alert_type, alert_severity, alert_json,
		    isValidHost(alert_origin, ipbuf_origin, sizeof(ipbuf_origin)) ? ipbuf_origin : NULL,
		    isValidHost(alert_target, ipbuf_target, sizeof(ipbuf_target)) ? ipbuf_target : NULL,
		    true, time(NULL)));
};

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
	     selection,
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

	if ((rc == 0) && (strcasestr(selection, "delete") == 0))
      refreshCachedNumAlerts();

    return rc;
  } else {
    lua_pushnil(vm);
    return(0);
  }
}

/* ******************************************* */

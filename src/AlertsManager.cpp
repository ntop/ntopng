/*
 *
 * (C) 2013-19 - ntop.org
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
  sprintf(&filePath[base_offset], "%s", "alerts_v7.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v8.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v9.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v10.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v11.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v12.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v13.db");
  unlink(filePath);
  filePath[base_offset] = 0;

  /* open the newest */
  strncpy(fileName, filename, sizeof(fileName));
  fileName[sizeof(fileName) - 1] = '\0';
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

AlertsManager::~AlertsManager() { }

/* **************************************************** */

int AlertsManager::openStore() {
  char create_query[STORE_MANAGER_MAX_QUERY * 3];
  int rc;

  if(!store_initialized)
    return 1;

  /* cleanup old database files */

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "rowid            INTEGER PRIMARY KEY AUTOINCREMENT, " /* Must tell it is AUTOINCREMENT */
	   "alert_type       INTEGER NOT NULL, "
	   "alert_subtype    TEXT NOT NULL, "
	   "alert_granularity INTEGER NOT NULL, "
	   "alert_entity     INTEGER NOT NULL, "
	   "alert_entity_val TEXT NOT NULL,    "
	   "alert_severity   INTEGER NOT NULL, "
	   "alert_tstamp     INTEGER NOT NULL, "
	   "alert_tstamp_end INTEGER DEFAULT NULL, "
	   "alert_json       TEXT DEFAULT NULL"
	   ");"
	   "CREATE INDEX IF NOT EXISTS t2i_type     ON %s(alert_type); "
	   "CREATE INDEX IF NOT EXISTS t2i_subtype  ON %s(alert_subtype); "
	   "CREATE INDEX IF NOT EXISTS t2i_granularity ON %s(alert_granularity); "
	   "CREATE INDEX IF NOT EXISTS t2i_alert_entity ON %s(alert_entity, alert_entity_val); "
	   "CREATE INDEX IF NOT EXISTS t2i_severity ON %s(alert_severity); "
	   "CREATE INDEX IF NOT EXISTS t2i_tstamp   ON %s(alert_tstamp); "
	   "CREATE INDEX IF NOT EXISTS t2i_tstamp_e ON %s(alert_tstamp_end); "
	   "CREATE INDEX IF NOT EXISTS t2i_engaged  ON %s(alert_granularity); ",
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME,
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME,
	   ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME, ALERTS_MANAGER_TABLE_NAME);
  m.lock(__FILE__, __LINE__);
  rc = exec_query(create_query, NULL, NULL);
  if(rc == SQLITE_ERROR) ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
  m.unlock(__FILE__, __LINE__);

  snprintf(create_query, sizeof(create_query),
	   "CREATE TABLE IF NOT EXISTS %s ("
	   "rowid            INTEGER PRIMARY KEY AUTOINCREMENT, " /* Must tell it is AUTOINCREMENT */
	   "alert_tstamp     INTEGER NOT NULL, "
	   "alert_tstamp_end INTEGER DEFAULT NULL, "
	   "alert_type       INTEGER NOT NULL, "
	   "alert_severity   INTEGER NOT NULL, "
	   "alert_counter    INTEGER NOT NULL DEFAULT 1, "
	   "alert_json       TEXT DEFAULT NULL, "
	   "vlan_id          INTEGER NOT NULL DEFAULT 0, "
	   "proto            INTEGER NOT NULL DEFAULT 0, "
	   "l7_master_proto  INTEGER NOT NULL DEFAULT %u, "
	   "l7_proto         INTEGER NOT NULL DEFAULT %u, "
	   "cli_country      TEXT DEFAULT NULL, "
	   "srv_country      TEXT DEFAULT NULL, "
	   "cli_os           TEXT DEFAULT NULL, "
	   "srv_os           TEXT DEFAULT NULL, "
	   "cli_asn          TEXT DEFAULT NULL, "
	   "srv_asn          TEXT DEFAULT NULL, "
	   "cli_addr         TEXT DEFAULT NULL, "
	   "srv_addr         TEXT DEFAULT NULL, "
	   "cli2srv_bytes    INTEGER NOT NULL DEFAULT 0, "
	   "srv2cli_bytes    INTEGER NOT NULL DEFAULT 0, "
	   "cli2srv_packets  INTEGER NOT NULL DEFAULT 0, "
	   "srv2cli_packets  INTEGER NOT NULL DEFAULT 0, "
	   "cli_blacklisted  INTEGER NOT NULL DEFAULT 0, "
	   "srv_blacklisted  INTEGER NOT NULL DEFAULT 0, "
	   "cli_localhost    INTEGER NOT NULL DEFAULT 0, "
	   "srv_localhost    INTEGER NOT NULL DEFAULT 0, "
	   "flow_status      INTEGER NOT NULL DEFAULT 0  "
	   ");"
	   "CREATE INDEX IF NOT EXISTS t3i_tstamp    ON %s(alert_tstamp); "
	   "CREATE INDEX IF NOT EXISTS t3i_tstamp    ON %s(alert_tstamp_end); "
	   "CREATE INDEX IF NOT EXISTS t3i_type      ON %s(alert_type); "
	   "CREATE INDEX IF NOT EXISTS t3i_severity  ON %s(alert_severity); "
	   "CREATE INDEX IF NOT EXISTS t3i_vlanid    ON %s(vlan_id); "
	   "CREATE INDEX IF NOT EXISTS t3i_proto     ON %s(proto); "
	   "CREATE INDEX IF NOT EXISTS t3i_l7mproto  ON %s(l7_master_proto); "
	   "CREATE INDEX IF NOT EXISTS t3i_l7proto   ON %s(l7_proto); "
	   "CREATE INDEX IF NOT EXISTS t3i_ccountry  ON %s(cli_country); "
	   "CREATE INDEX IF NOT EXISTS t3i_scountry  ON %s(srv_country); "
	   "CREATE INDEX IF NOT EXISTS t3i_cos       ON %s(cli_os); "
	   "CREATE INDEX IF NOT EXISTS t3i_sos       ON %s(srv_os); "
	   "CREATE INDEX IF NOT EXISTS t3i_casn      ON %s(cli_asn); "
	   "CREATE INDEX IF NOT EXISTS t3i_sasn      ON %s(srv_asn); "
	   "CREATE INDEX IF NOT EXISTS t3i_caddr     ON %s(cli_addr); "
	   "CREATE INDEX IF NOT EXISTS t3i_saddr     ON %s(srv_addr); "
	   "CREATE INDEX IF NOT EXISTS t3i_clocal    ON %s(cli_localhost); "
	   "CREATE INDEX IF NOT EXISTS t3i_slocal    ON %s(srv_localhost); "
	   "CREATE INDEX IF NOT EXISTS t3i_status    ON %s(flow_status); "
	   "CREATE INDEX IF NOT EXISTS t3i_hash      ON %s(alert_type, alert_severity, vlan_id, proto, l7_master_proto, l7_proto, flow_status, cli_addr, srv_addr); ",
	   ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   NDPI_PROTOCOL_UNKNOWN,
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
  if(rc == SQLITE_ERROR) ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
  m.unlock(__FILE__, __LINE__);

  return rc;
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

bool AlertsManager::hasAlerts() {
  char query[STORE_MANAGER_MAX_QUERY];
  int step;
  bool rc = false;
  sqlite3_stmt *stmt = NULL;

  if(!store_initialized || !store_opened)
    return(-1);

  m.lock(__FILE__, __LINE__);

  snprintf(query, sizeof(query),
     "SELECT rowid "
     "FROM %s "
     "LIMIT 1",
     ALERTS_MANAGER_TABLE_NAME);

  if(sqlite3_prepare_v2(db, query, -1, &stmt, 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
    goto out;
  }

  if((step = sqlite3_step(stmt)) != SQLITE_DONE) {
    if(step == SQLITE_ERROR)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
    else
      rc = true;
  }

out:
  if(stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************************** */

/* NOTE: do not call this from C, use alert queues in LUA */
int AlertsManager::storeAlert(time_t tstart, time_t tend, int granularity, AlertType alert_type, const char *subtype,
      AlertLevel alert_severity, AlertEntity alert_entity, const char *alert_entity_value,
      const char *alert_json, bool *new_alert, u_int64_t *rowid,
      bool ignore_disabled, bool check_maximum) {
  int rc = 0;

  if(ignore_disabled || !ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    sqlite3_stmt *stmt = NULL;

    if(!store_initialized || !store_opened)
      return -1;
    else if(check_maximum)
      markForMakeRoom(false);

    m.lock(__FILE__, __LINE__);

    iface->setHasAlerts(true);

    snprintf(query, sizeof(query),
       "INSERT INTO %s "
       "(alert_granularity, alert_tstamp, alert_tstamp_end, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json, alert_subtype) "
       "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?); ",
       ALERTS_MANAGER_TABLE_NAME);

      if(sqlite3_prepare_v2(db, query, -1,  &stmt, 0)
	 || sqlite3_bind_int(stmt,   1,  granularity)
	 || sqlite3_bind_int64(stmt, 2,  static_cast<long int>(tstart))
	 || sqlite3_bind_int64(stmt, 3,  static_cast<long int>(tend))
	 || sqlite3_bind_int(stmt,   4,  static_cast<int>(alert_type))
	 || sqlite3_bind_int(stmt,   5,  static_cast<int>(alert_severity))
	 || sqlite3_bind_int(stmt,   6,  static_cast<int>(alert_entity))
	 || sqlite3_bind_text(stmt,  7,  alert_entity_value, -1, SQLITE_STATIC)
	 || sqlite3_bind_text(stmt,  8,  alert_json, -1, SQLITE_STATIC)
	 || sqlite3_bind_text(stmt,  9,  subtype, -1, SQLITE_STATIC)) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
	rc = -2;
	goto out;
      }

      while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
	if(rc == SQLITE_ERROR) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
	  rc = -3;
	  goto out;
	}
      }

    /* Success */
    *rowid = sqlite3_last_insert_rowid(db);
    rc = 0;

 out:
    if(stmt) sqlite3_finalize(stmt);
    m.unlock(__FILE__, __LINE__);
  }

  return(rc);
}

/* **************************************************** */

int AlertsManager::storeFlowAlert(lua_State *L, int index, u_int64_t *rowid) {
  time_t tstamp = 0;
  AlertType alert_type = 0;
  AlertLevel alert_severity = alert_level_none;
  FlowStatus status = 0;
  const char *alert_json = "";
  u_int16_t vlan_id = 0;
  u_int8_t protocol = 0;
  u_int16_t ndpi_master_protocol = 0, ndpi_app_protocol = 0;
  const char *cli_ip = "", *srv_ip = "";
  const char *cli_country = "", *srv_country = "";
  const char *cli_os = "", *srv_os = "";
  u_int32_t   cli_asn = 0, srv_asn = 0;
  bool cli_is_localhost = false, srv_is_localhost = false;
  bool cli_is_blacklisted = false, srv_is_blacklisted = false;
  u_int64_t cli2srv_bytes = 0, srv2cli_bytes = 0;
  u_int64_t cli2srv_packets = 0, srv2cli_packets = 0;
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL, *stmt2 = NULL, *stmt3 = NULL;
  int64_t rc = 0;
  u_int64_t cur_rowid = (u_int64_t)-1, cur_counter;
  u_int64_t cur_cli2srv_bytes, cur_srv2cli_bytes, cur_cli2srv_packets, cur_srv2cli_packets = 0;

  *rowid = 0;

  if(ntop->getPrefs()->are_alerts_disabled())
    return 0;

  if(!store_initialized || !store_opened)
    return -1;

  markForMakeRoom(true);

  /* Read alert fields from Lua */

  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
      const char *key = lua_tostring(L, -2);
      int t = lua_type(L, -1);

      switch(t) {
      case LUA_TSTRING:
        if(!strcmp(key, "alert_json"))
          alert_json = lua_tostring(L, -1);
        else if(!strcmp(key, "cli_addr"))
          cli_ip = lua_tostring(L, -1);
        else if(!strcmp(key, "srv_addr"))
          srv_ip = lua_tostring(L, -1);
        else if(!strcmp(key, "cli_country"))
          cli_country = lua_tostring(L, -1);
        else if(!strcmp(key, "srv_country"))
          srv_country = lua_tostring(L, -1);
        else if(!strcmp(key, "cli_os"))
          cli_os = lua_tostring(L, -1);
        else if(!strcmp(key, "srv_os"))
          srv_os = lua_tostring(L, -1);
	break;

      case LUA_TNUMBER:
        if(!strcmp(key, "alert_tstamp"))
          tstamp = lua_tonumber(L, -1);
        else if(!strcmp(key, "alert_type"))
          alert_type = lua_tonumber(L, -1);
        else if(!strcmp(key, "alert_severity"))
           alert_severity = (AlertLevel) lua_tonumber(L, -1);
        else if(!strcmp(key, "flow_status"))
          status = lua_tonumber(L, -1);
        else if(!strcmp(key, "vlan_id"))
          vlan_id = lua_tonumber(L, -1);
        else if(!strcmp(key, "proto"))
          protocol = lua_tonumber(L, -1);
        else if(!strcmp(key, "l7_master_proto"))
          ndpi_master_protocol = lua_tonumber(L, -1);
        else if(!strcmp(key, "l7_proto"))
          ndpi_app_protocol = lua_tonumber(L, -1);
        else if(!strcmp(key, "cli_asn"))
          cli_asn = lua_tonumber(L, -1);
        else if(!strcmp(key, "srv_asn"))
          srv_asn = lua_tonumber(L, -1);
        else if(!strcmp(key, "cli2srv_bytes"))
          cli2srv_bytes = lua_tonumber(L, -1);
        else if(!strcmp(key, "cli2srv_packets"))
          cli2srv_packets = lua_tonumber(L, -1);
        else if(!strcmp(key, "srv2cli_bytes"))
          srv2cli_bytes = lua_tonumber(L, -1);
        else if(!strcmp(key, "srv2cli_packets"))
          srv2cli_packets = lua_tonumber(L, -1);
	break;

      case LUA_TBOOLEAN:
        if(!strcmp(key, "cli_localhost"))
          cli_is_localhost = lua_toboolean(L, -1);
        else if(!strcmp(key, "srv_localhost"))
          srv_is_localhost = lua_toboolean(L, -1);
        else if(!strcmp(key, "cli_blacklisted"))
          cli_is_blacklisted = lua_toboolean(L, -1);
        else if(!strcmp(key, "srv_blacklisted"))
          srv_is_blacklisted = lua_toboolean(L, -1);
	break;

      default:
	break;
      }

    lua_pop(L, 1);
  }

  /* Safety check */
  if (!tstamp) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "storeFlowAlert: some mandatory parameter is missing");
    return -1;
  }

  /* Store to DB*/

  m.lock(__FILE__, __LINE__);

  /* Check if this alert already exists ...*/
  snprintf(query, sizeof(query),
	   "SELECT rowid, alert_counter, cli2srv_bytes, srv2cli_bytes, cli2srv_packets, srv2cli_packets "
	   "FROM %s "
	   "WHERE alert_type = ? AND alert_severity = ? "
	   "AND vlan_id = ? AND proto = ? AND l7_master_proto = ? AND l7_proto = ? "
	   "AND flow_status = ? AND cli_addr = ? AND srv_addr = ? "
	   "AND alert_tstamp >= ? "
	   "LIMIT 1; ",
	   ALERTS_MANAGER_FLOWS_TABLE_NAME);

  if(sqlite3_prepare_v2(db, query, -1, &stmt, 0)
     || sqlite3_bind_int(stmt,    1, static_cast<int>(alert_type))
     || sqlite3_bind_int(stmt,    2, static_cast<int>(alert_severity))
     || sqlite3_bind_int(stmt,    3, vlan_id)
     || sqlite3_bind_int(stmt,    4, protocol)
     || sqlite3_bind_int(stmt,    5, ndpi_master_protocol)
     || sqlite3_bind_int(stmt,    6, ndpi_app_protocol)
     || sqlite3_bind_int(stmt,    7, (int)status)
     || sqlite3_bind_text(stmt,   8, cli_ip, -1, SQLITE_STATIC)
     || sqlite3_bind_text(stmt,   9, srv_ip, -1, SQLITE_STATIC)
     || sqlite3_bind_int64(stmt, 10, static_cast<long int>(tstamp) - ALERTS_MANAGER_MAX_AGGR_SECS)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
    rc = -1;
    goto out;
  }

  /* Try and read the rowid (if the record exists) */
  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if(rc == SQLITE_ROW) {
      cur_rowid = sqlite3_column_int(stmt, 0);
      cur_counter = sqlite3_column_int(stmt, 1);
      cur_cli2srv_bytes = sqlite3_column_int(stmt, 2);
      cur_srv2cli_bytes = sqlite3_column_int(stmt, 3);
      cur_cli2srv_packets = sqlite3_column_int(stmt, 4);
      cur_srv2cli_packets = sqlite3_column_int(stmt, 5);
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [rowid: %u][cur_counter: %u]\n", sqlite3_column_text(stmt, 0), cur_rowid, cur_counter);
    } else if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
      rc = -1;
      goto out;
    }
  }

  if(cur_rowid != (u_int64_t)-1) { /* Already existing record found */
    snprintf(query, sizeof(query),
	     "UPDATE %s "
	     "SET alert_counter = ?, alert_tstamp_end = ?, cli2srv_bytes = ?, srv2cli_bytes = ?, cli2srv_packets = ?, srv2cli_packets = ? "
	     "WHERE rowid = ? ",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME);

    if(sqlite3_prepare_v2(db, query, -1, &stmt2, 0)
       || sqlite3_bind_int64(stmt2, 1, static_cast<long int>(cur_counter + 1))
       || sqlite3_bind_int64(stmt2, 2, static_cast<long int>(tstamp))
       || sqlite3_bind_int64(stmt2, 3, cur_cli2srv_bytes + cli2srv_bytes)
       || sqlite3_bind_int64(stmt2, 4, cur_srv2cli_bytes + srv2cli_bytes)
       || sqlite3_bind_int64(stmt2, 5, cur_cli2srv_packets + cli2srv_packets)
       || sqlite3_bind_int64(stmt2, 6, cur_srv2cli_packets + srv2cli_packets)
       || sqlite3_bind_int64(stmt2, 7, static_cast<long int>(cur_rowid))) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
      rc = -1;
      goto out;
    }

    while((rc = sqlite3_step(stmt2)) != SQLITE_DONE) {
      if(rc == SQLITE_ERROR) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
        rc = -1;
        goto out;
      }
    }

  } else { /* no exising record found */
    /* This alert is being engaged */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_tstamp, alert_type, alert_severity, alert_json, "
	     "vlan_id, proto, l7_master_proto, l7_proto, "
	     "cli_country, srv_country, cli_os, srv_os, cli_asn, srv_asn, "
	     "cli_addr, srv_addr, "
	     "cli2srv_bytes, srv2cli_bytes, "
	     "cli2srv_packets, srv2cli_packets, "
	     "cli_blacklisted, srv_blacklisted, "
	     "cli_localhost, srv_localhost, flow_status) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME);

    if(sqlite3_prepare_v2(db, query, -1, &stmt3, 0)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare the statement for %s", query);
      rc = -1;
      goto out;
    }

    if(sqlite3_bind_int64(stmt3,     1, static_cast<long int>(tstamp))
       || sqlite3_bind_int(stmt3,    2, (int)(alert_type))
       || sqlite3_bind_int(stmt3,    3, (int)(alert_severity))
       || sqlite3_bind_text(stmt3,   4, alert_json, -1, SQLITE_STATIC)
       || sqlite3_bind_int(stmt3,    5, vlan_id)
       || sqlite3_bind_int(stmt3,    6, protocol)
       || sqlite3_bind_int(stmt3,    7, ndpi_master_protocol)
       || sqlite3_bind_int(stmt3,    8, ndpi_app_protocol)
       || sqlite3_bind_text(stmt3,   9, cli_country, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt3,  10, srv_country, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt3,  11, cli_os, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt3,  12, srv_os, -1, SQLITE_STATIC)
       || sqlite3_bind_int(stmt3,   13, cli_asn)
       || sqlite3_bind_int(stmt3,   14, srv_asn)
       || sqlite3_bind_text(stmt3,  15, cli_ip, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt3,  16, srv_ip, -1, SQLITE_STATIC)
       || sqlite3_bind_int64(stmt3, 17, cli2srv_bytes)
       || sqlite3_bind_int64(stmt3, 18, srv2cli_bytes)
       || sqlite3_bind_int64(stmt3, 19, cli2srv_packets)
       || sqlite3_bind_int64(stmt3, 20, srv2cli_packets)
       || sqlite3_bind_int(stmt3,   21, cli_is_blacklisted ? 1 : 0)
       || sqlite3_bind_int(stmt3,   22, srv_is_blacklisted ? 1 : 0)
       || sqlite3_bind_int(stmt3,   23, cli_is_localhost ? 1 : 0)
       || sqlite3_bind_int(stmt3,   24, srv_is_localhost ? 1 : 0)
       || sqlite3_bind_int(stmt3,   25, (int) status)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind to arguments to %s", query);
      rc = -1;
      goto out;
    }

    while((rc = sqlite3_step(stmt3)) != SQLITE_DONE) {
      if(rc == SQLITE_ERROR) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: step [%s][%s]",
                                     query, sqlite3_errmsg(db));
        rc = -1;
        goto out;
      }
    }

    cur_rowid = sqlite3_last_insert_rowid(db);
  }

  rc = 0;
out:

  if(stmt) sqlite3_finalize(stmt);
  if(stmt2) sqlite3_finalize(stmt2);
  if(stmt3) sqlite3_finalize(stmt3);
  m.unlock(__FILE__, __LINE__);

  if((rc == 0) && (cur_rowid != (u_int64_t)-1))
    *rowid = cur_rowid;

  iface->setHasAlerts(true);

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s", alert_json);

  return rc;
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

    ntop->getTrace()->traceEvent(TRACE_DEBUG, "queryAlertsRaw: %s", query);

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

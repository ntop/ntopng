/*
 *
 * (C) 2013-20 - ntop.org
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

static const char *hex_chars = "0123456789ABCDEF";

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
  sprintf(&filePath[base_offset], "%s", "alerts_v14.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v15.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v16.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v17.db");
  unlink(filePath);
  sprintf(&filePath[base_offset], "%s", "alerts_v18.db");
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
	   "alert_counter    INTEGER NOT NULL DEFAULT 1, "
	   "alert_json       TEXT DEFAULT NULL, "
	   "ip               BINARY(16) NOT NULL DEFAULT 0"
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
	   "cli_asn          INTEGER NOT NULL DEFAULT 0, "
	   "srv_asn          INTEGER NOT NULL DEFAULT 0, "
	   "cli_addr         TEXT DEFAULT NULL, "
	   "srv_addr         TEXT DEFAULT NULL, "
	   "cli_port         INTEGER NOT NULL DEFAULT 0, "
	   "srv_port         INTEGER NOT NULL DEFAULT 0, "
	   "cli2srv_bytes    INTEGER NOT NULL DEFAULT 0, "
	   "srv2cli_bytes    INTEGER NOT NULL DEFAULT 0, "
	   "cli2srv_packets  INTEGER NOT NULL DEFAULT 0, "
	   "srv2cli_packets  INTEGER NOT NULL DEFAULT 0, "
	   "cli_blacklisted  INTEGER NOT NULL DEFAULT 0, "
	   "srv_blacklisted  INTEGER NOT NULL DEFAULT 0, "
	   "cli_localhost    INTEGER NOT NULL DEFAULT 0, "
	   "srv_localhost    INTEGER NOT NULL DEFAULT 0, "
	   "cli_ip           BINARY(16) NOT NULL DEFAULT 0, "
	   "srv_ip           BINARY(16) NOT NULL DEFAULT 0, "
	   "first_seen       INTEGER NOT NULL, "
	   "score            INTEGER NOT NULL DEFAULT 0, "
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
	   "CREATE INDEX IF NOT EXISTS t3i_hash      ON %s(alert_type, alert_severity, vlan_id, proto, l7_master_proto, l7_proto, flow_status, cli_addr, srv_addr, cli_port, srv_port); ",
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

  if((step = exec_statement(stmt)) == SQLITE_ROW)
    rc = true;

  iface->incNumAlertsQueries();

out:
  if(stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return(rc);
}

/* **************************************************** */

int AlertsManager::parseEntityValueIp(const char *alert_entity_value, struct in6_addr *ip_raw) {
  char tmp_entity[128];
  char *sep;
  int rv;

  memset(ip_raw, 0, sizeof(*ip_raw));

  if(!alert_entity_value)
    return(-1);

  strncpy(tmp_entity, alert_entity_value, sizeof(tmp_entity));

  /* Ignore VLAN */
  if((sep = strchr(tmp_entity, '@')))
    *sep = '\0';

  /* Ignore subnet. Save the networks as a single IP. */
  if((sep = strchr(tmp_entity, '/')))
    *sep = '\0';

  /* Try to parse as IP address */
  if(strchr(tmp_entity, ':'))
    rv = inet_pton(AF_INET6, tmp_entity, ip_raw);
  else
    rv = inet_pton(AF_INET, tmp_entity, ((char*)ip_raw)+12);

#if 0
  for(int i=0; i<16; i++) {
    u_int8_t val = ip_raw.s6_addr[i];

    ip_hex[i*2]   = hex_chars[(val >> 4) & 0xF];
    ip_hex[i*2+1] = hex_chars[val & 0xF];
  }

  ip_hex[32] = '\0';

  printf("%s (%s) - %d\n", ip_hex, tmp_entity);
#endif

  return(rv);
}

/* **************************************************** */

/*
  Generates a key used to cache the alert
*/
char *AlertsManager::getAlertCacheKey(int ifid, AlertType alert_type, const char *subtype, int granularity,
				      AlertEntity alert_entity, const char *alert_entity_value, AlertLevel alert_severity) {
  char * res = NULL;

  if((res = (char*)malloc(CONST_MAX_LEN_REDIS_KEY))) {
    if(snprintf(res, CONST_MAX_LEN_REDIS_KEY,
		ALERTS_MANAGER_AGGR_CACHE_KEY,
		ifid,
		alert_type, subtype, granularity,
		alert_entity, alert_entity_value, alert_severity) >= CONST_MAX_LEN_REDIS_KEY) {
      free(res);
      res = NULL;
    }
  }

  return res;
}

/* **************************************************** */

/*
  Checks if an alert is cached an, in case, it returns the corresponding rowid in cached_rowid
*/
bool AlertsManager::isCached(int ifid, AlertType alert_type, const char *subtype, int granularity,
			     AlertEntity alert_entity, const char *alert_entity_value, AlertLevel alert_severity,
			     u_int64_t *cached_rowid) {
  char *cached_k = getAlertCacheKey(ifid, alert_type, subtype, granularity, alert_entity, alert_entity_value, alert_severity);
  bool is_cached = false;

  if(cached_k) {
    Redis *r = ntop->getRedis();

    if(r) {
      char cur_rowid_str[32];
      u_int64_t cur_rowid;

      if(r->get(cached_k, cur_rowid_str, sizeof(cur_rowid_str)) == 0) {
	errno = 0; /* Still thread-safe, errno is per-thread */
	cur_rowid = strtol(cur_rowid_str, NULL, 0); /* Use strtol as result is a 64 bit integer */

	if(!errno)
	  *cached_rowid = cur_rowid,
	    is_cached = true;
      }
    }

    free(cached_k);
  }

  return is_cached;
}

/* **************************************************** */

/*
  Adds an an alert with a give rowid to the cache of alerts
*/
void AlertsManager::cache(int ifid, AlertType alert_type, const char *subtype, int granularity,
			  AlertEntity alert_entity, const char *alert_entity_value, AlertLevel alert_severity,
			  u_int64_t rowid) {
  char *cached_k = getAlertCacheKey(ifid, alert_type, subtype, granularity, alert_entity, alert_entity_value, alert_severity);

  if(cached_k) {
    Redis *r = ntop->getRedis();

    if(r) {
      char rowid_str[32];

      snprintf(rowid_str, sizeof(rowid_str), "%lu", rowid);
      /* The cache has a time-to-live corresponding to the aggregation period. Once the aggregation period is
	 reached, the key disappears and a new alert is added. */
      r->set(cached_k, rowid_str, ALERTS_MANAGER_MAX_AGGR_SECS);
    }

    free(cached_k);
  }
}

/* **************************************************** */

/* NOTE: do not call this from C, use alert queues in LUA */
int AlertsManager::storeAlert(time_t tstart, time_t tend, int granularity, AlertType alert_type, const char *subtype,
			      AlertLevel alert_severity, AlertEntity alert_entity, const char *alert_entity_value,
			      const char *alert_json, bool *new_alert, u_int64_t *rowid,
			      bool ignore_disabled, bool check_maximum) {
  int rc = 0;
  u_int64_t cur_rowid = (u_int64_t)-1;

  if(ignore_disabled || !ntop->getPrefs()->are_alerts_disabled()) {
    char query[STORE_MANAGER_MAX_QUERY];
    struct in6_addr ip_raw;
    sqlite3_stmt *stmt = NULL, *stmt2 = NULL;

    if(!store_initialized || !store_opened)
      return -1;
    else if(check_maximum)
      markForMakeRoom(false);

    m.lock(__FILE__, __LINE__);

    iface->setHasAlerts(true);

    /* If alert tstart and tend coincide, that is, if the alert wasn't engaged, we try and aggregated it to
       solve issues such as https://github.com/ntop/ntopng/issues/3430 */
    if(tstart == tend) {
      if(isCached(getNetworkInterface()->get_id(),
		  alert_type, subtype, granularity,
		  alert_entity, alert_entity_value, alert_severity, &cur_rowid)) {

	snprintf(query, sizeof(query),
		 "UPDATE %s "
		 "SET alert_counter = alert_counter + 1, alert_tstamp_end = ? "
		 "WHERE rowid = ? ",
		 ALERTS_MANAGER_TABLE_NAME);

	if(sqlite3_prepare_v2(db, query, -1, &stmt2, 0)
	   || sqlite3_bind_int64(stmt2, 1, static_cast<long int>(tend))
	   || sqlite3_bind_int64(stmt2, 2, static_cast<long int>(cur_rowid))) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: step");
	  rc = -2;
	  goto out;
	}

	if((rc = exec_statement(stmt2)) == SQLITE_DONE) {
	  int num_updates = sqlite3_changes(db);

	  // ntop->getTrace()->traceEvent(TRACE_ERROR, "Changes %u", num_updates);

	  /* Ensure the number of UPDATEd rows is greater than zero. A zero value means
	     the row is no longer in the database (alert deleted) but it is still in cache, so
	     a new insert need to be performed. The new insert will also refresh the cache.
	  */
	  if(num_updates > 0) {
	    /* Done updating... */
	    *rowid = cur_rowid;
	    iface->incNumWrittenAlerts();
	    rc = 0;
	    goto out;
	  }
	}
      }
    }

    /* If here, the alert was engaged or not already found in the DB */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_granularity, alert_tstamp, alert_tstamp_end, alert_type, alert_severity, alert_entity, alert_entity_val, alert_json, alert_subtype, ip) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_TABLE_NAME);

    parseEntityValueIp(alert_entity_value, &ip_raw);

    if(sqlite3_prepare_v2(db, query, -1,  &stmt, 0)
       || sqlite3_bind_int(stmt,   1,  granularity)
       || sqlite3_bind_int64(stmt, 2,  static_cast<long int>(tstart))
       || sqlite3_bind_int64(stmt, 3,  static_cast<long int>(tend))
       || sqlite3_bind_int(stmt,   4,  static_cast<int>(alert_type))
       || sqlite3_bind_int(stmt,   5,  static_cast<int>(alert_severity))
       || sqlite3_bind_int(stmt,   6,  static_cast<int>(alert_entity))
       || sqlite3_bind_text(stmt,  7,  alert_entity_value, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  8,  alert_json, -1, SQLITE_STATIC)
       || sqlite3_bind_text(stmt,  9,  subtype, -1, SQLITE_STATIC)
       || sqlite3_bind_blob(stmt, 10,  ip_raw.s6_addr, sizeof(ip_raw.s6_addr), SQLITE_STATIC)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
      rc = -3;
      goto out;
    }

    if((rc = exec_statement(stmt)) != SQLITE_DONE) {
      rc = -4;
      goto out;
    }

    /* Success */
    *rowid = sqlite3_last_insert_rowid(db);
    cache(getNetworkInterface()->get_id(),
	  alert_type, subtype, granularity,
	  alert_entity, alert_entity_value, alert_severity, *rowid);
    iface->incNumWrittenAlerts();
    rc = 0;

  out:
    if(stmt)  sqlite3_finalize(stmt);
    if(stmt2) sqlite3_finalize(stmt2);
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
  u_int32_t cli_asn = 0, srv_asn = 0;
  u_int16_t cli_port = 0, srv_port = 0;
  bool cli_is_localhost = false, srv_is_localhost = false;
  bool cli_is_blacklisted = false, srv_is_blacklisted = false;
  bool replace_alert = false;
  u_int16_t score = 0;
  u_int64_t first_seen = 0;
  u_int64_t cli2srv_bytes = 0, srv2cli_bytes = 0;
  u_int64_t cli2srv_packets = 0, srv2cli_packets = 0;
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL, *stmt2 = NULL, *stmt3 = NULL;
  int64_t rc = 0;
  u_int64_t cur_rowid = (u_int64_t)-1, cur_counter;
  u_int64_t cur_cli2srv_bytes, cur_srv2cli_bytes, cur_cli2srv_packets, cur_srv2cli_packets = 0;
  struct in6_addr cli_ip_raw, srv_ip_raw;
  int family = AF_INET;

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
        else if(!strcmp(key, "cli_addr")) {
          cli_ip = lua_tostring(L, -1);
	  family = (strchr(cli_ip, ':') != NULL) ? AF_INET6 : AF_INET;
	}
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
           alert_severity = (AlertLevel)lua_tointeger(L, -1);
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
        else if(!strcmp(key, "cli_port"))
          cli_port = lua_tonumber(L, -1);
        else if(!strcmp(key, "srv_port"))
          srv_port = lua_tonumber(L, -1);
        else if(!strcmp(key, "cli2srv_bytes"))
          cli2srv_bytes = lua_tonumber(L, -1);
        else if(!strcmp(key, "cli2srv_packets"))
          cli2srv_packets = lua_tonumber(L, -1);
        else if(!strcmp(key, "srv2cli_bytes"))
          srv2cli_bytes = lua_tonumber(L, -1);
        else if(!strcmp(key, "srv2cli_packets"))
          srv2cli_packets = lua_tonumber(L, -1);
        else if(!strcmp(key, "score"))
          score = lua_tonumber(L, -1);
        else if(!strcmp(key, "first_seen"))
          first_seen = lua_tonumber(L, -1);
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
	else if(!strcmp(key, "replace_alert"))
	  replace_alert = lua_toboolean(L, -1);
	break;

      default:
	break;
      }

    lua_pop(L, 1);
  }

  /* Safety check */
  if (!tstamp) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "storeFlowAlert: some mandatory parameter is missing");
    return -2;
  }

  /* Store to DB */

  m.lock(__FILE__, __LINE__);

  /* Check if this alert already exists ...*/
  snprintf(query, sizeof(query),
	   "SELECT rowid, alert_counter, cli2srv_bytes, srv2cli_bytes, cli2srv_packets, srv2cli_packets "
	   "FROM %s "
	   "WHERE vlan_id = ? AND proto = ? AND l7_master_proto = ? AND l7_proto = ? "
	   "AND cli_addr = ? AND srv_addr = ? AND cli_port = ? AND srv_port = ? "
	   "%s "
	   "LIMIT 1; ",
	   ALERTS_MANAGER_FLOWS_TABLE_NAME,
	   replace_alert ? "AND first_seen = ?" : "AND alert_tstamp >= ? AND alert_type = ? AND alert_severity = ? AND flow_status = ?");

  if(sqlite3_prepare_v2(db, query, -1, &stmt, 0)
     || sqlite3_bind_int(stmt,    1, vlan_id)
     || sqlite3_bind_int(stmt,    2, protocol)
     || sqlite3_bind_int(stmt,    3, ndpi_master_protocol)
     || sqlite3_bind_int(stmt,    4, ndpi_app_protocol)
     || sqlite3_bind_text(stmt,   5, cli_ip, -1, SQLITE_STATIC)
     || sqlite3_bind_text(stmt,   6, srv_ip, -1, SQLITE_STATIC)
     || sqlite3_bind_int(stmt,    7, cli_port)
     || sqlite3_bind_int(stmt,    8, srv_port)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
    rc = -3;
    goto out;
  }

  iface->incNumAlertsQueries();

  if(replace_alert) {
    /* Match the exact flow */
    if(sqlite3_bind_int(stmt,    9, first_seen)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
      rc = -4;
      goto out;
    }
  } else {
    /* Match similar flows */
    if(sqlite3_bind_int64(stmt,  9, static_cast<long int>(tstamp) - ALERTS_MANAGER_MAX_AGGR_SECS)
       || sqlite3_bind_int(stmt,    10, static_cast<int>(alert_type))
       || sqlite3_bind_int(stmt,    11, static_cast<int>(alert_severity))
       || sqlite3_bind_int(stmt,    12, (int)status)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s", sqlite3_errmsg(db));
      rc = -5;
      goto out;
    }
  }

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", sqlite3_expanded_sql(stmt));
#endif

  /* Try and read the rowid (if the record exists) */
  if((rc = exec_statement(stmt)) == SQLITE_ROW) {
    cur_rowid = sqlite3_column_int(stmt, 0);
    cur_counter = sqlite3_column_int(stmt, 1);
    cur_cli2srv_bytes = sqlite3_column_int(stmt, 2);
    cur_srv2cli_bytes = sqlite3_column_int(stmt, 3);
    cur_cli2srv_packets = sqlite3_column_int(stmt, 4);
    cur_srv2cli_packets = sqlite3_column_int(stmt, 5);
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [rowid: %u][cur_counter: %u]\n", sqlite3_column_text(stmt, 0), cur_rowid, cur_counter);
  }

  if(cur_rowid != (u_int64_t)-1) { /* Already existing record found, update it */
    snprintf(query, sizeof(query),
	     "UPDATE %s "
	     "SET alert_counter = ?, alert_tstamp_end = ?, cli2srv_bytes = ?, srv2cli_bytes = ?, cli2srv_packets = ?, srv2cli_packets = ?, "
	     "score = ?, alert_type = ?, alert_severity = ?, flow_status = ?, alert_json = ? "
	     "WHERE rowid = ? ",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME);

    if(sqlite3_prepare_v2(db, query, -1, &stmt2, 0)
       || sqlite3_bind_int64(stmt2, 1, static_cast<long int>(replace_alert ? cur_counter : (cur_counter + 1)))
       || sqlite3_bind_int64(stmt2, 2, static_cast<long int>(tstamp))
       || sqlite3_bind_int64(stmt2, 3, replace_alert ? cur_cli2srv_bytes : (cur_cli2srv_bytes + cli2srv_bytes))
       || sqlite3_bind_int64(stmt2, 4, replace_alert ? cur_srv2cli_bytes : (cur_srv2cli_bytes + srv2cli_bytes))
       || sqlite3_bind_int64(stmt2, 5, replace_alert ? cur_cli2srv_packets : (cur_cli2srv_packets + cli2srv_packets))
       || sqlite3_bind_int64(stmt2, 6, replace_alert ? cur_srv2cli_packets : (cur_srv2cli_packets + srv2cli_packets))
       || sqlite3_bind_int(stmt2,   7, score)
       || sqlite3_bind_int(stmt2,   8, alert_type)
       || sqlite3_bind_int(stmt2,   9, alert_severity)
       || sqlite3_bind_int(stmt2,  10, status)
       || sqlite3_bind_text(stmt2, 11, alert_json, -1, SQLITE_STATIC)
       || sqlite3_bind_int64(stmt2,12, static_cast<long int>(cur_rowid))) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
      rc = -6;
      goto out;
    }

    if((rc = exec_statement(stmt2)) != SQLITE_DONE) {
      rc = -7;
      goto out;
    }

  } else { /* no exising record found */
    /* This alert is being engaged */
    snprintf(query, sizeof(query),
	     "INSERT INTO %s "
	     "(alert_tstamp, alert_type, alert_severity, alert_json, "
	     "vlan_id, proto, l7_master_proto, l7_proto, "
	     "cli_country, srv_country, cli_os, srv_os, cli_asn, srv_asn, "
	     "cli_addr, srv_addr, cli_port, srv_port, "
	     "cli2srv_bytes, srv2cli_bytes, "
	     "cli2srv_packets, srv2cli_packets, "
	     "cli_blacklisted, srv_blacklisted, "
	     "cli_localhost, srv_localhost, "
	     "cli_ip, srv_ip, "
	     "score, first_seen, flow_status) "
	     "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?); ",
	     ALERTS_MANAGER_FLOWS_TABLE_NAME);

    if(sqlite3_prepare_v2(db, query, -1, &stmt3, 0)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to prepare the statement for %s", query);
      rc = -8;
      goto out;
    }

    memset(&cli_ip_raw, 0, sizeof(cli_ip_raw));
    memset(&srv_ip_raw, 0, sizeof(srv_ip_raw));

    /* NOTE: IPv4 addresses are mapped into the IPv6 address space */
    if(cli_ip && cli_ip[0])
      inet_pton(family, cli_ip, (family == AF_INET6) ? (void*)&cli_ip_raw : ((char*)&cli_ip_raw)+12);

    if(srv_ip && srv_ip[0])
      inet_pton(family, srv_ip, (family == AF_INET6) ? (void*)&srv_ip_raw : ((char*)&srv_ip_raw)+12);

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
       || sqlite3_bind_int(stmt3,   17, cli_port)
       || sqlite3_bind_int(stmt3,   18, srv_port)
       || sqlite3_bind_int64(stmt3, 19, cli2srv_bytes)
       || sqlite3_bind_int64(stmt3, 20, srv2cli_bytes)
       || sqlite3_bind_int64(stmt3, 21, cli2srv_packets)
       || sqlite3_bind_int64(stmt3, 22, srv2cli_packets)
       || sqlite3_bind_int(stmt3,   23, cli_is_blacklisted ? 1 : 0)
       || sqlite3_bind_int(stmt3,   24, srv_is_blacklisted ? 1 : 0)
       || sqlite3_bind_int(stmt3,   25, cli_is_localhost ? 1 : 0)
       || sqlite3_bind_int(stmt3,   26, srv_is_localhost ? 1 : 0)
       || sqlite3_bind_blob(stmt3,  27, cli_ip_raw.s6_addr, sizeof(cli_ip_raw.s6_addr), SQLITE_STATIC)
       || sqlite3_bind_blob(stmt3,  28, srv_ip_raw.s6_addr, sizeof(srv_ip_raw.s6_addr), SQLITE_STATIC)
       || sqlite3_bind_int(stmt3,   29, (int) score)
       || sqlite3_bind_int64(stmt3, 30, static_cast<long int>(first_seen))
       || sqlite3_bind_int(stmt3,   31, (int) status)) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind to arguments to %s", query);
      rc = -9;
      goto out;
    }

    if((rc = exec_statement(stmt3)) != SQLITE_DONE) {
      rc = -1;
      goto out;
    }

    cur_rowid = sqlite3_last_insert_rowid(db);
  }

  /* Success */
  iface->incNumWrittenAlerts();
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
				  const char *filter, const char *allowed_nets_filter,
				  const char *group_by, const char *table_name,
				  bool ignore_disabled) {
  if(!ntop->getPrefs()->are_alerts_disabled() || ignore_disabled) {
    alertsRetriever ar;
    const char *where = filter;
    char tmp_where[STORE_MANAGER_MAX_QUERY];
    char query[STORE_MANAGER_MAX_QUERY];
    char *zErrMsg = NULL;
    int rc;

    if(allowed_nets_filter) {
      if(filter && filter[0]) {
	snprintf(tmp_where, sizeof(tmp_where), "((%s) AND (%s))",
	  filter, allowed_nets_filter);
	where = tmp_where;
      } else
	where = allowed_nets_filter;
    }

    snprintf(query, sizeof(query),
	     "%s FROM %s %s%s %s",
	     selection,
	     table_name ? table_name : "",
	     (where && where[0]) ? "WHERE " : "",
	     (where && where[0]) ? where : "",
	     (group_by && group_by[0]) ? group_by : "");

    ntop->getTrace()->traceEvent(TRACE_DEBUG, "queryAlertsRaw: %s", query);

    m.lock(__FILE__, __LINE__);

    lua_newtable(vm);

    ar.vm = vm, ar.current_offset = 0;
    rc = sqlite3_exec(db, query, getAlertsCallback, (void*)&ar, &zErrMsg);
    iface->incNumAlertsQueries();

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

static char* appendFilterString(char *filters, char *new_filter) {
  if(!filters)
    filters = strdup(new_filter);
  else {
    filters = (char*) realloc(filters, strlen(filters) + strlen(new_filter)
      + sizeof(" OR "));

    if(filters) {
      strcat(filters, " OR ");
      strcat(filters, new_filter);
    }
  }

  return(filters);
}

/* ******************************************* */

struct sqlite_filter_data {
  bool match_all;
  char *hosts_filter;
  char *flows_filter;
};

static void allowed_nets_walker(patricia_node_t *node, void *data, void *user_data) {
  struct sqlite_filter_data *filterdata = (sqlite_filter_data*)user_data;
  struct in6_addr lower_addr;
  struct in6_addr upper_addr;
  int bitlen = node->prefix->bitlen;
  char lower_hex[33], upper_hex[33];
  char hosts_buf[512], flows_buf[512];

  if(filterdata->match_all)
    return;

  if(bitlen == 0) {
    /* Match all, no filter necessary */
    filterdata->match_all = true;

    if(filterdata->hosts_filter) {
      free(filterdata->hosts_filter);
      filterdata->flows_filter = NULL;
    }

    if(filterdata->flows_filter) {
      free(filterdata->flows_filter);
      filterdata->flows_filter = NULL;
    }

    return;
  }

  if(node->prefix->family == AF_INET) {
    memset(&lower_addr, 0, sizeof(lower_addr)-4);
    memcpy(((char*)&lower_addr) + 12, &node->prefix->add.sin.s_addr, 4);

    bitlen += 96;
  } else
    memcpy(&lower_addr, &node->prefix->add.sin6, sizeof(lower_addr));

  /* Calculate upper address */
  memcpy(&upper_addr, &lower_addr, sizeof(upper_addr));

  for(int i=0; i<(128 - bitlen); i++) {
    u_char bit = 127-i;

    upper_addr.s6_addr[bit / 8] |= (1 << (bit % 8));

    /* Also normalize the lower address */
    lower_addr.s6_addr[bit / 8] &= ~(1 << (bit % 8));
  }

  /* Convert to hex */
  for(int i=0; i<16; i++) {
    u_char lval = lower_addr.s6_addr[i];
    u_char uval = upper_addr.s6_addr[i];

    lower_hex[i*2]   = hex_chars[(lval >> 4) & 0xF];
    lower_hex[i*2+1] = hex_chars[lval & 0xF];

    upper_hex[i*2]   = hex_chars[(uval >> 4) & 0xF];
    upper_hex[i*2+1] = hex_chars[uval & 0xF];
  }

  lower_hex[32] = '\0';
  upper_hex[32] = '\0';

#if 0
    char lower_str[INET6_ADDRSTRLEN];
    char upper_str[INET6_ADDRSTRLEN];

    printf("\t%s (%s) - %s (%s)\n",
      lower_hex, inet_ntop(AF_INET6, &lower_addr, lower_str, sizeof(lower_addr)),
      upper_hex, inet_ntop(AF_INET6, &upper_addr, upper_str, sizeof(upper_addr)));
#endif

  /* Build filter strings */
  snprintf(hosts_buf, sizeof(hosts_buf),
	    "((ip >= x'%s') AND (ip <= x'%s'))",
	    lower_hex, upper_hex);

  snprintf(flows_buf, sizeof(flows_buf),
	    "(((cli_ip >= x'%s') AND (cli_ip <= x'%s')) OR ((srv_ip >= x'%s') AND (srv_ip <= x'%s')))",
	    lower_hex, upper_hex, lower_hex, upper_hex);

  filterdata->hosts_filter = appendFilterString(filterdata->hosts_filter, hosts_buf);

  filterdata->flows_filter = appendFilterString(filterdata->flows_filter, flows_buf);
}

/* ******************************************* */

void AlertsManager::buildSqliteAllowedNetworksFilters(lua_State *vm) {
  AddressTree *allowed_nets = getLuaVMUserdata(vm, allowedNets);

  if(allowed_nets) {
    struct sqlite_filter_data data;
    memset(&data, 0, sizeof(data));

    allowed_nets->walk(allowed_nets_walker, &data);

    getLuaVMUservalue(vm, sqlite_hosts_filter) = data.hosts_filter;
    getLuaVMUservalue(vm, sqlite_flows_filter) = data.flows_filter;
  }

  getLuaVMUservalue(vm, sqlite_filters_loaded) = true;
}

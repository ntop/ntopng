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

/* **************************************************** */

static void* queryLoop(void* ptr) {
  return(((MySQLDB*)ptr)->queryLoop());
}

/* **************************************************** */

void* MySQLDB::queryLoop() {
  Redis *r = ntop->getRedis();
  MYSQL mysql_alt;
  char sql[CONST_MAX_SQL_QUERY_LEN];

  while(!ntop->getGlobals()->isShutdown()
	&& !MySQLDB::isDbCreated() /* wait until the db has been created */) {
    sleep(1);
  }

  if(ntop->getGlobals()->isShutdown() || !connectToDB(&mysql_alt, true))
    return(NULL);

  while(!ntop->getGlobals()->isShutdown()) {
    int rc = r->lpop(CONST_SQL_QUEUE, sql, sizeof(sql));

    if(rc == 0) {
      if (strlen(sql) >= CONST_MAX_SQL_QUERY_LEN - 1){
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Tried to execute a query longer than %u. Skipping.",
				     CONST_MAX_SQL_QUERY_LEN - 2);
	continue;  // prevents overflown queries to generate mysql errors
      } else if(exec_sql_query(&mysql_alt, sql, true, true, false) < 0) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s", get_last_db_error(&mysql_alt));
	ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", sql);
	mysql_close(&mysql_alt);
	if(!connectToDB(&mysql_alt, true))
	  return(NULL);
      }
    } else
      sleep(1);    
  }

  mysql_close(&mysql_alt);
  return(NULL);
}

/* ******************************************* */
volatile bool MySQLDB::db_created = false;
bool MySQLDB::createDBSchema() {
  char sql[CONST_MAX_SQL_QUERY_LEN];

  if(iface) {
    if(connectToDB(&mysql, false) == false){
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to connect: %s\n", get_last_db_error(&mysql));
      return false;
    }

    /* 1 - Create database if missing */
    snprintf(sql, sizeof(sql), "CREATE DATABASE IF NOT EXISTS `%s`", ntop->getPrefs()->get_mysql_dbname());
    if(exec_sql_query(&mysql, sql, true) < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error(&mysql));
      return false;
    }

    if(mysql_select_db(&mysql, ntop->getPrefs()->get_mysql_dbname())) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error(&mysql));
      return false;
    }

    /* 2.1 - Create table if missing [IPv6] */
    snprintf(sql, sizeof(sql), "CREATE TABLE IF NOT EXISTS `%sv6` ("
	     "`idx` int(11) NOT NULL AUTO_INCREMENT,"
	     "`VLAN_ID` smallint(5) unsigned DEFAULT NULL,"
	     "`L7_PROTO` smallint(5) unsigned DEFAULT NULL,"
	     "`IP_SRC_ADDR` varchar(48) DEFAULT NULL,"
	     "`L4_SRC_PORT` smallint(5) unsigned DEFAULT NULL,"
	     "`IP_DST_ADDR` varchar(48) DEFAULT NULL,"
	     "`L4_DST_PORT` smallint(5) unsigned DEFAULT NULL,"
	     "`PROTOCOL` tinyint(3) unsigned DEFAULT NULL,"
	     "`BYTES` int(10) unsigned DEFAULT NULL,"
	     "`PACKETS` int(10) unsigned DEFAULT NULL,"
	     "`FIRST_SWITCHED` int(10) unsigned DEFAULT NULL,"
	     "`LAST_SWITCHED` int(10) unsigned DEFAULT NULL,"
	     "`INFO` varchar(255) DEFAULT NULL,"
	     "`JSON` blob,"
#ifdef NTOPNG_PRO
	     "`PROFILE` varchar(255) DEFAULT NULL,"
#endif
	     "`NTOPNG_INSTANCE_NAME` varchar(256) DEFAULT NULL,"
	     "`INTERFACE` varchar(64) DEFAULT NULL,"
	     "KEY `idx` (`idx`,`IP_SRC_ADDR`,`IP_DST_ADDR`,`FIRST_SWITCHED`,`LAST_SWITCHED`,`INFO`(200)),"
#ifdef NTOPNG_PRO
	     "KEY `ix_flowsv6_4_profile` (`PROFILE`),"
#endif
	     "KEY `ix_flowsv6_4_ntopng_instance_name` (`NTOPNG_INSTANCE_NAME`(255)),"
	     "KEY `ix_flowsv6_4_ntopng_interface` (`INTERFACE`)"
	     ") ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8"
	     "/*!50100 PARTITION BY HASH (`FIRST_SWITCHED`)"
	     "PARTITIONS 32 */",
	     ntop->getPrefs()->get_mysql_tablename());

    if(exec_sql_query(&mysql, sql, true) < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error(&mysql));
      return false;
    }

    /* 2.2 - Create table if missing [IPv4] */
    snprintf(sql, sizeof(sql), "CREATE TABLE IF NOT EXISTS `%sv4` ("
	     "`idx` int(11) NOT NULL AUTO_INCREMENT,"
	     "`VLAN_ID` smallint(5) unsigned DEFAULT NULL,"
	     "`L7_PROTO` smallint(5) unsigned DEFAULT NULL,"
	     "`IP_SRC_ADDR` int(10) unsigned DEFAULT NULL,"
	     "`L4_SRC_PORT` smallint(5) unsigned DEFAULT NULL,"
	     "`IP_DST_ADDR` int(10) unsigned DEFAULT NULL,"
	     "`L4_DST_PORT` smallint(5) unsigned DEFAULT NULL,"
	     "`PROTOCOL` tinyint(3) unsigned DEFAULT NULL,"
	     "`BYTES` int(10) unsigned DEFAULT NULL,"
	     "`PACKETS` int(10) unsigned DEFAULT NULL,"
	     "`FIRST_SWITCHED` int(10) unsigned DEFAULT NULL,"
	     "`LAST_SWITCHED` int(10) unsigned DEFAULT NULL,"
	     "`INFO` varchar(255) DEFAULT NULL,"
	     "`JSON` blob,"
#ifdef NTOPNG_PRO
	     "`PROFILE` varchar(255) DEFAULT NULL,"
#endif
	     "`NTOPNG_INSTANCE_NAME` varchar(256) DEFAULT NULL,"
	     "`INTERFACE` varchar(64) DEFAULT NULL,"
	     "KEY `idx` (`idx`,`IP_SRC_ADDR`,`IP_DST_ADDR`,`FIRST_SWITCHED`,`LAST_SWITCHED`,`INFO`(200)),"
#ifdef NTOPNG_PRO
	     "KEY `ix_flowsv4_4_profile` (`PROFILE`),"
#endif
	     "KEY `ix_flowsv4_4_ntopng_instance_name` (`NTOPNG_INSTANCE_NAME`(255)),"
	     "KEY `ix_flowsv4_4_ntopng_interface` (`INTERFACE`)"
	     ") ENGINE=InnoDB AUTO_INCREMENT=520 DEFAULT CHARSET=utf8"
	     "/*!50100 PARTITION BY HASH (`FIRST_SWITCHED`)"
	     "PARTITIONS 32 */",
	     ntop->getPrefs()->get_mysql_tablename());

    if(exec_sql_query(&mysql, sql, true) < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error(&mysql));
      return false;
    }

    // the remainder of this method has the purpose of MIGRATING old table structures to
    // the most recent one.

    // We adapt old table structures to the new schema using alter tables
    /* Add fields if not present */
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv4_%u` ADD `INFO` varchar(255)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);

    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv6_%u` ADD `INFO` varchar(255)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);

#ifdef NTOPNG_PRO
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv4_%u` "
	     "ADD `PROFILE` varchar(255) DEFAULT NULL,"
	     "ADD INDEX `ix_%sv4_%u_profile` (PROFILE)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv6_%u` "
	     "ADD `PROFILE` varchar(255) DEFAULT NULL,"
	     "ADD INDEX `ix_%sv6_%u_profile` (PROFILE)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);
#endif
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv4_%u` "
	     "ADD `NTOPNG_INSTANCE_NAME` varchar(256) DEFAULT NULL,"
	     "ADD INDEX `ix_%sv4_%u_ntopng_instance_name` (NTOPNG_INSTANCE_NAME)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv6_%u` "
	     "ADD `NTOPNG_INSTANCE_NAME` varchar(256) DEFAULT NULL,"
	     "ADD INDEX `ix_%sv6_%u_ntopng_instance_name` (NTOPNG_INSTANCE_NAME)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv4_%u` "
	     "ADD `INTERFACE` varchar(64) DEFAULT NULL,"
	     "ADD INDEX `ix_%sv4_%u_ntopng_interface` (INTERFACE)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv6_%u` "
	     "ADD `INTERFACE` varchar(64) DEFAULT NULL,"
	     "ADD INDEX `ix_%sv6_%u_ntopng_interface` (INTERFACE)",
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);

    // We trasfer old table contents into the new schema
    snprintf(sql, sizeof(sql), "INSERT IGNORE INTO `%sv4` "
	     "SELECT * FROM `%sv4_%u`",
	     ntop->getPrefs()->get_mysql_tablename(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);
    snprintf(sql, sizeof(sql), "INSERT IGNORE INTO `%sv6` "
	     "SELECT * FROM `%sv6_%u`",
	     ntop->getPrefs()->get_mysql_tablename(),
	     ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
    exec_sql_query(&mysql, sql, true, true);

    // Drop old tables (their contents have been transferred)
  }
  snprintf(sql, sizeof(sql), "DROP TABLE IF EXISTS  `%sv4_%u` ",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
  exec_sql_query(&mysql, sql, true, true);
  snprintf(sql, sizeof(sql), "DROP TABLE IF EXISTS `%sv6_%u` ",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_id());
  exec_sql_query(&mysql, sql, true, true);

  // Add extra indices to speedup queries
  snprintf(sql, sizeof(sql), "ALTER TABLE `%sv4` "
	   "ADD INDEX `ix_%sv4_ntopng_first_src_dst` (FIRST_SWITCHED, IP_SRC_ADDR, IP_DST_ADDR)",
	   ntop->getPrefs()->get_mysql_tablename(),
	   ntop->getPrefs()->get_mysql_tablename());
  exec_sql_query(&mysql, sql, true, true);
  snprintf(sql, sizeof(sql), "ALTER TABLE `%sv6` "
	   "ADD INDEX `ix_%sv6_ntopng_first_src_dst` (FIRST_SWITCHED, IP_SRC_ADDR, IP_DST_ADDR)",
	   ntop->getPrefs()->get_mysql_tablename(),
	   ntop->getPrefs()->get_mysql_tablename());
  exec_sql_query(&mysql, sql, true, true);

  // Add an extra column with the interface id to speed up certain quer
  snprintf(sql, sizeof(sql), "ALTER TABLE `%sv4` ADD COLUMN INTERFACE_ID SMALLINT(5) DEFAULT NULL",
	   ntop->getPrefs()->get_mysql_tablename());
  exec_sql_query(&mysql, sql, true, true);

  snprintf(sql, sizeof(sql), "ALTER TABLE `%sv6` ADD COLUMN INTERFACE_ID SMALLINT(5) DEFAULT NULL",
	   ntop->getPrefs()->get_mysql_tablename());
  exec_sql_query(&mysql, sql, true, true);

  // Populate the brand new column INTERFACE_ID with the ids of interfaces
  // and set to NULL the column INTERFACE
  snprintf(sql, sizeof(sql), "UPDATE `%sv4` SET INTERFACE_ID = %u WHERE INTERFACE ='%s'",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_id(), iface->get_name());
  if (exec_sql_query(&mysql, sql, true, true) == 0){
    // change succeeded, we have to flush possibly existing mysql queues
    // that may have different format
    ntop->getRedis()->del((char*)CONST_SQL_QUEUE);
  }

  snprintf(sql, sizeof(sql), "UPDATE `%sv6` SET INTERFACE_ID = %u WHERE INTERFACE ='%s'",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_id(), iface->get_name());
  exec_sql_query(&mysql, sql, true, true);
  snprintf(sql, sizeof(sql), "UPDATE `%sv4` SET INTERFACE = NULL WHERE INTERFACE ='%s'",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_name());
  exec_sql_query(&mysql, sql, true, true);
  snprintf(sql, sizeof(sql), "UPDATE `%sv6` SET INTERFACE = NULL WHERE INTERFACE ='%s'",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_name());
  exec_sql_query(&mysql, sql, true, true);

  // Check if the INTERFACE column can be dropped
  snprintf(sql, sizeof(sql), "SELECT 1 FROM `%sv4` WHERE INTERFACE IS NOT NULL LIMIT 1",
	   ntop->getPrefs()->get_mysql_tablename());
  if(exec_sql_query(&mysql, sql, true, true) == 0) {
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv4` DROP COLUMN INTERFACE",
	     ntop->getPrefs()->get_mysql_tablename());
    exec_sql_query(&mysql, sql, true, true);
  }
  snprintf(sql, sizeof(sql), "SELECT 1 FROM `%sv6` WHERE INTERFACE IS NOT NULL LIMIT 1",
	   ntop->getPrefs()->get_mysql_tablename());
  if(exec_sql_query(&mysql, sql, true, true) == 0) {
    snprintf(sql, sizeof(sql), "ALTER TABLE `%sv6` DROP COLUMN INTERFACE",
	     ntop->getPrefs()->get_mysql_tablename());
    exec_sql_query(&mysql, sql, true, true);
  }

  // Move column BYTES to BYTES_IN and add BYTES_OUT
  // note that this operation will arbitrarily move the old BYTES contents to BYTES_IN
  const u_int16_t ipvers[2] = {4, 6};
  for (u_int16_t i = 0; i < sizeof(ipvers) / sizeof(u_int16_t); i++){
    snprintf(sql, sizeof(sql),
	     "SELECT 1 "
	     "FROM information_schema.COLUMNS "
	     "WHERE TABLE_SCHEMA='%s' "
	     "AND TABLE_NAME='%sv%hu' "
	     "AND COLUMN_NAME='BYTES' ",
	     ntop->getPrefs()->get_mysql_dbname(),
	     ntop->getPrefs()->get_mysql_tablename(),
	     ipvers[i]);
    if(exec_sql_query(&mysql, sql, true, true) > 0){
      // if here, the column BYTES exists so we want to alter the table
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "MySQL schema update. Altering table %sv%hu: "
				   "renaming BYTES to IN_BYTES and adding OUT_BYTES",
				   ntop->getPrefs()->get_mysql_tablename(), ipvers[i]);

      snprintf(sql, sizeof(sql),
	       "ALTER TABLE `%sv%hu` "
	       "CHANGE BYTES IN_BYTES INT(10) DEFAULT 0, "
	       "ADD OUT_BYTES INT(10) DEFAULT 0 AFTER IN_BYTES",
	       ntop->getPrefs()->get_mysql_tablename(), ipvers[i]);
      exec_sql_query(&mysql, sql, true, true);
    }
  }

  // Modify database engine to MyISAM (that is much faster in non-transactional environments)
  for (u_int16_t i = 0; i < sizeof(ipvers) / sizeof(u_int16_t); i++){
    snprintf(sql, sizeof(sql),
	     "SELECT 1 "
	     "FROM information_schema.TABLES "
	     "WHERE TABLE_SCHEMA='%s' "
	     "AND TABLE_NAME='%sv%hu' "
	     "AND ENGINE='InnoDB' ",
	     ntop->getPrefs()->get_mysql_dbname(),
	     ntop->getPrefs()->get_mysql_tablename(),
	     ipvers[i]);
    if(exec_sql_query(&mysql, sql, true, true) > 0){
      // if here, the table has enging InnoDB so we want to modify that to MyISAM
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "MySQL schema update. Altering table %sv%hu: "
				   "changing engine from InnoDB to MyISAM.",
				   ntop->getPrefs()->get_mysql_tablename(), ipvers[i]);

      snprintf(sql, sizeof(sql),
	       "ALTER TABLE `%sv%hu` ENGINE='MyISAM'",
	       ntop->getPrefs()->get_mysql_tablename(), ipvers[i]);
      exec_sql_query(&mysql, sql, true, true);
    }
  }

  // make counter fields as unsigned so they can store 2x values
  const char *counter_fields[3] = {"IN_BYTES", "OUT_BYTES", "PACKETS"};
  for (u_int16_t i = 0; i < sizeof(ipvers) / sizeof(u_int16_t); i++){
    for (u_int16_t j = 0; j < sizeof(counter_fields) / sizeof(char*); j++){
      snprintf(sql, sizeof(sql),
	       "SELECT 1 "
	       "FROM information_schema.COLUMNS "
	       "WHERE TABLE_SCHEMA='%s' "
	       "AND TABLE_NAME='%sv%hu' "
	       "AND COLUMN_NAME='%s' "
	       "AND COLUMN_TYPE NOT LIKE '%%UNSIGNED' ",
	       ntop->getPrefs()->get_mysql_dbname(),
	       ntop->getPrefs()->get_mysql_tablename(),
	       ipvers[i], counter_fields[j]);
      if(exec_sql_query(&mysql, sql, true, true) > 0){
	// if here we have to convert the type to unsigned
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "MySQL schema update. Altering table %sv%hu: "
				     "changing %s data type to unsigned int.",
				     ntop->getPrefs()->get_mysql_tablename(),
				     ipvers[i],
				     counter_fields[j]);

	snprintf(sql, sizeof(sql),
		 "ALTER TABLE `%sv%hu` MODIFY COLUMN `%s` int(10) unsigned",
		 ntop->getPrefs()->get_mysql_tablename(), ipvers[i], counter_fields[j]);
	exec_sql_query(&mysql, sql, true, true);
      }
    }
  }

  db_created = true;
  return true;
}

/* ******************************************* */

MySQLDB::MySQLDB(NetworkInterface *_iface) : DB(_iface) {
  connectToDB(&mysql, false);
}

/* ******************************************* */

MySQLDB::~MySQLDB() {
  mysql_close(&mysql);
}

/* ******************************************* */

void MySQLDB::startDBLoop() {
  pthread_create(&queryThreadLoop, NULL, ::queryLoop, (void*)this);
}

/* ******************************************* */

#ifdef NOTUSED
char* MySQLDB::get_insert_into_values(IPVersion vers) {
  char sql[CONST_MAX_SQL_QUERY_LEN];

  snprintf(sql,
	   sizeof(sql),
	   "INSERT INTO `%sv%i` (VLAN_ID,L7_PROTO,IP_SRC_ADDR,L4_SRC_PORT,IP_DST_ADDR,L4_DST_PORT,PROTOCOL,"
	   "BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,INFO,JSON,NTOPNG_INSTANCE_NAME,INTERFACE_ID"
#ifdef NTOPNG_PRO
	   ",PROFILE"
#endif
	   ") "
	   "VALUES ",
	   ntop->getPrefs()->get_mysql_tablename(),
	   vers);

  return strdup(sql);
}
#endif

/* ******************************************* */

bool MySQLDB::dumpFlow(time_t when, bool partial_dump, Flow *f, char *json) {
  char sql[CONST_MAX_SQL_QUERY_LEN], cli_str[64], srv_str[64], *json_buf;
  u_int32_t packets, first_seen, last_seen;
  u_int32_t bytes_cli2srv, bytes_srv2cli;

  if((f->get_cli_host() == NULL) || (f->get_srv_host() == NULL) || !MySQLDB::db_created)
    return(false);

  if(json == NULL)
    json_buf = strdup("");
  else {
    int l, i, j;

    l = strlen(json);

    if((json_buf = (char*)malloc(2*l + 1)) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      return(false);
    }

    for(i = 0, j = 0; i<l; i++) {
      /* http://stackoverflow.com/questions/9596652/how-to-escape-apostrophe-in-mysql */
      if(json[i] == '\'')
	json_buf[j++] = '\'';

      json_buf[j++] = json[i];
    }

    json_buf[j] = '\0';
  }

  if(partial_dump) {
    bytes_cli2srv = f->get_partial_bytes_cli2srv();
    bytes_srv2cli = f->get_partial_bytes_srv2cli();
    packets = f->get_partial_packets();
    first_seen = f->get_partial_first_seen();
    last_seen = f->get_partial_last_seen();
  } else {
    bytes_cli2srv = f->get_bytes_cli2srv();
    bytes_srv2cli = f->get_bytes_srv2cli();
    packets = f->get_packets();
    first_seen = f->get_first_seen();
    last_seen = f->get_last_seen();
  }

  if(f->get_cli_host()->get_ip()->isIPv4()) {
    snprintf(sql, sizeof(sql),
	     "INSERT INTO `%sv4` (VLAN_ID,L7_PROTO,IP_SRC_ADDR,L4_SRC_PORT,IP_DST_ADDR,L4_DST_PORT,PROTOCOL,"
	     "IN_BYTES,OUT_BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,INFO,JSON,NTOPNG_INSTANCE_NAME,INTERFACE_ID"
#ifdef NTOPNG_PRO
	     ",PROFILE"
#endif
	     ") VALUES ('%u','%u','%u','%u','%u','%u','%u','%u','%u','%u','%u','%u','%s',COMPRESS('%s'), '%s', '%u'"
#ifdef NTOPNG_PRO
	     ",'%s'"  // this is the string for traffic profile
#endif
	     ") ",
	     ntop->getPrefs()->get_mysql_tablename(),
	     f->get_vlan_id(),
	     f->get_detected_protocol().protocol,
	     htonl(f->get_cli_host()->get_ip()->get_ipv4()),
	     f->get_cli_port(),
	     htonl(f->get_srv_host()->get_ip()->get_ipv4()),
	     f->get_srv_port(),
	     f->get_protocol(),
	     bytes_cli2srv, bytes_srv2cli,
	     packets, first_seen, last_seen,
	     f->getFlowServerInfo() ? f->getFlowServerInfo() : "",
	     json_buf,
	     ntop->getPrefs()->get_instance_name(),
	     iface->get_id()
#ifdef NTOPNG_PRO
	     ,f->get_profile_name()
#endif
	     );
  }  else {
    snprintf(sql, sizeof(sql),
	     "INSERT INTO `%sv6` (VLAN_ID,L7_PROTO,IP_SRC_ADDR,L4_SRC_PORT,IP_DST_ADDR,L4_DST_PORT,PROTOCOL,"
	     "IN_BYTES,OUT_BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,INFO,JSON,NTOPNG_INSTANCE_NAME,INTERFACE_ID"
#ifdef NTOPNG_PRO
	     ",PROFILE"
#endif
	     ") VALUES ('%u','%u','%s','%u','%s','%u','%u','%u','%u','%u','%u','%u','%s',COMPRESS('%s'), '%s', '%u'"
#ifdef NTOPNG_PRO
	     ",'%s'"  // this is the string for traffic profile
#endif
	     ") ",
	     ntop->getPrefs()->get_mysql_tablename(),
	     f->get_vlan_id(),
	     f->get_detected_protocol().protocol,
	     f->get_cli_host()->get_ip()->print(cli_str, sizeof(cli_str)),
	     f->get_cli_port(),
	     f->get_srv_host()->get_ip()->print(srv_str, sizeof(srv_str)),
	     f->get_srv_port(),
	     f->get_protocol(),
	     bytes_cli2srv, bytes_srv2cli,
	     packets, first_seen, last_seen,
	     f->getFlowServerInfo() ? f->getFlowServerInfo() : "",
	     json_buf,
	     ntop->getPrefs()->get_instance_name(),
	     iface->get_id()
#ifdef NTOPNG_PRO
	     ,f->get_profile_name()
#endif
	     );
  }
  free(json_buf);

  ntop->getRedis()->lpush(CONST_SQL_QUEUE, sql, CONST_MAX_MYSQL_QUEUE_LEN);

  return(true);
}

/* ******************************************* */

bool MySQLDB::connectToDB(MYSQL *conn, bool select_db) {
  MYSQL *rc;
  unsigned long flags = CLIENT_COMPRESS;
  char *dbname = select_db ? ntop->getPrefs()->get_mysql_dbname() : NULL;

  db_operational = false;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Attempting to connect to MySQL for interface %s...",
			       iface->get_name());

  if(m) m->lock(__FILE__, __LINE__);

  if(mysql_init(conn) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to initialize MySQL connection");
    if(m) m->unlock(__FILE__, __LINE__);
    return(false);
  }

  if(ntop->getPrefs()->get_mysql_host()[0] == '/') /* Use socket */
    rc = mysql_real_connect(conn,
			    NULL, /* Host */
			    ntop->getPrefs()->get_mysql_user(),
			    ntop->getPrefs()->get_mysql_pw(),
			    dbname,
			    0, ntop->getPrefs()->get_mysql_host() /* socket */,
			    flags);
  else
    rc = mysql_real_connect(conn,
			    ntop->getPrefs()->get_mysql_host(),
			    ntop->getPrefs()->get_mysql_user(),
			    ntop->getPrefs()->get_mysql_pw(),
			    dbname,
			    3306 /* port */,
			    NULL /* socket */, flags);

  if(rc == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to connect to MySQL: %s [%s:%s]\n",
				 mysql_error(conn),
				 ntop->getPrefs()->get_mysql_host(),
				 ntop->getPrefs()->get_mysql_user());

    if(m) m->unlock(__FILE__, __LINE__);
    return(false);
  }

  db_operational = true;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Succesfully connected to MySQL [%s:%s] for interface %s",
			       ntop->getPrefs()->get_mysql_host(),
			       ntop->getPrefs()->get_mysql_user(),
			       iface->get_name());

  if(m) m->unlock(__FILE__, __LINE__);
  return(true);
}

/* ******************************************* */

/*
  Locking is necessary when multiple queries are executed
  simulatenously (e.g. via Lua)
*/
int MySQLDB::exec_sql_query(MYSQL *conn, char *sql,
			    bool doReconnect, bool ignoreErrors,
			    bool doLock) {
  int rc;
  MYSQL_RES *result;

  /* Don't check db_created here. This method is private
     so hopefully we know what we're doing.
   */
  if(!db_operational)
    return(-2);

  if(doLock && m) m->lock(__FILE__, __LINE__);
  if((rc = mysql_query(conn, sql)) != 0) {
    if(!ignoreErrors)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: [%s][%s]",
				   get_last_db_error(conn), sql);

    switch(mysql_errno(conn)) {
    case CR_SERVER_GONE_ERROR:
    case CR_SERVER_LOST:
      if(doReconnect) {
	mysql_close(conn);
	if(doLock && m) m->unlock(__FILE__, __LINE__);

	connectToDB(conn, true);

	return(exec_sql_query(conn, sql, false));
      } else
	ntop->getTrace()->traceEvent(TRACE_INFO, "[%s][%s]", get_last_db_error(conn), sql);
      break;

    default:
      ntop->getTrace()->traceEvent(TRACE_INFO, "[%s][%s]", get_last_db_error(conn), sql);
      break;
    }

    rc = -1;
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully executed '%s'", sql);
    // we want to return the number of rows which is more informative
    // than a simple 0
    if((result = mysql_store_result(&mysql)) == NULL)
      rc = 0;  // unable to retrieve the result but still the query succeded
    else {
      rc = mysql_num_rows(result);
      ntop->getTrace()->traceEvent(TRACE_INFO,
				   "Current result set has %lu rows",
				   (unsigned long)rc);
      mysql_free_result(result);
      rc = mysql_num_rows(result);
    }
  }

  if(doLock && m) m->unlock(__FILE__, __LINE__);

  return(rc);
}

/* ******************************************* */

int MySQLDB::exec_sql_query(lua_State *vm, char *sql, bool limitRows) {
  MYSQL_RES *result;
  MYSQL_ROW row;
  char *fields[MYSQL_MAX_NUM_FIELDS] = { NULL };
  int num_fields, rc, num = 0;

  if(!MySQLDB::db_created /* Make sure the db exists before doing queries */
     || !db_operational)
    return(-2);

  if(m) m->lock(__FILE__, __LINE__);

  if((rc = mysql_query(&mysql, sql)) != 0) {
    /* retry */
    mysql_close(&mysql);
    if(m) m->unlock(__FILE__, __LINE__);
    connectToDB(&mysql, true);

    if(!db_operational)
      return(-2);

    if(m) m->lock(__FILE__, __LINE__);
    rc = mysql_query(&mysql, sql);
  }

  if((rc != 0)
     || (((result = mysql_store_result(&mysql)) == NULL)
	 && mysql_field_count(&mysql) != 0 /* mysql_store_result() returned nothing; should it have? */)) {
    rc = mysql_errno(&mysql);

    if(rc) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: [%s][%d]",
				   get_last_db_error(&mysql), rc);

      lua_pushstring(vm, get_last_db_error(&mysql));
    } else {
      lua_pushnil(vm);
    }

    if(m) m->unlock(__FILE__, __LINE__);
    return(rc);
  }

  if((result == NULL) || (mysql_field_count(&mysql) == 0)) {
    lua_pushnil(vm);
  } else {
    num_fields = min_val(mysql_num_fields(result), MYSQL_MAX_NUM_FIELDS);
    lua_newtable(vm);

    num = 0;
    while((row = mysql_fetch_row(result))) {
      lua_newtable(vm);

      if(num == 0) {
	for(int i = 0; i < num_fields; i++) {
	  MYSQL_FIELD *field = mysql_fetch_field(result);

	  fields[i] = field->name;
	}
      }

      for(int i = 0; i < num_fields; i++)
	lua_push_str_table_entry(vm, (const char*)fields[i], row[i] ? row[i] : (char*)"");

      lua_pushnumber(vm, ++num);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if(limitRows && num >= MYSQL_MAX_NUM_ROWS) break;
    }

    mysql_free_result(result);
  }

if(m) m->unlock(__FILE__, __LINE__);

  return(0);
}

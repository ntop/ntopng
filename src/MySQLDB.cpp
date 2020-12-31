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

#ifdef HAVE_MYSQL

/* **************************************************** */

static void* queryLoop(void* ptr) {
  Utils::setThreadName("MySQLQueryLoop");
  return(((MySQLDB*)ptr)->queryLoop());
}

/* **************************************************** */

void* MySQLDB::queryLoop() {
  Redis *r = ntop->getRedis();
  char sql[CONST_MAX_SQL_QUERY_LEN];
  bool queue_not_empty = false;

  while(!ntop->getGlobals()->isShutdown()
	&& !MySQLDB::isDbCreated() /* wait until the db has been created */) {
    sleep(1);
  }

  if(ntop->getGlobals()->isShutdown() || !mysql_alt_connected)
    return(NULL);

  while(isRunning() || queue_not_empty) {
    int rc = r->lpop(CONST_SQL_QUEUE, sql, sizeof(sql));

    if(rc == 0) {
      queue_not_empty = true;
      try_exec_sql_query(&mysql_alt, sql);
    } else {
      queue_not_empty = false;
      _usleep(10000);
    }
  }

  return(NULL);
}

/* ******************************************* */
volatile bool MySQLDB::db_created = false;
bool MySQLDB::createDBSchema(bool set_db_created) {
  char sql[CONST_MAX_SQL_QUERY_LEN];

  if(iface) {
    disconnectFromDB(&mysql);
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

    // We transfer old table contents into the new schema
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

  // Add an extra column with the interface id to speed up certain query
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
      // if here, the table has engine InnoDB so we want to modify that to MyISAM
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s", sql);
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

  // Modify the number of partitions from 32 to 8
  for (u_int16_t i = 0; i < sizeof(ipvers) / sizeof(u_int16_t); i++){
    snprintf(sql, sizeof(sql),
	     "SELECT 1 "
	     "FROM information_schema.PARTITIONS "
	     "WHERE TABLE_SCHEMA='%s' "
	     "AND TABLE_NAME='%sv%hu' "
	     "GROUP BY TABLE_NAME HAVING COUNT(*) = 32 ",
	     ntop->getPrefs()->get_mysql_dbname(),
	     ntop->getPrefs()->get_mysql_tablename(),
	     ipvers[i]);
    if(exec_sql_query(&mysql, sql, true, true) > 0){
      // if here, the table has 32 partitions and we want to convert them to 8
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s", sql);
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "MySQL schema update. Altering table %sv%hu: "
				   "changing the number of partitions to 8.",
				   ntop->getPrefs()->get_mysql_tablename(), ipvers[i]);

      snprintf(sql, sizeof(sql),
	       "ALTER TABLE `%sv%hu` PARTITION BY HASH(FIRST_SWITCHED) PARTITIONS 8",
	       ntop->getPrefs()->get_mysql_tablename(), ipvers[i]);
      ntop->getTrace()->traceEvent(TRACE_INFO, "%s", sql);
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
  for (u_int16_t i = 0; i < sizeof(ipvers) / sizeof(u_int16_t); i++){
    snprintf(sql, sizeof(sql),
             "SELECT 1 "
             "FROM information_schema.COLUMNS "
             "WHERE TABLE_SCHEMA='%s' "
             "AND TABLE_NAME='%sv%hu' "
             "AND COLUMN_NAME='idx' "
             "AND (COLUMN_TYPE NOT LIKE 'BIGINT%%' OR EXTRA != 'auto_increment') ",
             ntop->getPrefs()->get_mysql_dbname(),
             ntop->getPrefs()->get_mysql_tablename(),
             ipvers[i]);
    if(exec_sql_query(&mysql, sql, true, true) > 0){
      // if here we have to convert the type to unsigned
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "MySQL schema update. Altering table %sv%hu: "
                                   "changing idx data type to bigint.",
                                   ntop->getPrefs()->get_mysql_tablename(),
                                   ipvers[i]);

      snprintf(sql, sizeof(sql),
               "ALTER TABLE `%sv%hu` MODIFY COLUMN `idx` bigint NOT NULL AUTO_INCREMENT",
               ntop->getPrefs()->get_mysql_tablename(), ipvers[i]);
      exec_sql_query(&mysql, sql, true, true);
    }
  }

  if(set_db_created)
    db_created = true;
  return true;
}

/* ******************************************* */

bool MySQLDB::createNprobeDBView() {
  char sql[CONST_MAX_SQL_QUERY_LEN];
  const u_int16_t ipvers[2] = {4, 6};
  u_int16_t i = 0;

  if(mysql_select_db(&mysql, ntop->getPrefs()->get_mysql_dbname())) {
    goto err;
    return false;
  }

  for(; i < sizeof(ipvers) / sizeof(u_int16_t); i++){
    snprintf(sql, sizeof(sql), MYSQL_DROP_NPROBE_VIEW, ipvers[i]);

    ntop->getTrace()->traceEvent(TRACE_INFO,
				 "Deleting existing nProbe views for IPV%hu:\n"
				 "[%s]",
				 ipvers[i],
				 sql);

    if(exec_sql_query(&mysql, sql, true) < 0)
      goto err;

    snprintf(sql, sizeof(sql), MYSQL_CREATE_NPROBE_VIEW,
	     ipvers[i], ipvers[i], ipvers[i], iface->get_id(),
	     ntop->getPrefs()->get_mysql_tablename(),
	     ipvers[i]);

    ntop->getTrace()->traceEvent(TRACE_INFO,
				 "Creating nProbe view on table %sflows for IPV%hu:\n"
				 "[%s]",
				 ntop->getPrefs()->get_mysql_tablename(),
				 ipvers[i],
				 sql);

    if(exec_sql_query(&mysql, sql, true) < 0) {
    err:
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error(&mysql));
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Before starting ntopng, make sure to start nprobe with option --mysql and template @NTOPNG@.");
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Example:");
      ntop->getTrace()->traceEvent(TRACE_ERROR, "./nprobe -i eno1 -T \"@NTOPNG@\" --mysql=\"localhost:ntopng:nf:root:root\" --zmq \"tcp://127.0.0.1:5556\" --zmq-probe-mode");
      ntop->getTrace()->traceEvent(TRACE_ERROR, "./ntopng  -i \"tcp://*:5556c\" -F \"mysql-nprobe;localhost;ntopng;nf;root;root\"");
      return false;
    }

  }

  db_created = true;

  return true;
}

/* ******************************************* */

MySQLDB::MySQLDB(NetworkInterface *_iface) : DB(_iface) {
  mysqlEnqueuedFlows = 0;
  log_fd = NULL;
  open_log();

  connectToDB(&mysql, false);
  mysql_alt_connected = connectToDB(&mysql_alt, true);
}

/* ******************************************* */

MySQLDB::~MySQLDB() {
  shutdown();
  disconnectFromDB(&mysql_alt);
  disconnectFromDB(&mysql);

  if(log_fd) fclose(log_fd);
}

/* ******************************************* */

void MySQLDB::open_log() {
  static char sql_log_path[MAX_PATH];

  if(ntop->getPrefs()->is_sql_log_enabled()) {
    snprintf(sql_log_path, sizeof(sql_log_path)-1, "%s/%d/ntopng_sql.log",
	     ntop->get_working_dir(), iface->get_id());

    log_fd = fopen(sql_log_path, "a");

    if(!log_fd)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create log %s", sql_log_path);
    else
      chmod(sql_log_path, CONST_DEFAULT_FILE_MODE);
  }
}

/* ******************************************* */

void MySQLDB::startLoop() {
  /*
    If mysql flows dump is enabled, then it is necessary to create
    and update the database schema. This must be executed only once.
   */
  if(!MySQLDB::db_created) {
    if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
      if(!createDBSchema()){
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "Unable to create database schema, quitting.");
	exit(EXIT_FAILURE);
      }
    } else if(ntop->getPrefs()->do_read_flows_from_nprobe_mysql()) {
      if(!createNprobeDBView()){
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "Unable to create a view on the nProbe database.");
	exit(EXIT_FAILURE);
      }
    }
  }

  pthread_create(&queryThreadLoop, NULL, ::queryLoop, (void*)this);
}

/* ******************************************* */

void MySQLDB::shutdown() {
  if(running) {
    void *res;

    DB::shutdown();
    pthread_join(queryThreadLoop, &res);
  }
}

/* ******************************************* */

char* MySQLDB::escapeAphostrophes(const char *unescaped) {
  char *buf;
  int l, i, j;

  if(!unescaped)
    return NULL;

  l = strlen(unescaped);

  if((buf = (char*)malloc(2*l + 1)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    return NULL;
  }

  for(i = 0, j = 0; i<l; i++) {
    /* http://stackoverflow.com/questions/9596652/how-to-escape-apostrophe-in-mysql */
    if(unescaped[i] == '\'')
	buf[j++] = '\'';

      buf[j++] = unescaped[i];
    }

  buf[j] = '\0';

  return buf;
}

/* ******************************************* */

int MySQLDB::flow2InsertValues(Flow *f, char *json,
			       char *values_buf, size_t values_buf_len) const {
  char cli_str[64], srv_str[64], *json_buf, *info_buf;
  u_int32_t packets, first_seen, last_seen;
  u_int32_t bytes_cli2srv, bytes_srv2cli;
  size_t len;

  if(!values_buf || !values_buf_len || !f)
    return -1;

  json_buf = escapeAphostrophes(json);
  info_buf = escapeAphostrophes(f->getFlowInfo());

  /* Prevents ERROR 1406 (22001): Data too long for column 'INFO' at row 1 */
  if(info_buf && strlen(info_buf) > 254)
    info_buf[255] = '\0';

  /* Use of partial_ functions is safe as they will deal with partial dumps automatically */
  bytes_cli2srv = f->get_partial_bytes_cli2srv();
  bytes_srv2cli = f->get_partial_bytes_srv2cli();
  packets = f->get_partial_packets();
  first_seen = f->get_partial_first_seen();
  last_seen = f->get_partial_last_seen();

  if(f->get_cli_ip_addr()->isIPv4()) {
    len = snprintf(values_buf, values_buf_len,
		   MYSQL_INSERT_VALUES_V4,
		   f->get_vlan_id(),
		   f->get_detected_protocol().app_protocol,
		   htonl(f->get_cli_ip_addr()->get_ipv4()),
		   f->get_cli_port(),
		   htonl(f->get_srv_ip_addr()->get_ipv4()),
		   f->get_srv_port(),
		   f->get_protocol(),
		   bytes_cli2srv, bytes_srv2cli,
		   packets, first_seen, last_seen,
		   info_buf ? info_buf : "",
		   json_buf ? json_buf : "",
		   ntop->getPrefs()->get_instance_name(),
		   iface->get_id()
#ifdef NTOPNG_PRO
		   ,f->get_profile_name()
#endif
		   );
  }  else {
    len = snprintf(values_buf, values_buf_len,
		   MYSQL_INSERT_VALUES_V6,
		   f->get_vlan_id(),
		   f->get_detected_protocol().app_protocol,
		   f->get_cli_ip_addr()->print(cli_str, sizeof(cli_str)),
		   f->get_cli_port(),
		   f->get_srv_ip_addr()->print(srv_str, sizeof(srv_str)),
		   f->get_srv_port(),
		   f->get_protocol(),
		   bytes_cli2srv, bytes_srv2cli,
		   packets, first_seen, last_seen,
		   info_buf ? info_buf : "",
		   json_buf ? json_buf : "",
		   ntop->getPrefs()->get_instance_name(),
		   iface->get_id()
#ifdef NTOPNG_PRO
		   ,f->get_profile_name()
#endif
		   );
  }

  if(json_buf)
    free(json_buf);
  if(info_buf)
    free(info_buf);

  return len;
}

/* ******************************************* */

void MySQLDB::try_exec_sql_query(MYSQL *conn, char *sql) {
  int rc;

  if (!db_operational) {
    if(!connectToDB(conn, true)) {
      _usleep(100);
      return;
    }
  }

  if (strlen(sql) >= CONST_MAX_SQL_QUERY_LEN - 1) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Tried to execute a query longer than %u. Skipping.",
      CONST_MAX_SQL_QUERY_LEN - 2);
  } else if((rc = exec_sql_query(conn, sql, true /* Attempt to reconnect */, true /* Don't print errors */, false)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s [rc=%d]", get_last_db_error(conn), rc);
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s", sql);

    /* Don't give up, manually re-connect */
    disconnectFromDB(conn);
    if(!connectToDB(conn, true)) _usleep(100);
  } else {
    incNumExportedFlows();
  }
}

/* ******************************************* */

bool MySQLDB::dumpFlow(time_t when, Flow *f, char *json) {
  char sql[CONST_MAX_SQL_QUERY_LEN];

  if((f->get_cli_ip_addr() == NULL) || (f->get_srv_ip_addr() == NULL) || !MySQLDB::db_created)
    return(false);

  if(f->get_cli_ip_addr()->isIPv4())
    snprintf(sql, sizeof(sql), "INSERT INTO `%sv4` " MYSQL_INSERT_FIELDS " VALUES ",
	     ntop->getPrefs()->get_mysql_tablename());
  else
    snprintf(sql, sizeof(sql), "INSERT INTO `%sv6` " MYSQL_INSERT_FIELDS " VALUES ",
	     ntop->getPrefs()->get_mysql_tablename());

  /* do the actual flow insertion as a tuple */
  flow2InsertValues(f, json, &sql[strlen(sql)], sizeof(sql) - strlen(sql) - 1);

  if (iface->read_from_pcap_dump()) {
    /* 
     Inserting inline in case of PCAP file as interrupting the datapath
     is not an issue and also avoids flows drops due to the redis queue 
     maximum length
    */
    try_exec_sql_query(&mysql_alt, sql);

  } else {
    if (ntop->getRedis()->llen(CONST_SQL_QUEUE) < CONST_MAX_MYSQL_QUEUE_LEN) {
      /* 
       We know that we should have locked before evaluating the condition
       above as another thread, via the lpush below, can invalidate the condition.
       However, we prefer to avoid an additional lock as the lpush guarantees
       that no more than CONST_MAX_MYSQL_QUEUE_LEN will ever be in the queue.
       The drawback is that the counter mysqlDroppedFlows
       is not guaranteed to be 100% accurate but we can tolerate this.
      */
      ntop->getRedis()->lpush(CONST_SQL_QUEUE, sql, CONST_MAX_MYSQL_QUEUE_LEN);
    } else {
      incNumDroppedFlows();
    }
  }

  return(true);
}

/* ******************************************* */

void MySQLDB::disconnectFromDB(MYSQL *conn) {
  mysql_close(conn);
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Disconnected from MySQL for interface %s...",
			       iface->get_name() ? iface->get_name() : "<unknown>");
}

/* ******************************************* */

static MYSQL *mysql_try_connect(MYSQL *conn, const char *dbname) {
  MYSQL *rc;
  unsigned long flags = CLIENT_COMPRESS;

  if(!ntop->getPrefs()->get_mysql_host())
    return(NULL);

  if(ntop->getPrefs()->get_mysql_host()[0] == '/') /* Use socketD */
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
			    ntop->getPrefs()->get_mysql_port(),
			    NULL /* socket */, flags);

  return(rc);
}

/* ******************************************* */

void mysql_result_to_lua(lua_State *vm, MYSQL_RES *result, bool limitRows) {
  MYSQL_ROW row;
  char *fields[MYSQL_MAX_NUM_FIELDS] = { NULL };
  int num_fields = min_val(mysql_num_fields(result), MYSQL_MAX_NUM_FIELDS);
  int num = 0;
  lua_newtable(vm);

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

    lua_pushinteger(vm, ++num);
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    if(num > MYSQL_MAX_NUM_ROWS) {
      static bool warning_shown = false;
      if(!warning_shown) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many results returned from MySQL, reduce query result set");
	warning_shown = true;
      }
    }

    if(limitRows && num >= MYSQL_MAX_NUM_ROWS) break;
  }
}

/* ******************************************* */

bool MySQLDB::connectToDB(MYSQL *conn, bool select_db) {
  MYSQL *rc;
  char *dbname = select_db ? ntop->getPrefs()->get_mysql_dbname() : NULL;

  db_operational = false;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Attempting to connect to MySQL for interface %s...",
			       iface->get_name());

  m.lock(__FILE__, __LINE__);

  if(mysql_init(conn) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to initialize MySQL connection");
    m.unlock(__FILE__, __LINE__);
    return(db_operational);
  }

  rc = mysql_try_connect(conn, dbname);

  if(rc == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to connect to MySQL: %s [%s@%s:%i]\n",
				 mysql_error(conn),
				 ntop->getPrefs()->get_mysql_user(),
				 ntop->getPrefs()->get_mysql_host(),
                 ntop->getPrefs()->get_mysql_port());

    m.unlock(__FILE__, __LINE__);
    return(db_operational);
  }

  db_operational = true;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Successfully connected to MySQL [%s@%s:%i] for interface %s",
			       ntop->getPrefs()->get_mysql_user(),
			       ntop->getPrefs()->get_mysql_host(),
			       ntop->getPrefs()->get_mysql_port(),
			       iface->get_name());

  m.unlock(__FILE__, __LINE__);
  return(db_operational);
}

/* ******************************************* */

int MySQLDB::exec_single_query(lua_State *vm, char *sql) {
  MYSQL conn;
  MYSQL_RES *result;
  bool result_ok = false;

  if(mysql_init(&conn) != NULL) {
    if((mysql_try_connect(&conn, NULL /* no db */) != NULL) &&
	  (mysql_query(&conn, sql) == 0) &&
	  ((result = mysql_store_result(&conn)) != NULL)) {
        if(mysql_field_count(&conn) != 0) {
          mysql_result_to_lua(vm, result, false);
          result_ok = true;
        }

        mysql_free_result(result);
    }

    mysql_close(&conn);
  }

  if(!result_ok) {
    lua_pushnil(vm);
    return(-1);
  }

  return(0);
}

/* ******************************************* */

/*
  Locking is necessary when multiple queries are executed
  simultaneously (e.g. via Lua)
*/
int MySQLDB::exec_sql_query(MYSQL *conn, const char *sql,
			    bool doReconnect, bool ignoreErrors,
			    bool doLock) {
  int rc;
  MYSQL_RES *result;

  /* Don't check db_created here. This method is private
     so hopefully we know what we're doing.
   */
  if(!db_operational)
    return(-2);

  if(doLock) m.lock(__FILE__, __LINE__);
  if((rc = mysql_query(conn, sql)) != 0) {
    if(!ignoreErrors)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: [%s][%s]",
				   get_last_db_error(conn), sql);

    switch(mysql_errno(conn)) {
    case CR_SERVER_GONE_ERROR:
    case CR_SERVER_LOST:
      if(doReconnect) {
	disconnectFromDB(conn);
	if(doLock) m.unlock(__FILE__, __LINE__);

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
      rc = 0;  // unable to retrieve the result but still the query succeeded
    else {
      rc = mysql_num_rows(result);
      ntop->getTrace()->traceEvent(TRACE_INFO,
				   "Current result set has %lu rows",
				   (unsigned long)rc);
      mysql_free_result(result);
    }
  }

  if(doLock) m.unlock(__FILE__, __LINE__);

  return(rc);
}

/* ******************************************* */

int MySQLDB::exec_sql_query(lua_State *vm, char *sql, bool limitRows, bool wait_for_db_created) {
  MYSQL_RES *result;
  int rc;

  if((wait_for_db_created && !MySQLDB::db_created /* Make sure the db exists before doing queries */)
     || !db_operational)
    return(-2);

  m.lock(__FILE__, __LINE__);


  if(ntop->getPrefs()->is_sql_log_enabled() && log_fd && sql) {
#ifndef WIN32
    char log_date[32];
    time_t log_time = time(NULL);
    struct tm result;

    strftime(log_date, sizeof(log_date),
	     "%d/%b/%Y %H:%M:%S", localtime_r(&log_time, &result));
    fprintf(log_fd, "%s ", log_date);
#endif

    fprintf(log_fd, "%s\n", sql);
    fflush(log_fd);
  }
  
  if((rc = mysql_query(&mysql, sql)) != 0) {
    /* retry */
    disconnectFromDB(&mysql);
    m.unlock(__FILE__, __LINE__);
    connectToDB(&mysql, true);

    if(!db_operational)
      return(-2);

    m.lock(__FILE__, __LINE__);
    rc = mysql_query(&mysql, sql);
  }

  if((rc != 0)
     || (((result = mysql_store_result(&mysql)) == NULL)
	 && mysql_field_count(&mysql) != 0 /* mysql_store_result() returned nothing; should it have? */)) {
    rc = mysql_errno(&mysql);

    if(rc) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: [%s][%d][%s]",
				   get_last_db_error(&mysql), rc, sql);
      lua_pushstring(vm, get_last_db_error(&mysql));
    } else {
      lua_pushnil(vm);
    }

    m.unlock(__FILE__, __LINE__);
    return(rc);
  }

  if((result == NULL) || (mysql_field_count(&mysql) == 0)) {
    lua_pushnil(vm);
  } else {
    mysql_result_to_lua(vm, result, limitRows);
    mysql_free_result(result);
  }
  
  m.unlock(__FILE__, __LINE__);

  return(0);
}

#endif

/*
 *
 * (C) 2013-15 - ntop.org
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

/* ******************************************* */

MySQLDB::MySQLDB(NetworkInterface *_iface) : DB(_iface) {
  MYSQL *rc;
  char sql[512];

  db_operational = false;

  if(mysql_init(&mysql) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to initialize MySQL connection");
    return;
  }

  rc = mysql_real_connect(&mysql, 
			  ntop->getPrefs()->get_mysql_host(),
			  ntop->getPrefs()->get_mysql_user(), 
			  ntop->getPrefs()->get_mysql_pw(),
			  NULL,
			  3306, NULL, 0);
    
  if(rc == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to connect to MySQL: %s [%s:%s]\n",
				 mysql_error(&mysql), 
				 ntop->getPrefs()->get_mysql_host(),
				 ntop->getPrefs()->get_mysql_user());
    return;
  }

  db_operational = true;

  /* 1 - Create database if missing */
  snprintf(sql, sizeof(sql), "CREATE DATABASE IF NOT EXISTS %s", ntop->getPrefs()->get_mysql_dbname());
  if(exec_sql_query(sql, 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    return;
  }
  
  if(mysql_select_db(&mysql, ntop->getPrefs()->get_mysql_dbname())) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    return;
  }

  /* 2 - Create table if missing */
  snprintf(sql, sizeof(sql), "CREATE TABLE IF NOT EXISTS `%s` ("
	   "`idx` int(11) NOT NULL auto_increment,"
	   "`vlan_id` int(11),"
	   "`cli_ip` varchar(48), `cli_port` int(11),"
	   "`srv_ip` varchar(48), `srv_port` int(11),"
	   "`proto` int(11), `bytes` int(11), `packets` int(11),"
	   "`first_seen` int(11), `last_seen` int(11),"
	   "`json` varchar(255),"
	   "INDEX(`idx`,`cli_ip`,`srv_ip`,`first_seen`, `last_seen`)) PARTITION BY HASH(first_seen) PARTITIONS 16",
	   ntop->getPrefs()->get_mysql_tablename());
  if(exec_sql_query(sql, 0) != 0) {
    printf("\n%s\n", sql);
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    return;
  }
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Succesfully connected to MySQL [%s:%s]\n",
			       ntop->getPrefs()->get_mysql_host(),
			       ntop->getPrefs()->get_mysql_user());
}

/* ******************************************* */

MySQLDB::~MySQLDB() {
  mysql_close(&mysql);
}

/* ******************************************* */

bool MySQLDB::dumpFlow(time_t when, Flow *f, char *json) {
  return(false);
}

/* ******************************************* */

int MySQLDB::exec_sql_query(char *sql, u_char dump_error_if_any) {

  if(!db_operational)
    return(-2);
  
  if(mysql_query(&mysql, sql)) {
    if(dump_error_if_any)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: [%s][%s]", 
				   get_last_db_error(), sql);
    return(-1);
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully executed '%s'", sql);
    return(0);
  }
}


#endif /* HAVE_MYSQL */

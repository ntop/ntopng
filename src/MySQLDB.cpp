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
  char sql[1024];
  my_bool reconnect = 1; /* Reconnect in case of timeout */

  db_operational = false;

  if(mysql_init(&mysql) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to initialize MySQL connection");
    return;
  }

  mysql_options(&mysql, MYSQL_OPT_RECONNECT, &reconnect);

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

  /* 2.1 - Create table if missing [IPv6] */
  snprintf(sql, sizeof(sql), "CREATE TABLE IF NOT EXISTS `%sv6` ("
	   "`idx` int(11) NOT NULL auto_increment,"
	   "`VLAN_ID` smallint unsigned, `L7_PROTO` smallint unsigned,"
	   "`IPV4_SRC_ADDR` varchar(48), `L4_SRC_PORT` smallint unsigned,"
	   "`IPV4_DST_ADDR` varchar(48), `L4_DST_PORT` smallint unsigned,"
	   "`PROTOCOL` tinyint unsigned, `BYTES` int unsigned, `PACKETS` int unsigned,"
	   "`FIRST_SWITCHED` int unsigned, `LAST_SWITCHED` int unsigned,"
	   "`JSON` BLOB,"
	   "INDEX(`idx`,`IPV4_SRC_ADDR`,`IPV4_DST_ADDR`,`FIRST_SWITCHED`, `LAST_SWITCHED`)) PARTITION BY HASH(`FIRST_SWITCHED`) PARTITIONS 32",
	   ntop->getPrefs()->get_mysql_tablename());

  if(exec_sql_query(sql, 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    return;
  }
  
  /* 2.2 - Create table if missing [IPv4] */
  snprintf(sql, sizeof(sql), "CREATE TABLE IF NOT EXISTS `%sv4` ("
	   "`idx` int(11) NOT NULL auto_increment,"
	   "`VLAN_ID` smallint unsigned, `L7_PROTO` smallint unsigned,"
	   "`IPV4_SRC_ADDR` int unsigned, `L4_SRC_PORT` smallint unsigned,"
	   "`IPV4_DST_ADDR` int unsigned, `L4_DST_PORT` smallint unsigned,"
	   "`PROTOCOL` tinyint unsigned, `BYTES` int unsigned, `PACKETS` int unsigned,"
	   "`FIRST_SWITCHED` int unsigned, `LAST_SWITCHED` int unsigned,"
	   "`JSON` BLOB,"
	   "INDEX(`idx`,`IPV4_SRC_ADDR`,`IPV4_DST_ADDR`,`FIRST_SWITCHED`, `LAST_SWITCHED`)) PARTITION BY HASH(`FIRST_SWITCHED`) PARTITIONS 32",
	   ntop->getPrefs()->get_mysql_tablename());

  if(exec_sql_query(sql, 0) != 0) {
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
  if((f->get_cli_host() == NULL) || (f->get_srv_host() == NULL))
    return(false);

  if(f->get_cli_host()->get_ip()->isIPv4())
    return(dumpV4Flow(when, f, json));
  else
    return(dumpV6Flow(when, f, json));
}

/* ******************************************* */

bool MySQLDB::dumpV4Flow(time_t when, Flow *f, char *json) {
  char sql[4096];

  snprintf(sql, sizeof(sql), "INSERT INTO `%sv4` (VLAN_ID,L7_PROTO,IPV4_SRC_ADDR,L4_SRC_PORT,IPV4_DST_ADDR,L4_DST_PORT,PROTOCOL,BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,JSON) "
	   "VALUES ('%u','%u','%u','%u','%u','%u','%u','%u','%u','%u','%u',COMPRESS('%s'))",
	   ntop->getPrefs()->get_mysql_tablename(),
	   f->get_vlan_id(),
	   f->get_detected_protocol().protocol,
	   f->get_cli_host()->get_ip()->get_ipv4(), f->get_cli_port(),
	   f->get_srv_host()->get_ip()->get_ipv4(), f->get_srv_port(),
	   f->get_protocol(), (unsigned int)f->get_bytes(),  (unsigned int)f->get_packets(),
	   (unsigned int)f->get_first_seen(), (unsigned int)f->get_last_seen(), 
	   json ? json : "");

  if(exec_sql_query(sql, 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    return(false);
  }

  return(true);
}

/* ******************************************* */

bool MySQLDB::dumpV6Flow(time_t when, Flow *f, char *json) {
  char sql[4096], cli_str[64], srv_str[64];

  snprintf(sql, sizeof(sql), "INSERT INTO `%sv6` (VLAN_ID,L7_PROTO,IPV4_SRC_ADDR,L4_SRC_PORT,IPV4_DST_ADDR,L4_DST_PORT,PROTOCOL,BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,JSON) "
	   "VALUES ('%u','%u','%s','%u','%s','%u','%u','%u','%u','%u','%u',COMPRESS('%s'))",
	   ntop->getPrefs()->get_mysql_tablename(),
	   f->get_vlan_id(),
	   f->get_detected_protocol().protocol,
	   f->get_cli_host()->get_ip()->print(cli_str, sizeof(cli_str)),
	   f->get_cli_port(),
	   f->get_srv_host()->get_ip()->print(srv_str, sizeof(srv_str)),
	   f->get_srv_port(),
	   f->get_protocol(), (unsigned int)f->get_bytes(),  (unsigned int)f->get_packets(),
	   (unsigned int)f->get_first_seen(), (unsigned int)f->get_last_seen(), 
	   json ? json : "");

  if(exec_sql_query(sql, 0) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    printf("\n%s\n", sql);
    return(false);
  }

  return(true);
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

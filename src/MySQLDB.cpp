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
  char sql[1024];

  if(connectToDB(false) == false)
    return;

  if(iface) {
    /* 1 - Create database if missing */
    snprintf(sql, sizeof(sql), "CREATE DATABASE IF NOT EXISTS %s", ntop->getPrefs()->get_mysql_dbname());
    if(exec_sql_query(sql, 1) != 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
      return;
    }

    if(mysql_select_db(&mysql, ntop->getPrefs()->get_mysql_dbname())) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
      return;
    }

    /* 2.1 - Create table if missing [IPv6] */
    snprintf(sql, sizeof(sql), "CREATE TABLE IF NOT EXISTS `%sv6_%u` ("
	     "`idx` int(11) NOT NULL auto_increment,"
	     "`VLAN_ID` smallint unsigned, `L7_PROTO` smallint unsigned,"
	     "`IPV4_SRC_ADDR` varchar(48), `L4_SRC_PORT` smallint unsigned,"
	     "`IPV4_DST_ADDR` varchar(48), `L4_DST_PORT` smallint unsigned,"
	     "`PROTOCOL` tinyint unsigned, `BYTES` int unsigned, `PACKETS` int unsigned,"
	     "`FIRST_SWITCHED` int unsigned, `LAST_SWITCHED` int unsigned,"
	     "`JSON` BLOB,"
	     "INDEX(`idx`,`IPV4_SRC_ADDR`,`IPV4_DST_ADDR`,`FIRST_SWITCHED`, `LAST_SWITCHED`)) PARTITION BY HASH(`FIRST_SWITCHED`) PARTITIONS 32",
	     ntop->getPrefs()->get_mysql_tablename(),
	     iface->get_id());

    if(exec_sql_query(sql, 1) != 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
      return;
    }

    /* 2.2 - Create table if missing [IPv4] */
    snprintf(sql, sizeof(sql), "CREATE TABLE IF NOT EXISTS `%sv4_%u` ("
	     "`idx` int(11) NOT NULL auto_increment,"
	     "`VLAN_ID` smallint unsigned, `L7_PROTO` smallint unsigned,"
	     "`IPV4_SRC_ADDR` int unsigned, `L4_SRC_PORT` smallint unsigned,"
	     "`IPV4_DST_ADDR` int unsigned, `L4_DST_PORT` smallint unsigned,"
	     "`PROTOCOL` tinyint unsigned, `BYTES` int unsigned, `PACKETS` int unsigned,"
	     "`FIRST_SWITCHED` int unsigned, `LAST_SWITCHED` int unsigned,"
	     "`JSON` BLOB,"
	     "INDEX(`idx`,`IPV4_SRC_ADDR`,`IPV4_DST_ADDR`,`FIRST_SWITCHED`, `LAST_SWITCHED`)) PARTITION BY HASH(`FIRST_SWITCHED`) PARTITIONS 32",
	     ntop->getPrefs()->get_mysql_tablename(),
	     iface->get_id());

    if(exec_sql_query(sql, 1) != 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
      return;
    }
  }
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
  char sql[8192];

  snprintf(sql, sizeof(sql), "INSERT INTO `%sv4_%u` (VLAN_ID,L7_PROTO,IPV4_SRC_ADDR,L4_SRC_PORT,IPV4_DST_ADDR,L4_DST_PORT,PROTOCOL,BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,JSON) "
	   "VALUES ('%u','%u','%u','%u','%u','%u','%u','%u','%u','%u','%u',COMPRESS('%s'))",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	   f->get_vlan_id(),
	   f->get_detected_protocol().protocol,
	   f->get_cli_host()->get_ip()->get_ipv4(), f->get_cli_port(),
	   f->get_srv_host()->get_ip()->get_ipv4(), f->get_srv_port(),
	   f->get_protocol(), (unsigned int)f->get_bytes(),  (unsigned int)f->get_packets(),
	   (unsigned int)f->get_first_seen(), (unsigned int)f->get_last_seen(),
	   json ? json : "");

  if(exec_sql_query(sql, 1) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    return(false);
  }

  return(true);
}

/* ******************************************* */

bool MySQLDB::dumpV6Flow(time_t when, Flow *f, char *json) {
  char sql[8192], cli_str[64], srv_str[64];

  snprintf(sql, sizeof(sql), "INSERT INTO `%sv6_%u` (VLAN_ID,L7_PROTO,IPV4_SRC_ADDR,L4_SRC_PORT,IPV4_DST_ADDR,L4_DST_PORT,PROTOCOL,BYTES,PACKETS,FIRST_SWITCHED,LAST_SWITCHED,JSON) "
	   "VALUES ('%u','%u','%s','%u','%s','%u','%u','%u','%u','%u','%u',COMPRESS('%s'))",
	   ntop->getPrefs()->get_mysql_tablename(), iface->get_id(),
	   f->get_vlan_id(),
	   f->get_detected_protocol().protocol,
	   f->get_cli_host()->get_ip()->print(cli_str, sizeof(cli_str)),
	   f->get_cli_port(),
	   f->get_srv_host()->get_ip()->print(srv_str, sizeof(srv_str)),
	   f->get_srv_port(),
	   f->get_protocol(), (unsigned int)f->get_bytes(),  (unsigned int)f->get_packets(),
	   (unsigned int)f->get_first_seen(), (unsigned int)f->get_last_seen(),
	   json ? json : "");

  if(exec_sql_query(sql, 1) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: %s\n", get_last_db_error());
    printf("\n%s\n", sql);
    return(false);
  }

  return(true);
}

/* ******************************************* */

bool MySQLDB::connectToDB(bool select_db) {
  MYSQL *rc;
  unsigned long flags = CLIENT_COMPRESS;
  char *dbname = select_db ? ntop->getPrefs()->get_mysql_dbname() : NULL;

  db_operational = false;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Attempting to connect to MySQL for interface %s...",
			       iface->get_name());

  if(m) m->lock(__FILE__, __LINE__);

  if(mysql_init(&mysql) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to initialize MySQL connection");
    if(m) m->unlock(__FILE__, __LINE__);
    return(false);
  }

  if(ntop->getPrefs()->get_mysql_host()[0] == '/') /* Use socket */
    rc = mysql_real_connect(&mysql,
			    NULL, /* Host */
			    ntop->getPrefs()->get_mysql_user(),
			    ntop->getPrefs()->get_mysql_pw(),
			    dbname,
			    0, ntop->getPrefs()->get_mysql_host() /* socket */,
			    flags);
  else
    rc = mysql_real_connect(&mysql,
			    ntop->getPrefs()->get_mysql_host(),
			    ntop->getPrefs()->get_mysql_user(),
			    ntop->getPrefs()->get_mysql_pw(),
			    dbname,
			    3306 /* port */,
			    NULL /* socket */, flags);

  if(rc == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failed to connect to MySQL: %s [%s:%s]\n",
				 mysql_error(&mysql),
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

int MySQLDB::exec_sql_query(char *sql, int do_reconnect) {
  int rc;

  if(!db_operational)
    return(-2);

  if(m) m->lock(__FILE__, __LINE__);
  if((rc = mysql_query(&mysql, sql)) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "MySQL error: [%s][%s]",  get_last_db_error(), sql);

    switch(mysql_errno(&mysql)) {
    case CR_SERVER_LOST:
      if(do_reconnect) {
	mysql_close(&mysql);
	if(m) m->unlock(__FILE__, __LINE__);

	connectToDB(true);

	return(exec_sql_query(sql, 0));
      } else
	printf("\n\n%s\n", sql);
      break;

    default:
      printf("\n\n%s\n", sql);
      break;
    }

    rc = -1;
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully executed '%s'", sql);
    rc = 0;
  }

  if(m) m->unlock(__FILE__, __LINE__);

  return(rc);
}

/* ******************************************* */

#define MAX_NUM_FIELDS  255
#define MAX_NUM_ROWS    999

int MySQLDB::exec_sql_query(lua_State *vm, char *sql) {
  MYSQL_RES *result;
  MYSQL_ROW row;
  char *fields[MAX_NUM_FIELDS] = { NULL };
  int num_fields, rc, num = 0;

  if(!db_operational)
    return(-2);

  if(m) m->lock(__FILE__, __LINE__);
  if(((rc = mysql_query(&mysql, sql)) != 0)
     || ((result = mysql_store_result(&mysql)) == NULL)) {
    
    lua_pushstring(vm, get_last_db_error());
    if(m) m->unlock(__FILE__, __LINE__);
    return(rc);
  }

  num_fields = min_val(mysql_num_fields(result), MAX_NUM_FIELDS);
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
    
    for(int i = 0; i < num_fields; i++) {
      lua_push_str_table_entry(vm, (const char*)fields[i], row[i] ? row[i] : (char*)"");
    }
    
    lua_pushnumber(vm, ++num);
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    if(num >= MAX_NUM_ROWS) break;
  }

  mysql_free_result(result);

  if(m) m->unlock(__FILE__, __LINE__);

  return(0);
}

#endif /* HAVE_MYSQL */

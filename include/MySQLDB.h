/*
 *
 * (C) 2013-22 - ntop.org
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

#ifndef _MYSQL_DB_CLASS_H_
#define _MYSQL_DB_CLASS_H_

#include "ntop_includes.h"

#ifdef HAVE_MYSQL

class MySQLDB : public DB {
 protected:
  MYSQL mysql;
  bool db_operational;
  FILE *log_fd;
  u_int32_t mysqlEnqueuedFlows;
  Mutex m;
  
  volatile bool db_created;
  pthread_t queryThreadLoop;

  bool connectToDB(MYSQL *conn, bool select_db);
  void open_log();
  char* get_last_db_error(MYSQL *conn) { return((char*)mysql_error(conn)); }
  int exec_sql_query(MYSQL *conn, const char *sql, bool doReconnect = true,
		     bool ignoreErrors = false, bool doLock = true);
  void try_exec_sql_query(MYSQL *conn, char *sql);
  virtual bool createDBSchema();
  bool createNprobeDBView();
  MYSQL* mysql_try_connect(MYSQL *conn, const char *dbname);
  int exec_quick_sql_query(char *sql, char *out, u_int out_len);
  void mysql_result_to_lua(lua_State *vm, MYSQL_RES *result,
			   int num_fields, bool limitRows);
    
 public:
  MySQLDB(NetworkInterface *_iface);
  virtual ~MySQLDB();

  virtual void* queryLoop();
  virtual bool dumpFlow(time_t when, Flow *f, char *json);

  void disconnectFromDB(MYSQL *conn);
  virtual bool isDbCreated() { return db_created; };
  char *escapeAphostrophes(const char *unescaped);
  int flow2InsertValues(Flow *f, char *json, char *values_buf, size_t values_buf_len);
  int exec_sql_query(lua_State *vm, char *sql, bool limitRows, bool wait_for_db_created);
  virtual bool startQueryLoop();
  void shutdown();
  int exec_single_query(lua_State *vm, char *sql);
  int select_database(char *dbname);
};

#endif

#endif /* _MYSQL_DB_CLASS_H_ */

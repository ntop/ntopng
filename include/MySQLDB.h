/*
 *
 * (C) 2013-21 - ntop.org
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

class MySQLDB : public DB {
 protected:
  MYSQL mysql;
  MYSQL mysql_alt;
  bool db_operational, mysql_alt_connected;
  FILE *log_fd;
  u_int32_t mysqlEnqueuedFlows;
  Mutex m;

  static volatile bool db_created;
  pthread_t queryThreadLoop;

  bool connectToDB(MYSQL *conn, bool select_db);
  void open_log();
  char* get_last_db_error(MYSQL *conn) { return((char*)mysql_error(conn)); }
  int exec_sql_query(MYSQL *conn, const char *sql, bool doReconnect = true,
		     bool ignoreErrors = false, bool doLock = true);
  void try_exec_sql_query(MYSQL *conn, char *sql);
  virtual bool createDBSchema(bool set_db_created = true);
  bool createNprobeDBView();

 public:
  MySQLDB(NetworkInterface *_iface);
  virtual ~MySQLDB();

  virtual void* queryLoop();
  virtual bool dumpFlow(time_t when, Flow *f, char *json);

  void disconnectFromDB(MYSQL *conn);
  static volatile bool isDbCreated() { return db_created; };
  static char *escapeAphostrophes(const char *unescaped);
  int flow2InsertValues(Flow *f, char *json, char *values_buf, size_t values_buf_len) const;
  int exec_sql_query(lua_State *vm, char *sql, bool limitRows, bool wait_for_db_created = true);
  void startLoop();
  void shutdown();
  static int exec_single_query(lua_State *vm, char *sql);
};

#endif /* _MYSQL_DB_CLASS_H_ */

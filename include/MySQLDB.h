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

#ifndef _MYSQL_DB_CLASS_H_
#define _MYSQL_DB_CLASS_H_

#include "ntop_includes.h"

class MySQLDB : public DB {
 protected:
  MYSQL mysql;
  bool db_operational;
  struct timeval lastUpdateTime;

  u_int32_t mysqlDroppedFlowsQueueTooLong;
  u_int64_t mysqlExportedFlows, mysqlLastExportedFlows;
  float mysqlExportRate;
  static volatile bool db_created;
  pthread_t queryThreadLoop;

  bool connectToDB(MYSQL *conn, bool select_db);
  char* get_last_db_error(MYSQL *conn) { return((char*)mysql_error(conn)); }
  int flow2InsertValues(bool partial_dump, Flow *f, char *json, char *values_buf, size_t values_buf_len) const;
  int exec_sql_query(MYSQL *conn, char *sql, bool doReconnect = true, bool ignoreErrors = false, bool doLock = true);

 public:
  MySQLDB(NetworkInterface *_iface = NULL);
  virtual ~MySQLDB();

  virtual void* queryLoop();
  bool createDBSchema();
  static volatile bool isDbCreated() {return db_created;};
  inline u_int32_t numDroppedFlows() const { return mysqlDroppedFlowsQueueTooLong; };
  inline float exportRate() const { return mysqlExportRate; };
  virtual bool dumpFlow(time_t when, bool partial_dump, bool idle_flow, Flow *f, char *json);
  int exec_sql_query(lua_State *vm, char *sql, bool limitRows);
  void startDBLoop();
  void updateStats(const struct timeval *tv);
  void lua(lua_State* vm) const;
};

#endif /* _MYSQL_DB_CLASS_H_ */

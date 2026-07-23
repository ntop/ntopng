/*
 *
 * (C) 2013-26 - ntop.org
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

#ifndef _DB_CLASS_H_
#define _DB_CLASS_H_

#include "ntop_includes.h"

typedef int db_result_row_callback(std::vector<std::string>* row,
                                   std::vector<std::string>* columns,
                                   void* user_data);

class DB {
 private:
 protected:
  NetworkInterface* iface;
  bool running;

 public:
  DB(NetworkInterface* _iface);
  virtual ~DB() {};

  virtual const char* getEngineName() { return "Unknown"; };
  virtual bool startDumpLoop() { return false; }

  virtual int execSQLQuery(const char* sql, bool doReconnect = true,
                           bool ignoreErrors = false,
                           db_result_row_callback* cb = NULL,
                           void* cb_user_data = NULL) {
    return (-1);
  }

  virtual int execSQLQuery(lua_State* vm, const char* sql, bool limitRows,
                           bool wait_for_db_created) {
    return (-1);
  }

  virtual int execSQLQuery2CSV(const char* sql, const char* delimiter,
                               const char* null_value, bool dump_in_json_format,
                               bool remove_headers,
                               struct mg_connection* mg_conn) {
    return (-1);
  }

  /* Execute queries that do not return data (e.g. insert) */
  virtual int execSQLWrite(const char* sql) { return (-1); }

  /* Batch insert (used by ClickHouse timeseries) */
  virtual bool insertTimeseriesBatch(const char* table,
                                     const std::vector<CHTSPoint*>& points,
                                     std::string& err) {
    return false;
  }

  virtual void archiveData(time_t epoch_begin, time_t epoch_end) {}

  inline NetworkInterface* getNetworkInterface() { return iface; };
  inline void startDBLoop() {
    if (startDumpLoop()) running = true;
  };
  inline int isRunning() { return (running); };
  virtual bool isDbCreated() { return (true); };
  virtual void shutdown();
  virtual void flush() {};
  virtual void checkIdle(time_t when) { ; }
};

#endif /* _DB_CLASS_H_ */

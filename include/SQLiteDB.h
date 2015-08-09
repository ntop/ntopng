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

#ifndef _SQLITE_DB_CLASS_H_
#define _SQLITE_DB_CLASS_H_

#include "ntop_includes.h"

typedef struct {
  sqlite3 *db;
  u_int32_t num_contacts_db_insert;
  char last_open_contacts_db_path[MAX_PATH];
  time_t last_insert;
} db_cache;

class SQLiteDB : public DB {
 private:
  sqlite3 *db;
  u_int32_t dir_duration;
  char db_path[MAX_PATH];
  time_t end_dump;
  u_int8_t db_id;

  void initDB(time_t when, const char *create_sql_string);
  void termDB();
  bool execSQL(sqlite3 *_db, char* sql);

 public:
  SQLiteDB(NetworkInterface *_iface = NULL,
     u_int32_t _dir_duration = CONST_DB_DUMP_FREQUENCY,
     u_int8_t _db_id = 0);
  ~SQLiteDB();
  
  inline u_int8_t get_db_id()       { return(db_id); };
  bool dumpFlow(time_t when, Flow *f, char *json);
};

#endif /* _SQLITE_DB_CLASS_H_ */

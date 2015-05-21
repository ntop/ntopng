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

/* ******************************************* */

DB::DB(NetworkInterface *_iface, u_int32_t _dir_duration, u_int8_t _db_id) {
  if((m = new(std::nothrow) Mutex()) == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mutex. Are you running out of memory?");

  dir_duration = max_val(_dir_duration, 300); /* 5 min is the minimum duration */
  db_path[0] = '\0';

  // sqlite3_config(SQLITE_CONFIG_SERIALIZED);
  db = NULL, end_dump = 0, iface = _iface, db_id = _db_id;
  contacts_cache_idx = 0;

  for(int i=0; i<CONST_NUM_OPEN_DB_CACHE; i++) {
    contacts_cache[i].db = NULL,
      contacts_cache[i].last_open_contacts_db_path[0] = '\0',
      contacts_cache[i].num_contacts_db_insert = 0,
      contacts_cache[i].last_insert = 0;
  }
}

/* ******************************************* */

DB::~DB() {
  termDB();
  if(m) delete m;
}

/* ******************************************* */

void DB::termDB() {
  if(!ntop->getPrefs()->do_dump_flows_on_db()) return;

  if(db) {
    execSQL(db, (char*)"COMMIT;");
    sqlite3_close(db);
    db = NULL;
  }

  for(int i=0; i<CONST_NUM_OPEN_DB_CACHE; i++) {
    if(contacts_cache[i].db != NULL) {
      char *zErrMsg = NULL;

      if(sqlite3_exec(contacts_cache[i].db, "COMMIT;", NULL, 0, &zErrMsg) != SQLITE_OK)
	sqlite3_free(zErrMsg);
    }
  }

  end_dump = 0;
}

/* ******************************************* */

void DB::initDB(time_t when, const char *create_sql_string) {
  char path[MAX_PATH];

  if(!ntop->getPrefs()->do_dump_flows_on_db()) return;

  if(db != NULL) {
    if(when < end_dump)
      return;
    else
      termDB(); /* Too old: we first close it */
  }

  when -= when % dir_duration;

  strftime(path, sizeof(path), "%Y/%m/%d/%H", localtime(&when));
  snprintf(db_path, sizeof(db_path), "%s/%u/flows/%s",
	   ntop->get_working_dir(), iface->get_id(), path);
  ntop->fixPath(db_path);

  if(Utils::mkdir_tree(db_path)) {
    strftime(path, sizeof(path), "%Y/%m/%d/%H/%M", localtime(&when));
    snprintf(db_path, sizeof(db_path), "%s/%u/flows/%s.sqlite",
	     ntop->get_working_dir(), iface->get_id(), path);

    end_dump = when + dir_duration;
    if(sqlite3_open(db_path, &db) != 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "[DB] Unable to open/create DB %s [%s]",
				   db_path, sqlite3_errmsg(db));
      end_dump = 0, db = NULL;
    } else {
      execSQL(db, (char*)create_sql_string);
      ntop->getTrace()->traceEvent(TRACE_INFO,
				   "[DB] Created %s", db_path);
    }
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "[DB] Unable to create directory tree %s", db_path);
}

/* ******************************************* */

bool DB::dumpFlow(time_t when, Flow *f, char *json) {
  const char *create_flows_db = "BEGIN; CREATE TABLE IF NOT EXISTS flows (ID INTEGER PRIMARY KEY   AUTOINCREMENT, vlan_id number, cli_ip string KEY, cli_port number, "
    "srv_ip string KEY, srv_port number, proto number, bytes number, first_seen number, last_seen number, duration number, json string);";
  char sql[4096], cli_str[64], srv_str[64];
  sqlite3_stmt *stmt = NULL;
  char *j = json ? : strndup("", 1);
  int rc = 1;

  snprintf(sql, sizeof(sql),
	   "INSERT INTO flows VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);");

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Dump Flow: %s", json);

  if(m) m->lock(__FILE__, __LINE__);
  initDB(when, create_flows_db);

  if (sqlite3_prepare(db, sql, -1, &stmt, 0) ||
      sqlite3_bind_int(stmt, 1, f->get_vlan_id()) ||
      sqlite3_bind_text(stmt, 2, f->get_cli_host()->get_ip()->print(cli_str, sizeof(cli_str)), sizeof(cli_str), SQLITE_TRANSIENT) ||
      sqlite3_bind_int(stmt, 3, f->get_cli_port()) ||
      sqlite3_bind_text(stmt, 4, f->get_srv_host()->get_ip()->print(srv_str, sizeof(srv_str)), sizeof(srv_str), SQLITE_TRANSIENT) ||
      sqlite3_bind_int(stmt, 5, f->get_srv_port()) ||
      sqlite3_bind_int(stmt, 6,  f->get_protocol()) ||
      sqlite3_bind_int(stmt, 7, (unsigned long)f->get_bytes()) ||
      sqlite3_bind_int(stmt, 8, (unsigned) f->get_first_seen()) ||
      sqlite3_bind_int(stmt, 9, (unsigned) f->get_last_seen()) ||
      sqlite3_bind_int(stmt, 10, f->get_duration()) ||
      sqlite3_bind_text(stmt, 11, j, strlen(j), SQLITE_TRANSIENT)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] Dump Flow query build failed: %s", sqlite3_errmsg(db));
    rc = 0;
    goto out;
  }

  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "[DB] SQL Error: step");
      rc = 0;
      goto out;
    }
  }

out:
  if (stmt) sqlite3_finalize(stmt);
  if(m) m->unlock(__FILE__, __LINE__);

  return rc;
}

/* ******************************************* */

bool DB::execSQL(sqlite3 *_db, char* sql) {
  if(ntop->getPrefs()->do_dump_flows_on_db()) {
    int rc;
    char *zErrMsg = 0;

    if(_db == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] NULL DB handler [%s]", sql);
      return(false);
    }

    ntop->getTrace()->traceEvent(TRACE_INFO, "[DB] %s", sql);

    rc = sqlite3_exec(_db, sql, NULL, 0, &zErrMsg);
    if(rc != SQLITE_OK) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[DB] SQL error: %s [%s]", sql, zErrMsg);
      sqlite3_free(zErrMsg);
      return(false);
    } else
      return(true);
  } else
    return(false);
}

/* ******************************************* */




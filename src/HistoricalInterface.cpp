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

/* **************************************************** */

HistoricalInterface::HistoricalInterface(const char *_endpoint)
  : ParserInterface(_endpoint) {

  if(ntop->getRedis())
      id = Utils::ifname2id(_endpoint);
    else
      id = -1;

    resetStats();
    purge_idle_flows_hosts = false;

  /* Create view for this interface so that it is visible in the GUI */
  view = new NetworkInterfaceView(this);
  if (!view)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Could not create view for interface %s", ifname);
  else {
    ntop->registerInterfaceView(view);
    view->set_id(this->id);
  }
}

/* **************************************************** */

void HistoricalInterface::resetStats() {
  num_historicals = 0, num_query_error = 0, num_open_error = 0, num_missing_file = 0, interface_id = 0;
  from_epoch = 0, to_epoch = 0;
  on_load = false;
}

/* **************************************************** */

void HistoricalInterface::cleanup() {
  if(!on_load) {
    NetworkInterface::cleanup();
    resetStats();
  }
}

/* **************************************************** */

int HistoricalInterface::sqlite_callback(void *data, int argc,
           char **argv, char **azColName) {
  for(int i=0; i<argc; i++) {
    // Inject only the json information
    if( (strcmp( (const char*)azColName[i], "json") == 0 ) &&
         (char*)(argv[i]) ) {

      parse_flows( (char*)(argv[i]) , sizeof((char*)(argv[i])) , 0, data);
    }
  }
  return(0);
}

/* **************************************************** */

int HistoricalInterface::loadData(char* p_file_name, int limit) {
  struct stat buf;
  char *zErrMsg = 0;
  sqlite3 *db;

  if(p_file_name && isRunning()) {
    // if(running == false)
    //   NetworkInterface::startPacketPolling();

    if(stat(p_file_name, &buf) != 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,"Missing file: %s",p_file_name);
      num_missing_file++;
      return CONST_HISTORICAL_FILE_ERROR;
    }

    if(sqlite3_open(p_file_name, &db)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to open %s: %s",
                                                        p_file_name, sqlite3_errmsg(db));
      num_open_error++;
      return CONST_HISTORICAL_OPEN_ERROR;
    } else
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Open db %s", p_file_name);

    char sql[256], sql_limit[20];
    snprintf(sql_limit, sizeof(sql_limit), "LIMIT %d", limit);
    snprintf(sql, sizeof(sql), "SELECT * FROM flows ORDER BY first_seen, srv_ip, srv_port, cli_ip, cli_port ASC %s",
             (limit == -1 ? "" : sql_limit));
    // Correctly open db, so now we can extract the contained flows via the sqlite_callback
    if(sqlite3_exec(db, sql, sqlite_callback, this, &zErrMsg)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "SQL Error: %s from %s", zErrMsg, p_file_name);
      sqlite3_free(zErrMsg);
      num_query_error++;
      goto close_db;
    }

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated flow polling from %s", p_file_name );

    close_db:
        sqlite3_close(db);

  }
  return CONST_HISTORICAL_OK;
}

/* **************************************************** */


int HistoricalInterface::loadData() {
  time_t actual_epoch, adjust_to_epoch;
  int ret_state = CONST_HISTORICAL_OK;
  NetworkInterface * iface = ntop->getInterfaceById(interface_id);

  if((iface != NULL) && (from_epoch != 0) && (to_epoch != 0)) {
    int iface_dump_id;

    iface_dump_id = iface->get_id();
    actual_epoch = from_epoch;
    adjust_to_epoch = to_epoch - 300; // Adjust to epoch each file contains 5 minute of data
    int num_steps = (from_epoch - adjust_to_epoch) / 300;
    if (num_steps < 1) num_steps = 1; /* avoid arithmetic exceptions */
    int limit = CONST_HISTORICAL_ROWS_LIMIT / num_steps;
    if (limit < 1) limit = 1;
    while (actual_epoch <= adjust_to_epoch && isRunning()) {
      char path[MAX_PATH];
      char db_path[MAX_PATH];
  
      memset(path, 0, sizeof(path));
      memset(db_path, 0, sizeof(db_path));

      strftime(path, sizeof(path), "%Y/%m/%d/%H/%M", localtime(&actual_epoch));
      snprintf(db_path, sizeof(db_path), "%s/%u/flows/%s.sqlite",
                    ntop->get_working_dir(), iface_dump_id , path);

     loadData(db_path, limit);

      num_historicals++;
      actual_epoch += 300; // 5 minute steps
    }
  }

  on_load = false;

  return ret_state;
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  HistoricalInterface *iface = (HistoricalInterface*)ptr;

  /* Wait until the initialization completes */
  while(!iface->isRunning() || !iface->is_on_load()) sleep(1);

  iface->loadData();
  return(NULL);
}

/* **************************************************** */

void HistoricalInterface::startLoadData(time_t  p_from_epoch, time_t p_to_epoch, int p_interface_id) {
  if(!on_load) {
    cleanup();
    on_load = true;

    from_epoch = p_from_epoch;
    to_epoch = p_to_epoch;
    interface_id = p_interface_id;

    pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);
    pollLoopCreated = true;
    NetworkInterface::startPacketPolling();
  }
}

/* **************************************************** */

void HistoricalInterface::shutdown() {
  void *res;

  if(running) {
    NetworkInterface::shutdown();
    pthread_join(pollLoop, &res);
  }
}

/* **************************************************** */

bool HistoricalInterface::set_packet_filter(char *filter) {
  ntop->getTrace()->traceEvent(TRACE_INFO,
			       "No filter can be set on a historical interface. Ignored %s", filter);
  return(false);
}

/*
 *
 * (C) 2013-18 - ntop.org
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


StatsManager::StatsManager(int interface_id, const char *filename) : StoreManager(interface_id) {
  char filePath[MAX_PATH], fileFullPath[MAX_PATH], fileName[MAX_PATH];

  MINUTE_CACHE_NAME = "MINUTE_STATS";
  HOUR_CACHE_NAME = "HOUR_STATS";
  DAY_CACHE_NAME = "DAY_STATS";

  snprintf(filePath, sizeof(filePath), "%s/%d/top_talkers/",
           ntop->get_working_dir(), ifid);
  strncpy(fileName, filename, sizeof(fileName));
  snprintf(fileFullPath, sizeof(fileFullPath), "%s/%d/top_talkers/%s",
	   ntop->get_working_dir(), ifid, filename);
  ntop->fixPath(filePath);
  ntop->fixPath(fileFullPath);

  if(!Utils::mkdir_tree(filePath)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Unable to create directory %s", filePath);
    return;
  }

  init(fileFullPath);
}

/**
 * @brief Opens a new cache to be used to store statistics.
 * @brief This function implements opening a new cache to store stats
 *        in; it is as of now based on SQLite3, and equals a new cache
 *        to a new table.
 *
 * @param cache_name Name of the cache to be opened.
 *
 * @return Zero in case of success, nonzero in case of failure.
 */
int StatsManager::openStore(const char *cache_name)
{
  char table_query[STORE_MANAGER_MAX_QUERY];
  int rc;

  if(!db)
    return 1;

  if(caches[cache_name])
    return 0;

  snprintf(table_query, sizeof(table_query),
	   "CREATE TABLE IF NOT EXISTS %s "
	   "(TSTAMP INTEGER PRIMARY KEY NOT NULL,"
	   "STATS TEXT NOT NULL);", cache_name);

  m.lock(__FILE__, __LINE__);

  rc = exec_query(table_query, NULL, NULL);

  if(!rc)
    caches[cache_name] = true;

  m.unlock(__FILE__, __LINE__);

  return rc;
}

/**
 * @brief Database interface to implement stats purging.
 * @details This function implements the database-specific code
 *          to delete stats older than a certain number of days.
 *
 * @todo Compute years better.
 *
 * @param cache_name Name of the cache to purge statistics from.
 * @param key Key to use as boundary.
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::deleteStatsOlderThan(const char * const cache_name, const time_t key) {
  char query[STORE_MANAGER_MAX_QUERY];
  int rc;

  if(!db)
    return -1;

  if(openStore(cache_name))
    return -1;

  snprintf(query, sizeof(query), "DELETE FROM %s WHERE "
	   "CAST(TSTAMP AS INTEGER) < %lu",
	   cache_name, static_cast<long int>(key));

  m.lock(__FILE__, __LINE__);

  rc = exec_query(query, NULL, NULL);

  m.unlock(__FILE__, __LINE__);

  return rc;
}

/**
 * @brief Minute stats interface to database purging.
 * @details This function hides cache-specific details (e.g. building the key
 *          for the minute stats cache.
 *
 * @param num_days Number of days to use to purge statistics.
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::deleteMinuteStatsOlderThan(unsigned num_days) {
  time_t rawtime;

  time(&rawtime);
  rawtime -= rawtime % 60;
  rawtime -= num_days * 24 * 60 * 60;

  return deleteStatsOlderThan(MINUTE_CACHE_NAME, rawtime);
}

/**
 * @brief Hour stats interface to database purging.
 * @details This function hides cache-specific details (e.g. building the key
 *          for the hour stats cache.
 *
 * @param num_days Number of days to use to purge statistics.
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::deleteHourStatsOlderThan(unsigned num_days) {
  time_t rawtime;

  time(&rawtime);
  rawtime -= rawtime % 60;
  rawtime -= num_days * 24 * 60 * 60;

  return deleteStatsOlderThan(HOUR_CACHE_NAME, rawtime);
}

/**
 * @brief Day stats interface to database purging.
 * @details This function hides cache-specific details (e.g. building the key
 *          for the day stats cache.
 *
 * @param num_days Number of days to use to purge statistics.
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::deleteDayStatsOlderThan(unsigned num_days) {
  time_t rawtime;

  time(&rawtime);
  rawtime -= rawtime % 60;
  rawtime -= num_days * 24 * 60 * 60;

  return deleteStatsOlderThan(DAY_CACHE_NAME, rawtime);
}

/**
 * @brief Callback for completion of retrieval of an interval of stats
 *
 * @param data Pointer to exchange data used by SQLite and the callback.
 * @param argc Number of retrieved columns.
 * @param argv Content of retrieved columns.
 * @param azColName Retrieved columns name.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
static int get_samplings_db(void *data, int argc,
                            char **argv, char **azColName) {
  struct statsManagerRetrieval *retr = (struct statsManagerRetrieval *)data;

  if(argc > 1) return -1;

  retr->rows.push_back(argv[0]);
  retr->num_vals++;

  return 0;
}

/**
 * @brief Retrieve an interval of samplings from a database
 * @details This function implements the database-specific code
 *          to retrieve an interval of samplings.
 *
 * @param retvals Pointer to a statsManagerRetrieval object keeping
 *        the result of the query.
 * @param cache_name Pointer to the name of the cache to retrieve
 *        stats from.
 * @param key_start Key to use as left boundary.
 * @param key_end Key to use as right boundary.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::retrieveStatsInterval(struct statsManagerRetrieval *retvals,
					const char * const cache_name,
                                        const time_t key_start,
					const time_t key_end) {
  char query[STORE_MANAGER_MAX_QUERY];
  int rc;

  if(!db)
    return -1;

  if(openStore(cache_name))
    return -1;

  // Set retvals to empty values - cannot use memset because of the vector
  struct statsManagerRetrieval empty;
  *retvals = empty;

  snprintf(query, sizeof(query), "SELECT STATS FROM %s WHERE TSTAMP >= %lu "
	   "AND TSTAMP <= %lu",
           cache_name, static_cast<long int>(key_start), static_cast<long int>(key_end));

  m.lock(__FILE__, __LINE__);

  rc = exec_query(query, get_samplings_db, (void *)retvals);

  m.unlock(__FILE__, __LINE__);

  return rc;
}

/**
 * @brief Retrieve an interval of samplings from the minute stats cache
 * @details This function implements the database-specific code
 *          to retrieve an interval of samplings masking out cache-specific
 *          details concerning the minute stats cache.
 *
 * @param epoch_start Left boundary of the interval.
 * @param epoch_end Right boundary of the interval.
 * @param retvals pointer to a statsManagerRetrieval object keeping
 *        the result of the query.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::retrieveMinuteStatsInterval(time_t epoch_start,
				              time_t epoch_end,
                                              struct statsManagerRetrieval *retvals) {
  if(!retvals)
    return -1;

  return retrieveStatsInterval(retvals, MINUTE_CACHE_NAME, epoch_start, epoch_end);
}

/**
 * @brief Retrieve an interval of samplings from the hour stats cache
 * @details This function implements the database-specific code
 *          to retrieve an interval of samplings masking out cache-specific
 *          details concerning the hour stats cache.
 *
 * @param epoch_start Left boundary of the interval.
 * @param epoch_end Right boundary of the interval.
 * @param retvals pointer to a statsManagerRetrieval object keeping
 *        the result of the query.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::retrieveHourStatsInterval(time_t epoch_start,
					    time_t epoch_end,
                                            struct statsManagerRetrieval *retvals) {
  if(!retvals)
    return -1;

  return retrieveStatsInterval(retvals, HOUR_CACHE_NAME, epoch_start, epoch_end);
}

/**
 * @brief Retrieve an interval of samplings from the day stats cache
 * @details This function implements the database-specific code
 *          to retrieve an interval of samplings masking out cache-specific
 *          details concerning the day stats cache.
 *
 * @param epoch_start Left boundary of the interval.
 * @param epoch_end Right boundary of the interval.
 * @param retvals pointer to a statsManagerRetrieval object keeping
 *        the result of the query.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::retrieveDayStatsInterval(time_t epoch_start,
					   time_t epoch_end,
                                           struct statsManagerRetrieval *retvals) {
  if(!retvals)
    return -1;

  return retrieveStatsInterval(retvals, DAY_CACHE_NAME, epoch_start, epoch_end);
}

/**
 * @brief Database interface to add a new stats sampling
 * @details This function implements the database-specific layer for
 *          the historical database (as of now using SQLite3).
 *
 * @param sampling String to be written at specified sampling point.
 * @param cache_name Name of the table to write the entry to.
 * @param key Key to use to insert the sampling.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::insertSampling(const char * const sampling, const char * const cache_name,
                                 long int key) {
  char query[STORE_MANAGER_MAX_QUERY];
  sqlite3_stmt *stmt = NULL;
  int rc = 0;

  if(!db)
    return -1;

  if(openStore(cache_name))
    return -1;

  snprintf(query, sizeof(query), "INSERT INTO %s (TSTAMP, STATS) VALUES(?,?)", cache_name);

  m.lock(__FILE__, __LINE__);

  if(sqlite3_prepare(db, query, -1, &stmt, 0) ||
     sqlite3_bind_int64(stmt, 1, key) ||
     sqlite3_bind_text(stmt, 2, sampling, strlen(sampling), SQLITE_TRANSIENT)) {
    rc = 1;
    goto out;
  }

  while((rc = sqlite3_step(stmt)) != SQLITE_DONE) {
    if(rc == SQLITE_ERROR) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: step");
      rc = 1;
      goto out;
    }
  }

  rc = 0;
 out:
  if (stmt) sqlite3_finalize(stmt);
  m.unlock(__FILE__, __LINE__);

  return rc;
}

/**
 * @brief Interface function for insertion of a new minute stats sampling
 * @details This public method implements insertion of a new sampling,
 *          hiding cache-specific details related to minute stats.
 *
 * @param timeinfo The sampling point expressed in localtime format.
 * @param sampling Pointer to a string keeping the sampling.
 *
 * @return Zero in case of success, nonzero in case of failure.
 */
int StatsManager::insertMinuteSampling(time_t epoch, const char * const sampling) {
  if(!sampling)
    return -1;

  return insertSampling(sampling, MINUTE_CACHE_NAME, static_cast<long int>(epoch));
}

/**
 * @brief Interface function for insertion of a new hour stats sampling
 * @details This public method implements insertion of a new sampling,
 *          hiding cache-specific details related to hour stats.
 *
 * @param timeinfo The sampling point expressed in localtime format.
 * @param sampling Pointer to a string keeping the sampling.
 *
 * @return Zero in case of success, nonzero in case of failure.
 */
int StatsManager::insertHourSampling(time_t epoch, const char * const sampling) {
  if(!sampling)
    return -1;

  return insertSampling(sampling, HOUR_CACHE_NAME, static_cast<long int>(epoch));
}

/**
 * @brief Interface function for insertion of a new day stats sampling
 * @details This public method implements insertion of a new sampling,
 *          hiding cache-specific details related to day stats.
 *
 * @param timeinfo The sampling point expressed in localtime format.
 * @param sampling Pointer to a string keeping the sampling.
 *
 * @return Zero in case of success, nonzero in case of failure.
 */
int StatsManager::insertDaySampling(time_t epoch, const char * const sampling) {
  if(!sampling)
    return -1;

  return insertSampling(sampling, DAY_CACHE_NAME, static_cast<long int>(epoch));
}

/* *************************************************************** */

/**
 * @brief Callback for completion of minute stats retrieval.
 *
 * @param data Pointer to exchange data used by SQLite and the callback.
 * @param argc Number of retrieved columns.
 * @param argv Content of retrieved columns.
 * @param azColName Retrieved columns name.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
static int get_sampling_db_callback(void *data, int argc,
                                    char **argv, char **azColName) {
  string *buffer = (string *)data;

  if(argc > 1)
    ntop->getTrace()->traceEvent(TRACE_INFO, "%s: more than one row (%d) returned",
				 __FUNCTION__, argc);

  buffer->assign(argv[0]);

  return 0;
}

/**
 * @brief Database interface to retrieve a stats sampling
 * @details This function implements the database-specific layer for
 *          the historical database (as of now using SQLite3).
 *
 * @param sampling Pointer to a string to be filled with retrieved data.
 * @param cache_name Name of the cache to retrieve stats from.
 * @param key_low Base key used to retrieve the sampling.
 * @param key_high End key used to retrieve the sampling.
 *
 * @return Zero in case of success, nonzero in case of error.
 */
int StatsManager::getSampling(string * sampling, const char * const cache_name,
                              time_t key_low, time_t key_high) {

  char query[STORE_MANAGER_MAX_QUERY];
  int rc;

  *sampling = "[ ]";

  if(!db)
    return -1;

  if(openStore(cache_name))
    return -1;

  snprintf(query, sizeof(query), "SELECT STATS FROM %s WHERE "
	   "CAST(TSTAMP AS INTEGER) <= %lu AND "
	   "CAST(TSTAMP AS INTEGER) >= %lu",
           cache_name, static_cast<long int>(key_high), static_cast<long int>(key_low));

  m.lock(__FILE__, __LINE__);

  rc = exec_query(query, get_sampling_db_callback, (void *)sampling);

  m.unlock(__FILE__, __LINE__);

  return rc;
}

/**
 * @brief Interface function for retrieval of a minute stats sampling
 * @details This public method implements retrieval of an existing
 *          sampling, hiding cache-specific details related to minute stats.
 *
 * @param epoch The sampling point expressed as number of seconds
 *              from epoch.
 * @param sampling Pointer to a string to be filled with the sampling.
 *
 * @return Zero in case of success, nonzero in case of failure.
 */
int StatsManager::getMinuteSampling(time_t epoch, string * sampling) {
  if(!sampling)
    return -1;

  time_t epoch_start = epoch - (epoch % 60);
  time_t epoch_end = epoch_start + 59;

  return getSampling(sampling, MINUTE_CACHE_NAME, epoch_start, epoch_end);
}


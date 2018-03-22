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

#ifndef _STATS_MANAGER_H_
#define _STATS_MANAGER_H_

#include "ntop_includes.h"

struct statsManagerRetrieval {
  vector<string> rows;
  int num_vals;

  statsManagerRetrieval(): num_vals(0) {}
};

class StatsManager : protected StoreManager {
public:
    StatsManager(int interface_id, const char *db_filename);
    ~StatsManager() {};
    int insertMinuteSampling(time_t epoch, const char * const sampling);
    int insertHourSampling(time_t epoch, const char * const sampling);
    int insertDaySampling(time_t epoch, const char * const sampling);
    int getMinuteSampling(time_t epoch, string * sampling);
    int openStore(const char *cache_name);
    int retrieveMinuteStatsInterval(time_t epoch_start, time_t epoch_end,
                                    struct statsManagerRetrieval *retvals);
    int retrieveHourStatsInterval(time_t epoch_start, time_t epoch_end,
                                  struct statsManagerRetrieval *retvals);
    int retrieveDayStatsInterval(time_t epoch_start, time_t epoch_end,
                                 struct statsManagerRetrieval *retvals);
    int deleteMinuteStatsOlderThan(unsigned num_days);
    int deleteHourStatsOlderThan(unsigned num_days);
    int deleteDayStatsOlderThan(unsigned num_days);
private:
    const char *MINUTE_CACHE_NAME,
	       *HOUR_CACHE_NAME, *DAY_CACHE_NAME; // see constructor for initialization
    /*
     * map has O(log(n)) access time, but we suppose the number
     * of caches is not huge
     */
    std::map<string, bool> caches;

    int insertSampling(const char * const sampling, const char * const cache_name, long int key);
    int getSampling(string * sampling, const char * const cache_name, time_t key_low, time_t key_high);
    int deleteStatsOlderThan(const char * const cache_name, const time_t key);
    int retrieveStatsInterval(struct statsManagerRetrieval *retvals, const char * const cache_name,
			      const time_t key_start, const time_t key_end);
};

#endif /* _STATS_MANAGER_H_ */

/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef _THREADED_ACTIVITY_STATS_H_
#define _THREADED_ACTIVITY_STATS_H_

#include "ntop_includes.h"

class ThreadedActivity;

typedef struct {
  ticks  tot_ticks, max_ticks;
  u_long tot_calls; /* Total number of calls */
  bool is_slow;
} threaded_activity_timeseries_delta_stats_t; /* Stats periodically reset to keep a most-recent view */

typedef struct {
  /* Overall totals */
  u_long tot_calls; /* Total number of calls */
  u_long tot_drops; /* Total number of times timeseries haven't been called because writes are detected to be slow */
  /* Stats for the last run */
  u_long tot_is_slow;  /* Total number of times the periodic activity has been detected to have slow updates */
  float last_max_call_duration_ms; /* Maximum time taken to perform a call during the last run */
  float last_avg_call_duration_ms; /* Average time taken to perform a call during the last run */
  bool  last_slow; /* True if slow timeseries updates have been detected during the last run */
  threaded_activity_timeseries_delta_stats_t last; /* Keep stats for the last run */
} threaded_activity_timeseries_stats_t;

typedef struct {
  struct {
    threaded_activity_timeseries_stats_t write;
  } timeseries;
  struct {
    bool has_drops;
  } alerts;
} threaded_activity_stats_t;

class ThreadedActivityStats {
 private:
  threaded_activity_stats_t ta_stats;
  time_t last_start_time, in_progress_since, last_queued_time;
  const ThreadedActivity *threaded_activity;
  u_long num_not_executed, num_is_slow;
  u_long max_duration_ms, last_duration_ms;
  int progress;
  time_t scheduled_time, deadline;
  static ticks tickspersec;
  bool not_executed, is_slow;

  void updateTimeseriesStats(bool write, ticks cur_ticks);
  void luaTimeseriesStats(lua_State *vm);
  
 public:
  ThreadedActivityStats(const ThreadedActivity *ta);
  ~ThreadedActivityStats();

  inline time_t getLastQueueTime()   { return(last_queued_time);  }
  inline time_t getInProgressSince() { return(in_progress_since); }
  inline time_t getLastStartTime()   { return(last_start_time);   }

  bool isTimeseriesSlow() const;
  inline bool hasAlertsDrops() const {
    return ta_stats.alerts.has_drops;
  }

  /* Timeseries stats and drops for writes */
  void updateTimeseriesWriteStats(ticks cur_ticks);
  void incTimeseriesWriteDrops();

  void updateStatsQueuedTime(time_t queued_time);
  void updateStatsBegin(struct timeval *begin);
  void updateStatsEnd(u_long duration_ms);

  void setNotExecutedAttivity(bool _not_executed)   { not_executed = _not_executed; if(_not_executed) num_not_executed++; }
  void setSlowPeriodicActivity(bool _slow)          { is_slow = _slow; if(_slow) num_is_slow++;                           }
  inline void setScheduledTime(time_t t) { scheduled_time = t; }
  inline void setDeadline(time_t t)      { deadline = t; }
  inline void setCurrentProgress(int _progress) { progress = min(max(_progress, 0), 100); }
  inline void setAlertsDrops()           { ta_stats.alerts.has_drops = true; }

  void lua(lua_State *vm);
};

#endif /* _THREADED_ACTIVITY_STATS_H_ */

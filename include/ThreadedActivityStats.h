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
  u_long tot_calls;
  bool is_slow;
} threaded_activity_rrd_stats_t;

typedef struct {
  struct {
    threaded_activity_rrd_stats_t write, read;
  } rrd;
} threaded_activity_stats_t;

class ThreadedActivityStats {
 private:
  threaded_activity_stats_t *ta_stats, *ta_stats_shadow;
  time_t last_start_time, in_progress_since, last_queued_time;
  const ThreadedActivity *threaded_activity;
  u_long max_duration_ms, last_duration_ms;
  u_long num_not_executed, num_is_slow;
  bool not_executed, is_slow;
  static ticks tickspersec;

  void updateRRDStats(bool write, ticks cur_ticks);
  void luaRRDStats(lua_State *vm, bool write, threaded_activity_stats_t *cur_stats);
  
 public:
  ThreadedActivityStats(const ThreadedActivity *ta);
  ~ThreadedActivityStats();

  inline time_t getLastQueueTime()   { return(last_queued_time);  }
  inline time_t getInProgressSince() { return(in_progress_since); }
  inline time_t getLastStartTime()   { return(last_start_time);   }

  bool isRRDSlow() const;
  void updateRRDWriteStats(ticks cur_ticks);
  void updateRRDReadStats(ticks cur_ticks);

  void updateStatsQueuedTime(time_t queued_time);
  void updateStatsBegin(struct timeval *begin);
  void updateStatsEnd(u_long duration_ms);

  void setNotExecutedAttivity()   { not_executed = true; num_not_executed++; }
  void setSlowPeriodicActivity()  { is_slow = true;      num_is_slow++;      }
  inline void clearErrors()       { not_executed = false; is_slow = false;   }

  void resetStats();

  void lua(lua_State *vm);
};

#endif /* _THREADED_ACTIVITY_STATS_H_ */

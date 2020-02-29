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

#include "ntop_includes.h"

ticks ThreadedActivityStats::tickspersec = Utils::gettickspersec();

/* ******************************************* */

ThreadedActivityStats::ThreadedActivityStats(const ThreadedActivity *ta) {
  memset(&ta_stats, 0, sizeof(ta_stats));
  last_start_time = in_progress_since = 0;
  last_queued_time = deadline = scheduled_time = 0;
  last_duration_ms = max_duration_ms = 0;
  threaded_activity = ta;
  num_not_executed = num_is_slow = 0;
  not_executed = is_slow = false;
  progress = 0;
}

/* ******************************************* */

ThreadedActivityStats::~ThreadedActivityStats() {
}

/* ******************************************* */

bool ThreadedActivityStats::isTimeseriesSlow() const {
  return ta_stats.timeseries.write.last.is_slow;
}

/* ******************************************* */

void ThreadedActivityStats::incTimeseriesWriteDrops(u_long num_drops) {
  ta_stats.timeseries.write.tot_drops += num_drops;
}

/* ******************************************* */

void ThreadedActivityStats::updateTimeseriesWriteStats(ticks cur_ticks) {
  threaded_activity_timeseries_delta_stats_t *last_stats = &ta_stats.timeseries.write.last;

  /* Increase overall total stats */
  ta_stats.timeseries.write.tot_calls++;

  /* Increase delta stats */
  last_stats->tot_ticks += cur_ticks;
  last_stats->tot_calls++;
  if(cur_ticks > last_stats->max_ticks) last_stats->max_ticks = cur_ticks;

  if(!last_stats->is_slow && last_stats->tot_calls && !(last_stats->tot_calls % 10)) {
    /* Evaluate the condition every 10 updates */
    if(last_stats->tot_ticks / (float)tickspersec / last_stats->tot_calls * 1000 >= THREADED_ACTIVITY_STATS_SLOW_TIMESERIES_MS) {
      last_stats->is_slow = true; /* Keep it slow for the rest of the current execution */
      ta_stats.timeseries.write.tot_is_slow++; /* Increase the overall total value as well */

      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Evaluated condition: [slow: %u][path: %s]", last_stats->is_slow ? 1 : 0, threaded_activity->activityPath());
    }
  }
}

/* ******************************************* */

void ThreadedActivityStats::updateStatsQueuedTime(time_t queued_time) {
  last_queued_time = queued_time;
}

/* ******************************************* */

void ThreadedActivityStats::updateStatsBegin(struct timeval *begin) {
  in_progress_since = last_start_time = begin->tv_sec;

  /* Start over */
  memset(&ta_stats.timeseries.write.last, 0, sizeof(ta_stats.timeseries.write.last));
  ta_stats.alerts.has_drops = false;
}

/* ******************************************* */

void ThreadedActivityStats::updateStatsEnd(u_long duration_ms) {
  /* Update time and progress information */
  in_progress_since = 0;
  last_duration_ms = duration_ms;
  if(duration_ms > max_duration_ms)
    max_duration_ms = duration_ms;

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "END [before] >>> [slow: %u][prev_slow: %u][last_slow: %u][path: %s][num_points: %u]",
  // 			       isTimeseriesSlow(), ta_stats.timeseries.write.last_slow, ta_stats.timeseries.write.last.is_slow, threaded_activity->activityPath(), ta_stats.timeseries.write.last.tot_calls);

  /* Update Timeseries stats for the last run which has just ended with this call */
  ta_stats.timeseries.write.last_slow = ta_stats.timeseries.write.last.is_slow;

  if(ta_stats.timeseries.write.last.tot_calls > 0)
    ta_stats.timeseries.write.last_max_call_duration_ms = ta_stats.timeseries.write.last.max_ticks / (float)tickspersec * 1000,
      ta_stats.timeseries.write.last_avg_call_duration_ms = ta_stats.timeseries.write.last.tot_ticks / (float)tickspersec / ta_stats.timeseries.write.last.tot_calls * 1000;
  else
    ta_stats.timeseries.write.last_max_call_duration_ms = ta_stats.timeseries.write.last_avg_call_duration_ms = 0;

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "END [after] >>> [slow: %u][prev_slow: %u][last_slow: %u][path: %s][num_points: %u]",
  // 			       isTimeseriesSlow(), ta_stats.timeseries.write.last_slow, ta_stats.timeseries.write.last.is_slow, threaded_activity->activityPath(), ta_stats.timeseries.write.last.tot_calls);
}

/* ******************************************* */

void ThreadedActivityStats::luaTimeseriesStats(lua_State *vm) {
  threaded_activity_timeseries_stats_t *cur_stats = &ta_stats.timeseries.write;

  lua_newtable(vm);

  lua_newtable(vm); /* "write" */

  /* Overall totals */
  lua_push_uint64_table_entry(vm, "tot_calls", (u_int64_t)cur_stats->tot_calls);
  lua_push_uint64_table_entry(vm, "tot_drops", (u_int64_t)cur_stats->tot_drops);

  /* Stats for the last run */
  lua_newtable(vm); /* "last" */

  lua_push_float_table_entry(vm, "max_call_duration_ms", cur_stats->last_max_call_duration_ms);
  lua_push_float_table_entry(vm, "avg_call_duration_ms", cur_stats->last_avg_call_duration_ms);
  lua_push_bool_table_entry(vm, "is_slow", cur_stats->last_slow);

  lua_pushstring(vm, "last");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_pushstring(vm, "write");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_pushstring(vm, "timeseries");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ******************************************* */

void ThreadedActivityStats::lua(lua_State *vm) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "max_duration_ms", (u_int64_t)max_duration_ms);
  lua_push_uint64_table_entry(vm, "last_duration_ms", (u_int64_t)last_duration_ms);

  lua_pushstring(vm, "duration");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  luaTimeseriesStats(vm);

  if(in_progress_since)
    lua_push_uint64_table_entry(vm, "in_progress_since", in_progress_since);

  if(last_start_time) 
    lua_push_uint64_table_entry(vm, "last_start_time", last_start_time);

  if(last_queued_time)
    lua_push_uint64_table_entry(vm, "last_queued_time", last_queued_time);

  if(not_executed)
    lua_push_bool_table_entry(vm, "not_executed", true);
  if(num_not_executed)
    lua_push_uint64_table_entry(vm, "num_not_executed", num_not_executed);

  if(is_slow)
    lua_push_bool_table_entry(vm, "is_slow", true);
  if(num_is_slow)
    lua_push_uint64_table_entry(vm, "num_is_slow", num_is_slow);

  if(isTimeseriesSlow())
    lua_push_bool_table_entry(vm, "timeseries_slow", true);
  if(ta_stats.timeseries.write.tot_is_slow)
    lua_push_uint64_table_entry(vm, "num_timeseries_slow", ta_stats.timeseries.write.tot_is_slow);

  if(hasAlertsDrops())
    lua_push_bool_table_entry(vm, "alerts_drops", true);

  lua_push_uint64_table_entry(vm, "scheduled_time", scheduled_time);
  lua_push_uint64_table_entry(vm, "deadline", deadline);
  lua_push_int32_table_entry(vm, "progress", progress);
}

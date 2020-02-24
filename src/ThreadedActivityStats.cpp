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
  ta_stats = (threaded_activity_stats_t*)calloc(1, sizeof(*ta_stats));
  ta_stats_shadow = NULL;
  last_start_time = in_progress_since = 0;
  last_queued_time = deadline = scheduled_time = 0;
  last_duration_ms = max_duration_ms = 0;
  threaded_activity = ta;
  num_not_executed = num_is_slow = 0;
  progress = 0;
  not_executed = is_slow = false;
}

/* ******************************************* */

ThreadedActivityStats::~ThreadedActivityStats() {
  if(ta_stats)        free(ta_stats);
  if(ta_stats_shadow) free(ta_stats_shadow);
}

/* ******************************************* */

bool ThreadedActivityStats::isRRDSlow() const {
  threaded_activity_stats_t *cur_stats = ta_stats;

  if(cur_stats) {
    return cur_stats->rrd.write.is_slow || cur_stats->rrd.read.is_slow;
  }

  return false;
}

/* ******************************************* */

void ThreadedActivityStats::incRRDWriteDrops() {
  threaded_activity_stats_t *cur_stats = ta_stats;

  if(cur_stats)
    cur_stats->rrd.write.tot_drops++;
}

/* ******************************************* */

void ThreadedActivityStats::updateRRDStats(bool write, ticks cur_ticks) {
  threaded_activity_stats_t *cur_stats = ta_stats;
  threaded_activity_rrd_stats_t *rrd_stats;

  if(cur_stats) {
    rrd_stats = write ? &cur_stats->rrd.write : &cur_stats->rrd.read;

    rrd_stats->tot_ticks += cur_ticks;
    rrd_stats->tot_calls += 1;
    if(cur_ticks > rrd_stats->max_ticks) rrd_stats->max_ticks = cur_ticks;

    if(rrd_stats->tot_calls && !(rrd_stats->tot_calls % 10)) {
      /* Evaluate the condition every 10 updates */
      if(rrd_stats->tot_ticks / (float)tickspersec / rrd_stats->tot_calls * 1000 >= THREADED_ACTIVITY_STATS_SLOW_RRD_MS)
	rrd_stats->is_slow = true;
      else
	rrd_stats->is_slow = false;

      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Evaluated condition: [slow: %u]", rrd_stats->is_slow ? 1 : 0);
    }
  }
}

/* ******************************************* */

void ThreadedActivityStats::updateRRDWriteStats(ticks cur_ticks) {
  updateRRDStats(true /* Write */, cur_ticks);
}

/* ******************************************* */

void ThreadedActivityStats::updateRRDReadStats(ticks cur_ticks) {
  updateRRDStats(false /* Read */, cur_ticks);
}

/* ******************************************* */

void ThreadedActivityStats::updateStatsQueuedTime(time_t queued_time) {
  last_queued_time = queued_time;
}

/* ******************************************* */

void ThreadedActivityStats::updateStatsBegin(struct timeval *begin) {
  in_progress_since = last_start_time = begin->tv_sec;
}

/* ******************************************* */

void ThreadedActivityStats::updateStatsEnd(u_long duration_ms) {
  in_progress_since = 0;
  last_duration_ms = duration_ms;
  if(duration_ms > max_duration_ms)
    max_duration_ms = duration_ms;
}

/* ******************************************* */

void ThreadedActivityStats::resetStats() {
  if(ta_stats_shadow) free(ta_stats_shadow);
  ta_stats_shadow = ta_stats;
  ta_stats = (threaded_activity_stats_t*)calloc(1, sizeof(*ta_stats));
}

/* ******************************************* */

void ThreadedActivityStats::luaRRDStats(lua_State *vm, bool write, threaded_activity_stats_t *cur_stats) {
  threaded_activity_rrd_stats_t *rrd_stats;

  if(cur_stats) {
    rrd_stats = write ? &cur_stats->rrd.write : &cur_stats->rrd.read;

    if(rrd_stats->tot_calls || rrd_stats->tot_drops) {
      lua_newtable(vm);

      lua_push_float_table_entry(vm, "max_call_duration_ms", rrd_stats->max_ticks / (float)tickspersec * 1000);
      lua_push_float_table_entry(vm, "avg_call_duration_ms", rrd_stats->tot_ticks / (float)tickspersec / rrd_stats->tot_calls * 1000);
      lua_push_uint64_table_entry(vm, "tot_calls", (u_int64_t)rrd_stats->tot_calls);
      lua_push_uint64_table_entry(vm, "tot_drops", (u_int64_t)rrd_stats->tot_drops);

      lua_pushstring(vm, write ? "write" : "read");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }
}

/* ******************************************* */

void ThreadedActivityStats::lua(lua_State *vm) {
  threaded_activity_stats_t *cur_stats = ta_stats;

  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "max_duration_ms", (u_int64_t)max_duration_ms);
  lua_push_uint64_table_entry(vm, "last_duration_ms", (u_int64_t)last_duration_ms);

  lua_pushstring(vm, "duration");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  luaRRDStats(vm, true  /* Write */, cur_stats);
  luaRRDStats(vm, false /* Read */,  cur_stats);

  lua_pushstring(vm, "rrd");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if(in_progress_since)
    lua_push_uint64_table_entry(vm, "in_progress_since", in_progress_since);

  if(last_start_time) 
    lua_push_uint64_table_entry(vm, "last_start_time", last_start_time);

  if(last_queued_time)
    lua_push_uint64_table_entry(vm, "last_queued_time", last_queued_time);

  if(not_executed)
    lua_push_bool_table_entry(vm, "not_excecuted", true);
  if(num_not_executed)
    lua_push_uint64_table_entry(vm, "num_not_executed", num_not_executed);

  if(is_slow)
    lua_push_bool_table_entry(vm, "is_slow", true);
  if(num_is_slow)
    lua_push_uint64_table_entry(vm, "num_is_slow", num_is_slow);

  if(isRRDSlow())
    lua_push_bool_table_entry(vm, "rrd_slow", true);

  lua_push_uint64_table_entry(vm, "scheduled_time", scheduled_time);
  lua_push_uint64_table_entry(vm, "deadline", deadline);
  lua_push_int32_table_entry(vm, "progress", progress);
}

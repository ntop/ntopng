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

/* ******************************************* */

ThreadedActivityStats::ThreadedActivityStats(const ThreadedActivity *ta) {
  ta_stats = (threaded_activity_stats_t*)calloc(1, sizeof(*ta_stats));
  ta_stats_shadow = NULL;
  start_time = 0;
  threaded_activity = ta;
}

/* ******************************************* */

ThreadedActivityStats::~ThreadedActivityStats() {
  if(ta_stats)        free(ta_stats);
  if(ta_stats_shadow) free(ta_stats_shadow);
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

void ThreadedActivityStats::updateStatsBegin(struct timeval *begin) {
  start_time = begin->tv_sec;
}

/* ******************************************* */

void ThreadedActivityStats::updateStatsEnd(u_long duration_ms) {
  threaded_activity_stats_t *cur_stats = ta_stats;

  start_time = 0;

  if(cur_stats) {
    cur_stats->last_duration_ms = duration_ms;

    if(duration_ms > cur_stats->max_duration_ms)
      cur_stats->max_duration_ms = duration_ms;
  }
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
  ticks tickspersec = Utils::gettickspersec();

  if(cur_stats) {
    rrd_stats = write ? &cur_stats->rrd.write : &cur_stats->rrd.read;

    if(rrd_stats->tot_calls) {
      lua_newtable(vm);

      lua_push_float_table_entry(vm, "max_call_duration_ms", rrd_stats->max_ticks / (float)tickspersec * 1000);
      lua_push_float_table_entry(vm, "avg_call_duration_ms", rrd_stats->tot_ticks / (float)tickspersec / rrd_stats->tot_calls * 1000);
      lua_push_uint64_table_entry(vm, "tot_calls", (u_int64_t)rrd_stats->tot_calls);

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

  lua_push_uint64_table_entry(vm, "max_duration_ms", (u_int64_t)cur_stats->max_duration_ms);
  lua_push_uint64_table_entry(vm, "last_duration_ms", (u_int64_t)cur_stats->last_duration_ms);

  lua_pushstring(vm, "duration");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  luaRRDStats(vm, true  /* Write */, cur_stats);
  luaRRDStats(vm, false /* Read */,  cur_stats);

  lua_pushstring(vm, "rrd");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if(start_time) {
    lua_push_uint64_table_entry(vm, "in_progress_since", start_time);
  }
}

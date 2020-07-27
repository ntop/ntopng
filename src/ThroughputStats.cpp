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

/* *************************************** */

ThroughputStats::ThroughputStats() {
  resetStats();
}

/* *************************************** */

void ThroughputStats::resetStats() {
  last_val = 0;
  thpt = 0;
  last_thpt = 0;
  thpt_trend = trend_unknown;
  last_update_time.tv_sec = 0, last_update_time.tv_usec = 0;
}

/* *************************************** */

ThroughputStats::ThroughputStats(const ThroughputStats &thpts) {
  last_val = thpts.last_val;
  thpt = thpts.thpt;
  last_thpt = thpts.last_thpt;
  thpt_trend = thpts.thpt_trend;
  memcpy(&last_update_time, &thpts.last_update_time, sizeof(last_update_time));
}

/* *************************************** */

void ThroughputStats::updateStats(const struct timeval *tv, u_int64_t new_val) {
  if(last_update_time.tv_sec > 0 /* Waits at least two calls before computing the throughput */
     && new_val >= last_val /* Protects against resets / wraps */) {
    float tdiff = Utils::msTimevalDiff(tv, &last_update_time);
    float new_thpt = ((float)((new_val - last_val) * 1000)) / (1 + tdiff);

    if(thpt < new_thpt)      thpt_trend = trend_up;
    else if(thpt > new_thpt) thpt_trend = trend_down;
    else                     thpt_trend = trend_stable;

    last_thpt = thpt;
    thpt = new_thpt;
  }

  last_val = new_val;
  memcpy(&last_update_time, tv, sizeof(struct timeval));
}

/* *************************************** */

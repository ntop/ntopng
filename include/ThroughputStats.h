/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _THROUGHPUT_STATS_H_
#define _THROUGHPUT_STATS_H_

#include "ntop_includes.h"

class ThroughputStats {
 private:
  u_int64_t last_val;
  float thpt, last_thpt;
  ValueTrend thpt_trend;
  struct timeval last_update_time;

 public:
  ThroughputStats();
  ThroughputStats(const ThroughputStats &thpts);
  inline float getThpt()       const { return thpt;       };
  inline ValueTrend getTrend() const { return thpt_trend; };
  inline void sum(ThroughputStats *thpts) const { thpts->thpt += thpt, thpts->thpt_trend = thpt_trend; /* TODO: handle trend */};
  void updateStats(const struct timeval *tv, u_int64_t new_val);
  void resetStats();
};

#endif /* _THROUGHPUT_STATS_H_ */

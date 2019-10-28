/*
 *
 * (C) 2013-19 - ntop.org
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

class ThreadedActivityStats {
 private:
  u_long max_duration_ms;
  u_long last_duration_ms;
  const ThreadedActivity *threaded_activity;
  
 public:
  ThreadedActivityStats(const ThreadedActivity *ta);
  ~ThreadedActivityStats();

  void updateStats(u_long duration_ms);
  void lua(lua_State *vm);
};

#endif /* _THREADED_ACTIVITY_STATS_H_ */

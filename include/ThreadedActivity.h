/*
 *
 * (C) 2013-17 - ntop.org
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

#ifndef _THREADED_ACTIVITY_H_
#define _THREADED_ACTIVITY_H_

#include "ntop_includes.h"

class ThreadPool;

class ThreadedActivity {
 private:
  pthread_t pthreadLoop;
  char *path;
  u_int16_t numRunningChildren;
  u_int32_t periodicity;
  bool align_to_localtime;
  bool thread_started, taskRunning;
  Mutex m;
  ThreadPool *pool;
  
  u_int32_t roundTime(u_int32_t now, u_int32_t rounder,
		      int32_t offset_from_utc);

  void periodicActivityBody();
  void aperiodicActivityBody();
  void uSecDiffPeriodicActivityBody();
  void scheduleJob(ThreadPool *pool);
  
 public:
  ThreadedActivity(const char* _path,
		   u_int32_t _periodicity_seconds = 0,
		   bool _align_to_localtime = false,
		   u_int8_t thread_pool_size = 1);
  ~ThreadedActivity();

  void activityBody();
  void runScript();
  void runScript(char *script_path, NetworkInterface *iface);
  void run();

  inline void modRunningChildren(int value) {
    m.lock(__FILE__, __LINE__);
    numRunningChildren += value;
    m.lock(__FILE__, __LINE__);
  }

  inline void incRunningChildren() { modRunningChildren(1);  }
  inline void decRunningChildren() { modRunningChildren(-1); }
};

#endif /* _THREADED_ACTIVITY_H_ */

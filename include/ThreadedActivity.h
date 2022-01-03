/*
 *
 * (C) 2013-22 - ntop.org
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
class PeriodicScript;

class ThreadedActivity {
 private:
  bool terminating;
  pthread_t pthreadLoop;
  u_int32_t deadline_approaching_secs;
  bool thread_started;
  bool systemTaskRunning;
  Mutex m;
  PeriodicScript *periodic_script;
  std::map<std::string, ThreadedActivityStats*> threaded_activity_stats;
  void setDeadlineApproachingSecs();
  void periodicActivityBody();
  void aperiodicActivityBody();
  void schedulePeriodicActivity(ThreadPool *pool, time_t scheduled_time, time_t deadline);
  ThreadedActivityState getThreadedActivityState(NetworkInterface *iface, char *script_name);
  void updateThreadedActivityStatsBegin(NetworkInterface *iface, char *script_name, struct timeval *begin);
  void updateThreadedActivityStatsEnd(NetworkInterface *iface, char *script_name, u_long latest_duration);
  void reloadVm(const char *ifname);
  LuaEngine* loadVm(char *script_path, NetworkInterface *iface, time_t when);
  void set_state(NetworkInterface *iface, char *script_name, ThreadedActivityState ta_state);
  static const char* get_state_label(ThreadedActivityState ta_state);
  bool isValidScript(char* dir, char *path);
  
 public:
  ThreadedActivity(const char* _path,		   
		   u_int32_t _periodicity_seconds = 0,
		   u_int32_t _max_duration_seconds = 0,
		   bool _align_to_localtime = false,
		   bool _exclude_viewed_interfaces = false,
		   bool _exclude_pcap_dump_interfaces = false,
		   ThreadPool* _pool = NULL);
  ~ThreadedActivity();

  const char *activityPath();
  void activityBody();
  void runSystemScript(time_t now);
  void runScript(time_t now, char *script_path, NetworkInterface *iface, time_t deadline);

  inline void shutdown()      { terminating = true; };
  void terminateEnqueueLoop();
  bool isTerminating();

  void run();
  void set_state_sleeping(NetworkInterface *iface, char *script_name);
  void set_state_queued(NetworkInterface *iface, char *script_name);
  void set_state_running(NetworkInterface *iface, char *script_name);
  bool isDeadlineApproaching(time_t deadline);
  u_int32_t getPeriodicity();
  u_int32_t getMaxDuration();
  bool excludePcap();
  bool excludeViewedIfaces();
  ThreadPool *getPool();
  bool alignToLocalTime();
  ThreadedActivityState get_state(NetworkInterface *iface, char *script_name);
  ThreadedActivityStats *getThreadedActivityStats(NetworkInterface *iface,
						  char *script_name,
						  bool allocate_if_missing);

  void lua(NetworkInterface *iface, lua_State *vm);
};

#endif /* _THREADED_ACTIVITY_H_ */

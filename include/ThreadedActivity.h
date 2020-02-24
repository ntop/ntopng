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

#ifndef _THREADED_ACTIVITY_H_
#define _THREADED_ACTIVITY_H_

#include "ntop_includes.h"

class ThreadPool;

class ThreadedActivity {
 private:
  bool terminating;
  pthread_t pthreadLoop;
  char *path;
  u_int32_t periodicity;
  u_int32_t deadline_approaching_secs;
  bool align_to_localtime;
  bool exclude_viewed_interfaces;
  bool exclude_pcap_dump_interfaces;
  bool thread_started;
  bool systemTaskRunning;
  bool reuse_vm;
  ThreadedActivityState *interfaceTasksRunning;
  Mutex m;
  ThreadPool *pool;
  ThreadedActivityStats **threaded_activity_stats;
  Mutex vms_mutex;

  /* ifid -> engine */
  std::map<int, LuaReusableEngine*> vms;

  void setDeadlineApproachingSecs();
  void periodicActivityBody();
  void aperiodicActivityBody();
  void uSecDiffPeriodicActivityBody();
  void schedulePeriodicActivity(ThreadPool *pool, time_t scheduled_time, time_t deadline);
  ThreadedActivityState *getThreadedActivityState(NetworkInterface *iface) const;
  void updateThreadedActivityStatsBegin(NetworkInterface *iface, struct timeval *begin);
  void updateThreadedActivityStatsEnd(NetworkInterface *iface, u_long latest_duration);
  void reloadVm(const char *ifname);
  LuaEngine* loadVm(char *script_path, NetworkInterface *iface, time_t when);
  void set_state(NetworkInterface *iface, ThreadedActivityState ta_state);
  static const char* get_state_label(ThreadedActivityState ta_state);

 public:
  ThreadedActivity(const char* _path,		   
		   u_int32_t _periodicity_seconds = 0,
		   bool _align_to_localtime = false,
		   bool _exclude_viewed_interfaces = false,
		   bool _exclude_pcap_dump_interfaces = false,
       bool _reuse_vm = false,
		   ThreadPool* _pool = NULL);
  ~ThreadedActivity();

  inline const char *activityPath() const { return path; };
  void activityBody();
  void runSystemScript();
  void runScript(char *script_path, NetworkInterface *iface, time_t deadline);

  inline void shutdown()      { terminating = true; };
  void terminateEnqueueLoop();
  bool isTerminating();

  void setNextVmReload(time_t when);

  void run();
  void set_state_sleeping(NetworkInterface *iface);
  void set_state_queued(NetworkInterface *iface);
  void set_state_running(NetworkInterface *iface);
  bool isQueueable(NetworkInterface *iface) const;
  bool isDeadlineApproaching(time_t deadline) const;
  inline u_int32_t getPeriodicity() { return(periodicity); };
  ThreadedActivityState get_state(NetworkInterface *iface) const;
  ThreadedActivityStats *getThreadedActivityStats(NetworkInterface *iface, bool allocate_if_missing);

  void lua(NetworkInterface *iface, lua_State *vm, bool reset_after_get);
};

#endif /* _THREADED_ACTIVITY_H_ */

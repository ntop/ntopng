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
  bool align_to_localtime;
  bool exclude_viewed_interfaces;
  bool exclude_pcap_dump_interfaces;
  bool thread_started;
  bool systemTaskRunning;
  bool reuse_vm;
  bool *interfaceTasksRunning;
  Mutex m;
  ThreadPool *pool;
  ThreadedActivityStats **threaded_activity_stats;
  Mutex vms_mutex;

  /* iface -> engine */
  std::map<std::string, LuaReusableEngine*> vms;

  void periodicActivityBody();
  void aperiodicActivityBody();
  void uSecDiffPeriodicActivityBody();
  void schedulePeriodicActivity(ThreadPool *pool, time_t deadline);
  void setInterfaceTaskRunning(NetworkInterface *iface, bool running);
  bool isInterfaceTaskRunning(NetworkInterface *iface);
  void updateThreadedActivityStats(NetworkInterface *iface, u_long latest_duration);
  void reloadVm(const char *ifname);

 public:
  ThreadedActivity(const char* _path,		   
		   u_int32_t _periodicity_seconds = 0,
		   bool _align_to_localtime = false,
		   bool _exclude_viewed_interfaces = false,
		   bool _exclude_pcap_dump_interfaces = false,
       bool _reuse_vm = false,
		   ThreadPool* _pool = NULL);
  ~ThreadedActivity();

  const char *activityPath() { return path; };
  void activityBody();
  void runScript();
  void runScript(char *script_path, NetworkInterface *iface, time_t deadline);

  inline void shutdown()      { terminating = true; };
  void terminateEnqueueLoop();
  bool isTerminating();
  void setNextVmReload(time_t when);

  void run();

  void lua(NetworkInterface *iface, lua_State *vm);
};

#endif /* _THREADED_ACTIVITY_H_ */

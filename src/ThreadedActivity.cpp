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

/* **************************************************** */

static void* startActivity(void* ptr)  {
  Utils::setThreadName(((ThreadedActivity*)ptr)->activityPath());

  ((ThreadedActivity*)ptr)->activityBody();
  return(NULL);
}

/* ******************************************* */

ThreadedActivity::ThreadedActivity(const char* _path,
				   u_int32_t _periodicity_seconds,
				   bool _align_to_localtime,
				   bool _exclude_viewed_interfaces,
				   bool _exclude_pcap_dump_interfaces,
				   bool _reuse_vm,
				   ThreadPool *_pool) {
  terminating = false;
  periodicity = _periodicity_seconds;
  align_to_localtime = _align_to_localtime;
  exclude_viewed_interfaces = _exclude_viewed_interfaces;
  exclude_pcap_dump_interfaces = _exclude_pcap_dump_interfaces;
  reuse_vm = _reuse_vm;
  thread_started = false, systemTaskRunning = false;
  path = strdup(_path); /* ntop->get_callbacks_dir() */;
  interfaceTasksRunning = (bool *) calloc(MAX_NUM_INTERFACE_IDS, sizeof(bool));
  threaded_activity_stats = new (std::nothrow) ThreadedActivityStats*[MAX_NUM_INTERFACE_IDS + 1 /* For the system interface */]();
  pool = _pool;

#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Creating ThreadedActivity '%s'", this, path);
#endif
}

/* ******************************************* */

ThreadedActivity::~ThreadedActivity() {
  std::map<int, LuaReusableEngine*>::iterator it;

  /* NOTE: terminateEnqueueLoop should have already been called by the PeriodicActivities
   * destructor. */
  terminateEnqueueLoop();

  if(threaded_activity_stats) {
    for(u_int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
      if(threaded_activity_stats[i])
	delete threaded_activity_stats[i];
    }

    delete[] threaded_activity_stats;
  }

  if(interfaceTasksRunning)
    free(interfaceTasksRunning);

  if(path) free(path);

  for(it = vms.begin(); it != vms.end(); ++it)
    delete(it->second);
}

/* ******************************************* */

/* Stop the possibly running pthreadLoop, so that new activities
 * won't be enqueued. */
void ThreadedActivity::terminateEnqueueLoop() {
  void *res;

  shutdown();

  if(thread_started) {
    pthread_join(pthreadLoop, &res);

#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Joined thread %s", path);
#endif

    thread_started = false;
  }
}

/* ******************************************* */

bool ThreadedActivity::isTerminating() {
  return(terminating
	 || ntop->getGlobals()->isShutdownRequested()
	 || ntop->getGlobals()->isShutdown());
};

/* ******************************************* */

bool ThreadedActivity::isRunning(const NetworkInterface *iface) const {
  if(iface == ntop->getSystemInterface())
    return systemTaskRunning;
  else {
    const int iface_id = iface->get_id();

    if(iface_id >= 0 && iface_id < MAX_NUM_INTERFACE_IDS)
      return interfaceTasksRunning[iface_id];
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to determine whether a task is running [path: %s][iface: %s]", path, iface->get_name());
  }

  return false;
}

/* ******************************************* */

void ThreadedActivity::setRunning(NetworkInterface *iface, bool running) {
  if(iface == ntop->getSystemInterface()) {
    if(systemTaskRunning != running)
      systemTaskRunning = running;
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error. [path: %s][iface: %s][running: %u][requested: %u]",
				   path, iface->get_name(), systemTaskRunning ? 1 : 0, running ? 1 : 0);
  } else {
    const int iface_id = iface->get_id();

    if((iface_id >= 0) && (iface_id < MAX_NUM_INTERFACE_IDS)) {
      if(interfaceTasksRunning[iface_id] != running)
	interfaceTasksRunning[iface_id] = running;
      else
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error. [path: %s][iface: %s][running: %u][set: %u]",
				     path, iface->get_name(), interfaceTasksRunning[iface_id] ? 1 : 0, running ? 1 : 0);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set task running running [path: %s][iface: %s][running: %u]", path, iface->get_name(), running ? 1 : 0);
    }
  }
}

/* ******************************************* */

bool ThreadedActivity::isDeadlineApproaching(time_t deadline) const {
  return deadline - time(NULL) <= 1 /* Possibly make it ThreadedActivity-dependent */;
}

/* ******************************************* */

/* NOTE: this runs into a separate thread, launched by PeriodicActivities
 * after creation. */
void ThreadedActivity::activityBody() {
  if(periodicity == 0)       /* The script is not periodic */
    aperiodicActivityBody();
  else if(periodicity == 1) /* Accurate time computation with micro-second-accurate sleep */
    uSecDiffPeriodicActivityBody();
  else
    periodicActivityBody();
}

/* ******************************************* */

void ThreadedActivity::run() {
  bool pcap_dump_only = true;

  for(int i = 0; i < ntop->get_num_interfaces(); i++) {
    NetworkInterface *iface = ntop->getInterface(i);
    if(iface && iface->getIfType() != interface_type_PCAP_DUMP)
      pcap_dump_only = false;
  }
  /* Don't schedule periodic activities it we are processing pcap files only. */
  if (exclude_pcap_dump_interfaces && pcap_dump_only)
    return;

  if(pthread_create(&pthreadLoop, NULL, startActivity, (void*)this) == 0) {
    thread_started = true;
#ifdef HAVE_LIBCAP
    Utils::setThreadAffinityWithMask(pthreadLoop, ntop->getPrefs()->get_other_cpu_affinity_mask());
#endif
  }
}

/* ******************************************* */

ThreadedActivityStats *ThreadedActivity::getThreadedActivityStats(NetworkInterface *iface, bool allocate_if_missing) {
  ThreadedActivityStats *ta = NULL;

  if(iface) {
    /* As the system interface has id -1, we add 1 to the offset to access the array of stats.
       The array of stats is allocated in the constructor with MAX_NUM_INTERFACE_IDS + 1 to also
       accomodate the system interface */
    int stats_idx = iface->get_id() + 1;

    if(stats_idx >= 0 && stats_idx < MAX_NUM_INTERFACE_IDS + 1) {
	if(!threaded_activity_stats[stats_idx]) {
	  if(allocate_if_missing) {
	    try {
	      ta = new ThreadedActivityStats(this);
	    } catch(std::bad_alloc& ba) {
	      return NULL;
	    }
	    threaded_activity_stats[stats_idx] = ta;
	  }
	} else
	  ta = threaded_activity_stats[stats_idx];
      }
  }

  return ta;
}

/* ******************************************* */

void ThreadedActivity::updateThreadedActivityStatsBegin(NetworkInterface *iface, struct timeval *begin) {
  ThreadedActivityStats *ta = getThreadedActivityStats(iface, true /* Allocate if missing */);

  if(ta)
    ta->updateStatsBegin(begin);
}

/* ******************************************* */

void ThreadedActivity::updateThreadedActivityStatsEnd(NetworkInterface *iface, u_long latest_duration) {
  ThreadedActivityStats *ta = getThreadedActivityStats(iface, true /* Allocate if missing */);

  if(ta)
    ta->updateStatsEnd(latest_duration);
}

/* ******************************************* */

/* Run a one-shot script / accurate (e.g. second) periodic script */
void ThreadedActivity::runSystemScript() {
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif
  char script_path[MAX_PATH];
  
  snprintf(script_path, sizeof(script_path), "%s/system/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &buf) == 0) {
    runScript(script_path, ntop->getSystemInterface(), 0 /* No deadline */);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to find script %s", path);
}

/* ******************************************* */

/* Run a script - both periodic and one-shot scripts are called here */
void ThreadedActivity::runScript(char *script_path, NetworkInterface *iface, time_t deadline) {
  LuaEngine *l = NULL;
  struct ntopngLuaContext *ctx;
  u_long max_duration_ms = periodicity * 1e3;
  u_long msec_diff;
  struct timeval begin, end;

  if(!iface)
    return;

  if(strcmp(path, SHUTDOWN_SCRIPT_PATH) && isTerminating())
    return;

  if(iface->isViewed() && exclude_viewed_interfaces)
    return;

#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Running %s", this, path);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Running %s (iface=%p)", script_path, iface);

  l = loadVm(script_path, iface, time(NULL));
  if(!l) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to load the Lua vm [%s][vm: %s]", iface->get_name(), path);
    return;
  }

  /* Set the deadline and the threaded activity in the vm so they can be accessed */
  lua_pushinteger(l->getState(), deadline);
  lua_setglobal(l->getState(), "deadline");
  ctx = getLuaVMContext(l->getState());
  ctx->deadline = deadline;
  ctx->threaded_activity = this;

  gettimeofday(&begin, NULL);
  updateThreadedActivityStatsBegin(iface, &begin);

  l->run_loaded_script();

  gettimeofday(&end, NULL);
  msec_diff = (end.tv_sec - begin.tv_sec) * 1000 + (end.tv_usec - begin.tv_usec) / 1000;
  updateThreadedActivityStatsEnd(iface, msec_diff);

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "[PeriodicActivity][%s][%s]: completed in %u/%u ms [%s]", iface->get_name(), path, msec_diff, max_duration_ms,
			       (((max_duration_ms > 0) && (msec_diff > max_duration_ms)) ? "SLOW" : "OK"));
#endif

  if((max_duration_ms > 0) &&
     (msec_diff > 2*max_duration_ms) &&
     /* These scripts are allowed to go beyong their max time */
     (strcmp(path, HOUSEKEEPING_SCRIPT_PATH) != 0) &&
     (strcmp(path, DISCOVER_SCRIPT_PATH) != 0) &&
     (strcmp(path, TIMESERIES_SCRIPT_PATH) != 0))
    iface->getAlertsQueue()->pushSlowPeriodicActivity(msec_diff, periodicity * 1e3, path);

  if(l && !reuse_vm)
    delete l;
}

/* ******************************************* */

LuaEngine* ThreadedActivity::loadVm(char *script_path, NetworkInterface *iface, time_t when) {
  LuaEngine *l = NULL;

  try {
    if(reuse_vm) {
      /* Reuse an existing engine or allocate a new one */
      LuaReusableEngine *engine;
      std::map<int, LuaReusableEngine*>::iterator it;

      vms_mutex.lock(__FILE__, __LINE__);

      if((it = vms.find(iface->get_id())) != vms.end())
	engine = it->second;
      else {
	engine = new LuaReusableEngine(script_path, iface, 300 /* reload interval */);

	/* Save the VM for later use */
	vms[iface->get_id()] = engine;
      }

      vms_mutex.unlock(__FILE__, __LINE__);

      l = engine->getVm(when);
    } else {
      /* NOTE: this needs to be deallocated by the caller */
      l = new LuaEngine();

      if(l->load_script(script_path, iface) != 0) {
	delete l;
	l = NULL;
      }
    }
  } catch(std::bad_alloc& ba) {
    l = NULL;
  }

  return(l);
}

/* ******************************************* */

void ThreadedActivity::aperiodicActivityBody() {
  if(!isTerminating())
    runSystemScript();
}

/* ******************************************* */

void ThreadedActivity::uSecDiffPeriodicActivityBody() {
  struct timeval begin, end;
  u_long usec_diff;
#ifndef PERIODIC_DEBUG
  u_long max_duration = periodicity * 1e6;
#endif
  
  while(!isTerminating()) {
    gettimeofday(&begin, NULL);
    runSystemScript();
    gettimeofday(&end, NULL);

    usec_diff = (end.tv_sec - begin.tv_sec) * 1e6 + (end.tv_usec - begin.tv_usec);

#ifndef PERIODIC_DEBUG
    if(usec_diff < max_duration) {
      u_int diff;

      if(periodicity == 1)
        /* Align to the start of the second to avoid crossing second bounds */
        diff = max_duration - end.tv_usec;
      else
        diff = max_duration - usec_diff;

      _usleep(diff);
    } /* else { the script took too long } */
#else
    /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s()", __FUNCTION__); */
#endif
  }
}

/* ******************************************* */

void ThreadedActivity::periodicActivityBody() {
  u_int32_t next_run = (u_int32_t)time(NULL);

  next_run = Utils::roundTime(next_run, periodicity, align_to_localtime ? ntop->get_time_offset() : 0);

  if(align_to_localtime)
    next_run -= periodicity;

  while(!isTerminating()) {
    u_int now = (u_int)time(NULL);

    if(now >= next_run) {
      next_run = Utils::roundTime(now, periodicity,
				  align_to_localtime ? ntop->get_time_offset() : 0);

      schedulePeriodicActivity(pool, next_run /* next_run is now also the deadline of the current script */);
    }

    sleep(1);
  }

  /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminating %s(%s) exit", __FUNCTION__, path); */
}

/* ******************************************* */

/* This function enqueues the periodic activity job into the ThreadPool.
 * The ThreadPool, running into another thread, will dequeue the job and call
 * ThreadedActivity::runScript. The variables systemTaskRunning and interfaceTasksRunning
 * are used to ensure that only a single instance of the job is running for a given
 * NetworkInterface. */
void ThreadedActivity::schedulePeriodicActivity(ThreadPool *pool, time_t deadline) {
  /* Schedule per system / interface */
  char script_path[MAX_PATH];
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif

  /* Schedule system script */
  snprintf(script_path, sizeof(script_path), "%s/system/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &buf) == 0) {
    if(pool->queueJob(this, script_path, ntop->getSystemInterface(), deadline)) {
#ifdef THREAD_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queued system job %s", script_path);
#endif
    }
  }

  /* Schedule interface script, one for each interface */
  snprintf(script_path, sizeof(script_path), "%s/interface/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &buf) == 0) {
    for(int i = 0; i < ntop->get_num_interfaces(); i++) {
      NetworkInterface *iface = ntop->getInterface(i);

      if(iface
	 && (iface->getIfType() != interface_type_PCAP_DUMP || !exclude_pcap_dump_interfaces)) {
	if(pool->queueJob(this, script_path, iface, deadline)) {
#ifdef THREAD_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queued interface job %s [%s]", script_path, iface->get_name());
#endif
	}	
      }
    }
  }
}

/* ******************************************* */

void ThreadedActivity::lua(NetworkInterface *iface, lua_State *vm) {
  ThreadedActivityStats *ta = getThreadedActivityStats(iface, false /* Do not allocate if missing */);

  if(ta) {
    lua_newtable(vm);

    ta->lua(vm);

    lua_pushstring(vm, path ? path : "");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ******************************************* */

void ThreadedActivity::setNextVmReload(time_t t) {
  std::map<int, LuaReusableEngine*>::iterator it;

  vms_mutex.lock(__FILE__, __LINE__);

  for(it = vms.begin(); it != vms.end(); ++it)
    it->second->setNextVmReload(t);

  vms_mutex.unlock(__FILE__, __LINE__);
}

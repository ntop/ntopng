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
				   ThreadPool *_pool) {
  terminating = false;
  periodicity = _periodicity_seconds;
  align_to_localtime = _align_to_localtime;
  exclude_viewed_interfaces = _exclude_viewed_interfaces;
  thread_started = false, systemTaskRunning = false;
  path = strdup(_path); /* ntop->get_callbacks_dir() */;
  interfaceTasksRunning = (bool *) calloc(MAX_NUM_INTERFACE_IDS, sizeof(bool));
  threaded_activity_stats = new (std::nothrow) ThreadedActivityStats*[MAX_NUM_INTERFACE_IDS]();
  pool = _pool;
  
#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Creating ThreadedActivity '%s'", this, path);
#endif
}

/* ******************************************* */

ThreadedActivity::~ThreadedActivity() {
  map<int, ThreadedActivityStats*>::const_iterator it;

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

void ThreadedActivity::setInterfaceTaskRunning(NetworkInterface *iface, bool running) {
  const int iface_id = iface->get_id();

  if((iface_id >= 0) && (iface_id < MAX_NUM_INTERFACE_IDS))
    interfaceTasksRunning[iface_id] = running;
}

/* ******************************************* */

bool ThreadedActivity::isInterfaceTaskRunning(NetworkInterface *iface) {
  const int iface_id = iface->get_id();

  if((iface_id >= 0) && (iface_id < MAX_NUM_INTERFACE_IDS))
    return interfaceTasksRunning[iface_id];

  return false;
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
  bool run_script = false;

  for(int i = 0; i < ntop->get_num_interfaces(); i++) {
    NetworkInterface *iface = ntop->getInterface(i);

    if(iface->isProcessingPackets()) {
       run_script = true;
       break;
    }
  }

  if(!run_script) return;

  if(pthread_create(&pthreadLoop, NULL, startActivity, (void*)this) == 0) {
    thread_started = true;
#ifdef HAVE_LIBCAP
    Utils::setThreadAffinityWithMask(pthreadLoop, ntop->getPrefs()->get_other_cpu_affinity_mask());
#endif
  }
}

/* ******************************************* */

void ThreadedActivity::updateThreadedActivityStats(NetworkInterface *iface, u_long latest_duration) {
  ThreadedActivityStats *ta = NULL;

  if(iface && iface->get_id() >= 0) {
    if(!threaded_activity_stats[iface->get_id()]) {
      try {
	ta = new ThreadedActivityStats(this);
      } catch(std::bad_alloc& ba) {
	return;
      }
      threaded_activity_stats[iface->get_id()] = ta;
    } else
      ta = threaded_activity_stats[iface->get_id()];

    if(ta)
      ta->updateStats(latest_duration);
  }
}

/* ******************************************* */

/* Run a one-shot script / accurate (e.g. second) periodic script */
void ThreadedActivity::runScript() {
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif
  char script_path[MAX_PATH];
  
  snprintf(script_path, sizeof(script_path), "%s/system/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &buf) == 0) {
    runScript(script_path, NULL);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to find script %s", path);
}

/* ******************************************* */

/* Run a script - both periodic and one-shot scripts are called here */
void ThreadedActivity::runScript(char *script_path, NetworkInterface *iface) {
  LuaEngine *l;
  u_long max_duration_ms = periodicity * 1e3;
  u_long msec_diff;
  struct timeval begin, end;

  if(!iface) iface = ntop->getSystemInterface();
  if(strcmp(path, SHUTDOWN_SCRIPT_PATH) && isTerminating()) return;
  if(iface->isViewed() && exclude_viewed_interfaces) return;

#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Running %s", this, path);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Running %s (iface=%p)", script_path, iface);
  
  try {
    l = new LuaEngine();
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[ThreadedActivity] Unable to start a Lua interpreter.");
      oom_warning_sent = true;
    }

    return;
  }

  gettimeofday(&begin, NULL);
  l->run_script(script_path, iface);
  gettimeofday(&end, NULL);

  msec_diff = (end.tv_sec - begin.tv_sec) * 1000 + (end.tv_usec - begin.tv_usec) / 1000;
  updateThreadedActivityStats(iface, msec_diff);

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

  if(iface == ntop->getSystemInterface())
    systemTaskRunning = false;
  else
    setInterfaceTaskRunning(iface, false);

  delete l;
}

/* ******************************************* */

void ThreadedActivity::aperiodicActivityBody() {
  if(!isTerminating())
    runScript();
}

/* ******************************************* */

void ThreadedActivity::uSecDiffPeriodicActivityBody() {
  struct timeval begin, end;
  u_long usec_diff;
#ifndef PERIODIC_DEBUG
  u_long max_duration = periodicity * 1e6;
#endif
  
  while(!isTerminating()) {
#ifndef PERIODIC_DEBUG
    while(systemTaskRunning) _usleep(1000);
#endif

    gettimeofday(&begin, NULL);
    systemTaskRunning = true;
    runScript();
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
      schedulePeriodicActivity(pool);

      next_run = Utils::roundTime(now, periodicity,
				  align_to_localtime ? ntop->get_time_offset() : 0);
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
void ThreadedActivity::schedulePeriodicActivity(ThreadPool *pool) {
  /* Schedule per system / interface */
  char script_path[MAX_PATH];
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif

  if(!systemTaskRunning) {
    /* Schedule system script */
    snprintf(script_path, sizeof(script_path), "%s/system/%s",
	     ntop->get_callbacks_dir(), path);
    
    if(stat(script_path, &buf) == 0) {
      systemTaskRunning = true;
      pool->queueJob(this, script_path, NULL);
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
	 && iface->isProcessingPackets()
	 && !isInterfaceTaskRunning(iface)) {
        pool->queueJob(this, script_path, iface);
        setInterfaceTaskRunning(iface, true);

#ifdef THREAD_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queued interface job %s [%s]", script_path, iface->get_name());
#endif

      }
    }
  }
}

/* ******************************************* */

void ThreadedActivity::lua(NetworkInterface *iface, lua_State *vm) {
  if(iface && iface->get_id() >= 0 && threaded_activity_stats[iface->get_id()]) {
    lua_newtable(vm);

    threaded_activity_stats[iface->get_id()]->lua(vm);

    lua_pushstring(vm, path ? path : "");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

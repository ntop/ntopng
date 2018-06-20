/*
 *
 * (C) 2013-18 - ntop.org
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
#ifdef  __APPLE__
  // Mac OS X: must be set from within the thread (can't specify thread ID)
  char buf[MAX_PATH];
  snprintf(buf, sizeof(buf), "ThreadedActivity %s", ((ThreadedActivity*)ptr)->activityPath());
  if(pthread_setname_np(buf))
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set pthread name %s", buf);
#endif

  ((ThreadedActivity*)ptr)->activityBody();
  return(NULL);
}

/* ******************************************* */

ThreadedActivity::ThreadedActivity(const char* _path,
				   u_int32_t _periodicity_seconds,
				   bool _align_to_localtime,
				   u_int8_t thread_pool_size) {
  terminating = false;
  periodicity = _periodicity_seconds;
  align_to_localtime = _align_to_localtime;
  thread_started = false, systemTaskRunning = false;
  path = strdup(_path); /* ntop->get_callbacks_dir() */;
  interfaceTasksRunning = (bool *) calloc(MAX_NUM_DEFINED_INTERFACES, sizeof(bool));

  if(periodicity > MIN_TIME_SPAWN_THREAD_POOL) {
    pool = new ThreadPool(thread_pool_size);

    if(pool == NULL) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of resources");
      throw -1;
    }
  } else
    pool = NULL;
  
#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Creating ThreadedActivity '%s'", this, path);
#endif
}

/* ******************************************* */

ThreadedActivity::~ThreadedActivity() {
  void *res;

  shutdown();

  if(pool) delete pool;

  if(interfaceTasksRunning)
    free(interfaceTasksRunning);

  if(thread_started) {
    pthread_join(pthreadLoop, &res);
#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Joined thread %s", path);
#endif
  }

  if(path) free(path);
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

  if((iface_id >= 0) && (iface_id < MAX_NUM_DEFINED_INTERFACES))
    interfaceTasksRunning[iface_id] = running;
}

/* ******************************************* */

bool ThreadedActivity::isInterfaceTaskRunning(NetworkInterface *iface) {
  const int iface_id = iface->get_id();

  if((iface_id >= 0) && (iface_id < MAX_NUM_DEFINED_INTERFACES))
    return interfaceTasksRunning[iface_id];

  return false;
}

/* ******************************************* */

void ThreadedActivity::activityBody() {
  if(periodicity == 0)       /* The script is not periodic */
    aperiodicActivityBody();
  else if(periodicity <= MIN_TIME_SPAWN_THREAD_POOL) /* Accurate time computation with micro-second-accurate sleep */
    uSecDiffPeriodicActivityBody();
  else
    periodicActivityBody();
}

/* ******************************************* */

void ThreadedActivity::run() {
  if(pthread_create(&pthreadLoop, NULL, startActivity, (void*)this) == 0)
    thread_started = true;
}

/* ******************************************* */

/* Run a one-shot script / accurate (e.g. second) periodic script */
void ThreadedActivity::runScript() {
  struct stat statbuf;
  char script_path[MAX_PATH];
  
  snprintf(script_path, sizeof(script_path), "%s/system/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &statbuf) == 0) {
    runScript(script_path, NULL);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to find script %s", path);
}

/* ******************************************* */

/* Run a script - both periodic and one-shot scripts are called here */
void ThreadedActivity::runScript(char *script_path, NetworkInterface *iface) {
  LuaEngine *l;

  if(strcmp(path, SHUTDOWN_SCRIPT_PATH) && isTerminating()) return;

#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Running %s", this, path);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Running %s (iface=%p)", script_path, iface);
  
  try {
    l = new LuaEngine();
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      oom_warning_sent = true;
    }

    return;
  }

  l->run_script(script_path, iface);

  if(iface == NULL)
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
      u_int diff = max_duration - usec_diff;

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
      scheduleJob(pool);

      next_run = Utils::roundTime(now, periodicity,
				  align_to_localtime ? ntop->get_time_offset() : 0);
    }

    sleep(1);
  }

  /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminating %s(%s) exit", __FUNCTION__, path); */
}

/* ******************************************* */

void ThreadedActivity::scheduleJob(ThreadPool *pool) {
  /* Schedule per system / interface */
  char script_path[MAX_PATH];
  struct stat statbuf;

  if(!systemTaskRunning) {
    /* Schedule system script */
    snprintf(script_path, sizeof(script_path), "%s/system/%s",
	     ntop->get_callbacks_dir(), path);
    
    if(stat(script_path, &statbuf) == 0) {
      pool->queueJob(this, script_path, NULL);
#ifdef THREAD_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queued system job %s", script_path);
#endif
    }
  }
  
  /* Schedule interface script, one for each interface */
  snprintf(script_path, sizeof(script_path), "%s/interface/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &statbuf) == 0) {
    for(int i=0; i<ntop->get_num_interfaces(); i++) {
      NetworkInterface *iface = ntop->getInterface(i);

      if(iface && !isInterfaceTaskRunning(iface)) {
        pool->queueJob(this, script_path, iface);
        setInterfaceTaskRunning(iface, true);
#ifdef THREAD_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queued interface job %s", script_path);
#endif
      }
    }
  }
}

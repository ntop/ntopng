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

#include "ntop_includes.h"

/* **************************************************** */

static void* startActivity(void* ptr)  {
  ((ThreadedActivity*)ptr)->activityBody();
  return(NULL);
}

/* ******************************************* */

ThreadedActivity::ThreadedActivity(const char* _path,
				   u_int32_t _periodicity_seconds,
				   bool _align_to_localtime,
				   u_int8_t thread_pool_size) {
  periodicity = _periodicity_seconds;
  align_to_localtime = _align_to_localtime;
  thread_started = false, taskRunning = false;
  path = strdup(_path); /* ntop->get_callbacks_dir() */;
  numRunningChildren = 0;
  
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

  if(path) free(path);
  if(pool) delete pool;

  if(thread_started)
    pthread_join(pthreadLoop, &res);
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

/* Run a script immediately */
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

void ThreadedActivity::runScript(char *script_path, NetworkInterface *iface) {
  Lua *l;

#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Running %s", this, path);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Running %s (iface=%p)", script_path, iface);
  
  try {
    l = new Lua();
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      oom_warning_sent = true;
    }

    return;
  }

  l->run_script(script_path, iface);

  delete l;
  taskRunning = false;
}

/* ******************************************* */

void ThreadedActivity::aperiodicActivityBody() {
  if(!ntop->getGlobals()->isShutdown())
    runScript();
}

/* ******************************************* */

void ThreadedActivity::uSecDiffPeriodicActivityBody() {
  struct timeval begin, end;
  u_long usec_diff;

  while(!ntop->getGlobals()->isShutdown()) {
    while(taskRunning) usleep(1000);

    gettimeofday(&begin, NULL);
    taskRunning = true;
    runScript();
    gettimeofday(&end, NULL);

    usec_diff = (end.tv_sec * 1e6) + end.tv_usec - (begin.tv_sec * 1e6) - begin.tv_usec;

    if(usec_diff < periodicity * 1e6) {
      u_int diff = (periodicity * 1e6) - usec_diff;

      _usleep(diff);
    } /* else { the script took too long } */
  }
}

/* ******************************************* */

u_int32_t ThreadedActivity::roundTime(u_int32_t now, u_int32_t rounder, int32_t offset_from_utc) {
  now -= (now % rounder);
  now += rounder; /* Aligned to midnight UTC */

  if(offset_from_utc > 0)
    now += 86400 - offset_from_utc;
  else if(offset_from_utc < 0)
    now += -offset_from_utc;

  return(now);
}

/* ******************************************* */

void ThreadedActivity::periodicActivityBody() {
  u_int32_t next_run = (u_int32_t)time(NULL);

  next_run = roundTime(next_run, periodicity, align_to_localtime ? ntop->get_time_offset() : 0);

  if(align_to_localtime)
    next_run -= periodicity;

  while(!ntop->getGlobals()->isShutdown()) {
    u_int now = (u_int)time(NULL);

    if(now >= next_run) {
      while(taskRunning) usleep(1000);
      taskRunning = true;
      scheduleJob(pool);

      next_run = roundTime(now, periodicity,
			   align_to_localtime ? ntop->get_time_offset() : 0);
    }

    sleep(1);
  }
}

/* ******************************************* */

void ThreadedActivity::scheduleJob(ThreadPool *pool) {
  /* Schedule per system / interface */
  char script_path[MAX_PATH];
  struct stat statbuf;
  
  while(numRunningChildren > 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "[%s] Waiting for %u to terminate",
				 path, numRunningChildren);
    sleep(1);
  }

  /* Schedule system script */
  snprintf(script_path, sizeof(script_path), "%s/system/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &statbuf) == 0)
    pool->queueJob(this, script_path, NULL);

  /* Schedule interface script */
  snprintf(script_path, sizeof(script_path), "%s/interface/%s",
	   ntop->get_callbacks_dir(), path);

  if(stat(script_path, &statbuf) == 0) {
    for(int i=0; i<ntop->get_num_interfaces(); i++) {
      NetworkInterface *iface = ntop->getInterface(i);

      if(iface)
	pool->queueJob(this, script_path, iface);
    }
  }
}

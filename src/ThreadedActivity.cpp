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

ThreadedActivity::ThreadedActivity(const char* _path, NetworkInterface *_iface,
				   u_int32_t _periodicity_seconds, bool _align_to_localtime) {
  iface = _iface;
  periodicity = _periodicity_seconds;
  align_to_localtime = _align_to_localtime;
  thread_started = false;

  snprintf(path, sizeof(path), "%s/%s", ntop->get_callbacks_dir(), _path);

#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Creating ThreadedActivity '%s'", this, path);
#endif
}

/* ******************************************* */

ThreadedActivity::~ThreadedActivity() {
  void *res;

  if(thread_started)
    pthread_join(pthreadLoop, &res);
}

/* ******************************************* */

void ThreadedActivity::activityBody() {
  if(periodicity == 0)       /* The script is not periodic */
    aperiodicActivityBody();
  else if(periodicity <= 10) /* Accurate time computation with micro-second-accurate sleep */
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

void ThreadedActivity::runScript() {
  struct stat statbuf;

#ifdef THREADED_DEBUG
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Running %s", this, path);
#endif
  
  if(stat(path, &statbuf) == 0) {
    Lua *l;

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

    l->run_script(path);
    delete l;
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "[%p] Missing script %s", this, path);
}

/* ******************************************* */

void ThreadedActivity::aperiodicActivityBody() {
  if(!ntop->getGlobals()->isShutdown())
    ntop->getPeriodicTaskPool()->scheduleJob(this);
}

/* ******************************************* */

void ThreadedActivity::uSecDiffPeriodicActivityBody() {
  struct timeval begin, end;
  u_long usec_diff;

  while(!ntop->getGlobals()->isShutdown()) {
    gettimeofday(&begin, NULL);
    ntop->getPeriodicTaskPool()->scheduleJob(this);
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
      ntop->getPeriodicTaskPool()->scheduleJob(this);
      next_run = roundTime(now, periodicity, align_to_localtime ? ntop->get_time_offset() : 0);
    }

    sleep(1);
  }
}

/* ******************************************* */

/*
 *
 * (C) 2013-21 - ntop.org
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

typedef struct _activity_descr {
  const char *path;
  u_int32_t periodicity;
  u_int32_t max_duration_secs;
  ThreadPool *pool;
  bool align_to_localtime;  
  bool exclude_viewed_interfaces;
  bool exclude_pcap_dump_interfaces;
  bool reuse_vm;
} activity_descr;

/* ******************************************* */

PeriodicActivities::PeriodicActivities() {
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++)
    activities[i] = NULL;

  standard_priority_pool = no_priority_pool = longrun_priority_pool
    = timeseries_pool = periodic_checks_pool = discover_pool
    = housekeeping_pool = notifications_pool = NULL;

  num_activities = 0;
}

/* ******************************************* */

PeriodicActivities::~PeriodicActivities() {
  /* Important: destroy the ThreadedActivities only *after* ensuring that both its pthreadLoop
   * thread and the possibly running activity into the ThreadPool::run thread
   * have been terminated. */
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++) {
    /* This will terminate the pthreadLoop of the activities */
    if(activities[i])
      activities[i]->terminateEnqueueLoop();
  }

  /* This will terminate any possibly running activities into the ThreadPool::run */
  if(standard_priority_pool)     delete standard_priority_pool;
  if(longrun_priority_pool)      delete longrun_priority_pool;
  if(timeseries_pool)            delete timeseries_pool;
  if(notifications_pool)         delete notifications_pool;
  if(periodic_checks_pool) delete periodic_checks_pool;
  if(discover_pool)              delete discover_pool;
  if(housekeeping_pool)          delete housekeeping_pool;
  if(no_priority_pool)           delete no_priority_pool;

  /* Now it's safe to delete the activities as no other thread is executing
   * their code. */
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++) {
    if(activities[i]) {
      delete activities[i];
      activities[i] = NULL;
      num_activities--;
    }
  }
}

/* ******************************************* */

void PeriodicActivities::lua(NetworkInterface *iface, lua_State *vm) {
  for(int i = 0; i < num_activities; i++) {
    if(activities[i])
      activities[i]->lua(iface, vm);
  }
}

/* ******************************************* */

void PeriodicActivities::sendShutdownSignal() {
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++) {
    if(activities[i])
      activities[i]->shutdown();
  }
}

/* ******************************************* */

void PeriodicActivities::startPeriodicActivitiesLoop() {
  struct stat buf;
  ThreadedActivity *startup_activity;
  u_int8_t num_threads = ntop->get_num_interfaces() + 1; /* +1 for the system interface */
  u_int8_t num_threads_no_priority = DEFAULT_THREAD_POOL_SIZE;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Started periodic activities loop...");

  if(stat(ntop->get_callbacks_dir(), &buf) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read directory %s", ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Possible cause:\n");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "The current user cannot access %s.", ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Please fix the directory right or add --dont-change-user to");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "the ntopng command line.");
    exit(0);
  }

  if((startup_activity = new (std::nothrow) ThreadedActivity(STARTUP_SCRIPT_PATH, false))) {
    /*
      Don't call run() as by the time the script will be run
      the delete below will free the memory 
    */
    startup_activity->runSystemScript(time(NULL));
    delete startup_activity;
    startup_activity = NULL;
  }

  if(num_threads_no_priority < num_threads)
    num_threads_no_priority = num_threads;

  if(num_threads_no_priority > MAX_THREAD_POOL_SIZE)
    num_threads_no_priority = MAX_THREAD_POOL_SIZE;

  standard_priority_pool     = new (std::nothrow) ThreadPool(false, num_threads);
  longrun_priority_pool      = new (std::nothrow) ThreadPool(false, num_threads);
  timeseries_pool            = new (std::nothrow) ThreadPool(false, 1);
  notifications_pool         = new (std::nothrow) ThreadPool(false, 1);
  periodic_checks_pool = new (std::nothrow) ThreadPool(false, 1);
  discover_pool              = new (std::nothrow) ThreadPool(false, 1);
  housekeeping_pool          = new (std::nothrow) ThreadPool(false, 1);
  no_priority_pool           = new (std::nothrow) ThreadPool(false, num_threads_no_priority);
  
  static activity_descr ad[] = {
    // Script                 Periodicity (s) Max (s)  Pool                        Align  !View  !PCAP  Reuse
    { SECOND_SCRIPT_PATH,                    1,     2, standard_priority_pool,     false, false, true,  true  },
    { STATS_UPDATE_SCRIPT_PATH,              5,    10, standard_priority_pool,     false, false, true,  true  },
    { PERIODIC_CHECKS_PATH,            5,    60, periodic_checks_pool, false, false, true,  true  },

    { HOUSEKEEPING_SCRIPT_PATH,              3,     6, housekeeping_pool,          false, false, false, true  },

    { MINUTE_SCRIPT_PATH,                   60,    60, no_priority_pool,           false, false, true,  false },
    { DAILY_SCRIPT_PATH,                 86400,  3600, no_priority_pool,           true,  false, true,  false },
#ifdef HAVE_NEDGE
    { PINGER_SCRIPT_PATH,                    5,     5, no_priority_pool,           false, false, true,  false },
#endif
    
    { TIMESERIES_SCRIPT_PATH,                1,  3600, timeseries_pool,            false, false, true,  true  },
    { NOTIFICATIONS_SCRIPT_PATH,             1,  3600, notifications_pool,         false, false, false, true  },

    { FIVE_MINUTES_SCRIPT_PATH,            300,   300, longrun_priority_pool,      false, false, true,  false },
    { HOURLY_SCRIPT_PATH,                 3600,   600, longrun_priority_pool,      false, false, true,  false },

    { DISCOVER_SCRIPT_PATH,                  5,  3600, discover_pool,              false, false, true,  true  },

    { NULL,                                  0,     0, NULL,                       false, false, false, false }
  };

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Each periodic activity script will use %u threads", num_threads);
  
  activity_descr *d = ad;
  
  while(d->path) {
    ThreadedActivity *ta = new (std::nothrow) ThreadedActivity(d->path,
						d->periodicity,
						d->max_duration_secs,
						d->align_to_localtime,
						d->exclude_viewed_interfaces,
						d->exclude_pcap_dump_interfaces,
						d->reuse_vm,
						d->pool);
    if(ta) {
      activities[num_activities++] = ta;
      ta->run();
    }

    d++;
  }
}

/* ******************************************* */

void PeriodicActivities::reloadVMs() {
  time_t next_reload = time(NULL) + 1;

  for(int i = 0; i < num_activities; i++)
    activities[i]->setNextVmReload(next_reload);
}

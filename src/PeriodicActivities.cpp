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

typedef struct _activity_descr {
  const char *path;
  u_int32_t periodicity;
  bool align_to_localtime;
  u_int8_t thread_pool_size;
} activity_descr;

/* ******************************************* */

PeriodicActivities::PeriodicActivities() {
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++)
    activities[i] = NULL;

  num_activities = 0;
}

/* ******************************************* */

PeriodicActivities::~PeriodicActivities() {
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++) {
    if(activities[i]) {
      delete activities[i];
      activities[i] = NULL;
      num_activities--;
    }
  }
}

/* ******************************************* */

void PeriodicActivities::startPeriodicActivitiesLoop() {
  struct stat buf;
  ThreadedActivity *startup_activity;
  static u_int8_t num_threads = DEFAULT_THREAD_POOL_SIZE;
    
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Started periodic activities loop...");

  if(stat(ntop->get_callbacks_dir(), &buf) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read directory %s", ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Possible cause:\n");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "The current user cannot access %s.", ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Please fix the directory right or add --dont-change-user to");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "the ntopng command line.");
    exit(0);
  }

  if((startup_activity = new ThreadedActivity(STARTUP_SCRIPT_PATH, false))) {
    /*
      Don't call run() as by the time the script will be run
      the delete below will free the memory 
    */
    startup_activity->runScript();
    delete startup_activity;
    startup_activity = NULL;
  }

  if(num_threads < ntop->get_num_interfaces())
    num_threads = ntop->get_num_interfaces();

  if(num_threads > MAX_THREAD_POOL_SIZE)
    num_threads = MAX_THREAD_POOL_SIZE;
  
  static activity_descr ad[] = {
    { SECOND_SCRIPT_PATH,       1,     false, 1           },
    { MINUTE_SCRIPT_PATH,       60,    false, num_threads },
    { FIVE_MINUTES_SCRIPT_PATH, 300,   false, num_threads },
    { HOURLY_SCRIPT_PATH,       3600,  false, num_threads },
    { DAILY_SCRIPT_PATH,        86400, true,  1           },
    { HOUSEKEEPING_SCRIPT_PATH, 3,     false, num_threads },
    { DISCOVER_SCRIPT_PATH,     5,     false, 1           },
#ifdef HAVE_NEDGE
    { PINGER_SCRIPT_PATH,       5,     false, 1           },
#endif
    { NULL, 0, false}
  };

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Each periodic activity script will use %u threads", num_threads);
  
  activity_descr *d = ad;
  
  while(d->path) {
    ThreadedActivity *ta = new ThreadedActivity(d->path,
						d->periodicity,
						d->align_to_localtime,
						d->thread_pool_size);
    if(ta) {
      activities[num_activities++] = ta;
      ta->run();
    }

    d++;
  }
}

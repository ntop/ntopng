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
  bool align_to_localtime;
  bool exclude_viewed_interfaces;
  bool exclude_pcap_dump_interfaces;
  ThreadedActivity *ta;
} activity_descr;

static activity_descr ad[] = {
  // Script                  Periodicity (s) Max (s) Align  !View  !PCAP NULL
  { SECOND_SCRIPT_DIR,                    1,     65, false, false, true, NULL },
  { FIVE_SECOND_SCRIPT_DIR,               5,     65, false, false, true, NULL },
  { MINUTE_SCRIPT_DIR,                   60,     60, false, false, true, NULL },
  { FIVE_MINUTES_SCRIPT_DIR,            300,    300, false, false, true, NULL },
  { HOURLY_SCRIPT_DIR,                 3600,    600, false, false, true, NULL },
  { DAILY_SCRIPT_DIR,                 86400,   3600, true,  false, true, NULL },
  
  /* TODO: remove these two periodic scripts */
  { HOUSEKEEPING_SCRIPT_PATH,             3,     65, false, false, false, NULL },
  { NULL,                                 0,      0, false, false, false, NULL }
};

/* ******************************************* */

PeriodicActivities::PeriodicActivities() {
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++)
    activities[i] = NULL;

  th_pool = new ThreadPool();

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

  delete th_pool;

  /* Now it's safe to delete the activities as no other thread is executing
   * their code. */
  for(u_int16_t i = 0; i < CONST_MAX_NUM_THREADED_ACTIVITIES; i++) {
    if(activities[i]) {
      delete activities[i]; /* This line calls ThreadedActivity::~ThreadedActivity() */
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

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Started periodic activities loop...");

  if(stat(ntop->get_callbacks_dir(), &buf) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read directory %s", ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Possible cause:\n");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "The current user cannot access %s.", ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Please fix the directory right or add --dont-change-user to");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "the ntopng command line.");
    exit(0);
  }

  if((startup_activity = new (std::nothrow) ThreadedActivity(STARTUP_SCRIPT_PATH))) {
    /*
      Don't call run() as by the time the script will be run
      the delete below will free the memory
    */
    startup_activity->runSystemScript(time(NULL));
    delete startup_activity;
    startup_activity = NULL;
  }

  for(u_int i=0; ad[i].path != NULL; i++) {
    std::vector<char*> iface_scripts_list, system_scripts_list;

    ad[i].ta = new (std::nothrow) ThreadedActivity(ad[i].path,
						   ad[i].periodicity,
						   ad[i].max_duration_secs,
						   ad[i].align_to_localtime,
						   ad[i].exclude_viewed_interfaces,
						   ad[i].exclude_pcap_dump_interfaces,
						   th_pool);
    if(ad[i].ta) {
      activities[num_activities++] = ad[i].ta;
      ad[i].ta->run();
    }
  }
}

/* ******************************************* */

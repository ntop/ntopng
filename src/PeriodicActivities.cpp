/*
 *
 * (C) 2013-24 - ntop.org
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
} activity_descr;

static activity_descr ad[] = {
    // Script                  Periodicity (s) Max (s) Align  !View  !PCAP
    {SECOND_SCRIPT_DIR, 1, 65, false, false, true},
    {FIVE_SECOND_SCRIPT_DIR, 5, 65, false, false, true},
    {MINUTE_SCRIPT_DIR, 60, 60, false, false, true},
    {FIVE_MINUTES_SCRIPT_DIR, 300, 300, false, false, true},
    {HOURLY_SCRIPT_DIR, 3600, 600, false, false, true},
    {DAILY_SCRIPT_DIR, 86400, 3600, true, false, true},

    {NULL, 0, 0, false, false, false}};

/* ******************************************* */

PeriodicActivities::PeriodicActivities() {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
  num_sec_min_activities = num_hour_day_activities = 0;

  th_pool = new ThreadPool();
  thread_running = false;
  num_sec_min_activities = 0, num_hour_day_activities = 0;
}

/* ******************************************* */

PeriodicActivities::~PeriodicActivities() {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
  
  delete th_pool;

  /* Now it's safe to delete the activities as no other thread is executing their code. */
  for (u_int16_t i = 0; i < num_sec_min_activities; i++)
    delete sec_min_activities[i]; /* This line calls ThreadedActivity::~ThreadedActivity() */

  for (u_int16_t i = 0; i < num_hour_day_activities; i++)
    delete hour_day_activities[i]; /* This line calls ThreadedActivity::~ThreadedActivity() */
}

/* ******************************************* */

void PeriodicActivities::lua(NetworkInterface *iface, lua_State *vm) {
  for (u_int16_t i = 0; i < num_sec_min_activities; i++)
    sec_min_activities[i]->lua(iface, vm);  
  
  for (u_int16_t i = 0; i < num_hour_day_activities; i++)
    hour_day_activities[i]->lua(iface, vm);      
}

/* **************************************************** */

static void *startActivity(void *ptr) {
  Utils::setThreadName("ntopng-periodic");

  ((PeriodicActivities *)ptr)->run();

  return (NULL);
}

/* ******************************************* */

/* This is the main infinite loop */
void PeriodicActivities::run() {
  while (!(ntop->getGlobals()->isShutdownRequested()
	   || ntop->getGlobals()->isShutdown())) {
    u_int32_t now = (u_int32_t)time(NULL);

    for (u_int16_t i = 0; i < num_sec_min_activities; i++)
      sec_min_activities[i]->schedule(this, now, false);

    if(num_running_hour_day_activities == 0) {
      /* At most only one concurrent activity */
      for (u_int16_t i = 0; i < num_hour_day_activities; i++)
	hour_day_activities[i]->schedule(this, now, true);
    }
    
    sleep(1);
  }

  thread_running = false;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated periodic activites...");
}

/* ******************************************* */

void PeriodicActivities::startPeriodicActivitiesLoop() {
  struct stat buf;
  ThreadedActivity *startup_activity;

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "Started periodic activities loop...");

  if (stat(ntop->get_callbacks_dir(), &buf) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read directory %s",
                                 ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Possible cause:\n");
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "The current user cannot access %s.",
                                 ntop->get_callbacks_dir());
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Please fix the directory right or add --dont-change-user to");
    ntop->getTrace()->traceEvent(TRACE_ERROR, "the ntopng command line.");
    exit(0);
  }

  if ((startup_activity = new (std::nothrow) ThreadedActivity(STARTUP_SCRIPT_PATH))) {
    /*
      Don't call run() as by the time the script will be run
      the delete below will free the memory
    */
    startup_activity->runSystemScript(time(NULL));
    delete startup_activity;
    startup_activity = NULL;
  }

  for (u_int i = 0; ad[i].path != NULL; i++) {
    ThreadedActivity *ta;

    if (ad[i].periodicity == 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping %s: 0 periodicity",
                                   ad[i].path);
      continue;
    }

    ta = new (std::nothrow) ThreadedActivity(ad[i].path, false, /* Exact */
					     ad[i].periodicity, ad[i].max_duration_secs, ad[i].align_to_localtime,
					     ad[i].exclude_viewed_interfaces, ad[i].exclude_pcap_dump_interfaces,
					     th_pool);

    if (ta) {
      if((strncmp(ad[i].path, "hour", 4) == 0)
	 || (strncmp(ad[i].path, "daily", 5) == 0))	
	hour_day_activities[num_hour_day_activities++] = ta;
      else
	sec_min_activities[num_sec_min_activities++] = ta;
    }


    if (ad[i].periodicity >= 60 /* no delay for sub-minute scripts */) {
      char script_dir[64];

      snprintf(script_dir, sizeof(script_dir), "%s%s", ad[i].path, DELAYED_TRAILER);

      ta = new (std::nothrow) ThreadedActivity(script_dir, true, /* Delayed */
					       ad[i].periodicity, ad[i].max_duration_secs, ad[i].align_to_localtime,
					       ad[i].exclude_viewed_interfaces, ad[i].exclude_pcap_dump_interfaces,
					       th_pool);
      if (ta) {
      if((strncmp(ad[i].path, "hour", 4) == 0)
	 || (strncmp(ad[i].path, "daily", 5) == 0))	
	hour_day_activities[num_hour_day_activities++] = ta;
      else
	sec_min_activities[num_sec_min_activities++] = ta;
      }
    }
  }

  ntop->getTrace()->traceEvent(TRACE_INFO, "Found [%u sec/min][%u hour/day] activity dirs",
                               num_sec_min_activities, num_hour_day_activities);

  if (pthread_create(&pthreadLoop, NULL, startActivity, (void *)this) == 0) {
    thread_running = true;
#ifdef __linux__
    Utils::setThreadAffinityWithMask(pthreadLoop, ntop->getPrefs()->get_other_cpu_affinity_mask());
#endif
  }
}


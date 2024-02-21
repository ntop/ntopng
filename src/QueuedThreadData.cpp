/*
 *
 * (C) 2017-24 - ntop.org
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

QueuedThreadData::QueuedThreadData(ThreadedActivity *_j,
				   char *_path,
				   NetworkInterface *_iface,
				   time_t _deadline,
				   PeriodicActivities *_pa,
				   bool _hourly_daily_activity) {
  j = _j, script_path = strdup(_path), iface = _iface;
  deadline = _deadline, pa = _pa,
    hourly_daily_activity = _hourly_daily_activity;;
}

/* **************************************************** */

QueuedThreadData::~QueuedThreadData() {
  if (script_path) free(script_path);
}

/* **************************************************** */

/* #define TASK_DEBUG */

void QueuedThreadData::run() {
  char name[64], *slash = strrchr(script_path, '/');
  char *label = slash ? &slash[1] : script_path;

#ifdef TASK_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "(**) Started task [%s][%s][%s]",
			       script_path, iface->get_name(),
			       hourly_daily_activity ? "hour/daily" : "sec/min");
#endif
  if (iface->get_id() == -1)
    snprintf(name, sizeof(name), "ntopng-S-%s", label);
  else
    snprintf(name, sizeof(name), "ntopng-%d-%s", iface->get_id(), label);
      
  Utils::setThreadName(name);

  pa->incRunningTasks(hourly_daily_activity);
  j->set_state_running(iface, script_path);
  j->runScript(time(NULL), script_path, iface, deadline);
  j->set_state_sleeping(iface, script_path);
  pa->decRunningTasks(hourly_daily_activity);
  
#ifdef TASK_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "(**) Completed task [%s][%s][%s]",
			       script_path, iface->get_name(),
			       hourly_daily_activity ? "hour/daily" : "sec/min");
#endif
}

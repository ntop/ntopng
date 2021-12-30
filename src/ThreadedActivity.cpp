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

#define THREAD_DEBUG

/* **************************************************** */

static void* startActivity(void* ptr)  {
  Utils::setThreadName(((ThreadedActivity*)ptr)->activityPath());

  ((ThreadedActivity*)ptr)->activityBody();
  return(NULL);
}

/* ******************************************* */

ThreadedActivity::ThreadedActivity(const char* _path,
				   u_int32_t _periodicity_seconds,
				   u_int32_t _max_duration_seconds,
				   bool _align_to_localtime,
				   bool _exclude_viewed_interfaces,
				   bool _exclude_pcap_dump_interfaces,
				   ThreadPool *_pool) {
  terminating = false;
  thread_started = false;
  
  periodic_script = new (std::nothrow) PeriodicScript(_path,
                                                      _periodicity_seconds,
                                                      _max_duration_seconds,
                                                      _align_to_localtime,
                                                      _exclude_viewed_interfaces,
                                                      _exclude_pcap_dump_interfaces,
                                                      _pool);
  
  setDeadlineApproachingSecs();
}

/* ******************************************* */

ThreadedActivity::~ThreadedActivity() {
  /* 
     NOTE:
     terminateEnqueueLoop should have already been called by the PeriodicActivities destructor.
  */
  terminateEnqueueLoop();

  for(std::map<std::string, ThreadedActivityStats*>::iterator it = threaded_activity_stats.begin();
      it != threaded_activity_stats.end(); ++it) {
    delete it->second;
  }
  
  if(periodic_script) delete periodic_script;
}

/* ******************************************* */

void ThreadedActivity::setDeadlineApproachingSecs() {
  if(getPeriodicity() <= 1)
    deadline_approaching_secs =  0;
  else if(getPeriodicity() <= 5)
    deadline_approaching_secs =  1;
  else if(getPeriodicity() <= 60)
    deadline_approaching_secs =  5;
  else /* > 60 secs */
    deadline_approaching_secs = 10;
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
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Joined thread %s", activityPath());
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

ThreadedActivityState ThreadedActivity::getThreadedActivityState(NetworkInterface *iface, char *script_name) {
  if(iface) {
    ThreadedActivityStats *s = getThreadedActivityStats(iface, script_name, false);

    if(s)
      return(s->getState());
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error. NULL interface.");

  return(threaded_activity_state_unknown);
}

/* ******************************************* */

static bool skipExecution(const char *path) {
#if 0
  if((ntop->getPrefs()->getTimeseriesDriver() != ts_driver_influxdb) &&
     (strcmp(path, TIMESERIES_SCRIPT_PATH) == 0))
    return(true);
#endif

  // Always execute periodic activities, thread timeseries.lua
  // is now also used by rrds to dequeue writes
  return(false);
}

/* ******************************************* */

void ThreadedActivity::set_state(NetworkInterface *iface,
				 char *script_name,
				 ThreadedActivityState ta_state) {
  ThreadedActivityStats *s = getThreadedActivityStats(iface, script_name, false);

  if(s)
    s->setState(ta_state);
}

/* ******************************************* */

ThreadedActivityState ThreadedActivity::get_state(NetworkInterface *iface,
						  char *script_name) {
  ThreadedActivityStats *s = getThreadedActivityStats(iface, script_name, false);

  if(s)
    return s->getState();

  return threaded_activity_state_unknown;
}

/* ******************************************* */

void ThreadedActivity::set_state_sleeping(NetworkInterface *iface,
					  char *script_name) {
  set_state(iface, script_name, threaded_activity_state_sleeping);
}

/* ******************************************* */

void ThreadedActivity::set_state_queued(NetworkInterface *iface,
					char *script_name) {
  ThreadedActivityStats *s = getThreadedActivityStats(iface, script_name, false);

  if(s) {
    s->setState(threaded_activity_state_queued);
    s->updateStatsQueuedTime(time(NULL));
  }
}

/* ******************************************* */

void ThreadedActivity::set_state_running(NetworkInterface *iface, char *script_name) {
  set_state(iface, script_name, threaded_activity_state_running);
}

/* ******************************************* */

bool ThreadedActivity::isDeadlineApproaching(time_t deadline) {
  if(terminating)
    return true;

  /*
    The deadline is approaching if the current time is closer than deadline_approaching_secs
    with reference to the deadline passed as parameter
  */
  bool res = deadline - time(NULL) <= deadline_approaching_secs;

  return res;
}

/* ******************************************* */

/* NOTE: this runs into a separate thread, launched by PeriodicActivities
 * after creation. */
void ThreadedActivity::activityBody() {
  if(getPeriodicity() == 0)       /* The script is not periodic */
    aperiodicActivityBody();
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

#if 0
  /* Don't schedule periodic activities it we are processing pcap files only. */
  if(excludePcap() && pcap_dump_only)
    return;
#endif
  
  if(pthread_create(&pthreadLoop, NULL, startActivity, (void*)this) == 0) {
    thread_started = true;
#ifdef __linux__
    Utils::setThreadAffinityWithMask(pthreadLoop, ntop->getPrefs()->get_other_cpu_affinity_mask());
#endif
  }
}

/* ******************************************* */

ThreadedActivityStats* ThreadedActivity::getThreadedActivityStats(NetworkInterface *iface,
								  char *script_name,
								  bool allocate_if_missing) {
  ThreadedActivityStats *ta = NULL;

  if(!isTerminating() && iface) {
    std::string key = std::to_string(iface->get_id()) + "/" + std::string(script_name);
    std::map<std::string, ThreadedActivityStats*>::iterator it = threaded_activity_stats.find(key);

#ifdef THREAD_DEBUG
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s() [%s]", __FUNCTION__, key.c_str());
#endif

    if(it == threaded_activity_stats.end()) {
      /* Not found */
      if(allocate_if_missing) {
	try {
	  ta = new ThreadedActivityStats(this);
	} catch(std::bad_alloc& ba) {
	  return NULL;
	}

	threaded_activity_stats[key] = ta;
      }
      
      return(ta);
    } else {
      return(it->second);
    }
  }
  
  return ta;
}

/* ******************************************* */

  void ThreadedActivity::updateThreadedActivityStatsBegin(NetworkInterface *iface,
							  char *script_name, struct timeval *begin) {
    ThreadedActivityStats *ta = getThreadedActivityStats(iface, script_name, true /* Allocate if missing */);

  if(ta)
    ta->updateStatsBegin(begin);
}

/* ******************************************* */

void ThreadedActivity::updateThreadedActivityStatsEnd(NetworkInterface *iface, char *script_name, u_long latest_duration) {
  ThreadedActivityStats *ta = getThreadedActivityStats(iface, script_name, true /* Allocate if missing */);

  if(ta)
    ta->updateStatsEnd(latest_duration);
}

/* ******************************************* */

/* Run a one-shot script / accurate (e.g. second) periodic script */
void ThreadedActivity::runSystemScript(time_t now) {
  struct stat buf;
  char script_path[MAX_PATH];
  
  snprintf(script_path, sizeof(script_path), "%s/system/%s",
	   ntop->get_callbacks_dir(), activityPath());

  if(stat(script_path, &buf) == 0) {
    set_state_running(ntop->getSystemInterface(), script_path);
    runScript(now, script_path, ntop->getSystemInterface(), now + getMaxDuration() /* this is the deadline */);
    set_state_sleeping(ntop->getSystemInterface(), script_path);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to find script %s", activityPath());
}

/* ******************************************* */

/* Run a script - both periodic and one-shot scripts are called here */
void ThreadedActivity::runScript(time_t now, char *script_name, NetworkInterface *iface, time_t deadline) {
  LuaEngine *l = NULL;
  u_long msec_diff;
  struct timeval begin, end;
  ThreadedActivityStats *thstats = getThreadedActivityStats(iface, script_name, true);

  if(!iface)
    return;

  if(strcmp((activityPath()), SHUTDOWN_SCRIPT_PATH) && isTerminating())
    return;

  if(iface->isViewed() && excludeViewedIfaces())
    return;

#ifdef THREAD_DEBUG
  // ntop->getTrace()->traceEvent(TRACE_WARNING, "[%p] Running %s", this, activityPath());
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Running %s (iface=%p)", script_name, iface);

  l = loadVm(script_name, iface, now);
  if(!l) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to load the Lua vm [%s][vm: %s]", iface->get_name(), activityPath());
    return;
  }

  /* Set the deadline and the threaded activity in the vm so they can be accessed */
  l->setThreadedActivityData(this, thstats, deadline);

  if(thstats) {
    thstats->setDeadline(deadline);
    thstats->setCurrentProgress(0);

    /* Reset the internal state for the current execution */
    thstats->setNotExecutedActivity(false);
    thstats->setSlowPeriodicActivity(false);
  }

  gettimeofday(&begin, NULL);
  updateThreadedActivityStatsBegin(iface, script_name, &begin);

  /* Set the current time globally  */
  lua_pushinteger(l->getState(), now);
  lua_setglobal(l->getState(), "_now");
  l->run_loaded_script();

  gettimeofday(&end, NULL);
  msec_diff = (end.tv_sec - begin.tv_sec) * 1000 + (end.tv_usec - begin.tv_usec) / 1000;
  updateThreadedActivityStatsEnd(iface, script_name, msec_diff);

  if(thstats && isDeadlineApproaching(deadline))
    thstats->setSlowPeriodicActivity(true);

  if(l)
    delete l;
}

/* ******************************************* */

LuaEngine* ThreadedActivity::loadVm(char *script_name, NetworkInterface *iface, time_t when) {
  LuaEngine *l = NULL;

  try {
    /* NOTE: this needs to be deallocated by the caller */
    l = new LuaEngine(NULL);

    if(l->load_script(script_name, iface) != 0) {
      delete l;
      l = NULL;
    }
  } catch(std::bad_alloc& ba) {
    l = NULL;
  }

  return(l);
}

/* ******************************************* */

void ThreadedActivity::aperiodicActivityBody() {
  if(!isTerminating())
    runSystemScript(time(NULL));
}

/* ******************************************* */

void ThreadedActivity::periodicActivityBody() {
  u_int now;
  u_int32_t next_deadline, next_schedule = (u_int32_t)time(NULL);
  
  next_schedule = Utils::roundTime(next_schedule, getPeriodicity(), 
				   alignToLocalTime() ? ntop->get_time_offset() : 0);

  while(!isTerminating()) {
    int tdiff;
    
    now = (u_int)time(NULL);

    if(now >= next_schedule) {
      next_deadline = now + getMaxDuration(); /* deadline is max_duration_secs from now */
      next_schedule = Utils::roundTime(now, getPeriodicity(), 
				       alignToLocalTime() ? ntop->get_time_offset() : 0);

      if(!skipExecution(activityPath()))
	schedulePeriodicActivity(getPool(), now, next_deadline);
    }

    tdiff = next_schedule-now;    

#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Next schedule: %d [%s]", tdiff, activityPath());
#endif

    while(tdiff > 0) {
      sleep(1);
      tdiff--;

      /* Do not wait forever during shutdown */
      if(isTerminating())
	break;
    }
  }

  /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminating %s(%s) exit", __FUNCTION__, path); */
}

/* ******************************************* */

bool ThreadedActivity::isValidScript(char* dir, char *path) {
  u_int len;
  char *suffix;
  
  /* Discard names starting with . */
  if(path[0] == '.') return(false);

#ifndef HAVE_NEDGE
  /* Discard scripts that start with nedge_... that are nEdge-only files */
  if(strncmp(path, NEDGE_HEADER, 6 /* strlen(NEDGE_HEADER) */) == 0)
    return(false);
#endif
  
  /* Discard files non ending with .lua suffix */
	     len = strlen(path);  
  if(len <= 4) return(false); else suffix = &path[len-4];
  
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s / %s [%s]", dir, path, suffix);

  return(strcmp(suffix, LUA_TRAILER) == 0 ? true : false);
}

/* ******************************************* */

/* This function enqueues the periodic activity job into the ThreadPool.
 * The ThreadPool, running into another thread, will dequeue the job and call
 * ThreadedActivity::runScript. The variables interfaceTasksRunning
 * are used to ensure that only a single instance of the job is running for a given
 * NetworkInterface. */
void ThreadedActivity::schedulePeriodicActivity(ThreadPool *pool, time_t scheduled_time, time_t deadline) {
  /* Schedule per system / interface */
  char dir_path[MAX_PATH];
  struct stat buf;
  DIR *dir_struct;
  struct dirent *ent;

  for(u_int i=0; i<2; i++) {
    if(i == 0) {
/* Schedule system script */
      snprintf(dir_path, sizeof(dir_path), "%s/%s/system/",
	       ntop->get_callbacks_dir(), activityPath());
    } else {
#ifdef NTOPNG_PRO
      /* Attempt to locate and execute the callback under the pro callbacks */
      snprintf(dir_path, sizeof(dir_path), "%s/%s/system/",
	       ntop->get_pro_callbacks_dir(), activityPath());    
#else
      break;
#endif
    }
    
    if(stat(dir_path, &buf) == 0) {
#ifdef THREAD_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Running scripts in %s", dir_path);
#endif
    
      /* Open the directory and run all the scripts inside it */
      if((dir_struct = opendir(dir_path)) != NULL) {
	while((ent = readdir(dir_struct)) != NULL) {
	  if(isValidScript(dir_path, ent->d_name)) {
	    char script_path[MAX_PATH];

	    /* Schedule interface script, one for each interface */
	    snprintf(script_path, sizeof(script_path), "%s%s", dir_path, ent->d_name);
	    
#ifdef THREAD_DEBUG
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Processing %s", script_path);
#endif
	    
	    if(pool->queueJob(this, script_path, ntop->getSystemInterface(), scheduled_time, deadline)) {
#ifdef THREAD_DEBUG
	      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queued system job %s", script_path);
#endif
	    }
	  }      
	}

	closedir(dir_struct);
      }
    }
  } /* for */

  for(u_int i=0; i<2; i++) {
    if(i == 0) {
      /* Schedule interface script, one for each interface */
      snprintf(dir_path, sizeof(dir_path), "%s/%s/interface/",
	       ntop->get_callbacks_dir(), activityPath());
    } else {
#ifdef NTOPNG_PRO
      /* Attempt at locating and executing the callback under the pro callbacks */
      snprintf(dir_path, sizeof(dir_path), "%s/%s/interface/",
	       ntop->get_pro_callbacks_dir(), activityPath());
#else
      break;
#endif
    }
    
    if(stat(dir_path, &buf) == 0) {
#ifdef THREAD_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Running scripts in %s", dir_path);
#endif
    
      /* Open the directory e run all the scripts inside it */
      if((dir_struct = opendir(dir_path)) != NULL) {
	while((ent = readdir(dir_struct)) != NULL) {
	  if(isValidScript(dir_path, ent->d_name)) {
	    for(int i = 0; i < ntop->get_num_interfaces(); i++) {
	      NetworkInterface *iface = ntop->getInterface(i);
            
	      /* Running the script for each interface if it's not a PCAP */
	      if(iface && (iface->getIfType() != interface_type_PCAP_DUMP || !excludePcap())) {      
		char script_path[MAX_PATH];
	      
		/* Schedule interface script, one for each interface */
		snprintf(script_path, sizeof(script_path), "%s%s", dir_path, ent->d_name);       
         
		if(pool->queueJob(this, script_path, iface, scheduled_time, deadline)) {
#ifdef THREAD_DEBUG
		  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queued interface job %s [%s]", script_path, iface->get_name());
#endif
		}
	      }
	    }
	  }
	}
      
	closedir(dir_struct);
      }
    }
  } /* for */
}

/* ******************************************* */

void ThreadedActivity::lua(NetworkInterface *iface, lua_State *vm) {
  ThreadedActivityStats *ta;
  std::map<std::string, ThreadedActivityStats*>::iterator it = threaded_activity_stats.begin();   /* TO FIX */

  if(it != threaded_activity_stats.end())
    ta = it->second;
  else
    ta = NULL;
  
  if(ta) {
    lua_newtable(vm);

    ta->lua(vm);

    lua_push_str_table_entry(vm, "state", Utils::get_state_label(ta->getState()));
    lua_push_uint64_table_entry(vm, "periodicity", getPeriodicity());
    lua_push_uint64_table_entry(vm, "max_duration_secs", getMaxDuration());
    lua_push_uint64_table_entry(vm, "deadline_secs", deadline_approaching_secs);

    lua_pushstring(vm, activityPath() ? activityPath() : "");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ******************************************* */

const char *ThreadedActivity::activityPath() {
  return (periodic_script ? periodic_script->getPath() : "");
}

/* ******************************************* */

u_int32_t ThreadedActivity::getPeriodicity() { 
  return (periodic_script ? periodic_script->getPeriodicity() : 0); 
}

/* ******************************************* */

u_int32_t ThreadedActivity::getMaxDuration() { 
  return (periodic_script ? periodic_script->getMaxDuration() : 0); 
}

/* ******************************************* */

bool ThreadedActivity::excludePcap() { 
  return (periodic_script ? periodic_script->excludePcap() : false);
}

/* ******************************************* */

bool ThreadedActivity::excludeViewedIfaces() { 
  return (periodic_script ? periodic_script->excludeViewedIfaces() : false);
}

/* ******************************************* */

bool ThreadedActivity::alignToLocalTime() { 
  return (periodic_script ? periodic_script->alignToLocalTime() : false);
}

/* ******************************************* */

ThreadPool *ThreadedActivity::getPool() { 
  return (periodic_script ? periodic_script->getPool() : NULL);
}



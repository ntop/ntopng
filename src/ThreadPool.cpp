/*
 *
 * (C) 2017-22 - ntop.org
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

// #define THREAD_DEBUG 1
// #define TASK_DEBUG 1

/* **************************************************** */

static void* doRun(void* ptr)  {
  Utils::setThreadName("ntopng-th-pool");

  ((ThreadPool*)ptr)->run();
  return(NULL);
}

/* **************************************************** */

ThreadPool::ThreadPool(char *comma_separated_affinity_mask) {
  m = new (std::nothrow) Mutex();
  pthread_cond_init(&condvar, NULL);
  terminating = false;

#ifdef __linux__
  CPU_ZERO(&affinity_mask);

  if(comma_separated_affinity_mask)
    Utils::setAffinityMask(comma_separated_affinity_mask, &affinity_mask);
  else if(ntop->getPrefs()->get_other_cpu_affinity())
    Utils::setAffinityMask(ntop->getPrefs()->get_other_cpu_affinity(), &affinity_mask);
#endif

  num_threads = 0;

  for(u_int i=0; i<5 /* Min number of threads */; i++)
    spawn();
}

/* **************************************************** */

ThreadPool::~ThreadPool() {
  void *res;

  shutdown();

  for(vector<pthread_t>::const_iterator it = threadsState.begin(); it != threadsState.end(); ++it) {
    pthread_cond_signal(&condvar);
    pthread_join(*it, &res);
  }

  threadsState.clear();

  while(!threads.empty()) {
    QueuedThreadData *q = threads.front();
    
    threads.pop();
    delete q;
  }
  
  pthread_cond_destroy(&condvar);
  delete m;
}

/* **************************************************** */

bool ThreadPool::spawn() {
  pthread_t new_thread;

  if(num_threads < CONST_MAX_NUM_THREADED_ACTIVITIES) {
    if(pthread_create(&new_thread, NULL, doRun, (void*)this) == 0) {
      threadsState.push_back(new_thread);

#ifdef __linux__
      Utils::setThreadAffinityWithMask(new_thread, &affinity_mask);
#endif
      num_threads++;

#ifdef THREAD_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Spawn thread [total: %u]", num_threads);
#endif

      return(true);
    }
  }

  return(false); /* Something didn't work as expected */
}

/* **************************************************** */

void ThreadPool::run() {
#ifdef THREAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Starting thread [%u]", pthread_self());
#endif

  while(!isTerminating()) {
    QueuedThreadData *q;

#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** About to dequeue job [%u][terminating=%d]",
				 pthread_self(), isTerminating());
#endif

    q = dequeueJob(true);

#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Dequeued job [%u][terminating=%d][%s][%s]",
				 pthread_self(), isTerminating(), q->script_path, q->iface->get_name());
#endif

    if((q == NULL) || isTerminating()) {
      if(q) delete q;
      break;
    } else {
      char name[64], *slash = strrchr(q->script_path, '/');
      char *label = slash ? &slash[1] : q->script_path;

#ifdef TASK_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "(**) Started task [%s][%s]",
				   q->script_path, q->iface->get_name());
#endif
      if (q->iface->get_id() == -1)
        snprintf(name, sizeof(name), "ntopng-S-%s", label);
      else
        snprintf(name, sizeof(name), "ntopng-%d-%s", q->iface->get_id(), label);
      Utils::setThreadName(name);
      
      q->j->set_state_running(q->iface, q->script_path);
      q->j->runScript(time(NULL), q->script_path, q->iface, q->deadline);
      q->j->set_state_sleeping(q->iface, q->script_path);
#ifdef TASK_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "(**) Completed task [%s][%s]",
				   q->script_path, q->iface->get_name());
#endif

      delete q;
    }
  }

#ifdef THREAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Terminating thread [%u]", pthread_self());
#endif
}

/* ******************************************* */

bool ThreadPool::isQueueable(ThreadedActivityState cur_state) {
  switch(cur_state) {
  case threaded_activity_state_sleeping:
  case threaded_activity_state_unknown:
    return(true);
    break;
    
  default:
#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "ThreadedActivity::isQueueable(%s)", Utils::get_state_label(cur_state));
#endif       
    return(false);
    break;
  }

  return(false); /* NOTREACHED */
}

/* **************************************************** */

bool ThreadPool::queueJob(ThreadedActivity *ta, char *script_path,
			  NetworkInterface *iface,
			  time_t scheduled_time, time_t deadline) {
  QueuedThreadData *q;
  ThreadedActivityStats *stats;
  ThreadedActivityState ta_state;

  if(isTerminating())
    return(false);

  if((stats = ta->getThreadedActivityStats(iface, script_path, true)) == NULL)
    return(false);
  else
    ta_state = stats->getState();

  if(!isQueueable(ta_state)) {
    /* This task is already in queue */

#ifdef THREAD_DEBUG
    char deadline_buf[32];
    time_t stats_deadline = stats->getDeadline();
    struct tm deadline_tm;

    strftime(deadline_buf, sizeof(deadline_buf), "%H:%M:%S", localtime_r(&stats_deadline, &deadline_tm));
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to schedule %s [running: %u][deadlline: %s]",
				 script_path, ta_state == threaded_activity_state_running ? 1 : 0, deadline_buf);
#endif

    if(ta_state == threaded_activity_state_queued) {
      /*
	If here, the periodic activity has been waiting in queue for too long and no thread has dequeued it.
	Hence, we can try and spawn an additional thread, up to a maximum
      */
#ifdef THREAD_DEBUG
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Waiting in queue for too long [len: %u/%u][num_interfaces: %u]",
				   threadsState.size(),
				   CONST_MAX_NUM_THREADED_ACTIVITIES, ntop->get_num_interfaces() + 1);
#endif
      stats->setNotExecutedActivity(true);
    } else if(ta_state == threaded_activity_state_running && (stats->getDeadline() < scheduled_time))
      stats->setSlowPeriodicActivity(true);
      
    return(false); /* Task still running or already queued, don't re-queue it */
  }
  
  q = new (std::nothrow) QueuedThreadData(ta, script_path, iface, deadline);

  if(!q) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create job");
    return(false);
  }

  if((int)threads.size() > (num_threads-3)) {
#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Job queue: %u", threads.size());
#endif

    spawn(); /* Spawn a new thread if there are queued jobs */
  }

  m->lock(__FILE__, __LINE__);
  if(stats)
    stats->setScheduledTime(scheduled_time);

  ta->set_state_queued(iface, script_path);
  threads.push(q);

  pthread_cond_signal(&condvar);
  m->unlock(__FILE__, __LINE__);

  return(true); /*  TODO: add a max queue len and return false */
}

/* **************************************************** */

QueuedThreadData* ThreadPool::dequeueJob(bool waitIfEmpty) {
  QueuedThreadData *q;

  m->lock(__FILE__, __LINE__);
  if(waitIfEmpty) {
    while(threads.empty() && (!isTerminating()))
      m->cond_wait(&condvar);
  }

  if(threads.empty() || isTerminating()) {
    q = NULL;
  } else {
    q = threads.front();
    threads.pop();
  }

#ifdef THREAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeued job [remaining: %u][%s]",
			       threads.size(), q ? q->iface->get_name() : "");
#endif

  m->unlock(__FILE__, __LINE__);

  return(q);
}

/* **************************************************** */

void ThreadPool::shutdown() {
#ifdef THREAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** %s() ***", __FUNCTION__);
#endif

  m->lock(__FILE__, __LINE__);
  terminating = true;
  pthread_cond_broadcast(&condvar);
  m->unlock(__FILE__, __LINE__);
}

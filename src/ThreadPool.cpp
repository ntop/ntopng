/*
 *
 * (C) 2017-20 - ntop.org
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

/* **************************************************** */

static void* doRun(void* ptr)  {
  Utils::setThreadName("TrPoolWorker");

  ((ThreadPool*)ptr)->run();
  return(NULL);
}

/* **************************************************** */

ThreadPool::ThreadPool(bool _high_priority, u_int8_t _pool_size,
		       char *comma_separated_affinity_mask) {
  pool_size = _pool_size;
  m = new (std::nothrow) Mutex();
  pthread_cond_init(&condvar, NULL);
  terminating = false;
  high_priority = _high_priority; /* Not used yet */

#ifdef __linux__
  cpu_set_t mask, *mask_to_set;
  
  if(comma_separated_affinity_mask != NULL) {
    Utils::setAffinityMask(comma_separated_affinity_mask, &mask);
    mask_to_set = &mask;
  } else
    mask_to_set = ntop->getPrefs()->get_other_cpu_affinity_mask();
#endif
  
  if((threadsState = (pthread_t*)malloc(sizeof(pthread_t)*pool_size)) == NULL)
    throw("Not enough memory");
  
  for(int i=0; i<pool_size; i++) {
    if(pthread_create(&threadsState[i], NULL, doRun, (void*)this) == 0) {
#ifdef __linux__
      Utils::setThreadAffinityWithMask(threadsState[i], mask_to_set);
#endif
    }
  }
}

/* **************************************************** */

ThreadPool::~ThreadPool() {
  void *res;

  shutdown();
  
  for(int i=0; i<pool_size; i++) {
#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Threads still running %d", pool_size-i);
#endif
    pthread_join(threadsState[i], &res);    
  }
  free(threadsState);

  pthread_cond_destroy(&condvar);
  delete m;
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
      Utils::setThreadName(q->script_path);
      q->j->set_state_running(q->iface);
      q->j->runScript(time(NULL), q->script_path, q->iface, q->deadline);
      q->j->set_state_sleeping(q->iface);
      delete q;
    }
  }

#ifdef THREAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Terminating thread [%u]", pthread_self());
#endif
}

/* **************************************************** */

bool ThreadPool::queueJob(ThreadedActivity *ta, char *path, NetworkInterface *iface, time_t scheduled_time, time_t deadline) {
  QueuedThreadData *q;
  ThreadedActivityStats *stats = ta->getThreadedActivityStats(iface, true);
  
  if(isTerminating())
    return(false);

  if(!ta->isQueueable(iface)) {
    ThreadedActivityState ta_state = ta->get_state(iface);

#ifdef THREAD_DEBUG
    char deadline_buf[32];
    time_t stats_deadline = stats->getDeadline();
    struct tm deadline_tm;

    strftime(deadline_buf, sizeof(deadline_buf), "%H:%M:%S", localtime_r(&stats_deadline, &deadline_tm));
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to schedule %s [running: %u][deadlline: %s]", path, ta_state == threaded_activity_state_running ? 1 : 0, deadline_buf);
#endif

    if(stats) {
      if(ta_state == threaded_activity_state_queued)
        stats->setNotExecutedAttivity(true);
      else if(ta_state == threaded_activity_state_running
	      && stats->getDeadline() < scheduled_time)
        stats->setSlowPeriodicActivity(true);
    }

    return(false); /* Task still running or already queued, don't re-queue it */
  }

  q = new (std::nothrow) QueuedThreadData(ta, path, iface, deadline);

  if(!q) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create job");
    return(false);
  }

  m->lock(__FILE__, __LINE__);

  if(stats)
    stats->setScheduledTime(scheduled_time);

  ta->set_state_queued(iface);
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


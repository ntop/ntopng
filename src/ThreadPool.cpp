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

ThreadPool::ThreadPool(bool _adaptive_pool_size, u_int8_t _pool_size,
                       char *comma_separated_affinity_mask) {
  m = new (std::nothrow) Mutex();
  pthread_cond_init(&condvar, NULL);
  terminating = false;
  adaptive_pool_size = _adaptive_pool_size;

#ifdef __linux__
  CPU_ZERO(&affinity_mask);

  if(comma_separated_affinity_mask)
    Utils::setAffinityMask(comma_separated_affinity_mask, &affinity_mask);
  else if(ntop->getPrefs()->get_other_cpu_affinity())
    Utils::setAffinityMask(ntop->getPrefs()->get_other_cpu_affinity(), &affinity_mask);
#endif

  for(int i = 0; i < _pool_size; i++)
    spawn();
}

/* **************************************************** */

ThreadPool::~ThreadPool() {
  void *res;

  shutdown();

  for(vector<pthread_t>::const_iterator it = threadsState.begin(); it != threadsState.end(); ++it) {
#ifdef THREAD_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Threads still running %d", pool_size-i);
#endif
    pthread_join(*it, &res);
  }

  threadsState.clear();

  pthread_cond_destroy(&condvar);
  delete m;
}

/* **************************************************** */

void ThreadPool::spawn() {
  pthread_t new_thread;

  if(pthread_create(&new_thread, NULL, doRun, (void*)this) == 0) {
    threadsState.push_back(new_thread);

#ifdef __linux__
    Utils::setThreadAffinityWithMask(new_thread, &affinity_mask);
#endif
  }
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
      if(ta_state == threaded_activity_state_queued) {
	/*
	  If here, the periodic activity has been waiting in queue for too long and no thread has dequeued it.
	  Hence, we can try and spawn an additional thread, up to a maximum
	*/
#ifdef THREAD_DEBUG
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Waiting in queue for too long [%u][%u][%u]", threadsState.size(), MAX_THREAD_POOL_SIZE, ntop->get_num_interfaces() + 1);
#endif

	if(adaptive_pool_size
	   && threadsState.size() < MAX_THREAD_POOL_SIZE
	   && threadsState.size() < ntop->get_num_interfaces() + 1 /* System Interface */) {
	  spawn();

#ifdef THREAD_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "New thread spawned [%u]", threadsState.size());
#endif
	}

        stats->setNotExecutedAttivity(true);
      } else if(ta_state == threaded_activity_state_running
	      && stats->getDeadline() < scheduled_time)
        stats->setSlowPeriodicActivity(true);
    }

    return(false); /* Task still running or already queued, don't re-queue it */
  }

  q = new QueuedThreadData(ta, path, iface, deadline);

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


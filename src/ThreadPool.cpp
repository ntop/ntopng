/*
 *
 * (C) 2017-18 - ntop.org
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
#ifdef  __APPLE__
  // Mac OS X: must be set from within the thread (can't specify thread ID)
  char buf[32];
  snprintf(buf, sizeof(buf), "ThreadPool worker");
  if(pthread_setname_np(buf))
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set pthread name %s", buf);
#endif

  ((ThreadPool*)ptr)->run();
  return(NULL);
}

/* **************************************************** */

ThreadPool::ThreadPool(u_int8_t _pool_size) {
  pool_size = _pool_size, queue_len = 0;
  m = new Mutex();
  pthread_cond_init(&condvar, NULL);
  terminating = false;
  
  if((threadsState = (pthread_t*)malloc(sizeof(pthread_t)*pool_size)) == NULL)
    throw("Not enough memory");
  
  for(int i=0; i<pool_size; i++)
    pthread_create(&threadsState[i], NULL, doRun, (void*)this);
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
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Dequeued job [%u][terminating=%d]",
				 pthread_self(), isTerminating());
#endif
    
    if((q == NULL) || isTerminating()) {
      if(q) delete q;
      break;
    } else {
      (q->j)->runScript(q->script_path, q->iface);
      delete q;
    }
  }

#ifdef THREAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** Terminating thread [%u]", pthread_self());
#endif
}

/* **************************************************** */

bool ThreadPool::queueJob(ThreadedActivity *j, char *path, NetworkInterface *iface) {
  QueuedThreadData *q;
  
  if(isTerminating())
    return(false);

  q = new QueuedThreadData(j, path, iface);

  if(!q) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create job");
    return(false);
  }

  m->lock(__FILE__, __LINE__);  
  threads.push(q);
  queue_len++;
  pthread_cond_signal(&condvar);
  m->unlock(__FILE__, __LINE__);

  return(true); /*  TODO: add a max queue len and return false */
}

/* **************************************************** */

QueuedThreadData* ThreadPool::dequeueJob(bool waitIfEmpty) {
  QueuedThreadData *q;

  m->lock(__FILE__, __LINE__);
  if(waitIfEmpty) {
    while((queue_len == 0) && (!isTerminating()))
      m->cond_wait(&condvar);
  }
  
  if((queue_len == 0) || isTerminating()) {
    q = NULL;
  } else {
    q = threads.front();
    threads.pop();
    queue_len--;
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


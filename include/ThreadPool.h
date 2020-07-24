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

#ifndef _THREAD_POOL_H_
#define _THREAD_POOL_H_

#include "ntop_includes.h"

class QueuedThreadData {
 public:
  ThreadedActivity *j;
  char *script_path;
  NetworkInterface *iface;
  bool high_priority;
  time_t deadline;
  
  QueuedThreadData(ThreadedActivity *_j, char *_path, NetworkInterface *_iface, time_t _deadline) {
    j = _j, script_path = strdup(_path), iface = _iface;
    deadline = _deadline;
  }

  ~QueuedThreadData() { if(script_path) free(script_path); }
};
	
class ThreadPool {
 private:
  bool terminating, high_priority;
  u_int8_t pool_size;
  pthread_cond_t condvar;
  Mutex *m;
  pthread_t *threadsState;
  std::queue <QueuedThreadData*> threads;

  QueuedThreadData* dequeueJob(bool waitIfEmpty);
  
 public:
  ThreadPool(bool _high_priority, u_int8_t _pool_size, char *comma_separated_affinity_mask = NULL);
  virtual ~ThreadPool();

  void shutdown();
  inline bool isTerminating() { return terminating; };

  void run();
  bool queueJob(ThreadedActivity *ta, char *path, NetworkInterface *iface, time_t scheduled_time, time_t deadline);
};


#endif /* _THREAD_POOL_H_ */

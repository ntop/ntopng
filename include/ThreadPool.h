/*
 *
 * (C) 2017 - ntop.org
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

class ThreadPool {
 private:
  u_int8_t pool_size;
  u_int16_t queue_len;
  ConditionalVariable *c;
  Mutex *m;
  std::queue <ThreadedActivity*> threads;

  bool queueJob(ThreadedActivity *j);
  ThreadedActivity* dequeueJob(bool waitIfEmpty);
  
 public:
  ThreadPool(u_int8_t _pool_size);
  ~ThreadPool();

  inline bool scheduleJob(ThreadedActivity *j) { return(queueJob(j)); }
}
;

#endif /* _THREAD_POOL_H_ */

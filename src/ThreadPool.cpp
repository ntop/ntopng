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

#include "ntop_includes.h"

/* **************************************************** */

ThreadPool::ThreadPool(u_int8_t _pool_size) {
  pool_size = _pool_size, queue_len = 0;
  m = new Mutex();
  c = new ConditionalVariable();
}

/* **************************************************** */

ThreadPool::~ThreadPool() {
  delete m;
  delete c;
}

/* **************************************************** */

bool ThreadPool::queueJob(ThreadedActivity *j) {
  m->lock(__FILE__, __LINE__);  
  threads.push(j);
  queue_len++;
  m->unlock(__FILE__, __LINE__);

  c->signal(false);
}

/* **************************************************** */

ThreadedActivity* ThreadPool::dequeueJob(bool waitIfEmpty) {
  ThreadedActivity *t;

  if(waitIfEmpty) {
    while(queue_len == 0)
      c->wait();
  }
  
  if(queue_len == 0) return(NULL);

  m->lock(__FILE__, __LINE__);
  t = threads.front();
  threads.pop();
  queue_len--;
  m->unlock(__FILE__, __LINE__);
  
  return(t);
}





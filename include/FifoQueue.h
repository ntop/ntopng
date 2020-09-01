/*
 *
 * (C) 2014-20 - ntop.org
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


#ifndef _FIFO_QUEUE_H
#define _FIFO_QUEUE_H

#include "ntop_includes.h"

template <typename T> class FifoQueue {
 protected:
  Mutex m;
  std::queue<T> q;
  u_int32_t max_size;
  u_int64_t num_enqueued, num_not_enqueued, num_dequeued;

 public:
  FifoQueue(u_int32_t queue_size) {
    max_size = queue_size;
    num_enqueued = num_not_enqueued = num_dequeued = 0;
  }
  virtual ~FifoQueue() { ; }
  
  /*
    Subclasses will implement it as sometimes the buffer
    needs to be duplicated as for strings
  */
  virtual bool enqueue(T item) = 0;
  
  T dequeue() {
    T rv;

    m.lock(__FILE__, __LINE__);

    if(q.empty())
      rv = static_cast<T>(NULL);
    else {
      rv = q.front();
      q.pop();
      num_dequeued++;
    }
    m.unlock(__FILE__, __LINE__);

    return(rv);
  }

  inline bool canEnqueue()      { return(getLength() < max_size); }
  inline u_int32_t getLength()  { return(q.size());               }
  inline bool empty()           { return(q.empty());              }
  inline void lua(lua_State* vm, const char * const table_name) {
    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "num_enqueued", num_enqueued);
    lua_push_uint64_table_entry(vm, "num_not_enqueued", num_not_enqueued);
    lua_push_uint64_table_entry(vm, "num_dequeued", num_enqueued);

    lua_pushstring(vm, table_name);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
};

#endif /* _FIFO_QUEUE_H */

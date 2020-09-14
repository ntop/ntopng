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

#ifndef _SPSC_QUEUE_H_
#define _SPSC_QUEUE_H_

#include "ntop_includes.h"

/* Lockless fixed-size Single-Producer Single-Consumer queue */

#define QUEUE_WATERMARK      8 /* pow of 2 */
#define QUEUE_WATERMARK_MASK (QUEUE_WATERMARK - 1)

template <typename T> class SPSCQueue {
 private:
  u_int64_t shadow_head;
  volatile u_int64_t head;
  volatile u_int64_t tail;
  u_int64_t shadow_tail;

  std::vector<T> queue;
  u_int32_t queue_size;

 public:
  SPSCQueue(u_int32_t size) {
    queue_size = Utils::pow2(size);
    queue.reserve(queue_size);
    tail = shadow_tail = queue_size-1;
    head = shadow_head = 0;
  }

  ~SPSCQueue() { ; }

  inline bool isNotEmpty() {
    u_int32_t next_tail = (shadow_tail + 1) & (queue_size-1);
    return next_tail != head;
  }

  inline bool isFull() {
    u_int32_t next_head = (shadow_head + 1) & (queue_size-1);
    return tail == next_head;
  }

  inline T dequeue() {
    u_int32_t next_tail;
    
    next_tail = (shadow_tail + 1) & (queue_size-1);
    if (next_tail != head) {
      T item = queue[next_tail];
      shadow_tail = next_tail;

      if ((shadow_tail & QUEUE_WATERMARK_MASK) == 0)
        tail = shadow_tail;

      return item;
    }

    return static_cast<T>(NULL);
  }

  inline bool enqueue(T item, bool flush) {
    u_int32_t next_head;

    next_head = (shadow_head + 1) & (queue_size-1);

    if (tail != next_head) {
      queue[shadow_head] = item;

      shadow_head = next_head;
      if (flush || (shadow_head & QUEUE_WATERMARK_MASK) == 0)
        head = shadow_head;

      return true;
    }

    return false;
  }

};

#endif /* _SPSC_QUEUE_H_ */

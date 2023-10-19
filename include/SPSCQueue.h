/*
 *
 * (C) 2014-23 - ntop.org
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

#define QUEUE_WATERMARK 8 /* pow of 2 */
#define QUEUE_WATERMARK_MASK (QUEUE_WATERMARK - 1)

template <typename T>
class SPSCQueue {
 private:
  char *name;
  u_int64_t num_failed_enqueues; /* Counts the number of times the enqueue has
                                    failed (queue full) */
  u_int64_t shadow_head;
  volatile u_int64_t head;
  volatile u_int64_t tail;
  u_int64_t shadow_tail;
  Condvar c;
  std::vector<T> queue;
  u_int32_t queue_size;

 public:
  /**
   * Constructor
   * @param size The queue size (rounded up to the next power of 2)
   */
  SPSCQueue(u_int32_t size, const char *_name) {
    queue_size = Utils::pow2(size);
    queue.resize(queue_size);
    tail = shadow_tail = queue_size - 1;
    head = shadow_head = 0;
    num_failed_enqueues = 0;
    name = strdup(_name ? _name : "");
  }

  /**
   * Destructor
   */
  ~SPSCQueue() {
    if (name) free(name);
  }

  /**
   * Return true if there is at least one item in the queue
   */
  inline bool isNotEmpty() {
    u_int32_t next_tail = (shadow_tail + 1) & (queue_size - 1);
    return next_tail != head;
  }

  /**
   * Return true if the queue is full
   */
  inline bool isFull() {
    u_int32_t next_head = (shadow_head + 1) & (queue_size - 1);
    return tail == next_head;
  }

  /**
   * Pop an item from the tail
   * Return the item (which is removed from the queue)
   * Note: isNotEmpty() should be called before. Similar to std lists,
   * if the container is not empty the function never throws exceptions.
   * Otherwise, it causes undefined behavior.
   */
  inline T dequeue() {
    u_int32_t next_tail;

    next_tail = (shadow_tail + 1) & (queue_size - 1);
    if (next_tail == head) throw "Empty queue";

    T item = queue[next_tail];
    shadow_tail = next_tail;

    if ((shadow_tail & QUEUE_WATERMARK_MASK) == 0) tail = shadow_tail;

    return item;
  }

  inline bool wait() { return ((c.wait() < 0) ? false : true); }

  /**
   * Push an item to the head
   * @param item The item to add to the queue
   * @param flush Immediately makes the item available to the consumer, a
   * watermark is used otherwise Return true on success, false if there is no
   * room
   */
  inline bool enqueue(T item, bool flush) {
    u_int32_t next_head;

    next_head = (shadow_head + 1) & (queue_size - 1);

    if (tail != next_head) {
      queue[shadow_head] = item;

      shadow_head = next_head;
      c.signal();

      if (flush || (shadow_head & QUEUE_WATERMARK_MASK) == 0)
        head = shadow_head;

      return true; /* success */
    }

    num_failed_enqueues++;
    return false; /* no room */
  }

  /**
   * Return the number of failed enqueue attempts
   */
  inline u_int64_t get_num_failed_enqueues() const {
    return num_failed_enqueues;
  };

  /**
   * Writes queue stats in a table of the vm passed as parameter
   */
  inline void lua(lua_State *vm) const {
    if (vm) {
      lua_newtable(vm);
      lua_push_uint64_table_entry(vm, "num_failed_enqueues",
                                  num_failed_enqueues);
      lua_pushstring(vm, name ? name : "");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  };
};

#endif /* _SPSC_QUEUE_H_ */

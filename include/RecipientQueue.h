/*
 *
 * (C) 2014-26 - ntop.org
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


#ifndef _RECIPIENT_QUEUES_
#define _RECIPIENT_QUEUES_

#include "ntop_includes.h"

/* The notifications queue of a recipient: the notifications are filtered
   before the enqueue (see Recipients::enqueue and NotificationPolicy) */
class RecipientQueue {
 private:
  u_int16_t recipient_id;

  AlertFifoQueue* queue;

  /* Counters for the number of enqueues */
  u_int64_t enqueued;

  /* Counters for the number of drops occurred when enqueuing */
  u_int64_t drops;

  /* Counters for the number of alerts filtered out (e.g. silenced) */
  u_int64_t filtered_out;

  /* Counters for the number of alerts delivered */
  u_int64_t delivered;

  /* Counters for the number of alerts not delivered due to an endpoint failure
   */
  u_int64_t delivery_failures;

  /* Timestamp of the last dequeue, regardless of queue priority */
  time_t last_use;

 public:
  RecipientQueue(u_int16_t recipient_id);
  ~RecipientQueue();

  /**
   * @brief Dequeues a notification from a `recipient_id` queue
   *
   * @return AlertFifoItem on success, NULL if queue is empty
   */
  AlertFifoItem* dequeue();

  /**
   * @brief Enqueues a notification to a `recipient_id` queue
   * @param notification A string containing the notification
   *
   * @return True if the enqueue succeeded, false otherwise
   */
  bool enqueue(const AlertFifoItem* const notification);

  /**
   * @brief Counts a notification delivered without enqueuing it (e.g. the
   * flow alerts of the builtin recipient, read from the flows on ClickHouse)
   */
  inline void countDelivered() {
    enqueued++;
    delivered++;
  };

  /**
   * @brief Returns queue status (drops and enqueued)
   * @param vm A Lua VM instance
   *
   * @return
   */
  void lua(lua_State* vm);

  /**
   * @brief Returns true if the recipient has no notifications enqueued
   *
   * @return A boolean
   */
  bool empty();

  /**
   * @brief Returns queue last use
   *
   * @return An epoch with the last use, or 0 if never used.
   */
  inline time_t get_last_use() const { return last_use; };

  /**
   * @brief Inc recipient stats (used by lua recipients)
   */
  inline void incStats(u_int64_t _delivered, u_int64_t _filtered_out,
                       u_int64_t _delivery_failures) {
    delivered += _delivered;
    filtered_out += _filtered_out;
    delivery_failures += _delivery_failures;
  }
};

#endif /* _RECIPIENT_QUEUES_ */

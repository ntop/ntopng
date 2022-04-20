/*
 *
 * (C) 2014-22 - ntop.org
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

class RecipientQueue {
 private:
  u_int16_t recipient_id;

  AlertFifoQueue *queue;

  /* Counters for the number of drops occurred when enqueuing */
  u_int64_t drops;

  /* Counters for the number of enqueues */
  time_t uses;

  /* Timestamp of the last dequeue, regardless of queue priority */
  time_t last_use;

  /* Minimum severity for notifications enqueued to this recipient */
  AlertLevel minimum_severity;

  /* Only enable enqueue/dequeue for notifications falling into these categories */
  Bitmap128 enabled_categories; /* MUST be large enough to contain MAX_NUM_SCRIPT_CATEGORIES */

  /* MUST be large enough to contain MAX_NUM_HOST_POOLS */
  Bitmap128 enabled_host_pools;

 public:
  RecipientQueue(u_int16_t recipient_id);
  ~RecipientQueue();

  /**
  * @brief Dequeues a notification from a `recipient_id` queue
  * @param notification The dequeued notification
  *
  * @return Boolean, true if the dequeue was successful and `notification` is populated correctly, false otherwise
  */
  bool dequeue(AlertFifoItem *notification);
  
  /**
  * @brief Enqueues a notification to a `recipient_id` queue
  * @param recipient_id An integer recipient identifier
  * @param notification A string containing the notification
  *
  * @return True if the enqueue succeeded, false otherwise
  */
  bool enqueue(const AlertFifoItem* const notification, AlertEntity alert_entity);
  
  /**
  * @brief Sets the minimum severity for notifications to use this recipient
  * @param minimum_severity The minimum severity for notifications to use this recipient
  *
  * @return
  */
  inline void setMinimumSeverity(AlertLevel _minimum_severity) { minimum_severity = _minimum_severity; };
  
  /**
  * @brief Sets enabled notification categories to use this recipient
  * @param enabled_categories A bitmap of notification categories to use this recipient
  *
  * @return
  */
  inline void setEnabledCategories(Bitmap128 _enabled_categories) { enabled_categories = _enabled_categories; };

  /**
  * @brief Sets enabled host pools to use this recipient
  * @param enabled_host_pools
  *
  * @return
  */
  inline void setEnabledHostPools(Bitmap128 _enabled_pools)       { enabled_host_pools = _enabled_pools; };
  
  /**
   * @brief Returns queue status (drops and uses)
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
};

#endif /* _RECIPIENT_QUEUES_ */

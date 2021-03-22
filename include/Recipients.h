/*
 *
 * (C) 2014-21 - ntop.org
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


#ifndef _RECIPIENTS_
#define _RECIPIENTS_

#include "ntop_includes.h"

class Recipients {
 private:
  /* Per-recipient queues */
  RecipientQueues* recipient_queues[MAX_NUM_RECIPIENTS];
  Mutex m;
 public:
  Recipients();
  ~Recipients();

  /**
  * @brief Dequeues a notification from a `recipient_id` queue, given a certain priority
  * @param recipient_id An integer recipient identifier
  * @param notification The dequeued notification
  *
  * @return Boolean, true if the dequeue was successful and `notification` is populated correctly, false otherwise
  */
  bool dequeue(u_int16_t recipient_id, RecipientNotificationPriority prio, AlertFifoItem *notification);
  /**
  * @brief Enqueues a notification to a `recipient_id` queue, depending on the priority
  * @param recipient_id An integer recipient identifier
  * @param prio The priority of the notification
  * @param notification The notification to be enqueued
  *
  * @return True if the enqueue succeeded, false otherwise
  */
  bool enqueue(u_int16_t recipient_id, RecipientNotificationPriority prio, const AlertFifoItem* const notification);
  /**
  * @brief Enqueues a notification to all available recipients
  * @param prio The priority of the notification
  * @param notification The notification to be enqueued
  * @param flow_only A boolean, indicating whether the notification has only to be enqueued for flow recipients
  *
  * @return True if the enqueue succeeded, false otherwise
  */
  bool enqueue(RecipientNotificationPriority prio, const AlertFifoItem* const notification, bool flow_only);
  /**
  * @brief Registers a recipient identified with `recipient_id` so its notification can be enqueued/dequeued
  * @param recipient_id An integer recipient identifier
  * @param minimum_severity The minimum severity for notifications to use this recipient
  * @param enabled_categories A bitmap of notification categories to use this recipient
  *
  * @return
  */
  void register_recipient(u_int16_t recipient_id, AlertLevel minimum_severity, u_int8_t enabled_categories);
  /**
  * @brief Sets all recipients responsible for flow alerts
  * @param flow_recipients A bitmap of recipient ids responsible for flows
  *
  * @return
  */
  void set_flow_recipients(u_int64_t flow_recipients);
  /**
  * @brief Marks a recipient as deleted
  * @param recipient_id An integer recipient identifier
  *
  * @return
  */
  void delete_recipient(u_int16_t recipient_id);
  /**
   * @brief Returns status (drops and uses) of a given recipient
   * @param recipient_id An integer recipient identifier
   * @param vm A Lua VM instance
   *
   * @return
   */
  void lua(u_int16_t recipient_id, lua_State* vm);
  /**
   * @brief Returns the last use (i.e., successful dequeue) of a given recipient
   * @param recipient_id An integer recipient identifier
   *
   * @return An epoch with the last use, or 0 if never used.
   */
  time_t last_use(u_int16_t recipient_id);
};

#endif /* _RECIPIENTS_ */

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
  * @param prio The priority of the notification
  *
  * @return A pointer to a notification string, or NULL if there was no notification in the queue. The pointer MUST be `free`d after use
  */
  char *dequeue(u_int16_t recipient_id, RecipientNotificationPriority prio);
  /**
  * @brief Enqueues a notification to a `recipient_id` queue, depending on the priority
  * @param recipient_id An integer recipient identifier
  * @param prio The priority of the notification
  * @param notification A string containing the notification
  *
  * @return True if the enqueue succeeded, false otherwise
  */
  bool enqueue(u_int16_t recipient_id, RecipientNotificationPriority prio, const char * const notification);
  /**
  * @brief Registers a recipient identified with `recipient_id` so its notification can be enqueued/dequeued
  * @param recipient_id An integer recipient identifier
  *
  * @return
  */
  void register_recipient(u_int16_t recipient_id);
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
};

#endif /* _RECIPIENTS_ */

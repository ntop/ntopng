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


#ifndef _RECIPIENT_QUEUES_
#define _RECIPIENT_QUEUES_

#include "ntop_includes.h"

class RecipientQueues {
 private:
  AlertFifoQueue *queues_by_prio[RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES];
  /* Counters for the number of drops occurred when enqueuing */
  u_int64_t drops_by_prio[RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES];
  /* Counters for the number of enqueues */
  time_t uses_by_prio[RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES];
  /* Timestamp of the last dequeue, regardless of queue priority */
  time_t last_use;

  /* Minimum severity for notifications enqueued to this recipient */
  AlertLevel minimum_severity;
  /* Only enable enqueue/dequeue for notifications falling into these categories */
  u_int8_t enabled_categories; /* MUST be large enough to contain MAX_NUM_SCRIPT_CATEGORIES */
  /* Booleans indicating whether this is a flow/host recipient */
  bool flow_recipient, host_recipient;

 public:
  RecipientQueues();
  ~RecipientQueues();

  /**
  * @brief Dequeues a notification from a `recipient_id` queue, given a certain priority
  * @param prio The priority of the notification
  * @param notification The dequeued notification
  *
  * @return Boolean, true if the dequeue was successful and `notification` is populated correctly, false otherwise
  */
  bool dequeue(RecipientNotificationPriority prio, AlertFifoItem *notification);
  /**
  * @brief Enqueues a notification to a `recipient_id` queue, depending on the priority
  * @param recipient_id An integer recipient identifier
  * @param prio The priority of the notification
  * @param notification A string containing the notification
  *
  * @return True if the enqueue succeeded, false otherwise
  */
  bool enqueue(RecipientNotificationPriority prio, const AlertFifoItem* const notification);
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
  inline void setEnabledCategories(u_int8_t _enabled_categories) { enabled_categories = _enabled_categories; };
  /**
  * @brief Marks/unmarks this recipient as a flow recipient, depending on the input boolean
  *
  * @return
  */
  inline void setFlowRecipient(u_int8_t _enabled) { flow_recipient = _enabled; };
  /**
  * @brief Marks/unmarks this recipient as a host recipient, depending on the input boolean
  *
  * @return
  */
  inline void setHostRecipient(u_int8_t _enabled) { host_recipient = _enabled; };
  /**
   * @brief Returns queue status (drops and uses)
   * @param vm A Lua VM instance
   *
   * @return
   */
  void lua(lua_State* vm);
  /**
   * @brief Returns queue last use
   *
   * @return An epoch with the last use, or 0 if never used.
   */
  inline time_t get_last_use() const { return last_use; };
  /**
   * @brief Returns true if the recipient is a flow recipient
   *
   * @return A boolean
   */
  inline bool isFlowRecipient() const { return flow_recipient; };
  /**
   * @brief Returns true if the recipient is a host recipient
   *
   * @return A boolean
   */
  inline bool isHostRecipient() const { return host_recipient; };
};

#endif /* _RECIPIENT_QUEUES_ */

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

#ifndef _RECIPIENTS_
#define _RECIPIENTS_

#include "ntop_includes.h"

class Recipients {
 private:
  /* Per-recipient queues */
  RecipientQueue* recipient_queues[MAX_NUM_RECIPIENTS];
  /* Ids of the registered recipients, to iterate only them (see empty()) */
  Bitmap64 registered_recipients; /* MUST be large enough to contain
                                     MAX_NUM_RECIPIENTS */
  /* Notifications dequeued (e.g. by the Lua endpoints, see dequeue()) and
     possibly still being processed, until the next pass of the notifications
     (see last_use()) */
  bool dequeued[MAX_NUM_RECIPIENTS];
  /* Notification policies, routing the alerts to the recipients */
  NotificationPolicy* policies[MAX_NUM_NOTIFICATION_POLICIES];
  /* Ids of the registered policies, to iterate only them (see enqueue()) */
  Bitmap128 registered_policies; /* MUST be large enough to contain
                                    MAX_NUM_NOTIFICATION_POLICIES */
  Mutex m;

  AlertLevel default_recipient_minimum_severity;

 public:
  Recipients();
  ~Recipients();

  /**
   * @brief Dequeues a notification from a `recipient_id` queue, given a certain
   * priority
   * @param recipient_id An integer recipient identifier
   *
   * @return AlertFifoItem on success, NULL on empty queue
   */
  AlertFifoItem* dequeue(u_int16_t recipient_id);

  /**
   * @brief Enqueues a notification to a `recipient_id` queue, depending on the
   * priority
   * @param recipient_id An integer recipient identifier
   * @param prio The priority of the notification
   * @param notification The notification to be enqueued
   *
   * @return True if the enqueue succeeded, false otherwise
   */
  bool enqueue(u_int16_t recipient_id, const AlertFifoItem* const notification);

  /**
   * @brief Enqueues a notification to the builtin recipient (alerts store,
   * minimum severity only) and to the recipients of the matching policies
   * (once per recipient)
   * @param notification The notification to be enqueued
   *
   * @return True if the enqueue succeeded, false otherwise
   */
  bool enqueue(const AlertFifoItem* const notification);

  /**
   * @brief Registers a recipient identified with `recipient_id` so its
   * notification can be enqueued/dequeued
   * @param recipient_id An integer recipient identifier
   * @param minimum_severity The minimum severity of the alerts stored by the
   * builtin recipient (recipient_id 0), ignored by the other recipients
   *
   * @return
   */
  void register_recipient(u_int16_t recipient_id, AlertLevel minimum_severity);

  /**
   * @brief Registers (or replaces) a notification policy
   * @param policy_id An integer policy identifier
   * @param policy The policy (owned by this class from now on)
   *
   * @return
   */
  void register_policy(u_int16_t policy_id, NotificationPolicy* policy);

  /**
   * @brief Deletes a notification policy
   * @param policy_id An integer policy identifier
   *
   * @return
   */
  void delete_policy(u_int16_t policy_id);

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
   * NOTE: called only by the processing of the notifications
   * (process_notifications() in recipients.lua), at the beginning of each pass
   * over the recipients: the notifications dequeued in the previous pass have
   * been processed (see empty())
   * @param recipient_id An integer recipient identifier
   *
   * @return An epoch with the last use, or 0 if never used.
   */
  time_t last_use(u_int16_t recipient_id);

  /**
   * @brief Inc recipient stats (used by Lua recipients)
   * @param recipient_id An integer recipient identifier
   */
  void incStats(u_int16_t recipient_id, u_int64_t delivered,
                u_int64_t filtered_out, u_int64_t delivery_failures);

  /**
   * @brief Checks whether there are notifications queued in any of the
   * recipients
   *
   * @return true if there are not notifications enqueued, false otherwise
   */
  bool empty();

  AlertLevel get_default_recipient_minimum_severity() {
    return default_recipient_minimum_severity;
  };
};

#endif /* _RECIPIENTS_ */

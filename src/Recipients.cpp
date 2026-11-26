/*
 *
 * (C) 2013-26 - ntop.org
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

/* *************************************** */

Recipients::Recipients() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  memset(&recipient_queues, 0, sizeof(recipient_queues));
  memset(&dequeued, 0, sizeof(dequeued));
  memset(&policies, 0, sizeof(policies));
  default_recipient_minimum_severity = alert_level_none;
}

/* *************************************** */

Recipients::~Recipients() {
  for (int i = 0; i < MAX_NUM_RECIPIENTS; i++) {
    if (recipient_queues[i]) delete recipient_queues[i];
  }

  for (int i = 0; i < MAX_NUM_NOTIFICATION_POLICIES; i++) {
    if (policies[i]) delete policies[i];
  }
}

/* *************************************** */

AlertFifoItem* Recipients::dequeue(u_int16_t recipient_id) {
  AlertFifoItem* notification = NULL;

  if (recipient_id >= MAX_NUM_RECIPIENTS) return NULL;

  m.lock(__FILE__, __LINE__);

  if (recipient_queues[recipient_id]) {
    /*
      Dequeue the notification
    */
    notification = recipient_queues[recipient_id]->dequeue();

    /* Possibly being processed until the next pass (see last_use()) */
    if (notification) dequeued[recipient_id] = true;
  }

  m.unlock(__FILE__, __LINE__);

  return notification;
}

/* *************************************** */

bool Recipients::enqueue(u_int16_t recipient_id,
                         const AlertFifoItem* const notification) {
  bool res = false;

  if (recipient_id >= MAX_NUM_RECIPIENTS || !notification) return false;

  m.lock(__FILE__, __LINE__);

  /*
     Perform the actual enqueue
   */
  if (recipient_queues[recipient_id]) {
    res = recipient_queues[recipient_id]->enqueue(notification);
  }

  m.unlock(__FILE__, __LINE__);

  if (res) {
    /* The recipient makes a copy of this as there can be many
     * delete on success (the caller will delete it on failure) */
    delete notification;
  }

  return res;
}

/* *************************************** */

bool Recipients::enqueue(const AlertFifoItem* const notification) {
  bool res = true; /* Initialized to true so that if no recipient is responsible
                      for the notification, true will be returned. */
  Bitmap64 targets;

  if (!notification) return false;

  m.lock(__FILE__, __LINE__);

  /* Builtin recipient (alerts store) */
  if (recipient_queues[0] &&
      notification->alert_severity >= default_recipient_minimum_severity) {
    if ((notification->alert_entity == alert_entity_flow) &&
        ntop->getPrefs()->do_dump_flows_on_clickhouse()) {
      /*
        Do not store flow alerts on ClickHouse as they are retrieved using a
        view on historical flows (i.e. flow alerts are not stored but read from
        flows) But still increment the number of uses.
        On Enterprise XXL+, with the issues enabled, they feed the issue manager
        through its own queue (not this one, kept for the alerts to be stored)
      */
#ifdef NTOPNG_PRO
      if (ntop->getPro()->is_enterprise_xxl_edition() &&
          ntop->getPrefs()->are_issues_enabled())
        ntop->getIssueManager()->enqueueFlowAlert(notification->alert);
#endif

      recipient_queues[0]->countDelivered();
    } else
      res &= recipient_queues[0]->enqueue(notification);
  }

  /* Recipients of the matching policies, once per recipient: only the set
     bits are visited */
  for (int policy_id = registered_policies.getNext(0); policy_id >= 0;
       policy_id = registered_policies.getNext(policy_id + 1)) {
    if (policies[policy_id]->match(notification))
      targets.bitmapOr(policies[policy_id]->getRecipients());
  }

  /* A full queue of one of these recipients is a drop of that recipient only
     (counted by its RecipientQueue): the alert is dropped (res) only when the
     builtin recipient, the alerts store, misses it */
  for (int recipient_id = targets.getNext(1); recipient_id >= 0;
       recipient_id = targets.getNext(recipient_id + 1)) {
    if (recipient_queues[recipient_id])
      recipient_queues[recipient_id]->enqueue(notification);
  }

  m.unlock(__FILE__, __LINE__);

  if (res) {
    /* The recipient makes a copy of this as there can be many,
     * delete on success (the caller will delete it on failure) */
    delete notification;
  }

  return res;
}

/* *************************************** */

void Recipients::register_recipient(u_int16_t recipient_id,
                                    AlertLevel minimum_severity) {
  if (recipient_id >= MAX_NUM_RECIPIENTS) return;

  m.lock(__FILE__, __LINE__);

  if (!recipient_queues[recipient_id]) {
    recipient_queues[recipient_id] = new (nothrow) RecipientQueue(recipient_id);
    if (recipient_queues[recipient_id])
      registered_recipients.setBit(recipient_id);
  }

  if (recipient_id == 0) /* Builtin recipient (DB) */
    default_recipient_minimum_severity = minimum_severity;

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Recipients::register_policy(u_int16_t policy_id,
                                 NotificationPolicy* policy) {
  if (policy_id >= MAX_NUM_NOTIFICATION_POLICIES) {
    delete policy;
    return;
  }

  m.lock(__FILE__, __LINE__);

  if (policies[policy_id]) delete policies[policy_id];
  policies[policy_id] = policy;

  if (policy)
    registered_policies.setBit(policy_id);
  else
    registered_policies.clearBit(policy_id);

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Recipients::delete_policy(u_int16_t policy_id) {
  if (policy_id >= MAX_NUM_NOTIFICATION_POLICIES) return;

  m.lock(__FILE__, __LINE__);

  if (policies[policy_id]) {
    delete policies[policy_id];
    policies[policy_id] = NULL;
    registered_policies.clearBit(policy_id);
  }

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Recipients::delete_recipient(u_int16_t recipient_id) {
  if (recipient_id >= MAX_NUM_RECIPIENTS) return;

  m.lock(__FILE__, __LINE__);

  if (recipient_queues[recipient_id]) {
    delete recipient_queues[recipient_id];
    recipient_queues[recipient_id] = NULL;
    registered_recipients.clearBit(recipient_id);
  }

  /* Its dequeued notifications are not processed anymore */
  dequeued[recipient_id] = false;

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Recipients::lua(u_int16_t recipient_id, lua_State* vm) {
  if (recipient_id >= MAX_NUM_RECIPIENTS) return;

  m.lock(__FILE__, __LINE__);

  if (recipient_queues[recipient_id]) recipient_queues[recipient_id]->lua(vm);

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

time_t Recipients::last_use(u_int16_t recipient_id) {
  time_t res = 0;

  if (recipient_id >= MAX_NUM_RECIPIENTS) return 0;

  m.lock(__FILE__, __LINE__);

  /* Beginning of a new pass of the notifications: the notifications dequeued
     in the previous pass have been processed */
  dequeued[recipient_id] = false;

  if (recipient_queues[recipient_id])
    res = recipient_queues[recipient_id]->get_last_use();

  m.unlock(__FILE__, __LINE__);

  return res;
}

/* *************************************** */

void Recipients::incStats(u_int16_t recipient_id, u_int64_t delivered,
                          u_int64_t filtered_out, u_int64_t delivery_failures) {
  if (recipient_id >= MAX_NUM_RECIPIENTS) return;

  m.lock(__FILE__, __LINE__);

  if (recipient_queues[recipient_id])
    recipient_queues[recipient_id]->incStats(delivered, filtered_out,
                                             delivery_failures);

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

bool Recipients::empty() {
  bool res = true;

  m.lock(__FILE__, __LINE__);

  /* Registered recipients only (dequeue() sets dequeued[] only for them) */
  for (int recipient_id = registered_recipients.getNext(0); recipient_id >= 0;
       recipient_id = registered_recipients.getNext(recipient_id + 1)) {
    /* Not empty also while dequeued notifications are being processed */
    if (dequeued[recipient_id] || !recipient_queues[recipient_id]->empty()) {
      res = false;
      break;
    }
  }

  m.unlock(__FILE__, __LINE__);

  return res;
}

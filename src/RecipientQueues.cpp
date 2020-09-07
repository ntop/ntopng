/*
 *
 * (C) 2013-20 - ntop.org
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

RecipientQueues::RecipientQueues() {
  /*
    Two queues, one high- and one low-priority
   */
  queue_prio_low = queue_prio_high = NULL;
}

/* *************************************** */

RecipientQueues::~RecipientQueues() {
  if(queue_prio_low)  delete queue_prio_low;
  if(queue_prio_high) delete queue_prio_high;
}

/* *************************************** */

char* RecipientQueues::dequeue(RecipientNotificationPriority prio) {
  FifoStringsQueue **cur_queue = (prio == recipient_notification_priority_high) ? &queue_prio_high : &queue_prio_low;

  if(*cur_queue)
    return (*cur_queue)->dequeue();

  return NULL;
}

/* *************************************** */

bool RecipientQueues::enqueue(RecipientNotificationPriority prio, const char * const notification) {
  FifoStringsQueue **cur_queue = (prio == recipient_notification_priority_high) ? &queue_prio_high : &queue_prio_low;

  /*
    Lazily allocate the queue and then enqueue the notification
   */
  if(*cur_queue
     || (*cur_queue = new (nothrow) FifoStringsQueue(ALERTS_NOTIFICATIONS_QUEUE_SIZE)))
    return (*cur_queue)->enqueue((char*)notification);

  return false;
}

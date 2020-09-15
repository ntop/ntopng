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
  for(int i = 0; i < RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES; i++)
    queues_by_prio[i] = NULL;
}

/* *************************************** */

RecipientQueues::~RecipientQueues() {
  for(int i = 0; i < RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES; i++)
    delete queues_by_prio;
}

/* *************************************** */

char* RecipientQueues::dequeue(RecipientNotificationPriority prio) {
  if(prio >= RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES)
    return NULL;

  if(queues_by_prio[prio])
    return queues_by_prio[prio]->dequeue();

  return NULL;
}

/* *************************************** */

bool RecipientQueues::enqueue(RecipientNotificationPriority prio, const char * const notification) {
  if(prio >= RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES)
    return false;

  /*
    Lazily allocate the queue and then enqueue the notification
   */
  if(queues_by_prio[prio]
     || (queues_by_prio[prio] = new (nothrow) FifoStringsQueue(ALERTS_NOTIFICATIONS_QUEUE_SIZE)))
    return queues_by_prio[prio]->enqueue((char*)notification);

  return false;
}

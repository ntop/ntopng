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

Recipients::Recipients() {
  memset(&recipient_queues, 0, sizeof(recipient_queues));
}

/* *************************************** */

Recipients::~Recipients() {
  for(int i = 0; i < MAX_NUM_RECIPIENTS; i++) {
    if(recipient_queues[i])
      delete recipient_queues[i];
  }
}

/* *************************************** */

char* Recipients::dequeue(u_int16_t recipient_id, RecipientNotificationPriority prio) {
  if(recipient_id >= MAX_NUM_RECIPIENTS
     || !recipient_queues[recipient_id])
    return NULL;

  /*
    Dequeue the notification for a given priority
   */
  return recipient_queues[recipient_id]->dequeue(prio);
}

/* *************************************** */

bool Recipients::enqueue(u_int16_t recipient_id, RecipientNotificationPriority prio, const char * const notification) {
  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return false;

  /* 
     Lazy allocation - allocate a recipient if it hasn't already been allocated
     and then perform the actual enqueue
   */
  if(recipient_queues[recipient_id]
     || (recipient_queues[recipient_id] = new (nothrow) RecipientQueues())) {
    return recipient_queues[recipient_id]->enqueue(prio, notification);
  }

  return false;
}

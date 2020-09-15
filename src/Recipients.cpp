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
  char * res = NULL;

  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return NULL;

  m.lock(__FILE__, __LINE__);

  if(recipient_queues[recipient_id]) {
    /*
      Dequeue the notification for a given priority
    */
    res = recipient_queues[recipient_id]->dequeue(prio);
  }

  m.unlock(__FILE__, __LINE__);

  return res;
}

/* *************************************** */

bool Recipients::enqueue(u_int16_t recipient_id, RecipientNotificationPriority prio, const char * const notification) {
  bool res = false;

  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return false;

  m.lock(__FILE__, __LINE__);

  /* 
     Perform the actual enqueue for the given priority
   */
  if(recipient_queues[recipient_id])
    res = recipient_queues[recipient_id]->enqueue(prio, notification);

  m.unlock(__FILE__, __LINE__);

  return res;
}

/* *************************************** */

void Recipients::register_recipient(u_int16_t recipient_id) {  
  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return;

  m.lock(__FILE__, __LINE__);

  if(!recipient_queues[recipient_id])
    recipient_queues[recipient_id] = new (nothrow) RecipientQueues();

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Recipients::delete_recipient(u_int16_t recipient_id) {
  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return;

  m.lock(__FILE__, __LINE__);

  if(recipient_queues[recipient_id]) {
    delete recipient_queues[recipient_id];
    recipient_queues[recipient_id] = NULL;
  }

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Recipients::lua(u_int16_t recipient_id, lua_State* vm) {
  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return;

  m.lock(__FILE__, __LINE__);

  if(recipient_queues[recipient_id])
    recipient_queues[recipient_id]->lua(vm);

  m.unlock(__FILE__, __LINE__);
}

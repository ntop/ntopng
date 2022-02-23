/*
 *
 * (C) 2013-22 - ntop.org
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

bool Recipients::dequeue(u_int16_t recipient_id, AlertFifoItem *notification) {
  bool res = false;

  if(recipient_id >= MAX_NUM_RECIPIENTS
     || !notification)
    return false;

  m.lock(__FILE__, __LINE__);

  if(recipient_queues[recipient_id]) {
    /*
      Dequeue the notification
    */
    res = recipient_queues[recipient_id]->dequeue(notification);
  }

  m.unlock(__FILE__, __LINE__);

  return res;
}

/* *************************************** */

bool Recipients::enqueue(u_int16_t recipient_id, const AlertFifoItem* const notification) {
  bool res = false;

  if(recipient_id >= MAX_NUM_RECIPIENTS
     || !notification)
    return false;

  m.lock(__FILE__, __LINE__);

  /* 
     Perform the actual enqueue
   */
  if(recipient_queues[recipient_id])
    res = recipient_queues[recipient_id]->enqueue(notification, alert_entity_other /* TODO */);

  m.unlock(__FILE__, __LINE__);

  return res;
}

/* *************************************** */

bool Recipients::enqueue(const AlertFifoItem* const notification, AlertEntity alert_entity) {
  bool res = true; /* Initialized to true so that if no recipient is responsible for the notification, true will be returned. */

  if(!notification)
    return false;

  m.lock(__FILE__, __LINE__);

  /* 
     Perform the actual enqueue to all available recipients
   */
  for(int recipient_id = 0; recipient_id < MAX_NUM_RECIPIENTS; recipient_id++) {
    if(recipient_queues[recipient_id]) {
      bool success;

      success = recipient_queues[recipient_id]->enqueue(notification, alert_entity);
      
      res &= success;
    }
  }

  m.unlock(__FILE__, __LINE__);

  return res;
}

/* *************************************** */

void Recipients::register_recipient(u_int16_t recipient_id, AlertLevel minimum_severity, 
                                    Bitmap128 enabled_categories, Bitmap128 enabled_host_pools, Bitmap128 enabled_interface_pools) {
  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return;

  m.lock(__FILE__, __LINE__);

  if(!recipient_queues[recipient_id])
    recipient_queues[recipient_id] = new (nothrow) RecipientQueues();

  if(recipient_queues[recipient_id]) {
    recipient_queues[recipient_id]->setMinimumSeverity(minimum_severity);
    recipient_queues[recipient_id]->setEnabledCategories(enabled_categories);
    recipient_queues[recipient_id]->setEnabledHostPools(enabled_host_pools);
    recipient_queues[recipient_id]->setEnabledInterfacePools(enabled_interface_pools);
  }

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "registered [%u][%u][%u]", recipient_id, minimum_severity, enabled_categories);

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

/* *************************************** */

time_t Recipients::last_use(u_int16_t recipient_id) {
  time_t res = 0;

  if(recipient_id >= MAX_NUM_RECIPIENTS)
    return 0;

  m.lock(__FILE__, __LINE__);

  if(recipient_queues[recipient_id])
    res = recipient_queues[recipient_id]->get_last_use();

  m.unlock(__FILE__, __LINE__);

  return res;
}

/* *************************************** */

bool Recipients::empty() {
  bool res = true;

  m.lock(__FILE__, __LINE__);

  for(int recipient_id = 0; recipient_id < MAX_NUM_RECIPIENTS; recipient_id++) {
    if(recipient_queues[recipient_id]) {
      if(!recipient_queues[recipient_id]->empty()) {
	res = false;
	break;
      }
    }
  }

  m.unlock(__FILE__, __LINE__);

  return res;
}

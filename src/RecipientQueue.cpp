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

RecipientQueue::RecipientQueue(u_int16_t _recipient_id) {
  recipient_id = _recipient_id;
  queue = NULL, drops = 0, uses = 0;
  last_use = 0;

  /* No minimum severity */
  minimum_severity = alert_level_none;

  /* All categories enabled by default */
  for (int i=0; i < MAX_NUM_SCRIPT_CATEGORIES; i++)
    enabled_categories.setBit(i);
}

/* *************************************** */

RecipientQueue::~RecipientQueue() {
  if(queue)
    delete queue;
}

/* *************************************** */

bool RecipientQueue::dequeue(AlertFifoItem *notification) {
  if(!queue || !notification)
    return false;

  *notification = queue->dequeue();

  if(notification->alert) {
    last_use = time(NULL);
    return true;
  }

  return false;
}

/* *************************************** */

bool RecipientQueue::enqueue(const AlertFifoItem* const notification, AlertEntity alert_entity) {
  bool res = false;

  if(!notification
     || !notification->alert
     || notification->alert_severity < minimum_severity              /* Severity too low for this recipient     */
     || !(enabled_categories.isSetBit(notification->alert_category))  /* Category not enabled for this recipient */
     )
    return true; /* Nothing to enqueue */

  if(recipient_id == 0) {
    /* Default recipient (SQLite / ClickHouse DB) - do not filter alerts by host */
    if(alert_entity == alert_entity_flow &&
        ntop->getPrefs()->useClickHouse()) {
      return true; /* Do not store flow alert - a view on historical flows is used */
    }
  } else { 
    /* Other recipients (notifications) */
    if(alert_entity == alert_entity_flow) {
      if(!enabled_host_pools.isSetBit(notification->pools.flow.cli_host_pool) &&
          !enabled_host_pools.isSetBit(notification->pools.flow.srv_host_pool))
        return true;
    } else if(alert_entity == alert_entity_host) {
      if(!enabled_host_pools.isSetBit(notification->pools.host.host_pool))
        return true;
    }
  }

  if((!queue &&
       !(queue = new (nothrow) AlertFifoQueue(ALERTS_NOTIFICATIONS_QUEUE_SIZE)))) {
    /* Queue not available */
    drops++;
    return false; /* Enqueue failed */
  }

  /* Enqueue the notification (allocate memory for the alert string) */
  AlertFifoItem q = *notification;
  if((q.alert = strdup(notification->alert)))
    res = queue->enqueue(q);

  if(!res) {
    drops++;
    if(q.alert) free(q.alert);
  } else
    uses++;

  return res;
}

/* *************************************** */

void RecipientQueue::lua(lua_State* vm) {
  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "last_use", last_use);
  lua_push_uint64_table_entry(vm, "num_drops", drops);
  lua_push_uint64_table_entry(vm, "num_uses", uses);
  lua_push_uint64_table_entry(vm, "fill_pct", queue ? queue->fillPct() : 0);
}

/* *************************************** */

bool RecipientQueue::empty() {
  bool res = true;

  if(queue) {
    if(!queue->empty()) {
      res = false;
    }  
  }

  return res;
}

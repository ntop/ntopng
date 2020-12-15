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
    queues_by_prio[i] = NULL,
      drops_by_prio[i] = 0,
      uses_by_prio[i] = 0,
      last_use = 0;
}

/* *************************************** */

RecipientQueues::~RecipientQueues() {
  for(int i = 0; i < RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES; i++)
    delete queues_by_prio[i];
}

/* *************************************** */

char* RecipientQueues::dequeue(RecipientNotificationPriority prio) {
  AlertFifoItem res;

  if(prio >= RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES || 
     !queues_by_prio[prio])
    return NULL;

  res = queues_by_prio[prio]->dequeue();

  if(res.alert)
    last_use = time(NULL);

  /* TODO return severity level */

  return res.alert;
}

/* *************************************** */

bool RecipientQueues::enqueue(RecipientNotificationPriority prio, const char * const notification) {
  bool res = false;
  AlertFifoItem item;

  if(prio >= RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES ||
     (!queues_by_prio[prio] && 
      !(queues_by_prio[prio] = new (nothrow) AlertFifoQueue(ALERTS_NOTIFICATIONS_QUEUE_SIZE)))) {
    /* Queue not available */
    drops_by_prio[prio]++;
    return false;
  }

  /* Qnqueue the notification */

  item.level = alert_level_none; /* TODO set severity level */
  item.alert = strdup(notification);

  if(item.alert) {

    res = queues_by_prio[prio]->enqueue(item);

    if (!res)
      free(item.alert);
  }

  if(!res)
    drops_by_prio[prio]++;
  else
    uses_by_prio[prio]++;

  return res;
}

/* *************************************** */

void RecipientQueues::lua(lua_State* vm) {
  u_int64_t num_drops = 0, num_uses = 0;
  u_int8_t fill_pct = 0; /* Maximum fill pct among all queues */
  for(int i = 0; i < RECIPIENT_NOTIFICATION_MAX_NUM_PRIORITIES; i++) {
    num_drops +=  drops_by_prio[i],
      num_uses += uses_by_prio[i];
    if(queues_by_prio[i] && queues_by_prio[i]->fillPct() > fill_pct)
      fill_pct = queues_by_prio[i]->fillPct();
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "last_use", last_use);
  lua_push_uint64_table_entry(vm, "num_drops", num_drops);
  lua_push_uint64_table_entry(vm, "num_uses", num_uses);
  lua_push_uint64_table_entry(vm, "fill_pct", fill_pct);
}

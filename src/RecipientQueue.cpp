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

// #define DEBUG_RECIPIENT_QUEUE

/* *************************************** */

RecipientQueue::RecipientQueue(u_int16_t _recipient_id) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  recipient_id = _recipient_id;
  queue = NULL;
  drops = 0, enqueued = 0;
  delivered = 0, delivery_failures = 0, filtered_out = 0;
  last_use = 0;
}

/* *************************************** */

RecipientQueue::~RecipientQueue() {
  if (queue) delete queue;
}

/* *************************************** */

AlertFifoItem* RecipientQueue::dequeue() {
  AlertFifoItem* notification;

  if (!queue) return NULL;

  notification = queue->dequeue();

  if (notification) {
    last_use = time(NULL);
  }

  return notification;
}

/* *************************************** */

bool RecipientQueue::enqueue(const AlertFifoItem* const notification) {
  AlertFifoItem* new_item;
  bool res;

  if ((!queue && !(queue = new (nothrow)
                       AlertFifoQueue(ALERTS_NOTIFICATIONS_QUEUE_SIZE)))) {
    /* Queue not available */
    drops++;
    return false; /* Enqueue failed */
  }

  /* Enqueue a copy of the notification (there can be many recipients) */
  new_item = new (nothrow) AlertFifoItem(notification);

  if (!new_item) {
    drops++;
    return false;
  }

  res = queue->enqueue(new_item);

  if (res)
    enqueued++;
  else {
    drops++;
    delete new_item;
  }

#ifdef DEBUG_RECIPIENT_QUEUE
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Enqueue to recipient %u %s [severity %d][category %d][entity %d][alert-id %d]",
      recipient_id, res ? "ok" : "failed (drop)", notification->alert_severity,
      notification->alert_category, notification->alert_entity,
      notification->alert_id);
#endif

  return res;
}

/* *************************************** */

void RecipientQueue::lua(lua_State* vm) {
  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "last_use", last_use);
  lua_push_uint64_table_entry(vm, "num_uses", enqueued);
  lua_push_uint64_table_entry(vm, "num_drops", drops);
  lua_push_uint64_table_entry(vm, "num_filtered_out", filtered_out);
  lua_push_uint64_table_entry(vm, "num_delivered", delivered);
  lua_push_uint64_table_entry(vm, "num_failures", delivery_failures);
  lua_push_float_table_entry(vm, "fill_pct", queue ? queue->fillPct() : 0);
}

/* *************************************** */

bool RecipientQueue::empty() {
  bool res = true;

  if (queue) {
    if (!queue->empty()) {
      res = false;
    }
  }

  return res;
}

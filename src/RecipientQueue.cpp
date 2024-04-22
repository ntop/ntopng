/*
 *
 * (C) 2013-24 - ntop.org
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
// #define DEBUG_DB_QUEUE

/* *************************************** */

RecipientQueue::RecipientQueue(u_int16_t _recipient_id) {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
  recipient_id = _recipient_id;
  queue = NULL, drops = 0, uses = 0;
  last_use = 0;
  skip_alerts = false;

  /* No minimum severity */
  minimum_severity = alert_level_none;

  /* All categories enabled by default */
  for (int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++)
    enabled_categories.setBit(i);

  /* All entities enabled by default */
  for (int i = 0; i < ALERT_ENTITY_MAX_NUM_ENTITIES; i++)
    enabled_entities.setBit(i);
    
  /* All flow alert types enabled by default */
  for (int i = 0; i < MAX_DEFINED_FLOW_ALERT_TYPE; i++)
    enabled_flow_alert_types.setBit(i);
    
  /* All host alert types enabled by default */
  for (int i = 0; i < MAX_DEFINED_HOST_ALERT_TYPE; i++)
    enabled_host_alert_types.setBit(i);
}

/* *************************************** */

RecipientQueue::~RecipientQueue() {
  if (queue) delete queue;
}

/* *************************************** */

AlertFifoItem *RecipientQueue::dequeue() {
  AlertFifoItem *notification;

  if (!queue) return NULL;

  notification = queue->dequeue();

  if (notification) {
    last_use = time(NULL);
  }

  return notification;
}

/* *************************************** */

/* Filter and Enqueue alerts to the recipient
 * (similar to what recipients.dispatch_notification does in Lua)
 */
bool RecipientQueue::enqueue(const AlertFifoItem* const notification) {
  bool res = false;

#ifdef DEBUG_RECIPIENT_QUEUE
#ifdef DEBUG_DB_QUEUE
  if (recipient_id == 0 && notification->alert_entity == alert_entity_host) {
#else
  if (recipient_id != 0) {
#endif
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enqueueing alert to recipient %d "
      "[severity %d][category %d][entity %d][alert-id %d]",
      recipient_id,
      notification->alert_severity, notification->alert_category, notification->alert_entity,  notification->alert_id);
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", notification->alert.c_str());
  }
#endif

  /* Checking if the alerts have not to be enqueued */
  if(skip_alerts && notification->score > 0)
    return true; /* Skipping alerts */
  else if(!skip_alerts) {
    /* In case alerts have not to be skipped, check the filters */
#ifdef DEBUG_RECIPIENT_QUEUE
#ifdef DEBUG_DB_QUEUE
    if (recipient_id == 0 && notification->alert_entity == alert_entity_host)
#else
  if (recipient_id != 0)
#endif
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Checking alert (entity %d) for recipient %d",
        notification->alert_entity, recipient_id);
#endif
   
    if (!notification ||
        notification->alert_severity <
            minimum_severity /* Severity too low for this recipient     */
        ||
        !(enabled_categories.isSetBit(
            notification
                ->alert_category)) /* Category not enabled for this recipient */
        || !(enabled_entities.isSetBit(
              notification->alert_entity)) /* Entity not enabled for this recipient */
        ||
        (alert_entity_flow == notification->alert_entity && !enabled_flow_alert_types.isSetBit(notification->alert_id))
        ||
        (alert_entity_host == notification->alert_entity && !enabled_host_alert_types.isSetBit(notification->alert_id))
    ) {
#ifdef DEBUG_RECIPIENT_QUEUE
#ifdef DEBUG_DB_QUEUE
      if (recipient_id == 0 && notification->alert_entity == alert_entity_host)
#else
      if (recipient_id != 0)
#endif
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Alert filtered out due to filtering policy for recipient %d "
          "[severity %s (%d vs %d)][category %s (%d)][entity %s (%d)][alert-id %s (%d)]",
          recipient_id,
          notification->alert_severity < minimum_severity ? "Nok" : "Ok", notification->alert_severity, minimum_severity,
          !(enabled_categories.isSetBit(notification->alert_category)) ? "Nok" : "Ok", notification->alert_category,
          !(enabled_entities.isSetBit(notification->alert_entity)) ? "Nok" : "Ok", notification->alert_entity,
          ((alert_entity_flow == notification->alert_entity && !enabled_flow_alert_types.isSetBit(notification->alert_id)) || (alert_entity_host == notification->alert_entity && !enabled_host_alert_types.isSetBit(notification->alert_id))) ? "Nok" : "Ok", notification->alert_id);
#endif
      return true; /* Nothing to enqueue */
    }

    if (recipient_id == 0 && /* Default recipient (DB) */
        notification->alert_entity == alert_entity_flow &&
        ntop->getPrefs()->do_dump_flows_on_clickhouse()) {
      /* Do not store flow alerts on ClickHouse as they are retrieved using a view
      * on historical flows) */
      /* But still increment the number of uses */
      uses++;
#ifdef DEBUG_RECIPIENT_QUEUE
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow alert (no enqueue - clickhouse uses: %u)", uses);
#endif
      return true;
    }

    if (recipient_id == 0) {
      /* Default recipient (SQLite / ClickHouse DB) - do not filter alerts by host
      */
    } else {
      /* Other recipients (notifications) */
      if (notification->alert_entity == alert_entity_flow) {
        if (!enabled_host_pools.isSetBit(
                notification->flow.cli_host_pool) &&
            !enabled_host_pools.isSetBit(notification->flow.srv_host_pool))
          return true;
      } else if (notification->alert_entity == alert_entity_host) {
        if (!enabled_host_pools.isSetBit(notification->host.host_pool)) {
#ifdef DEBUG_RECIPIENT_QUEUE
#ifdef DEBUG_DB_QUEUE
          if (recipient_id == 0 && notification->alert_entity == alert_entity_host)
#else
          if (recipient_id != 0)
#endif
            ntop->getTrace()->traceEvent(TRACE_NORMAL, "Alert filtered out due to host pool filtering");
#endif
          return true;
        }
      }
    }
  }

  if ((!queue && !(queue = new (nothrow)
                       AlertFifoQueue(ALERTS_NOTIFICATIONS_QUEUE_SIZE)))) {
    /* Queue not available */
    drops++;
    return false; /* Enqueue failed */
  }

  /* Enqueue the notification (allocate memory for the alert string) */
  AlertFifoItem *new_item = new AlertFifoItem(notification);

  if (new_item) {
    res = queue->enqueue(new_item);

    if (!res) {
      drops++;
      delete new_item;
#ifdef DEBUG_RECIPIENT_QUEUE
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Alert enqueue failed (drop)");
#endif
    } else {
      uses++;
#ifdef DEBUG_RECIPIENT_QUEUE
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Alert enqueued successfully (uses: %u)", uses);
#endif
    }
  } else {
    drops++;
  }

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

  if (queue) {
    if (!queue->empty()) {
      res = false;
    }
  }

  return res;
}

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

/* *********************************************** */

CategoryCounter::CategoryCounter() {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  duration = 0, last_epoch_update = 0;
}

/* *********************************************** */

CategoryCounter::CategoryCounter(const CategoryCounter &c) {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  bytes = c.bytes, duration = c.duration,
  last_epoch_update = c.last_epoch_update;
};

/* *********************************************** */

void CategoryCounter::lua(NetworkInterface *iface, lua_State *vm,
                          u_int16_t category_id, bool tsLua) {
  const char *name =
      iface->get_ndpi_category_name((ndpi_protocol_category_t)category_id);

  if (!tsLua) {
    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "category", category_id);
    lua_push_uint64_table_entry(vm, "bytes", bytes.getTotal());
    lua_push_uint64_table_entry(vm, "bytes.sent", bytes.getSent());
    lua_push_uint64_table_entry(vm, "bytes.rcvd", bytes.getRcvd());
    lua_push_uint64_table_entry(vm, "duration", duration);

    lua_pushstring(vm, name);
    lua_insert(vm, -2);
    lua_rawset(vm, -3);
  } else {
    char buf[64];

    snprintf(buf, sizeof(buf), "%llu|%llu", (unsigned long long)bytes.getSent(),
             (unsigned long long)bytes.getRcvd());

    lua_push_str_table_entry(vm, name, buf);
  }
}

/* *********************************************** */

void CategoryCounter::incStats(u_int32_t when, u_int64_t sent_bytes,
                               u_int64_t rcvd_bytes) {
  bytes.incStats(sent_bytes, rcvd_bytes);

  if ((when != 0) && (when - last_epoch_update >=
                      ntop->getPrefs()->get_housekeeping_frequency())) {
    duration += ntop->getPrefs()->get_housekeeping_frequency(),
        last_epoch_update = when;
  }
}

/* *********************************************** */

void CategoryCounter::addProtoJson(json_object *my_object,
                                   NetworkInterface *iface,
                                   ndpi_protocol_category_t category_id) {
  json_object *inner;
  const char *name = iface->get_ndpi_category_name(category_id);

  inner = json_object_new_object();

  json_object_object_add(inner, "id", json_object_new_int64(category_id));
  json_object_object_add(inner, "bytes_sent",
                         json_object_new_int64(bytes.getSent()));
  json_object_object_add(inner, "bytes_rcvd",
                         json_object_new_int64(bytes.getRcvd()));
  json_object_object_add(inner, "duration", json_object_new_int64(duration));

  json_object_object_add(my_object, name, inner);
}

/* *********************************************** */

void CategoryCounter::resetStats() {
  duration = 0, last_epoch_update = 0;
  bytes.resetStats();
}

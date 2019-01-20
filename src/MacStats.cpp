/*
 *
 * (C) 2013-19 - ntop.org
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

MacStats::MacStats(NetworkInterface *_iface) {
  iface = _iface;
  memset(&arp_stats, 0, sizeof(arp_stats));

  /* NOTE: ndpiStats: allocated dynamically and deleted by ~GenericTrafficElement */
  ndpiStats = NULL;
}

/* *************************************** */

void MacStats::lua(lua_State* vm, bool show_details) {
  if(show_details) {
    lua_push_uint64_table_entry(vm, "arp_requests.sent", arp_stats.sent_requests);
    lua_push_uint64_table_entry(vm, "arp_requests.rcvd", arp_stats.rcvd_requests);
    lua_push_uint64_table_entry(vm, "arp_replies.sent", arp_stats.sent_replies);
    lua_push_uint64_table_entry(vm, "arp_replies.rcvd", arp_stats.rcvd_replies);

    if(ndpiStats) ndpiStats->lua(iface, vm, true);
  }

  ((GenericTrafficElement*)this)->lua(vm, true);
}

/* *************************************** */

void MacStats::deserialize(json_object *o) {
  json_object *obj;

  if(ndpiStats && json_object_object_get_ex(o, "ndpiStats", &obj)) ndpiStats->deserialize(iface, obj);
  if(json_object_object_get_ex(o, "flows.dropped", &obj)) total_num_dropped_flows = json_object_get_int(obj);
}

/* *************************************** */

void MacStats::getJSONObject(json_object *my_object) {
  if(ndpiStats) json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObject(iface));
  if(total_num_dropped_flows) json_object_object_add(my_object, "flows.dropped", json_object_new_int(total_num_dropped_flows));
}

/*
 *
 * (C) 2017-21 - ntop.org
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

HostPoolStats::HostPoolStats(NetworkInterface *iface) : GenericTrafficElement() {
    ndpiStats = new (std::nothrow) nDPIStats();
    totalStats = new (std::nothrow) nDPIStats();
    mustReset = false;

    if(iface && iface->getTimeLastPktRcvd() > 0)
      first_seen = last_seen = iface->getTimeLastPktRcvd();
    else
      first_seen = last_seen = time(NULL);
 };

/* ***************************************** */

void HostPoolStats::updateSeen(time_t _last_seen) {
  last_seen = _last_seen;

  if((first_seen == 0) || (first_seen > last_seen))
    first_seen = last_seen;
}

/* ***************************************** */

void HostPoolStats::updateName(const char * const _pool_name) {
  pool_name.assign(_pool_name ? _pool_name : "");
}

/* ***************************************** */

void HostPoolStats::lua(lua_State* vm, NetworkInterface *iface) {
  u_int64_t bytes = 0;
  u_int32_t duration = 0;

  lua_newtable(vm);

  GenericTrafficElement::lua(vm, true);
  lua_push_uint64_table_entry(vm, "seen.first", first_seen);
  lua_push_uint64_table_entry(vm, "seen.last", last_seen);
  if(ndpiStats) ndpiStats->lua(iface, vm, true /* with categories */);

  if(totalStats) {
    getStats(&bytes, &duration);

    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "bytes", bytes);
    lua_push_uint64_table_entry(vm, "duration", duration);

    lua_pushstring(vm, (char*)"cross_application");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

json_object* HostPoolStats::getJSONObject(NetworkInterface *iface) {
  json_object *my_object;
  
  if((my_object = json_object_new_object()) == NULL) return(NULL);

  json_object_object_add(my_object, "sent", sent.getJSONObject());
  json_object_object_add(my_object, "rcvd", rcvd.getJSONObject());
  if(ndpiStats) json_object_object_add(my_object, "ndpi", ndpiStats->getJSONObject(iface));
  if(totalStats) json_object_object_add(my_object, "totals", totalStats->getJSONObject(iface));
  return my_object;
}

char* HostPoolStats::serialize(NetworkInterface *iface) {
  json_object *my_object = getJSONObject(iface);

  if (! my_object)  return NULL;

  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

void HostPoolStats::deserialize(NetworkInterface *iface, json_object *o) {
  json_object *obj;

  if(json_object_object_get_ex(o, "sent", &obj)) sent.deserialize(obj);
  if(json_object_object_get_ex(o, "rcvd", &obj)) rcvd.deserialize(obj);
  if(ndpiStats && json_object_object_get_ex(o, "ndpi", &obj)) ndpiStats->deserialize(iface, obj);
  if(totalStats && json_object_object_get_ex(o, "totals", &obj)) totalStats->deserialize(iface, obj);
}

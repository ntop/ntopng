/*
 *
 * (C) 2013-23 - ntop.org
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

Country::Country(NetworkInterface *_iface, const char *country)
    : GenericHashEntry(_iface),
      GenericTrafficElement(),
      Score(_iface),
      dirstats(_iface, 0) {
  country_name = strdup(country);

#ifdef COUNTRY_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created Country %s",
                               country_name);
#endif
}

/* *************************************** */

void Country::set_hash_entry_state_idle() { ; /* Nothing to do */ }

/* *************************************** */

Country::~Country() {
#ifdef COUNTRY_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted Country %s",
                               country_name);
#endif

  free(country_name);
}

/* *************************************** */

void Country::lua(lua_State *vm, DetailsLevel details_level,
                  bool asListElement) {
  lua_newtable(vm);

  lua_push_str_table_entry(vm, "country", country_name);
  lua_push_uint64_table_entry(vm, "bytes", getNumBytes());

  if (details_level >= details_high) {
    dirstats.lua(vm);
    GenericTrafficElement::lua(vm, true); /* Must stay after dirstats */
    lua_push_uint64_table_entry(vm, "seen.first", first_seen);
    lua_push_uint64_table_entry(vm, "seen.last", last_seen);
    lua_push_uint64_table_entry(vm, "duration", get_duration());

    lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());
  }

  Score::lua_get_score(vm);
  Score::lua_get_score_breakdown(vm);

  if (asListElement) {
    lua_pushstring(vm, country_name);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool Country::equal(const char *country) {
  return (strcmp(country_name, country) == 0);
}

/* *************************************** */

void Country::serialize(json_object *o, DetailsLevel details_level) {
  json_object *obj;
  GenericHashEntry::getJSONObject(o, details_level);

  if ((obj = sent.getJSONObject()) != NULL)
    json_object_object_add(o, "traffic", obj);
  if ((obj = json_object_new_object()) != NULL) {
    dirstats.serialize(obj);
    json_object_object_add(o, "dirstats", obj);
  }
}

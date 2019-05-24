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

bool SerializableElement::serializeToRedis() {
  json_object *my_obj;

  if((my_obj = json_object_new_object()) != NULL) {
    char key[CONST_MAX_LEN_REDIS_KEY];
    int rc;

    serialize(my_obj, details_max);

    rc = ntop->getRedis()->set(getSerializationKey(key, sizeof(key)),
      json_object_to_json_string(my_obj), ntop->getPrefs()->get_local_host_cache_duration());

    json_object_put(my_obj);
    return(rc == 0);
  }

  return(false);
}

/* *************************************** */

bool SerializableElement::deserializeFromRedis() {
  char key[CONST_MAX_LEN_REDIS_KEY];
  json_object *o;

  if((o = Utils::deserializeJson(getSerializationKey(key, sizeof(key)))) != NULL) {
    deserialize(o);
    json_object_put(o);
    return(true);
  }

  return(false);
}

/* *************************************** */

bool SerializableElement::deleteRedisSerialization() {
  char key[CONST_MAX_LEN_REDIS_KEY];
  char *serialization_key = getSerializationKey(key, sizeof(key));

  ntop->getTrace()->traceEvent(TRACE_INFO, "Delete serialization %s", serialization_key);
  return(ntop->getRedis()->del(serialization_key) == 0);
}

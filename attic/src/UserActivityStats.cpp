/*
 *
 * (C) 2016-18 - ntop.org
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

UserActivityStats::UserActivityStats() {
  reset();
}

/* *************************************** */

void UserActivityStats::reset() {
  memset(counters, 0, sizeof(counters));
}

/* **************************************************** */

const char * activity_names [] = {
  "Other",
  "Web",
  "Media",
  "VPN",
  "MailSync",
  "MailSend",
  "FileSharing",
  "FileTransfer",
  "Chat",
  "Game",
  "RemoteControl",
  "SocialNetwork",
};
COMPILE_TIME_ASSERT (COUNT_OF(activity_names) == UserActivitiesN);

/* *************************************** */

static const char* getActivityName(UserActivityID id) {
  return ((ntop->getPrefs()->is_flow_activity_enabled()
          && id < UserActivitiesN) ? activity_names[id] : NULL);
};

/* ******************************************* */

static bool getActivityId(const char * name, UserActivityID * out) {
  if(ntop->getPrefs()->is_flow_activity_enabled() && name) {
    for(int i=0; i<UserActivitiesN; i++)
      if(strcmp(activity_names[i], name) == 0) {
        *out = ((UserActivityID) i);
        return true;
      }
  }
  return false;
}

/* ******************************************* */

json_object* UserActivityStats::getJSONObject() {
  json_object *my_object = json_object_new_object();

  if(my_object) {    
    for (int i=0; i<UserActivitiesN; i++) {
      json_object *actobj = json_object_new_object();

      json_object_object_add(actobj, "up", json_object_new_int64(counters[i].up));
      json_object_object_add(actobj, "down", json_object_new_int64(counters[i].down));
      json_object_object_add(actobj, "bg", json_object_new_int64(counters[i].background));
      
      json_object_object_add(my_object, getActivityName((UserActivityID) i), actobj);
    }
  }

  return(my_object);
}

/* *************************************** */

void UserActivityStats::deserialize(json_object *o) {
  struct json_object_iterator it, itEnd;

  if(!o) return;

  reset();

  it = json_object_iter_begin(o), itEnd = json_object_iter_end(o);

  while (!json_object_iter_equal(&it, &itEnd)) {
    char *key  = (char*)json_object_iter_peek_name(&it);

    UserActivityID actid;
    if (getActivityId(key, &actid)) {
      struct json_object* jobj = json_object_iter_peek_value(&it);
      struct json_object* value;

      if (json_object_object_get_ex(jobj, "up", &value))
        counters[actid].up = json_object_get_int64(value);
      if (json_object_object_get_ex(jobj, "down", &value))
        counters[actid].down = json_object_get_int64(value);
      if (json_object_object_get_ex(jobj, "bg", &value))
        counters[actid].background = json_object_get_int64(value);
    }

    json_object_iter_next(&it);
  }
}

/* *************************************** */

void UserActivityStats::incBytes(UserActivityID id, u_int64_t upbytes, u_int64_t downbytes, u_int64_t bgbytes) {
  if(id < UserActivitiesN) {
    counters[id].up += upbytes;
    counters[id].down += downbytes;
    counters[id].background += bgbytes;
  }
}

/* *************************************** */

const UserActivityCounter * UserActivityStats::getBytes(UserActivityID id) {
  return((id < UserActivitiesN) ? &counters[id] : NULL);
}

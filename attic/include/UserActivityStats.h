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

#ifndef _USER_ACTIVITY_STATS_H_
#define _USER_ACTIVITY_STATS_H_

#include "ntop_includes.h"

typedef struct {
    u_int64_t up;
    u_int64_t down;
    u_int64_t background;
  } UserActivityCounter;

class UserActivityStats {
 private:
  UserActivityCounter counters[UserActivitiesN];

 public:
  UserActivityStats();

  void reset();
  void incBytes(UserActivityID id, u_int64_t upbytes, u_int64_t downbytes, u_int64_t bgbytes);
  const UserActivityCounter * getBytes(UserActivityID id);
  json_object* getJSONObject();
  void deserialize(json_object *o);
};

#endif

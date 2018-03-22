/*
 *
 * (C) 2013-18 - ntop.org
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

TrafficStats::TrafficStats() {
  numPkts = 0, numBytes = 0;
}

/* *************************************** */

#ifdef NOTUSED
void TrafficStats::printStats() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%llu Bytes/%llu Packets",
				      numBytes, numPkts);
}
#endif

/* *************************************** */

char* TrafficStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void TrafficStats::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  if(json_object_object_get_ex(o, "packets", &obj))
    numPkts = json_object_get_int64(obj);
  else
    numPkts = 0;
  
  if(json_object_object_get_ex(o, "bytes", &obj))
    numBytes = json_object_get_int64(obj);
  else
    numBytes = 0;
}

/* ******************************************* */

json_object* TrafficStats::getJSONObject() {
  json_object *my_object = json_object_new_object();
  
  if(my_object) {
    json_object_object_add(my_object, "packets", json_object_new_int64(numPkts));
    json_object_object_add(my_object, "bytes", json_object_new_int64(numBytes));
  }

  return(my_object);
}

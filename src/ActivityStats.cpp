/*
 *
 * (C) 2013-16 - ntop.org
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

/* Daily duration */
ActivityStats::ActivityStats(time_t when) {
  begin_time  = (when == 0) ? time(NULL) : when;
  begin_time += ntop->get_time_offset();
  begin_time -= (begin_time % CONST_MAX_ACTIVITY_DURATION);

  wrap_time = begin_time + CONST_MAX_ACTIVITY_DURATION;

  last_set_time = last_set_requested = 0;
  reset();

  //ntop->getTrace()->traceEvent(TRACE_WARNING, "Wrap stats at %u/%s", wrap_time, ctime(&wrap_time));
}

/* *************************************** */

void ActivityStats::reset() {
  memset(&bitset, 0, sizeof(bitset));
  last_set_time = 0;
}

/* *************************************** */

/* when comes from time() and thus is in UTC whereas we must wrap in localtime */
void ActivityStats::set(time_t when) {
  if((last_set_requested != when) && (when >= begin_time)) {
    time_t w;
    u_int minute;

    last_set_requested = when;

    if(when > wrap_time) {
      reset();

      begin_time = wrap_time;
      wrap_time += CONST_MAX_ACTIVITY_DURATION;

      ntop->getTrace()->traceEvent(TRACE_INFO,
				   "Resetting stats [when: %u][begin_time: %u][wrap_time: %u]",
				   when, begin_time, wrap_time);
    }

    w = (when - begin_time) % CONST_MAX_ACTIVITY_DURATION;

    if(w == last_set_time) return;

    minute = w / 60;

    bitset.counter[minute]++;

    last_set_time = when;
  }
};

/* *************************************** */

bool ActivityStats::writeDump(char* path) {
  FILE *fd = fopen(path, "wb");

  ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping activity %s", path);

  if(fd == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Error writing dump %s", path);
    return(false);
  }

  fwrite(&bitset, sizeof(bitset), 1, fd);
  fclose(fd);
  ntop->getTrace()->traceEvent(TRACE_INFO, "Written dump %s", path);
  return(true);
}

/* *************************************** */

bool ActivityStats::readDump(char* path) {
  FILE *fd = fopen(path, "rb");

  ntop->getTrace()->traceEvent(TRACE_INFO, "Reading activity %s", path);

  memset(&bitset, 0, sizeof(bitset));

  if(fd == NULL) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "Error reading dump %s: file missing ?", path);
    return(false);
  }

  fread(&bitset, sizeof(bitset), 1, fd);
  fclose(fd);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Read dump %s", path);
  return(true);
}

/* *************************************** */

json_object* ActivityStats::getJSONObject() {
  json_object *my_object;

  my_object = json_object_new_object();

  for(u_int32_t i=0; i<NUM_MINUTES_PER_DAY; i++) {
    if(bitset.counter[i] > 0) {
      char buf[32];

      snprintf(buf, sizeof(buf), "%lu", begin_time+i*60);
      json_object_object_add(my_object, buf, json_object_new_int(bitset.counter[i]));
    }
  }

  return(my_object);
}

/* *************************************** */

char* ActivityStats::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

void ActivityStats::deserialize(json_object *o) {
  struct json_object_iterator it, itEnd;

  if(!o) return;

  /* Reset all */
  reset();

  it = json_object_iter_begin(o), itEnd = json_object_iter_end(o);

  while (!json_object_iter_equal(&it, &itEnd)) {
    char *key  = (char*)json_object_iter_peek_name(&it);
    u_int32_t when = atol(key), minute;

    when %= CONST_MAX_ACTIVITY_DURATION;

    minute = when / 60;

    bitset.counter[minute]++;

    json_object_iter_next(&it);
  }
}

/* *************************************** */

void ActivityStats::extractPoints(activity_bitmap *b) {
  memcpy(b, &bitset, sizeof(activity_bitmap));
}

/* *************************************** */

/* http://codereview.stackexchange.com/questions/10122/c-correlation-leastsquarescoefs */

double ActivityStats::pearsonCorrelation(ActivityStats *s) {
  activity_bitmap x, y;

  extractPoints(&x);
  s->extractPoints(&y);

  return(Utils::pearsonValueCorrelation(&x, &y));
}

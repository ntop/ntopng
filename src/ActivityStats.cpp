/*
 *
 * (C) 2013-15 - ntop.org
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
  bitset = new Uint32EWAHBoolArray;

  begin_time  = (when == 0) ? time(NULL) : when;
  begin_time += ntop->get_time_offset();
  begin_time -= (begin_time % CONST_MAX_ACTIVITY_DURATION);


  wrap_time = begin_time + CONST_MAX_ACTIVITY_DURATION;

  last_set_time = last_set_requested = 0;

  //ntop->getTrace()->traceEvent(TRACE_WARNING, "Wrap stats at %u/%s", wrap_time, ctime(&wrap_time));
}

/* *************************************** */

ActivityStats::~ActivityStats() {
  delete bitset;
}

/* *************************************** */

void ActivityStats::reset() {
  m.lock(__FILE__, __LINE__);
  bitset->reset();
  last_set_time = 0;
  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

/* when comes from time() and thus is in UTC whereas we must wrap in localtime */
void ActivityStats::set(time_t when) {
  if((last_set_requested != when) && (when >= begin_time)) {
    time_t w;

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

    m.lock(__FILE__, __LINE__);
    bitset->set((size_t)w);
    m.unlock(__FILE__, __LINE__);
    last_set_time = when;
  }
};

/* *************************************** */

void ActivityStats::setDump(stringstream* dump) {
  m.lock(__FILE__, __LINE__);
  bitset->read(*dump);
  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

bool ActivityStats::writeDump(char* path) {
  stringstream ss;
  time_t now = time(NULL);
  time_t expire_time = now+((now+CONST_MAX_ACTIVITY_DURATION-1) % CONST_MAX_ACTIVITY_DURATION);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping activity %s", path);

  m.lock(__FILE__, __LINE__);
  bitset->write(ss);
  m.unlock(__FILE__, __LINE__);

  string s = ss.str();
  std::string encoded = Utils::base64_encode(reinterpret_cast<const unsigned char*>(s.c_str()), s.length());

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "===> %s(%s)(%s)(%d)", __FUNCTION__, path, encoded.c_str(), expire_time-now);

  /* Save it both in redis and disk */
  ntop->getRedis()->set(path, (char*)encoded.c_str(), (u_int)(expire_time-now));

  try {
    ofstream dumpFile(path);

    dumpFile << ss.str();
    dumpFile.close();
    ntop->getTrace()->traceEvent(TRACE_INFO, "Written dump %s", path);
    return(true);
  } catch(...) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Error writing dump %s", path);
    return(false);
  }
}

/* *************************************** */

bool ActivityStats::readDump(char* path) {
  char rsp[4096];

  ntop->getTrace()->traceEvent(TRACE_INFO, "Reading activity %s", path);

  if(ntop->getRedis()->get(path, rsp, sizeof(rsp)) == 0) {
    Uint32EWAHBoolArray tmp;
    std::string decoded = Utils::base64_decode(rsp);
    std::string s(decoded);
    std::stringstream ss(s);

#if 0
  /*
    We do not use "direct" bitset->read() as this is apparently creating
    crash problems.
   */
    if(!ss.str().empty()) tmp.read(ss);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "===> %s(%s)", __FUNCTION__, path);
    m.lock(__FILE__, __LINE__);
    bitset->reset();

    for(Uint32EWAHBoolArray::const_iterator i = tmp.begin(); i != tmp.end(); ++i)
      bitset->set((size_t)*i);

    m.unlock(__FILE__, __LINE__);
#else
    m.lock(__FILE__, __LINE__);
    bitset->reset();
    if(!ss.str().empty()) bitset->read(ss);
    m.unlock(__FILE__, __LINE__);
#endif

    ntop->getTrace()->traceEvent(TRACE_INFO, "Read dump %s", path);
    return(true);
  } else {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "Error reading dump %s: dump not found", path);
    return(false);
  }
}

/* *************************************** */

json_object* ActivityStats::getJSONObject() {
  json_object *my_object;
  char buf[32];
  u_int num = 0, last_dump = 0;

  my_object = json_object_new_object();

  m.lock(__FILE__, __LINE__);
  for(Uint32EWAHBoolArray::const_iterator i = bitset->begin(); i != bitset->end(); ++i) {
    /*
      As the bitmap has the time set in UTC we need to remove the timezone in order
      to represent the time as local time
    */

    /* Aggregate events at minute granularity */
    if(num == 0)
      num = 1, last_dump = *i;
    else {
      if((last_dump+60 /* 1 min */) > *i)
	num++;
      else {
	snprintf(buf, sizeof(buf), "%lu", begin_time+last_dump);
	json_object_object_add(my_object, buf, json_object_new_int(num));
	num = 1, last_dump = *i;
      }
    }
  }

  if(num > 0) {
    snprintf(buf, sizeof(buf), "%lu", begin_time+last_dump);
    json_object_object_add(my_object, buf, json_object_new_int(num));
  }
  m.unlock(__FILE__, __LINE__);

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
  m.lock(__FILE__, __LINE__);
  bitset->reset();

  it = json_object_iter_begin(o), itEnd = json_object_iter_end(o);

  while (!json_object_iter_equal(&it, &itEnd)) {
    char *key  = (char*)json_object_iter_peek_name(&it);
    u_int32_t when = atol(key);

    when %= CONST_MAX_ACTIVITY_DURATION;
    bitset->set(when);
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s=%d", key, 1);

    json_object_iter_next(&it);
  }
  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void ActivityStats::extractPoints(u_int8_t *elems) {
  m.lock(__FILE__, __LINE__);

 for(Uint32EWAHBoolArray::const_iterator i = bitset->begin(); i != bitset->end(); ++i) {
   u_int last_point = *i;

   if(last_point < CONST_MAX_ACTIVITY_DURATION)
     elems[last_point] = 1;
   else
     break;
 }

 m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

/* http://codereview.stackexchange.com/questions/10122/c-correlation-leastsquarescoefs */

double ActivityStats::pearsonCorrelation(ActivityStats *s) {
  u_int8_t x[CONST_MAX_ACTIVITY_DURATION] = { 0 };
  u_int8_t y[CONST_MAX_ACTIVITY_DURATION] = { 0 };

  extractPoints(x);
  s->extractPoints(y);

  return(Utils::pearsonValueCorrelation(x, y));
}


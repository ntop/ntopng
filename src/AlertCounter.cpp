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

// #define ALERT_DEBUG 1

/* *************************************** */

AlertCounter::AlertCounter() {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  max_hits_since_reset = 0;
  hits_reset_req = false;
  reset_window();
}

/* *************************************** */

void AlertCounter::reset_window(time_t when) {
  current_hits = 0;
  time_last_hit = when;
}

/* *************************************** */

void AlertCounter::inc(time_t when, AlertableEntity *alertable) {
  if (hits_reset_req) {
    max_hits_since_reset = 0;
    hits_reset_req = false;
    reset_window(when);
  }

  if (when - time_last_hit > 1) {
    if (current_hits > max_hits_since_reset)
      max_hits_since_reset = current_hits;
    reset_window(when);
  } else {
    current_hits++;
  }

  #if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
          "stats [host: %s][when: %u][time_last_hit: %u][max_hits_since_reset: %u][current_hits: %u]",
          alertable->getEntityValue().c_str(),
          when,
          time_last_hit,
          max_hits_since_reset,
          current_hits
          );
  #endif
}
/* *************************************** */

void AlertCounter::inc_no_time_window(){
  current_hits++;
}

void AlertCounter::dec(){
  current_hits--;
}
/* *************************************** */

u_int16_t AlertCounter::hits() const {
  if (hits_reset_req) /* Requested, but not yet reset */
    return 0;
  
  return (max_hits_since_reset > current_hits) ? 
    max_hits_since_reset : 
    current_hits;
}

/* *************************************** */

void AlertCounter::reset_hits() { hits_reset_req = true; }

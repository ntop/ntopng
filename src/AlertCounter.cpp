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

// #define ALERT_DEBUG 1

/* *************************************** */

AlertCounter::AlertCounter() {
  reset();
}

/* *************************************** */

void AlertCounter::reset(time_t when) {
  memset(&trailing_window, 0, sizeof(trailing_window));
  trailing_window_min = 0;
  trailing_index = 0;
  time_last_hit = when;
}

/* *************************************** */

void AlertCounter::inc(time_t when, Host *h) {
  if(when - time_last_hit > 1) /* Only consecutive hits matter */
    reset(when);

  if(when - time_last_hit) { /* If true, difference must be 1 as reset(when) is called if > 1 */
    u_int16_t tmp_min = trailing_window[0]; /* Update the minimum value to make sure all the elements in the window are >= */
    for(u_int8_t i = 1; i < ALERT_COUNTER_WINDOW_SECS; i++) {
      if(trailing_window[i] < tmp_min /* New minimum detected */)
	tmp_min = trailing_window[i];
    }
    trailing_window_min = tmp_min;

    trailing_index = (trailing_index + 1) % ALERT_COUNTER_WINDOW_SECS; /* Move to the next element in the array */
    trailing_window[trailing_index] = 0; /* Reset as it could contain old values */
    time_last_hit = when; /* Update the last hit */
  }

  if(trailing_window[trailing_index] < (u_int16_t)-1) /* Protect against wraps */
    trailing_window[trailing_index]++;

#if 0

  char buf[256];
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "stats [host: %s][when: %u][time_last_hit: %u][trailing_window_min: %u]"
			       "[trailing_window[0]: %u][trailing_window[1]: %u][trailing_window[2]: %u]",
			       h->get_ip()->print(buf, sizeof(buf)),
			       when,
			       time_last_hit,
			       trailing_window_min,
			       trailing_window[0],
			       trailing_window[1],
			       trailing_window[2]
			       );

#endif
}

/* *************************************** */

u_int16_t AlertCounter::hits() const {
  time_t now = time(NULL);

  if(now - time_last_hit > 1) /* Only fresh hits matter */
    return 0;

  return trailing_window_min;
}


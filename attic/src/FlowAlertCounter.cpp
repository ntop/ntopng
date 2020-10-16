/*
 *
 * (C) 2013-20 - ntop.org
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

FlowAlertCounter::FlowAlertCounter(u_int8_t _max_num_hits_sec,
				   u_int8_t _over_threshold_duration_sec) {
  max_num_hits_sec = _max_num_hits_sec,
    over_threshold_duration_sec = _over_threshold_duration_sec;
  thresholdTrepassed = false;

  reset();
}

/* *************************************** */

void FlowAlertCounter::reset() {
  time_last_hit = last_trespassed_threshold = 0;
  num_trespassed_threshold = num_hits_rcvd_last_second = 0;
}

/* *************************************** */

bool FlowAlertCounter::incHits(time_t when) {
  if(thresholdTrepassed) {
    if(when < last_trespassed_threshold + CONST_ALERT_GRACE_PERIOD)
      return true;
    else
      thresholdTrepassed = false;
  }

  /* When here, thresholdTrepassed == false holds */

  if(when > time_last_hit + 1)
    reset(); /* Start over */
  else if (when == time_last_hit + 1) {
    /* A new second has ticked */
    if(num_hits_rcvd_last_second <= max_num_hits_sec)
      reset();
    else
      num_hits_rcvd_last_second = 0;
  }

  num_hits_rcvd_last_second++, time_last_hit = when;

  if(num_hits_rcvd_last_second <= max_num_hits_sec) {
    /* Other hits may arrive within the current second */
  } else if(last_trespassed_threshold < when) {
    /* We are above the maximum number of hits allowed,
       and this is the first time during the current second */
    num_trespassed_threshold++, last_trespassed_threshold = when;

    if(num_trespassed_threshold > over_threshold_duration_sec)
      return(thresholdTrepassed = true);
  }

  return thresholdTrepassed;
}

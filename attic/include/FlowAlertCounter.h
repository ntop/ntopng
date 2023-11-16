/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _FLOW_ALERT_COUNTER_H_
#define _FLOW_ALERT_COUNTER_H_

#include "ntop_includes.h"

class FlowAlertCounter {
 private:
  bool thresholdTrepassed;
  u_int8_t max_num_hits_sec;
  u_int8_t over_threshold_duration_sec;
  time_t time_last_hit;
  time_t last_trespassed_threshold;
  u_int32_t num_trespassed_threshold; /**< Number of consecutives threshold trespassing. */
  u_int32_t num_hits_rcvd_last_second; /**< Number of hits reported in the last second. */

  void reset();

 public:
  FlowAlertCounter(u_int8_t _max_num_hits_sec,
	       u_int8_t _over_threshold_duration_sec);

  bool incHits(time_t when);
};

#endif /* _FLOW_ALERT_COUNTER_H_ */

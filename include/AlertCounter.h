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

#ifndef _ALERT_COUNTER_H_
#define _ALERT_COUNTER_H_

#include "ntop_includes.h"

/** @class AlertCounter
 *  @brief Base class for alerts.
 *  @details Defines a basic class for handling generated alerts.
 *
 *  @ingroup MonitoringData
 *
 */

#define  ALERT_COUNTER_WINDOW_SECS 3

class AlertCounter {
 private:
  time_t time_last_hit;
  u_int16_t trailing_window[ALERT_COUNTER_WINDOW_SECS];
  u_int16_t trailing_window_min;
  u_int16_t trailing_window_max_since_hits_reset;
  u_int8_t  trailing_index;
  bool hits_reset_req;
  
  void reset_window(time_t when = 0);

 public:
  AlertCounter();
  void inc(time_t when, AlertableEntity *alertable);
  u_int16_t hits() const;
  void reset_hits();
};

#endif /* _ALERT_COUNTER_H_ */

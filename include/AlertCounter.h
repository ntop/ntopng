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

class AlertCounter {
 private:
  bool thresholdTrepassed;
  u_int32_t max_num_hits_sec; /**< Threshold above which we trigger an alert. */
  u_int32_t num_hits_since_first_alert; /**< Number of hits since the first one that contributed to generate an alert. */
  u_int8_t over_threshold_duration_sec; /**< Consecutive duration of threshold trespassing before triggering an alert. */
  time_t time_last_hit; /**< Time of last hit received. */ 
  time_t time_last_alert_reported; /**< Time of last alert issued. */ 
  time_t last_trespassed_threshold; /**< Time of last event that trespassed the threshold. */
  u_int32_t num_trespassed_threshold; /**< Number of consecutives threshold trespassing. */
  u_int32_t num_hits_rcvd_last_second; /**< Number of hits reported in the last second. */
  u_int32_t last_trespassed_hits; /**< Number of hits during last threshold trespassing */
  
  void init();

 public:
  AlertCounter(u_int32_t _max_num_hits_sec,
	       u_int8_t _over_threshold_duration_sec);
  
  bool incHits(time_t when);
  inline u_int32_t getCurrentHits()          { return(num_hits_since_first_alert);  };
  inline u_int8_t getOverThresholdDuration() { return(over_threshold_duration_sec); };
  inline bool isAboveThreshold(time_t when)  { return(thresholdTrepassed && (time_last_hit >= (when-1)) ); };
  void resetThresholds(u_int32_t _max_num_hits_sec, u_int8_t _over_threshold_duration_sec);
  void lua(lua_State* vm, const char *table_key);
};

#endif /* _ALERT_COUNTER_H_ */

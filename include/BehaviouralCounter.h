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

#ifndef _BEHAVIOURAL_COUNTER_H_
#define _BEHAVIOURAL_COUNTER_H_

#include "ntop_includes.h"

class BehaviouralCounter {
 protected:
  bool is_anomaly;
  u_int64_t tot_num_anomalies, last_lower, last_upper, last_value;

 public:
  /* Number of points to be used by the algorithm in the learning phase */
  BehaviouralCounter() {
    is_anomaly = false,
    tot_num_anomalies = last_lower = last_upper = last_value = 0;
  }
  virtual ~BehaviouralCounter(){};

  /*
    In Parameters:
    - value         The measurement to evaluate

    Return:
     true     An anomaly has been detected (i.e. prediction < lower_bound, or
    prediction > upper_bound) false    The value is within the expected range
  */
  virtual bool addObservation(u_int64_t value) { return (false); };
  inline u_int64_t getTotNumAnomalies() { return (tot_num_anomalies); };

  /* Last measurement */
  inline bool anomalyFound() { return (is_anomaly); };
  inline u_int64_t getLastValue() { return (last_value); };
  inline u_int64_t getTotAnomalies() { return (tot_num_anomalies); };
  inline u_int64_t getLastLowerBound() { return (last_lower); };
  inline u_int64_t getLastUpperBound() { return (last_upper); };
};

#endif /* _BEHAVIOURAL_COUNTER_H_ */

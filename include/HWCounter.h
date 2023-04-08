/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _HW_COUNTER_H_
#define _HW_COUNTER_H_

#include "ntop_includes.h"

/* Counter based on Holt-Winters algorithm */
class HWCounter : public BehaviouralCounter {
 private:
  struct ndpi_hw_struct hw;

 public:
  HWCounter(u_int16_t num_learning_observations = 1 /* Basically smoothing without seasonality */,
	    double alpha = 0.7, double beta = 0.7, double gamma = 0.9)
    : BehaviouralCounter() {
    if(ndpi_hw_init(&hw, num_learning_observations, 1 /* additive */, alpha, beta, gamma, 0.05 /* 95% */) != 0)
      throw "Error while creating HW";
  }
  ~HWCounter() { ndpi_hw_free(&hw); }

  bool addObservation(u_int64_t value) {
    double forecast, confidence_band;
    bool rc = ndpi_hw_add_value(&hw, last_value = value, &forecast, &confidence_band) == 1 ? true : false;
    double l_forecast = forecast-confidence_band;
    double h_forecast = forecast+confidence_band;

    last_lower = (u_int64_t)floor(((l_forecast < 0) ? 0 : l_forecast)),
      last_upper = (u_int64_t)round(h_forecast+0.5), is_anomaly = rc;
    
    if(is_anomaly) tot_num_anomalies++;

    return(is_anomaly);
  }

  inline void resetStats() { ndpi_hw_reset(&hw); }
};

#endif /* _HW_COUNTER_H_ */

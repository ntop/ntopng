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

#ifndef _DES_COUNTER_H_
#define _DES_COUNTER_H_

#include "ntop_includes.h"

/* ************************ */

/* Counter based on Double Exponential smoothing algorithm */
class DESCounter : public BehaviouralCounter {
 private:
  struct ndpi_des_struct des;

 public:
  DESCounter(double alpha = 0.9, double beta = 0.035, float significance = 0.05)
      : BehaviouralCounter() {
    if (ndpi_des_init(&des, alpha, beta, significance) != 0)
      throw "Error while creating DES";
  }

  DESCounter(struct ndpi_des_struct *_des) {
    memcpy(&des, _des, sizeof(struct ndpi_des_struct));
  }

  bool addObservation(u_int64_t value) {
    double forecast, confidence_band;
    bool rc =
        (ndpi_des_add_value(&des, value, &forecast, &confidence_band) == 1)
            ? true
            : false;
    double l_forecast = forecast - confidence_band;
    double h_forecast = forecast + confidence_band;

    last_value = value;
    last_lower = (u_int64_t)floor(((l_forecast < 0) ? 0 : l_forecast));
    last_upper = (u_int64_t)round(h_forecast + 0.5);

    if (rc) {
      is_anomaly =
          ((value < last_lower) || (value > last_upper)) ? true : false;

      if (is_anomaly) tot_num_anomalies++;

      return (is_anomaly);
    }

    return (rc);
  }

  inline void resetStats() { ndpi_des_reset(&des); }
  inline DESCounter *clone() { return (new (std::nothrow) DESCounter(&des)); }
  inline void set(DESCounter *c) {
    memcpy(&des, &c->des, sizeof(struct ndpi_des_struct));
  }
};

#endif /* _DES_COUNTER_H_ */

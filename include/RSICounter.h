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

#ifndef _RSI_COUNTER_H_
#define _RSI_COUNTER_H_

#include "ntop_includes.h"

/* ******************************** */

/* Counter based on Relative Strenght Indicator algorithm */
class RSICounter : public BehaviouralCounter {
 private:
  struct ndpi_rsi_struct rsi;
  u_int8_t lower_pctg, upper_pctg;

 public:
  RSICounter(u_int16_t num_learning_observations = 10,
             u_int8_t lower_percentage = 25, u_int8_t upper_percentage = 75)
      : BehaviouralCounter() {
    if (ndpi_alloc_rsi(&rsi, num_learning_observations) != 0)
      throw "Error while creating RSI";

    if ((lower_percentage > upper_percentage) || (upper_percentage > 100))
      lower_percentage = 25, upper_percentage = 75; /* Using defaults */
    lower_pctg = lower_percentage, upper_pctg = upper_percentage;
  }
  ~RSICounter() { ndpi_free_rsi(&rsi); }

  bool addObservation(u_int64_t value) {
    float res = ndpi_rsi_add_value(&rsi, last_value = value);

    if (res == -1)
      last_lower = last_upper = 0, is_anomaly = false; /* Too early */
    else {
      is_anomaly = ((res < lower_pctg) || (res > upper_pctg)) ? true : false;
      last_lower = (u_int64_t)lower_pctg, last_upper = (u_int64_t)upper_pctg;
      if (is_anomaly) tot_num_anomalies++;
    }

    return (is_anomaly);
  }
};

#endif /* _RSI_COUNTER_H_ */

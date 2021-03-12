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

#ifndef _BEHAVIOURAL_COUNTER_H_
#define _BEHAVIOURAL_COUNTER_H_

#include "ntop_includes.h"

class BehaviouralCounter {
 private:

 public:
  /* Number of points to be used by the algorithm in the learning phase */
  BehaviouralCounter() { ; }
  virtual ~BehaviouralCounter() {  };

  /*
    In Parameters:
    - value         The measurement to evaluate

    Out Parameters
    - prediction    The predicted value for the measurement
    - lower_bound   The lower prediction
    - upper_bound   The upper prediction

    Return:
     true     An anomaly has been detected (i.e. prediction < lower_bound, or prediction > upper_bound)
     false    The value is within the expected range
  */
  virtual bool addObservation(u_int32_t value, u_int32_t *prediction,
			      u_int32_t *lower_bound, u_int32_t *upper_bound) { return(false); };
};

/* ******************************** */

/* Counter based on Relative Strenght Indicator algorithm */
class RSICounter : public BehaviouralCounter {
 private:
  struct ndpi_rsi_struct rsi;
  u_int8_t lower_pctg, upper_pctg;

 public:
  RSICounter(u_int16_t num_learning_observations = 10, u_int8_t lower_percentage = 25, u_int8_t upper_percentage = 75) : BehaviouralCounter() {
    if(ndpi_alloc_rsi(&rsi, num_learning_observations) != 0)
      throw "Error while creating RSI";

    if((lower_percentage > upper_percentage) || (upper_percentage > 100))
      lower_percentage = 25, upper_percentage = 75; /* Using defaults */
    lower_pctg = lower_percentage, upper_pctg = upper_percentage;
  }
  ~RSICounter() { ndpi_free_rsi(&rsi); }

  bool addObservation(u_int32_t value, u_int32_t *prediction,
		      u_int32_t *lower_bound, u_int32_t *upper_bound) {
    float res = ndpi_rsi_add_value(&rsi, value);

    *lower_bound = (u_int32_t)lower_pctg, *upper_bound = (u_int32_t)upper_pctg,
      *prediction = (u_int32_t)res;
    
    if(res == -1)
      return(false); /* Too early */
    else
      return(((res < lower_pctg) || (res > upper_pctg)) ? true : false);
  }
};

/* ************************ */

/* Counter based on Double Exponential smoothing algorithm */
class DESCounter : public BehaviouralCounter {
 private:
  struct ndpi_des_struct des;

 public:
 DESCounter(double alpha = 0.9, double beta = 0.5, float significance = 0.05) : BehaviouralCounter() {
    if(ndpi_des_init(&des, alpha, beta, significance) != 0)
      throw "Error while creating DES";
  }

  bool addObservation(u_int32_t value, u_int32_t *prediction,
		      u_int32_t *lower_bound, u_int32_t *upper_bound) {
    double forecast, confidence_band;
    bool rc = ndpi_des_add_value(&des, value, &forecast, &confidence_band) == 1 ? true : false;
    double l_forecast = forecast-confidence_band;
    double h_forecast = forecast+confidence_band;
    
    *lower_bound = (u_int32_t)((l_forecast < 0) ? 0 : l_forecast),
      *upper_bound = (u_int32_t)h_forecast,
      *prediction = (u_int32_t)forecast;
    
    return(rc);
  }
};

/* ******************************** */

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

  bool addObservation(u_int32_t value, u_int32_t *prediction,
		      u_int32_t *lower_bound, u_int32_t *upper_bound) {
    double forecast, confidence_band;
    bool rc = ndpi_hw_add_value(&hw, value, &forecast, &confidence_band) == 1 ? true : false;
    double l_forecast = forecast-confidence_band;
    double h_forecast = forecast+confidence_band;
    
    *lower_bound = (u_int32_t)((l_forecast < 0) ? 0 : l_forecast),
      *upper_bound = (u_int32_t)h_forecast,
      *prediction = (u_int32_t)forecast;
    
    return(rc);
  }
};

#endif /* _BEHAVIOURAL_COUNTER_H_ */

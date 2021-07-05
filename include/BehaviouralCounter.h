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
 protected:
  bool is_anomaly;
  u_int64_t tot_num_anomalies, last_lower, last_upper, last_value;

 public:
  /* Number of points to be used by the algorithm in the learning phase */
  BehaviouralCounter() { is_anomaly = false, tot_num_anomalies = last_lower = last_upper = last_value = 0; }
  virtual ~BehaviouralCounter() {  };

  /*
    In Parameters:
    - value         The measurement to evaluate

    Return:
     true     An anomaly has been detected (i.e. prediction < lower_bound, or prediction > upper_bound)
     false    The value is within the expected range
  */
  virtual bool addObservation(u_int64_t value) { return(false); };
  inline u_int64_t getTotNumAnomalies() { return(tot_num_anomalies); };

  /* Last measurement */
  inline bool anomalyFound()            { return(is_anomaly);        };
  inline u_int64_t getLastValue()       { return(last_value);        };
  inline u_int64_t getTotAnomalies()    { return(tot_num_anomalies); };
  inline u_int64_t getLastLowerBound()  { return(last_lower);        };
  inline u_int64_t getLastUpperBound()  { return(last_upper);        };
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

  bool addObservation(u_int64_t value) {
    float res = ndpi_rsi_add_value(&rsi, last_value = value);

    if(res == -1)
      last_lower = last_upper = 0, is_anomaly = false; /* Too early */
    else {
      is_anomaly = ((res < lower_pctg) || (res > upper_pctg)) ? true : false;
      last_lower = (u_int64_t)lower_pctg, last_upper = (u_int64_t)upper_pctg;
      if(is_anomaly) tot_num_anomalies++;
    }

    return(is_anomaly);
  }
};

/* ************************ */

/* Counter based on Double Exponential smoothing algorithm */
class DESCounter : public BehaviouralCounter {
 private:
  struct ndpi_des_struct des;

 public:
 DESCounter(double alpha = 0.9, double beta = 0.035, float significance = 0.05) : BehaviouralCounter() {
    if(ndpi_des_init(&des, alpha, beta, significance) != 0)
      throw "Error while creating DES";
  }

  bool addObservation(u_int64_t value) {
    double forecast, confidence_band;
    bool rc = (ndpi_des_add_value(&des, value, &forecast, &confidence_band) == 1) ? true : false;
    double l_forecast = forecast-confidence_band;
    double h_forecast = forecast+confidence_band;

    last_value = value;
    last_lower = (u_int64_t)floor(((l_forecast < 0) ? 0 : l_forecast));
    last_upper = (u_int64_t)round(h_forecast+0.5);

    if(rc) {
      is_anomaly = ((value < last_lower) || (value > last_upper)) ? true : false;

      if(is_anomaly) 
        tot_num_anomalies++;
      
      return(is_anomaly);
    }

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
};

#endif /* _BEHAVIOURAL_COUNTER_H_ */

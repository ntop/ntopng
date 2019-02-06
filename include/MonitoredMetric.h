/*
 *
 * (C) 2013-19 - ntop.org
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

#ifndef _MONITORED_METRIC_H_
#define _MONITORED_METRIC_H_

template <typename METRICTYPE> class MonitoredMetric {
 protected:
  METRICTYPE value, last_value, gains, losses;
  time_t     last_update;
  METRICTYPE anomaly_index;

  inline void updateAnomalyIndex(time_t when, int64_t delta) {
    if(delta > 0)
      gains = ewma(delta, gains),
	losses = ewma(0, losses);
    else
      gains = ewma(0, gains),
      losses = ewma(-delta, losses);

    if(last_update && (gains || losses))
      anomaly_index = (100 - (100 / (float)(1 + ((float)(gains) / (float)(losses) + 1))));
    else
      anomaly_index = 0;
    
#ifdef MONITOREDMETRIC_DEBUG
    if((anomaly_index > 0) && ((anomaly_index < 25) || (anomaly_index > 75)) && (gains > 0))
      printf("%s[%s] [RSI: %u][gains: %lu][losses: %lu]\n",
	     ((anomaly_index < 25) || (anomaly_index > 75)) ? "<<<***>>> Anomaly " : "",
	     __FUNCTION__, (unsigned int)anomaly_index, (unsigned long)gains, (unsigned long)losses);
#endif
  }
  
  static METRICTYPE ewma(METRICTYPE sample, METRICTYPE ewma, u_int8_t alpha_percent = 50) {
    // if(alpha_percent > 100) alpha_percent = 100;
    return((alpha_percent * sample + (100 - alpha_percent) * ewma) / 100);
  }

public:
  MonitoredMetric() {
    reset();
  }
  virtual ~MonitoredMetric() {};

  virtual void reset() {
    value = last_value = gains = losses = last_update = anomaly_index = 0;
  }
  inline METRICTYPE get()             const { return(value);         }
  inline METRICTYPE getAnomalyIndex() const { return(anomaly_index); }
  virtual void computeAnomalyIndex(time_t when) = 0;
  inline bool is_anomalous(time_t when, u_int8_t low_threshold = 25, u_int8_t high_threshold = 75) const {
    return(((anomaly_index > 0 && anomaly_index < low_threshold) || (anomaly_index > high_threshold)) ? true : false);
  }
  
  inline void setInitialValue(METRICTYPE v) {
    reset();
    value = v;
  }

  inline float inc(time_t when, METRICTYPE v) {
    value += v;
    return(anomaly_index /* Last computed */);
  }
  const char * const print(char * const buf, ssize_t buf_size) {
    if(buf && buf_size) {
      snprintf(buf, buf_size, "%s[value: %lu][last_value: %lu][RSI: %lu][gains: %lu][losses: %lu]\n",
	       this->is_anomalous(0) ? "<<<***>>> Anomaly " : "",
	       (unsigned long)this->value, (unsigned long)this->last_value,
	       (unsigned long)this->anomaly_index, (unsigned long)this->gains, (unsigned long)this->losses);
    }

    return buf;
  }
};

#endif /* _MONITORED_METRIC_H_ */

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

#ifndef _MONITORED_COUNTER_H_
#define _MONITORED_COUNTER_H_


template <typename COUNTERTYPE> class MonitoredCounter {
 private:
  COUNTERTYPE value, last_value, gains, losses, prev_diff;
  time_t      last_update;
  COUNTERTYPE anomaly_index;
  
  inline void computeMinuteAnomalyIndex(time_t when) {
    if((when - last_update) > 60 /* Do not update more frequently than a minute */) {
      /* https://en.wikipedia.org/wiki/Relative_strength_index RSI-like index */
      COUNTERTYPE diff = value - last_value;
      int64_t delta = (int64_t)(diff - prev_diff);
      
      if(delta > 0)
	gains = ewma(delta, gains);
      else
	losses = ewma(-delta, losses);

      if(losses > 0)
	anomaly_index = (100 - (100 / (float)(1 + ((float)gains / (float)losses))));
      else
	anomaly_index = 0;

#ifdef MONITOREDCOUNTER_DEBUG
      printf("=> [value: %lu][diff/prev_diff: %lu/%lu][delta: %ld][RSI: %lu][gains: %lu][losses: %lu]\n",
	     (unsigned long)value, (unsigned long)diff, (unsigned long)prev_diff, (long)delta,
	     (unsigned long)anomaly_index, (unsigned long)gains, (unsigned long)losses);
      
      if((anomaly_index > 0) /* && ((anomaly_index < 25) || (anomaly_index > 75)) && (gains > 0) */)
	printf("%s[%s] [RSI %u][gains: %lu][losses: %lu]\n",
	       ((anomaly_index < 25) || (anomaly_index > 75)) ? "<<<***>>> Anomaly " : "",
	       __FUNCTION__, (unsigned int)anomaly_index, (unsigned long)gains, (unsigned long)losses);
      
#endif
      
      last_update = when, last_value = value, prev_diff = diff;
    }
  }
  
  inline COUNTERTYPE ewma(COUNTERTYPE sample, COUNTERTYPE ewma, u_int8_t alpha_percent = 30) {
    // if(alpha_percent > 100) alpha_percent = 100;
    return((alpha_percent * sample + (100 - alpha_percent) * ewma) / 100);
  }

public:
  MonitoredCounter() {
    reset();
  }

  inline void reset() {
    prev_diff = value = last_value = gains = losses = 0, last_update = 0, anomaly_index = 0;
  }

  inline COUNTERTYPE get()             { return(value);         }
  inline COUNTERTYPE getAnomalyIndex() { return(anomaly_index); }

  inline bool is_anomalous(time_t when, u_int8_t low_threshold = 25, u_int8_t high_threshold = 75) {
    computeMinuteAnomalyIndex(when); /* Update if necesary */
    return(((anomaly_index < low_threshold) || (anomaly_index > high_threshold)) ? true : false);
  }
  
  inline void setInitialValue(COUNTERTYPE v) {
    reset(), value = v;
  }

  inline float dec(time_t when, COUNTERTYPE v) {
    return(inc(when, -v));
  }

  inline float inc(time_t when, COUNTERTYPE v) {
    value += v;
    
    computeMinuteAnomalyIndex(when); /* Update if necesary */
         
    return(anomaly_index /* Last computed */);
  }
};

#endif /* _MONITORED_COUNTER_H_ */

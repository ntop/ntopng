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
  COUNTERTYPE last_value, gains, losses, losses_prev, gains_prev;
  u_int32_t num_loops;
  u_int16_t observation_window;

 public:
  MonitoredCounter(u_int16_t window_len = 10) {
    observation_window = window_len, reset();
  }
  inline void reset()      { last_value = gains = losses = losses_prev = gains_prev = 0, num_loops = 0; }
  inline COUNTERTYPE get() { return(last_value); }

  inline bool is_anomalous(u_int8_t low_threshold = 25, u_int8_t high_threshold = 75) {
    return(((last_value < low_threshold) || (last_value > high_threshold))
	   && (num_loops > observation_window) ? true : false);
  }
  inline u_int8_t dec(COUNTERTYPE value) { return(inc(-value)); }
  inline u_int8_t inc(COUNTERTYPE value) {
    int64_t delta;
    u_int8_t rsi_val;

    if(num_loops > 0) {
      u_int64_t losses_diff;

      delta = (int64_t)(value-last_value);
      
      if(delta > 0)
	gains = gains + delta;
      else
	losses = losses - delta;

      /* https://en.wikipedia.org/wiki/Relative_strength_index */
      if((losses_diff = losses-losses_prev) > 0)
	rsi_val = (u_int8_t)(100 - (100 / (1 + ((gains-gains_prev) / losses_diff))));
      else
	rsi_val = 0;

#ifdef MONITOREDCOUNTER_DEBUG
      if((num_loops > observation_window) && (rsi_val > 0) && (gains > 0))
	printf("%s[%s] Anomaly [RSI %u][%ld delta][gains: %lu][losses: %lu]\n",
	       ((rsi_val < 25) || (rsi_val > 75)) ? "<<<***>>>" : "",
	       __FUNCTION__, rsi_val, (long)delta, (unsigned long)gains, (unsigned long)losses);
#endif
      if(num_loops > observation_window) {
	if(delta > 0)
	  gains_prev = gains_prev + delta;
	else
	  losses_prev = losses_prev - delta;
      }
    } else
      rsi_val = 0;

    last_value = value, num_loops++;

    return(rsi_val);
  }
};

#endif /* _MONITORED_COUNTER_H_ */

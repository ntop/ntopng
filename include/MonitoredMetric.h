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

#ifndef _MONITORED_METRIC_H_
#define _MONITORED_METRIC_H_

template <typename METRICTYPE> class MonitoredMetric {
 protected:
  METRICTYPE value, last_value, gains, losses;
  time_t     last_update;
  METRICTYPE anomaly_index;

  inline void updateAnomalyIndex(time_t when, int64_t delta) {
    if(delta > 0)
      gains = ewma((METRICTYPE)delta, gains),
	losses = ewma(0, losses);
    else
      gains = ewma(0, gains),
        losses = ewma((METRICTYPE)-delta, losses);

    anomaly_index = 0;
    if(delta /* No variation -> no anomaly */
       && last_update /* Wait at least two points */
       && (gains || losses) /* Meaningless to calculate an anomaly when both are at zero */) {
      float gain_loss_ratio = 1;
      if (losses != 0)
        gain_loss_ratio = (float)(gains) / (float)(losses) + 1;
      if (gain_loss_ratio != 0)
        anomaly_index = (METRICTYPE)(100 - (100 / (float)(gain_loss_ratio)));
    }
    
#ifdef MONITOREDMETRIC_DEBUG
    if((anomaly_index > 0) && ((anomaly_index < 25) || (anomaly_index > 75)) && (gains > 0))
      printf("%s[%s] [RSI: %u][gains: %lu][losses: %lu][delta: %" PRId64 "][last_update: %u]\n",
	     is_misbehaving(when) ? "<<<***>>> Anomaly " : "",
	     __FUNCTION__, (unsigned int)anomaly_index, (unsigned long)gains, (unsigned long)losses,
	     delta, (unsigned int)last_update);
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
    value = 0, last_value = 0, gains = 0, losses = 0, last_update = 0, anomaly_index = 0;
  }
  inline METRICTYPE get()             const { return(value);         }
  inline METRICTYPE getAnomalyIndex() const { return(anomaly_index); }
  virtual void computeAnomalyIndex(time_t when) = 0;
  inline bool is_misbehaving(time_t when, u_int8_t low_threshold = 25, u_int8_t high_threshold = 75) const {
    return(last_update
	   && ((anomaly_index > 0 && anomaly_index < low_threshold) || (anomaly_index > high_threshold)) ? true : false);
  }
  
  inline void setInitialValue(METRICTYPE v) {
    reset();
    last_value = value = v;
  }

  inline float inc(METRICTYPE v) {
    value += v;
    return((float)anomaly_index /* Last computed */);
  }

  const char * const print(char * const buf, ssize_t buf_size) {
    if(buf && buf_size) {
      snprintf(buf, buf_size, "%s[value: %lu][last_value: %lu][RSI: %lu][gains: %lu][losses: %lu][last_update: %u]\n",
	       this->is_misbehaving(0) ? "<<<***>>> Anomaly " : "",
	       (unsigned long)this->value, (unsigned long)this->last_value,
	       (unsigned long)this->anomaly_index, (unsigned long)this->gains, (unsigned long)this->losses,
	       (unsigned int)this->last_update);
    }

    return buf;
  }

  void const lua(lua_State *vm, const char *table_key) const {
#ifdef MONITOREDMETRIC_DEBUG
    char buf[128];
    printf("Lua anomaly [%s] %s", table_key, print(buf, sizeof(buf)));
#endif

    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "anomaly_index", anomaly_index);
    lua_push_uint64_table_entry(vm, "value", value);
    lua_push_uint64_table_entry(vm, "last_value", last_value);

    lua_pushstring(vm, table_key);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
};

#endif /* _MONITORED_METRIC_H_ */

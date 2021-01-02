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

#ifndef _MONITORED_COUNTER_H_
#define _MONITORED_COUNTER_H_


template <typename METRICTYPE> class MonitoredCounter : public MonitoredMetric<METRICTYPE> {
 private:
  METRICTYPE last_diff;

 public:
  void computeAnomalyIndex(time_t when) {
    if((when - this->last_update) > 60 /* Do not update more frequently than a minute */) {
      /* https://en.wikipedia.org/wiki/Relative_strength_index RSI-like index */
      METRICTYPE diff = this->value - this->last_value;
      int64_t delta = (int64_t)(diff) - last_diff;

      this->updateAnomalyIndex(when, delta);

#ifdef MONITOREDCOUNTER_DEBUG
      printf("%s[MonitoredCounter][value: %lu][diff: %lu][last_diff: %lu][delta: %ld][RSI: %lu][gains: %lu][losses: %lu]\n",
	     this->is_misbehaving(when) ? "<<<***>>> Anomaly " : "",
             (unsigned long)this->value, (unsigned long)diff, (unsigned long)last_diff, (long)delta,
	     (unsigned long)this->anomaly_index, (unsigned long)this->gains, (unsigned long)this->losses);
#endif

      this->last_update = when, this->last_value = this->value, this->last_diff = diff;
    }
  }

  virtual void reset() {
    last_diff = 0;
    MonitoredMetric<METRICTYPE>::reset();
  }
};

#endif /* _MONITORED_COUNTER_H_ */

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

#ifndef _MONITORED_GAUGE_H_
#define _MONITORED_GAUGE_H_


template <typename METRICTYPE> class MonitoredGauge : public MonitoredMetric<METRICTYPE> {
 public:
  void computeAnomalyIndex(time_t when) {
    if((when - this->last_update) > 60 /* Do not update more frequently than a minute */) {
      /* https://en.wikipedia.org/wiki/Relative_strength_index RSI-like index */
      int64_t delta = ((int64_t)(this->value) - this->last_value) / (when - this->last_update);

      this->updateAnomalyIndex(when, delta);

#ifdef MONITOREDGAUGE_DEBUG
      if(this->anomaly_index)
	printf("%s[MonitoredGauge][value: %lu][delta: %ld][RSI: %lu][gains: %lu][losses: %lu]\n",
	       this->is_misbehaving(when) ? "<<<***>>> Anomaly " : "",
	       (unsigned long)this->value, (long)delta,
	       (unsigned long)this->anomaly_index, (unsigned long)this->gains, (unsigned long)this->losses);
#endif

      this->last_update = when, this->last_value = this->value;
    }
  }
  
  inline float dec(METRICTYPE v) {
    /* Don't worry about int/u_int, look at the arithmetics and you will see that is always works */
    return(this->inc(-v));
  }
};

#endif /* _MONITORED_GAUGE_H_ */

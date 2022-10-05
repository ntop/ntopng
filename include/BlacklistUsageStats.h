/*
 *
 * (C) 2019-22 - ntop.org
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

#ifndef _BLACKLIST_USAGE_STATS_H_
#define _BLACKLIST_USAGE_STATS_H_

class BlacklistUsageStats {
 private:
  u_int32_t num_hits;
  
#ifdef FULL_BL_STATS
  u_int32_t num_true_positives, /* the number of IPs that attack and are in the blacklist      */
    num_false_positives,        /* the number IPs that are in the blacklist but didn't attack  */
    num_false_negatives,        /* the number of IPs that attacked but are not in the blacklist */
    num_true_negatives;         /* the number of IPs that didn't attack and are not in the blacklist, or 2^32 */
#endif
  
public:
  BlacklistUsageStats() {
    num_hits = 0;
#ifdef FULL_BL_STATS
    num_true_positives = num_false_positives = num_false_negatives = num_true_negatives = 0;
#endif
  }

#ifdef FULL_BL_STATS
  inline float correlationCoefficient() {
    /* https://en.wikipedia.org/wiki/Phi_coefficient */
    u_int32_t num = (num_true_positives+num_true_negatives) - (num_false_positives * num_false_negatives);
    u_int32_t den = (num_true_positives+cnum_true_positives) * (num_true_positives+num_false_negatives)
      * (num_true_negatives + num_false_positives) * (num_true_negatives + num_false_negatives);
    
    return((den == 0) ? 0. : ((float)num / sqrt(num)));
  }
  
  inline void inc(u_int32_t tp, u_int32_t fp, u_int32_t fn, u_int32_t tn) {
    num_true_positives += tp, num_false_positives += fp, num_false_negatives += fn, num_true_negatives += tn;
  }
  
  inline void get(u_int32_t *tp, u_int32_t *fp, u_int32_t *fn, u_int32_t *tn) {
    *tp = num_true_positives, *fp = num_false_positives, *fn = num_false_negatives, *tn = num_true_negatives;    
  }
#endif
  
  inline void incHits()         { num_hits++;       }
  inline u_int32_t getNumHits() { return(num_hits); }
};


#endif /* _BLACKLIST_USAGE_STATS_H_ */

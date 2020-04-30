/*
 *
 * (C) 2019 - ntop.org
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

#ifndef _CONTINUOUS_PING_STATS_H_
#define _CONTINUOUS_PING_STATS_H_

#ifndef WIN32

struct cp_stats {
  u_int32_t num_ping_sent, num_ping_rcvd;
  float min_rtt, max_rtt, last_rtt, diff_sum, rtt_sum;
};

/* ***************************************** */

class ContinuousPingStats {
 private:
  time_t last_refresh;
  struct cp_stats stats;

 public:
  ContinuousPingStats() { reset(); heartbeat(); }

  inline void getStats(struct cp_stats *out) { memcpy(&out, &stats, sizeof(struct cp_stats)); }
  inline void heartbeat()                    { last_refresh = time(NULL);                     }
  inline void incSent()                      { stats.num_ping_sent++;                         }
  inline time_t getLastHeartbeat()           { return(last_refresh);                          }
  void update(float rtt);
  float getSuccessRate(float *min_rtt, float *max_rtt, float *jitter, float *mean);
  inline void reset() { memset(&stats, 0, sizeof(stats)); }
};

#endif /* WIN32 */

#endif /* _CONTINUOUS_PING_STATS_H_ */

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

#ifndef _CONTINUOUS_PING_H_
#define _CONTINUOUS_PING_H_

#ifndef WIN32

struct cp_stats {
  time_t last_refresh;
  u_int32_t num_ping_sent, num_ping_rcvd;
  float min_rtt, max_rtt, last_rtt;
};

/* ***************************************** */
  
class ContinuousPingStats {
 private:
  struct cp_stats stats;

 public:
  ContinuousPingStats() { reset(); }

  inline void getStats(struct cp_stats *out) { memcpy(&out, &stats, sizeof(struct cp_stats)); }
  inline void heartbeat()                    { stats.last_refresh = time(NULL);               }
  inline void incSent()                      { stats.num_ping_sent++;                         }
  inline void update(float rtt) {
    stats.num_ping_rcvd++, stats.last_rtt = rtt;
    stats.min_rtt = (stats.num_ping_rcvd == 1) ? rtt : min(stats.min_rtt, rtt);
    stats.max_rtt = max(stats.max_rtt, rtt);
  }  

  inline float getSuccessRate(float *min_rtt, float *max_rtt) {
    float pctg = (stats.num_ping_sent == 0) ? 0 : (float)(stats.num_ping_rcvd*100)/(float)(stats.num_ping_sent);
      
    *min_rtt = stats.min_rtt, *max_rtt = stats.max_rtt;

    return(pctg);
  }
  
  inline void reset() { memset(&stats, 0, sizeof(stats)); heartbeat(); }
};

/* ***************************************** */

class ContinuousPing {
 private:
  std::map<std::string /* IP */, ContinuousPingStats* /* stats */> v4_results, v6_results;
  Ping *pinger;
  pthread_t poller;
  Mutex m;

  void pingAll();
  void readPingResults();
  
 public:
  ContinuousPing();
  ~ContinuousPing();

  void runPingCampaign();
  void ping(char *_addr, bool use_v6);
  void pollResults();
  void collectResponses(lua_State* vm);    
};

#endif /* WIN32    */
#endif /* _CONTINUOUS_PING_H_ */

/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef WIN32

#include "ntop_includes.h"

/* #define TRACE_PING */

/* ***************************************** */

void ContinuousPingStats::update(float rtt) {
  stats.num_ping_sent++, stats.num_ping_rcvd++;
  
  if(rtt > 0) {
    stats.diff_sum += fabs(stats.last_rtt - rtt);
    stats.rtt_sum += rtt, stats.last_rtt = rtt;
    stats.min_rtt  = (stats.num_ping_rcvd == 1) ? rtt : min(stats.min_rtt, rtt);
    stats.max_rtt  = max(stats.max_rtt, rtt);
  }
}  

/* ***************************************** */

float ContinuousPingStats::getSuccessRate(float *min_rtt, float *max_rtt, float *jitter, float *mean) {
  float pctg = min((stats.num_ping_sent == 0) ? 0 : (float)(stats.num_ping_rcvd*100)/(float)(stats.num_ping_sent), 100.f);

  *min_rtt = stats.min_rtt, *max_rtt = stats.max_rtt;
  *mean   = (stats.num_ping_rcvd == 0) ? 0 : stats.rtt_sum/stats.num_ping_rcvd;
  *jitter = (stats.num_ping_rcvd <  2) ? 0 : (stats.diff_sum / (stats.num_ping_rcvd-1));
  
#ifdef TRACE_PING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[sent: %u][rcvd: %u][RTT: %.3f/%.3f][Mean/Jitter: %.3f / %.3f]",
			       stats.num_ping_sent, stats.num_ping_rcvd,
			       stats.min_rtt, stats.max_rtt, *mean, *jitter);
#endif
  
  return(pctg);
}

#endif /* WIN32 */

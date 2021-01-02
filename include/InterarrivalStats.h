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

#ifndef _INTERARRIVAL_STATS_H_
#define _INTERARRIVAL_STATS_H_

#include "ntop_includes.h"

class InterarrivalStats {
private:
  struct timeval lastTime;
  ndpi_analyze_struct delta_ms;

public:
  InterarrivalStats();

  void updatePacketStats(struct timeval *when, bool update_iat);

  inline u_int32_t getMin()    { return(ndpi_data_min(&delta_ms));     }
  inline u_int32_t getMax()    { return(ndpi_data_max(&delta_ms));     }
  inline float     getAvg()    { return(ndpi_data_average(&delta_ms)); }
  inline float     getStdDev() { return(ndpi_data_stddev(&delta_ms));  }
};

#endif /* _INTERARRIVAL_STATS_H_ */

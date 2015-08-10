/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _ACTIVITY_STATS_H_
#define _ACTIVITY_STATS_H_

#include "ntop_includes.h"

#define ACTIVITY_BITS         32
#define NUM_ACTIVITY_BITS     (1+(CONST_MAX_ACTIVITY_DURATION/ACTIVITY_BITS))
#define ACTIVITY_SET(p, n)    ((p)->bits[(n)/ACTIVITY_BITS] |= (1 << (((u_int32_t)n) % ACTIVITY_BITS)))
#define ACTIVITY_CLR(p, n)    ((p)->bits[(n)/ACTIVITY_BITS] &= ~(1 << (((u_int32_t)n) % ACTIVITY_BITS)))
#define ACTIVITY_ISSET(p, n)  ((p)->bits[(n)/ACTIVITY_BITS] & (1 << (((u_int32_t)n) % ACTIVITY_BITS)))
#define ACTIVITY_ZERO(p)      memset((char *)(p), 0, sizeof(*(p)))
#define ACTIVITY_ONE(p)       memset((char *)(p), 0xFF, sizeof(*(p)))

typedef struct {
  u_int32_t  bits[NUM_ACTIVITY_BITS];
} activity_bitmap;

/*
  Statistics for 1 day (86400 sec) 
*/

class ActivityStats {
 private:
  time_t begin_time, wrap_time, last_set_time, last_set_requested;
  activity_bitmap bitset;

 public:
  ActivityStats(time_t when=0);

  void reset();
  void set(time_t when);
  void extractPoints(u_int8_t *elems);
  std::stringstream* getDump();
  void setDump(std::stringstream* dump);
  bool writeDump(char* path);
  bool readDump(char* path);
  json_object* getJSONObject();
  char* serialize();  
  void deserialize(json_object *o);
  inline time_t get_wrap_time() { return(wrap_time); };
  /* Returns the Pearson correlation coefficient */
  double pearsonCorrelation(ActivityStats *s);
};

#endif /* _ACTIVITY_STATS_H_ */

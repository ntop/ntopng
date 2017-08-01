/*
 *
 * (C) 2013-17 - ntop.org
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
  void extractPoints(activity_bitmap *b);
  std::stringstream* getDump();
  void setDump(std::stringstream* dump);
  bool writeDump(char* path);
  bool readDump(char* path);
  json_object* getJSONObject();
  char* serialize();  
  void deserialize(json_object *o);
  inline time_t get_wrap_time() { return(wrap_time); };
};

#endif /* _ACTIVITY_STATS_H_ */

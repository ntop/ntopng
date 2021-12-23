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

#ifndef _ROUND_TRIP_STATS_H_
#define _ROUND_TRIP_STATS_H_

class RoundTripStats {
 private:
   u_int32_t stats[10];
   u_int8_t stats_it;

 public:
   RoundTripStats();
   ~RoundTripStats();
    
   void addPoint(u_int32_t thpt);
   void sum(RoundTripStats *_stats);    
   void luaRTStats(lua_State* vm, const char *stats_name);
   inline u_int32_t *getStats() { return(stats); };
};

#endif /* _ROUND_TRIP_STATS_H_ */

/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _NTOP_HOST_SCORE_H_
#define _NTOP_HOST_SCORE_H_

class HostScore {
 private:
  u_int16_t cli_score[MAX_NUM_SCORE_CATEGORIES], srv_score[MAX_NUM_SCORE_CATEGORIES];
  u_int16_t last_min_dec; /* Account the number of decrements in the last minute */
  u_int32_t next_reset_decrement_time;
  
  u_int32_t sum(const bool as_client);
  void lua_breakdown(lua_State *vm, bool as_client);

  void inline checkDecrementReset(time_t when) {
    if(((u_int32_t)when) > next_reset_decrement_time)
      last_min_dec = 0, next_reset_decrement_time = when+60;   
  }
  
 public:
  HostScore();

  inline u_int32_t get()                { return(getClient() + getServer()); };
  inline u_int32_t getClient()          { return(sum(true  /* as client */));    };
  inline u_int32_t getServer()          { return(sum(false /* as server */));    };
  inline u_int32_t getLastMinPeak(time_t when=0) {
    if(when) checkDecrementReset(when);
    return(last_min_dec+get());
  }
  
  u_int16_t incValue(u_int16_t score, ScoreCategory score_category, bool as_client);
  u_int16_t decValue(time_t when, u_int16_t score, ScoreCategory score_category, bool as_client);

  void lua_breakdown(lua_State *vm);
};

#endif

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

#ifndef _NTOP_SCORE_STATS_H_
#define _NTOP_SCORE_STATS_H_

class ScoreStats {
 private:

 protected:
  u_int32_t cli_score[MAX_NUM_SCORE_CATEGORIES], srv_score[MAX_NUM_SCORE_CATEGORIES];
  
  static u_int64_t sum(u_int32_t const scores[]);
  static u_int16_t incValue(u_int32_t scores[], u_int16_t score, ScoreCategory score_category);
  static u_int16_t decValue(u_int32_t scores[], u_int16_t score, ScoreCategory score_category);

  void lua_breakdown(lua_State *vm, bool as_client);
  
 public:
  ScoreStats();
  virtual ~ScoreStats() {};

  /* Total getters */
  u_int64_t get()               const { return(getClient() + getServer()); };
  virtual u_int64_t getClient() const { return(sum(cli_score /* as client */)); };
  virtual u_int64_t getServer() const { return(sum(srv_score /* as server */)); };

  /* Getters by category */
  virtual u_int32_t getClient(ScoreCategory sc) const { return(cli_score[sc]); };
  virtual u_int32_t getServer(ScoreCategory sc) const { return(srv_score[sc]); };

  u_int16_t incValue(u_int16_t score, ScoreCategory score_category, bool as_client);
  virtual u_int16_t decValue(u_int16_t score, ScoreCategory score_category, bool as_client);

  void lua_breakdown(lua_State *vm);
  void serialize_breakdown(ndpi_serializer* serializer);
};

#endif

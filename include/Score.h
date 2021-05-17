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

#ifndef _NTOP_SCORE_H_
#define _NTOP_SCORE_H_

class Score {
 private:
  bool view_interface_score;
  ScoreStats *score; /* A pointer to the score class, which depents on view/non-view interfaces */
  
 public:
  Score(NetworkInterface *_iface);
  virtual ~Score();

  inline u_int32_t getScore()         const { return score ? score->get() : 0; };
  inline u_int32_t getScoreAsClient() const { return score ? score->getClient() : 0; };
  inline u_int32_t getScoreAsServer() const { return score ? score->getServer() : 0; };
  inline void serialize_breakdown(ndpi_serializer* serializer) const { if(score) score->serialize_breakdown(serializer); };
  u_int16_t incScoreValue(u_int16_t score_incr, ScoreCategory score_category, bool as_client);
  u_int16_t decScoreValue(u_int16_t score_decr, ScoreCategory score_category, bool as_client);

  void lua_get_score(lua_State* vm);
  void lua_get_score_breakdown(lua_State* vm);
};

#endif

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

  u_int32_t sumValues(const bool as_client) const;
  void lua_breakdown(lua_State *vm, bool as_client) const;

 public:
  HostScore();

  inline u_int32_t getValue()        const { return getClientValue() + getServerValue(); };
  inline u_int32_t getClientValue()  const { return sumValues(true  /* as client */);    };
  inline u_int32_t getServerValue()  const { return sumValues(false /* as server */);    };

  u_int16_t incValue(u_int16_t score, ScoreCategory score_category, bool as_client);
  u_int16_t decValue(u_int16_t score, ScoreCategory score_category, bool as_client);

  void lua_breakdown(lua_State *vm) const;
};

#endif

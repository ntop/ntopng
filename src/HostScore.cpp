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

#include "ntop_includes.h"

/* *************************************** */

HostScore::HostScore() {
  memset(&cli_score, 0, sizeof(cli_score)),
    memset(&srv_score, 0, sizeof(srv_score));
}

/* *************************************** */

u_int32_t HostScore::sumValues(bool as_client) const {
  u_int32_t res = 0;
  const u_int16_t *src = as_client ? cli_score : srv_score;

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++)
    res += src[i];

  return res;
};

/* *************************************** */

/*
  Increases a value for the `score_category` score by `score`. Client/server score is increased,
  according to parameter `as_client`. The actual increment performed is returned by the function.
  NOTE: The actual increment performed can be less than `score`, if incrementing by `score` would have
  caused an overflow.

  HostScore::incValue must be called from the same thread of HostScore::decValue to prevent races.
*/
u_int16_t HostScore::incValue(u_int16_t score, ScoreCategory score_category, bool as_client) {
  u_int16_t *dst = as_client ? cli_score : srv_score;
  u_int16_t actual_inc = 0;

  if(score_category >= MAX_NUM_SCORE_CATEGORIES || score == 0)
    return 0;

  if(dst[score_category] + score <= (u_int16_t)-1) {
    /* Enough room to do a full increment by `score` */
    actual_inc = score;
    dst[score_category] += score;
  } else if (dst[score_category] < (u_int16_t)-1){
    /* Not enough room to do a full increment by `score`, let's reach the maximum possible value and set the
       actual increment performed. */
    actual_inc = (u_int16_t)-1 - dst[score_category];
    dst[score_category] += actual_inc;
  }

  return actual_inc;
}

/* *************************************** */

/*
  Decreases a value for the `score_category` score by `score`. Client/server score is decreased,
  according to parameter `as_client`. The actual decrement performed is returned by the function.
  NOTE: The actual decrement is either `score` or zero if `score_category` is unknown.

  HostScore::decValue must be called from the same thread of HostScore::incValue to prevent races.
*/
u_int16_t HostScore::decValue(u_int16_t score, ScoreCategory score_category, bool as_client) {
  u_int16_t *dst = as_client ? cli_score : srv_score;

  if(score_category >= MAX_NUM_SCORE_CATEGORIES || score == 0)
    return 0;

  if(dst[score_category] - score >= 0)
    /* Decrement leaves the destination consistent */
    dst[score_category] -= score;
  else
    /* Something was wrong */
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error. Decrement of host score yielding a negative number.");

  return score;
}

/* *************************************** */

void HostScore::lua_breakdown(lua_State *vm, bool as_client) const {
  u_int32_t total = 0;
  const u_int16_t *src = as_client ? cli_score : srv_score;

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++)
    total += src[i];

  if(total == 0) total = 1; /* Prevents zero-division errors */

  lua_newtable(vm);

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++) {
    lua_pushinteger(vm, i); /* The integer category id as key */
    lua_pushnumber(vm, src[i] / (float)total * 100); /* The % as value */
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, as_client ? "as_client" : "as_server");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

/*
  Outputs Lua tables for client and server per-category score breakdown.
*/
void HostScore::lua_breakdown(lua_State *vm) const {
  lua_newtable(vm);

  lua_breakdown(vm, true  /* as client */);
  lua_breakdown(vm, false /* as server */);

  lua_pushstring(vm, "score_pct");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

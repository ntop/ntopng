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

ScoreStats::ScoreStats() {
  memset(&cli_score, 0, sizeof(cli_score)),
    memset(&srv_score, 0, sizeof(srv_score));
}

/* *************************************** */

u_int64_t ScoreStats::sum(u_int32_t const scores[]) {
  u_int64_t res = 0;

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++)
    res += scores[i];

  return res;
};

/* *************************************** */

/*
  Increases a value for the `score_category` score by `score`. Client/server score is increased,
  according to parameter `as_client`. The actual increment performed is returned by the function.
*/
u_int16_t ScoreStats::incValue(u_int32_t scores[], u_int16_t score, ScoreCategory score_category) {
  scores[score_category] += score;

  return score;
}

/* *************************************** */

/*
  Decreases a value for the `score_category` score by `score`. Client/server score is decreased,
  according to parameter `as_client`. The actual decrement performed is returned by the function.
*/
u_int16_t ScoreStats::decValue(u_int32_t scores[], u_int16_t score, ScoreCategory score_category) {
  scores[score_category] -= score;

  return score;
}

/* *************************************** */

u_int16_t ScoreStats::incValue(u_int16_t score, ScoreCategory score_category, bool as_client) {
  return as_client ? incValue(cli_score, score, score_category) : incValue(srv_score, score, score_category);
}

/* *************************************** */

u_int16_t ScoreStats::decValue(u_int16_t score, ScoreCategory score_category, bool as_client) {
  return as_client ? decValue(cli_score, score, score_category) : decValue(srv_score, score, score_category);
}

/* *************************************** */

void ScoreStats::lua_breakdown(lua_State *vm, bool as_client) {
  u_int32_t total = as_client ? getClient() : getServer();

  if(total == 0) total = 1; /* Prevents zero-division errors */

  lua_newtable(vm);

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++) {
    ScoreCategory score_category = (ScoreCategory)i;

    lua_pushinteger(vm, i); /* The integer category id as key */
    lua_pushnumber(vm, (as_client ? getClient(score_category) : getServer(score_category)) / (float)total * 100); /* The % as value */
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, as_client ? "score_breakdown_client" : "score_breakdown_server");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

/*
  Outputs Lua tables for client and server per-category score breakdown.
*/
void ScoreStats::lua_breakdown(lua_State *vm) {
  lua_newtable(vm);

  lua_breakdown(vm, true  /* as client */);
  lua_breakdown(vm, false /* as server */);

  lua_pushstring(vm, "score_pct");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

/*
  Serialize for client and server per-category score breakdown.
  Used by ScoreAnomalyAlert.h
*/
void ScoreStats::serialize_breakdown(ndpi_serializer* serializer) {
  u_int32_t total = getClient();

  if(total == 0) total = 1; /* Prevents zero-division errors */

  /* Client breakdown score value per category */
  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++) {
    ScoreCategory score_category = (ScoreCategory)i;
    std::string score_cat = "score_breakdown_client_" + std::to_string(i);
  
    ndpi_serialize_string_uint64(serializer, score_cat.c_str(), getClient(score_category) / (float)total * 100);
  }

  /* Server breakdown score value per category */
  total = getServer();

  if(total == 0) total = 1; /* Prevents zero-division errors */

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++) {
    ScoreCategory score_category = (ScoreCategory)i;
    std::string score_cat = "score_breakdown_server_" + std::to_string(i);
  
    ndpi_serialize_string_uint64(serializer, score_cat.c_str(), getServer(score_category) / (float)total * 100);
  }
}

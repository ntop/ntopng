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

u_int32_t HostScore::sumOldValues(const score_t score[MAX_NUM_SCRIPT_CATEGORIES]) {
  u_int32_t res = 0;

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++)
    res += score[i].old_score;

  return res;
};

/* *************************************** */

void HostScore::refreshValue(score_t *score) {
  /* Add the score calculated on the idle flows */
  score->new_score += score->idle_flow_score;

  /* Consolidate the new_score and prepare the counter for the next run */
  score->old_score = score->new_score;

  /* Reset new scores to start counting again */
  score->new_score = score->idle_flow_score = 0;
}

/* *************************************** */

/* This should be called once per minute. It computes the "visible" score
 * value (the one returned by getValue()). */
void HostScore::refreshValue() {
  /* Lock to access the idle score which is updated in another thread different from this */
  m.lock(__FILE__, __LINE__);

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++)
    refreshValue(&cli_score[i]),
      refreshValue(&srv_score[i]);

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

/* This should be called once per minute. It computes the "visible" score
 * value (the one returned by getValue()). */
void HostScore::incValue(const u_int16_t score[MAX_NUM_SCRIPT_CATEGORIES], bool as_client) {
  score_t *dst = as_client ? cli_score : srv_score;

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++)
    dst[i].new_score += score[i];
}

/* *************************************** */

/* This is called on short-lived flows which go idle */
void HostScore::incIdleFlowScore(const u_int16_t score[MAX_NUM_SCRIPT_CATEGORIES], bool as_client) {
  score_t *dst = as_client ? cli_score : srv_score;
  /*
    Necessary to lock as the increase on idle flow scores is performed from a thread
    which is different from the one who reads the same values.
  */
  m.lock(__FILE__, __LINE__);

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++) {
    dst[i].idle_flow_score += score[i];
  }

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void HostScore::lua_breakdown(lua_State *vm, const score_t score[MAX_NUM_SCRIPT_CATEGORIES], const char * const key) {
  u_int32_t total = 0;
  u_int16_t snapshot[MAX_NUM_SCRIPT_CATEGORIES];

  /* Snapshot current scores so they won't change in-use
     Also compute the total so that we can return results as a percentage.
     Lock as old_scores may be reset.
  */
  m.lock(__FILE__, __LINE__);

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++)
    snapshot[i] = score[i].old_score, total += score[i].old_score;

  m.unlock(__FILE__, __LINE__);

  if(total == 0) total = 1; /* Prevents zero-division errors */

  lua_newtable(vm);

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++) {
    lua_pushinteger(vm, i); /* The integer category id as key */
    lua_pushnumber(vm, snapshot[i] / (float)total * 100); /* The % as value */
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, key);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void HostScore::lua_breakdown(lua_State *vm) {
  lua_newtable(vm);

  lua_breakdown(vm, cli_score, "as_client");
  lua_breakdown(vm, srv_score, "as_server");

  lua_pushstring(vm, "score_pct");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

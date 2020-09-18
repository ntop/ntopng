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
  memset(&cat_cli_score, 0, sizeof(cat_cli_score)),
    memset(&cat_srv_score, 0, sizeof(cat_srv_score));;
}

/* *************************************** */

/* Increases a category score passed as a pointer in `result` by `val` */
void HostScore::compressAndIncCatScore(u_int8_t *result, u_int16_t val) {
  /*
    Compress the actual `val` into a number which stays in a u_int8_t.
    Compression is done using a shift for a compression factor of 256, that is:
    - A score between 1 and 255 is compressed in:      1
    - A score between 256 and 511 is compressed in:    2
    - A score between 512 and 1023 is compressed in:   3
    - ... and so on
  */
  u_int8_t compressed_val = (val >> 8) + 1;

  if(*result + compressed_val <= CAT_SCORE_MAX)
    /* Adding the compressed val doesn't cause the counter to wrap. */
    *result += compressed_val;
  else if(*result < CAT_SCORE_MAX)
    /* Adding the compressed val would have caused the counter to wrap, so
       the counter is just set to its maximum value. */
    *result = CAT_SCORE_MAX;
}

/* *************************************** */

void HostScore::incCategoryValue(category_score_t *cat_score, u_int16_t val, ScriptCategory script_category) {
  if(script_category >= MAX_NUM_SCRIPT_CATEGORIES
     || val == 0)
    return;

  /* Compress the value and put the result in `new_score` in the right `script_category` */
  compressAndIncCatScore(&cat_score->new_score[script_category], val);
}

/* *************************************** */

void HostScore::incIdleCatFlowScore(category_score_t *cat_score, u_int16_t val, ScriptCategory script_category) {
  if(script_category >= MAX_NUM_SCRIPT_CATEGORIES
     || val == 0)
    return;

  /* Compress the value and put the result in `new_idle_scor`, in the right `script_category` */
  compressAndIncCatScore(&cat_score->idle_score[script_category], val);
}

/* *************************************** */

/* Static method to increase the value of a `score` submitted as pointer by val for active flows */
void HostScore::incValue(score_t *score, u_int16_t val) {
  /* Increase and protect against wraps */
  if(score->new_score + val <= SCORE_MAX)
    score->new_score += val;
  else if(score->new_score < SCORE_MAX)
    score->new_score = SCORE_MAX;
};

/* *************************************** */

/* Static method to increase the value of a `score` submitted as pointer by `val` for short-lived idle flows */
void HostScore::incIdleFlowScore(score_t *score, u_int16_t val) {
  /* Increase and protect against wraps */
  if(score->idle_flow_score + val <= SCORE_MAX)
    score->idle_flow_score += val;
  else if(score->idle_flow_score < SCORE_MAX)
    score->idle_flow_score = SCORE_MAX;
};

/* *************************************** */

void HostScore::incValue(const u_int16_t score[MAX_NUM_SCRIPT_CATEGORIES], bool as_client) {
  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++) {
    ScriptCategory script_category = (ScriptCategory)i;
    u_int16_t val = score[script_category];

    if(as_client)
      incValue(&cli_score, val),
	incCategoryValue(&cat_cli_score, val, script_category);
    else
      incValue(&srv_score, val),
	incCategoryValue(&cat_srv_score, val, script_category);
  }
}

/* *************************************** */

void HostScore::incIdleFlowScore(const u_int16_t score[MAX_NUM_SCRIPT_CATEGORIES], bool as_client) {
  /*
    Necessary to lock as the increase on idle flow scores is performed from a thread
    which is different from the one who reads the same values.
  */
  m.lock(__FILE__, __LINE__);

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++) {
    ScriptCategory script_category = (ScriptCategory)i;
    u_int16_t val = score[script_category];

    if(as_client)
      incIdleFlowScore(&cli_score, val),
	incIdleCatFlowScore(&cat_cli_score, val, script_category);
    else
      incIdleFlowScore(&srv_score, val),
	incIdleCatFlowScore(&cat_srv_score, val, script_category);
  }

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

/* This should be called once per minute. It computes the "visible" score
 * value (the one returned by getValue()). */
void HostScore::refreshValue(score_t *score, category_score_t *cat_score) {
  /* Lock to access the idle score which is updated in another thread different from this */
  m.lock(__FILE__, __LINE__);

  /* Keep into account also the idle flow score into the new score */
  if(score->new_score + score->idle_flow_score <= SCORE_MAX)
    score->new_score += score->idle_flow_score;
  else
    score->new_score = SCORE_MAX;
  /* Now that the idle flow score has been read, it can be reset */
  score->idle_flow_score = 0;

  /* Time to update per-category scores with per-category idle scores */
  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++) {
    if(cat_score->new_score[i] + cat_score->idle_score[i] <= CAT_SCORE_MAX)
      cat_score->new_score[i] += cat_score->idle_score[i];
    else
      cat_score->new_score[i] = CAT_SCORE_MAX;

    /* Now we can reset the value which has already been read */
    cat_score->idle_score[i] = 0;
  }

  m.unlock(__FILE__, __LINE__);

  /* Account the new_score and prepare the counter for the next run */
  score->old_score = score->new_score;
  score->new_score = 0;

  /* Account per-category scores and prepare counters for the next run */
  memcpy(&cat_score->old_score, &cat_score->new_score, sizeof(cat_score->new_score));
  memset(&cat_score->new_score, 0, sizeof(cat_score->new_score));
}

/* *************************************** */

/* This should be called once per minute. It computes the "visible" score
 * value (the one returned by getValue()). */
void HostScore::refreshValue() {
  refreshValue(&cli_score, &cat_cli_score),
    refreshValue(&srv_score, &cat_srv_score);
}

/* *************************************** */

void HostScore::lua_breakdown(lua_State *vm, const cat_score_type old_score[MAX_NUM_SCRIPT_CATEGORIES], const char * const key) const {
  u_int32_t total = 0;
  /* Snapshot current scores so they won't change in-use */
  cat_score_type snapshot[MAX_NUM_SCRIPT_CATEGORIES];
  memcpy(&snapshot, old_score, sizeof(snapshot));

  /* Compute the total so that we can return results as a percentage */
  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++)
    total += snapshot[i];

  if(total == 0) total = 1; /* Prevents zero-division errors */

  lua_newtable(vm);

  for(int i = 0; i < MAX_NUM_SCRIPT_CATEGORIES; i++) {
    lua_pushnumber(vm, i); /* The integer category id as key */
    lua_pushnumber(vm, snapshot[i] / (float)total * 100); /* The % as value */
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, key);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void HostScore::lua_breakdown(lua_State *vm) const {
  lua_newtable(vm);

  lua_breakdown(vm, cat_cli_score.old_score, "as_client");
  lua_breakdown(vm, cat_srv_score.old_score, "as_server");

  lua_pushstring(vm, "score_pct");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

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

/* An (unsigned) type for the score */
typedef u_int16_t score_type;
/* An (unsigned) type for the category score */
typedef u_int8_t  cat_score_type;

/* Maximum number which can fit a score */
#define SCORE_MAX      (score_type)-1
/* Maximum number which can fit a category score */
#define CAT_SCORE_MAX  (cat_score_type)-1

typedef struct {
  /* Handle score */
  score_type old_score, new_score;
  /* Necessary to handle score for short idle flows */
  score_type idle_flow_score;
} score_t;

typedef struct {
  /* Per-category (compressed) scores for active flows */
  cat_score_type old_score[MAX_NUM_SCRIPT_CATEGORIES], new_score[MAX_NUM_SCRIPT_CATEGORIES];
  /* Per-category (compressed) scores for idle, short-lived flows */
  cat_score_type idle_score[MAX_NUM_SCRIPT_CATEGORIES];
} category_score_t;

class HostScore {
 private:
  score_t cli_score, srv_score;
  category_score_t cat_cli_score, cat_srv_score;
  Mutex m;

  static inline void compressAndIncCatScore(u_int8_t *result, u_int16_t val);

  static inline void incCategoryValue(category_score_t *cat_score, u_int16_t val, ScriptCategory script_category);
  static inline void incValue(score_t *score, u_int16_t val);

  static inline void incIdleCatFlowScore(category_score_t *cat_score, u_int16_t val, ScriptCategory script_category);
  static inline void incIdleFlowScore(score_t *score, u_int16_t val);

  inline void refreshValue(score_t *score,  category_score_t *cat_score);
  void lua_breakdown(lua_State *vm, const cat_score_type old_score[MAX_NUM_SCRIPT_CATEGORIES], const char * const key) const;
 public:
  HostScore();

  inline u_int16_t getValue()                const { return(cli_score.old_score + srv_score.old_score); };
  inline u_int16_t getClientValue()          const { return(cli_score.old_score); };
  inline u_int16_t getServerValue()          const { return(srv_score.old_score); };
  void refreshValue();

  void incValue(const u_int16_t score[MAX_NUM_SCRIPT_CATEGORIES], bool as_client);
  /* This call is not performed into the same thread as the incScore, so
   * it needs a separate counter to avoid contention. */
  void incIdleFlowScore(const u_int16_t score[MAX_NUM_SCRIPT_CATEGORIES], bool as_client);
  void lua_breakdown(lua_State *vm) const;
};

#endif

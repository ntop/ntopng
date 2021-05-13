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

/* ***************************************************** */

Score::Score(NetworkInterface *_iface) {
  view_interface_score = _iface->isView();
  score = NULL;
}

/* ***************************************************** */

Score::~Score() {
  if(score) delete score;
};

/* *************************************** */

u_int16_t Score::incScoreValue(u_int16_t score_incr, ScoreCategory score_category, bool as_client) {
  if(score
     || (score = view_interface_score ? new (std::nothrow) ViewScoreStats() : new (std::nothrow) ScoreStats())) { /* Allocate if necessary */
    return score->incValue(score_incr, score_category, as_client);
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error. Unable to allocate memory for score");
    return 0;
  }
}

/* *************************************** */

u_int16_t Score::decScoreValue(u_int16_t score_decr, ScoreCategory score_category, bool as_client) {
  if(score) {
    return score->decValue(score_decr, score_category, as_client);
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error. Memory for score not allocated");
    return 0;
  }
}

/* ***************************************************** */

void Score::lua_get_score(lua_State *vm) {
  lua_push_uint64_table_entry(vm, "score", score ? score->get() : 0);
  lua_push_uint64_table_entry(vm, "score.as_client", score ? score->getClient() : 0);
  lua_push_uint64_table_entry(vm, "score.as_server", score ? score->getServer() : 0);
}

/* ***************************************************** */

void Score::lua_get_score_breakdown(lua_State *vm) {
  if(score)
    score->lua_breakdown(vm);
}


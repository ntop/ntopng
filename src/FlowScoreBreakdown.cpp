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

FlowScoreBreakdown::FlowScoreBreakdown() {
  for(int i = 0; i < FLOW_MAX_SCORE_BREAKDOWN; i++)
    flow_score_breakdown[i] = {
      .alert_id = flow_alert_normal,
      .alert_score = 0
    };
}

/* ***************************************************** */

FlowScoreBreakdown::~FlowScoreBreakdown() {
};

/* ***************************************************** */

bool FlowScoreBreakdown::incScore(FlowAlertType alert_type, u_int16_t score_inc) {
  for(int i = 0; i < FLOW_MAX_SCORE_BREAKDOWN; i++) {
    if(flow_score_breakdown[i].alert_id == flow_alert_normal)
      /* Reserve this available array entry for this alert */
      flow_score_breakdown[i].alert_id = alert_type.id;

    if(flow_score_breakdown[i].alert_id == alert_type.id) {
      /* Do the increment and handle overflows */
      if(flow_score_breakdown[i].alert_score + score_inc + 1 > (u_int8_t)-1)
	/* Not enough */
	flow_score_breakdown[i].alert_score = (u_int8_t)-1;
      else
	/* Enough */
	flow_score_breakdown[i].alert_score += score_inc;

      /* Alert type found */
      return true;
    }
  }

  /* The array is full, no room for this alert_type */
  return false;
}

/* ****************************************** */

void FlowScoreBreakdown::lua(lua_State* vm, const char *label) const {
  lua_newtable(vm);

  for(int i = 0; i < FLOW_MAX_SCORE_BREAKDOWN; i++) {
    /* No more entries set */
    if(flow_score_breakdown[i].alert_id == flow_alert_normal)
      break;

    lua_newtable(vm);

    /* Write the score */
    lua_push_int32_table_entry(vm, "score", (flow_score_breakdown[i].alert_score));

    /* And also tell lua if this is the maximum score */
    if(flow_score_breakdown[i].alert_score == (u_int8_t)-1)
      lua_push_bool_table_entry(vm, "is_max", true);

    lua_pushinteger(vm, flow_score_breakdown[i].alert_id); /* The integer alert id, used as key of this lua table */
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ***************************************************** */

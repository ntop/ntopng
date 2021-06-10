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

#ifndef _FLOW_SCORE_BREAKDOWN_
#define _FLOW_SCORE_BREAKDOWN_

class FlowScoreBreakdown {
 private:
  /*
    Used to keep a per-alert breakdown of the flow score
  */
  struct {
    FlowAlertTypeEnum alert_id;
    u_int8_t alert_score;
  } flow_score_breakdown[FLOW_MAX_SCORE_BREAKDOWN];
  
 public:
  FlowScoreBreakdown();
  ~FlowScoreBreakdown();

  bool incScore(FlowAlertType alert_type, u_int16_t score_inc);
  void lua(lua_State* vm, const char *label) const;
};

#endif

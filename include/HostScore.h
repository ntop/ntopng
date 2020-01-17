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
  u_int32_t old_score, new_score;

  /* Necessary to handle short idle flows */
  u_int32_t old_idle_flow_score, new_idle_flow_score;

 public:
  HostScore();
  inline void incValue(u_int16_t score)    { new_score += score; };
  inline u_int16_t getValue() const        { return(old_score); };
  void refreshValue();

  /* This call is not performed into the same thread as the incScore, so
   * it needs a separate counter to avoid contention. */
  inline void incIdleFlowScore(u_int16_t score) { new_idle_flow_score += score; };
};

#endif

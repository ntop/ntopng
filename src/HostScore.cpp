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

void HostScore::incValue(u_int16_t score, bool as_client) {
  if(as_client)
    incValue(&cli_score, score);
  else
    incValue(&srv_score, score);
}

/* *************************************** */

/* This should be called once per minute. It computes the "visible" score
 * value (the one returned by getValue()). */
void HostScore::incIdleFlowScore(u_int16_t score, bool as_client) {
  if(as_client)
    incIdleFlowScore(&cli_score, score);
  else
    incIdleFlowScore(&srv_score, score);
}

/* *************************************** */

void HostScore::refreshValue(score_t *score) {
  /* Add the score calculated on the idle flows */
  score->new_score += (score->new_idle_flow_score - score->old_idle_flow_score);
  score->old_idle_flow_score = score->new_idle_flow_score;

  /* Account the new_score and prepare the counter for the next run */
  score->old_score = score->new_score;
  score->new_score = 0;  
}

/* *************************************** */

/* This should be called once per minute. It computes the "visible" score
 * value (the one returned by getValue()). */
void HostScore::refreshValue() {
  refreshValue(&cli_score),
    refreshValue(&srv_score);
}

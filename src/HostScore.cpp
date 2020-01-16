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
  old_score = new_score = 0;
  old_idle_flow_score = new_idle_flow_score = 0;
}

/* *************************************** */

/* This should be called once per minute. It computes the "visible" score
 * value (the one returned by getValue()). */
void HostScore::refreshValue() {
  /* Add the score calculated on the idle flows */
  new_score += (new_idle_flow_score - old_idle_flow_score);
  old_idle_flow_score = new_idle_flow_score;

  /* Account the new_score and prepare the counter for the next run */
  old_score = new_score;
  new_score = 0;
}

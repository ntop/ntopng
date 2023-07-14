/*
 *
 * (C) 2020-23 - ntop.org
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

#define DEFAULT_DECAY_TIME 10 /* sec */

/* **************************************************** */

u_int32_t ScoreCounter::dec(u_int16_t score) {  
  if(value >= score) {
    u_int32_t old_value = value;
    
    value -= score, decay_time = ntop->get_current_time() + DEFAULT_DECAY_TIME;
    a = ((float)(old_value - value)) / DEFAULT_DECAY_TIME, b = old_value;
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error [%u vs %u]", value, score);
    value = 0;
  }
  
  return(value);
}

/* **************************************************** */

u_int32_t ScoreCounter::get() {
  if(decay_time == 0)
    return(value); /* No decay */
  else {
    if(decay_time < ntop->get_current_time()) {
      decay_time = 0; /* Decay is over */
      return(value);
    } else {
      u_int32_t tdiff = DEFAULT_DECAY_TIME-(decay_time - ntop->get_current_time());

      return(b - (u_int32_t)(a * tdiff));
    }
  }
}

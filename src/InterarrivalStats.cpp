/*
 *
 * (C) 2013-21 - ntop.org
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

InterarrivalStats::InterarrivalStats() {
  memset(&lastTime, 0, sizeof(lastTime));
  ndpi_init_data_analysis(&delta_ms, 0);
}

/* ******************************************** */

void InterarrivalStats::updatePacketStats(struct timeval* when,
					  bool update_iat) {
  if(update_iat && lastTime.tv_sec) {
    float deltaMS = Utils::msTimevalDiff(when, &lastTime);
    
    if(deltaMS > 0)
      ndpi_data_add_value(&delta_ms, (u_int32_t)deltaMS);    
  }
  
  memcpy(&lastTime, when, sizeof(struct timeval)); 
}

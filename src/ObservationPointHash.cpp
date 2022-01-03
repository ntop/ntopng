/*
 *
 * (C) 2013-22 - ntop.org
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

/* ************************************ */

ObservationPointHash::ObservationPointHash(NetworkInterface *_iface, u_int _num_hashes, u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "ObservationPointHash") {
  ;
}

/* ************************************ */

ObservationPoint* ObservationPointHash::get(u_int16_t obs_point, bool is_inline_call) {
  if(obs_point == 0 || obs_point == (u_int16_t) -1)
    return(NULL);
  else {
    u_int32_t hash = obs_point;

    hash %= num_hashes;

    if(table[hash] == NULL) {
      return(NULL);
    } else {
      ObservationPoint *head;

      if(!is_inline_call)
	locks[hash]->rdlock(__FILE__, __LINE__);

      head = (ObservationPoint*)table[hash];

      while(head != NULL) {
	if((!head->idle()) && head->equal(obs_point))
	  break;
	else
	  head = (ObservationPoint*)head->next();
      }

      if(!is_inline_call)
	locks[hash]->unlock(__FILE__, __LINE__);

      return(head);
    }
  }
}

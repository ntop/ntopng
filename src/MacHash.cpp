/*
 *
 * (C) 2013-18 - ntop.org
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

MacHash::MacHash(NetworkInterface *_iface, u_int _num_hashes, u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "MacHash") {
  ;
}

/* ************************************ */

Mac* MacHash::get(const u_int8_t mac[6]) {
  if(mac == NULL)
    return(NULL);
  else {
    u_int32_t hash = Utils::macHash((u_int8_t*)mac);

    hash %= num_hashes;

    if(table[hash] == NULL) {
      return(NULL);
    } else {
      Mac *head;

      locks[hash]->lock(__FILE__, __LINE__);
      head = (Mac*)table[hash];

      while(head != NULL) {
	if((!head->idle()) && head->equal(mac))
	  break;
	else
	  head = (Mac*)head->next();
      }
    
      locks[hash]->unlock(__FILE__, __LINE__);
    
      return(head);
    }
  }
}

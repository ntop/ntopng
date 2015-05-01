/*
 *
 * (C) 2015 - ntop.org
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

/* *********************************************************** */

VirtualHostHash::VirtualHostHash(NetworkInterface *_iface, u_int _num_hashes, u_int _max_hash_size)
  : GenericHash(_iface, _num_hashes, _max_hash_size) {
  ;
}

/* *********************************************************** */

VirtualHost* VirtualHostHash::get(char *key) {
  u_int32_t hash = Utils::hashString(key) % num_hashes;

  if(table[hash] == NULL) {
    return(NULL);
  } else {
    VirtualHost *head;

    locks[hash]->lock(__FILE__, __LINE__);
    head = (VirtualHost*)table[hash];
    
    while(head != NULL) {      
      if((!head->idle())
	 && head->get_name()
	 && (strcmp(key, head->get_name()) == 0))
	break;
      else
	head = (VirtualHost*)head->next();
    }
    locks[hash]->unlock(__FILE__, __LINE__);

    return(head);
  }
}

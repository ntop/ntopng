/*
 *
 * (C) 2013-19 - ntop.org
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
 *x
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* ************************************ */

VlanHash::VlanHash(NetworkInterface *_iface, u_int _num_hashes, u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "VlanHash") {
  ;
}

/* ************************************ */

Vlan* VlanHash::get(u_int16_t _vlan_id) {
  u_int32_t hash = _vlan_id;

  hash %= num_hashes;

  if(table[hash] == NULL) {
    return(NULL);
  } else {
    Vlan *head;

    locks[hash]->lock(__FILE__, __LINE__);
    head = (Vlan*)table[hash];

    while(head != NULL) {
      if((!head->idle()) && head->equal(_vlan_id))
	break;
      else
	head = (Vlan*)head->next();
    }
    
    locks[hash]->unlock(__FILE__, __LINE__);
    
    return(head);
  }
}

#ifdef VLAN_DEBUG

static bool print_ases(GenericHashEntry *_vl, void *user_data) {
  Vlan *vl = (Vlan*)_vl;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Vlan %u [num_uses: %u]",
			       vl->get_vlan_id(),
			       vl->getNumHosts());
  
  return(false); /* false = keep on walking */
}

void VlanHash::printHash() {
  disablePurge();

  walk(print_ases, NULL);
  
  enablePurge();
}

#endif

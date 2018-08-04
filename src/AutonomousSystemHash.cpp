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
 *x
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* ************************************ */

AutonomousSystemHash::AutonomousSystemHash(NetworkInterface *_iface, u_int _num_hashes,
					   u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "AutonomousSystemHash") {
  ;
}

/* ************************************ */

AutonomousSystem* AutonomousSystemHash::get(IpAddress *ipa) {
  u_int32_t asn;
  ntop->getGeolocation()->getAS(ipa, &asn, NULL /* Don't care about AS name here */);
  u_int32_t hash = asn;

  hash %= num_hashes;

  if(table[hash] == NULL) {
    return(NULL);
  } else {
    AutonomousSystem *head;

    locks[hash]->lock(__FILE__, __LINE__);
    head = (AutonomousSystem*)table[hash];

    while(head != NULL) {
      if((!head->idle()) && head->equal(asn))
	break;
      else
	head = (AutonomousSystem*)head->next();
    }
    
    locks[hash]->unlock(__FILE__, __LINE__);
    
    return(head);
  }
}

/* ************************************ */

#ifdef AS_DEBUG

static bool print_ases(GenericHashEntry *_as, void *user_data) {
  AutonomousSystem *as = (AutonomousSystem*)_as;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Autonomous System [asn: %u] [asname: %s] [num_uses: %u]",
			       as->get_asn(),
			       as->get_asname(),
			       as->getNumHosts());
  
  return(false); /* false = keep on walking */
}

/* ************************************ */

void AutonomousSystemHash::printHash() {
  disablePurge();

  walk(print_ases, NULL);
  
  enablePurge();
}

#endif

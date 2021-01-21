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
 *x
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* ************************************ */

OperatingSystemHash::OperatingSystemHash(NetworkInterface *_iface, u_int _num_hashes,
					   u_int _max_hash_size):GenericHash(_iface, _num_hashes, _max_hash_size, "OperatingSystemHash") {
  ;
}

/* ************************************ */

OperatingSystem* OperatingSystemHash::get(OSType os_type, bool is_inline_call) {
  u_int32_t hash;

  hash = os_type;
  
  hash %= num_hashes;

  if(table[hash] == NULL) {
    return(NULL);
  } else {
    OperatingSystem *head;

    if(!is_inline_call)
      locks[hash]->rdlock(__FILE__, __LINE__);

    head = (OperatingSystem*)table[hash];

    while(head != NULL) {
      if(!head->idle() && head->equal(os_type))
	break;
      else
	head = (OperatingSystem*)head->next();
    }

    if(!is_inline_call)
      locks[hash]->unlock(__FILE__, __LINE__);

    return(head);
  }
}

/* ************************************ */

#ifdef AS_DEBUG

static bool print_oses(GenericHashEntry *_as, void *user_data) {
  OperatingSystem *as = (OperatingSystem*)_as;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Operating System [os: %u] [num_uses: %u]",
			       as->get_os(),
			       os->getNumHosts());
  
  return(false); /* false = keep on walking */
}

/* ************************************ */

void OperatingSystemHash::printHash() {
  disablePurge();

  walk(print_oses, NULL);
  
  enablePurge();
}

#endif

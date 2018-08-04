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

CountriesHash::CountriesHash(NetworkInterface *_iface, u_int _num_hashes,
					   u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "CountriesHash") {
  ;
}

/* ************************************ */

Country* CountriesHash::get(const char *country_name) {
  u_int32_t hash = Utils::stringHash(country_name);

  hash %= num_hashes;

  if(table[hash] == NULL) {
    return(NULL);
  } else {
    Country *head;

    locks[hash]->lock(__FILE__, __LINE__);
    head = (Country*)table[hash];

    while(head != NULL) {
      if((!head->idle()) && head->equal(country_name))
	break;
      else
	head = (Country*)head->next();
    }
    
    locks[hash]->unlock(__FILE__, __LINE__);
    
    return(head);
  }
}

/* ************************************ */

#ifdef COUNTRY_DEBUG

static bool print_country(GenericHashEntry *_country, void *user_data) {
  Country *country = (Country*)_country;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Country [name: %s] [num_uses: %u]",
			       country->get_name(),
			       country->getNumHosts());
  
  return(false); /* false = keep on walking */
}

/* ************************************ */

void CountriesHash::printHash() {
  disablePurge();

  walk(print_country, NULL);
  
  enablePurge();
}

#endif

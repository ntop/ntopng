/*
 *
 * (C) 2013-16 - ntop.org
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

InterfaceStatsHash::InterfaceStatsHash(u_int _max_hash_size) {
  max_hash_size = _max_hash_size;
  buckets = (sFlowInterfaceStats**)calloc(sizeof(sFlowInterfaceStats), max_hash_size);

  if(buckets == NULL)
    throw "Not enough memory";
}

/* ************************************ */

InterfaceStatsHash::~InterfaceStatsHash() {
  for(int i=0; i<max_hash_size; i++)
    if(buckets[i] != NULL) free(buckets[i]);

  free(buckets);
}
/* ************************************ */

bool InterfaceStatsHash::set(u_int32_t deviceIP, u_int32_t ifIndex, sFlowInterfaceStats *stats) {
  u_int32_t hash = (deviceIP+ifIndex) % max_hash_size, num_runs = 0;

  if(buckets[hash] == NULL) {
    return(false);
  } else {
    sFlowInterfaceStats *head;
    bool ret = true;

    m.lock(__FILE__, __LINE__);
    head = (sFlowInterfaceStats*)buckets[hash];
    
    while(head != NULL) {      
      if((head->deviceIP == deviceIP) && (head->ifIndex == ifIndex))
	break;
      else {
	/* Inplace hash */
	hash = (hash + 1) % max_hash_size, num_runs++;

	if(num_runs >= max_hash_size) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: too many loops=%u", max_hash_size);
	  m.unlock(__FILE__, __LINE__);
	  return(false);
	}

	head = buckets[hash];
      }
    }

    if(head) {
      /* Overwrite value */
      memcpy(head, stats, sizeof(sFlowInterfaceStats));      
    } else {
      buckets[hash] = (sFlowInterfaceStats*)malloc(sizeof(sFlowInterfaceStats));
      if(buckets[hash])
	memcpy(buckets[hash], stats, sizeof(sFlowInterfaceStats));
      else
	ret = false;
    }

    m.unlock(__FILE__, __LINE__);

    return(ret);
  }
}

/* ************************************ */

bool InterfaceStatsHash::get(u_int32_t deviceIP, u_int32_t ifIndex, sFlowInterfaceStats *stats) {
  u_int32_t hash = (deviceIP+ifIndex) % max_hash_size, num_runs = 0;

  if(buckets[hash] == NULL) {
    return(false);
  } else {
    sFlowInterfaceStats *head;

    m.lock(__FILE__, __LINE__);
    head = (sFlowInterfaceStats*)buckets[hash];
    
    while(head != NULL) {      
      if((head->deviceIP == deviceIP) && (head->ifIndex == ifIndex)) {
	memcpy(stats, head, sizeof(sFlowInterfaceStats));
	break;
      } else {
	/* Inplace hash */
	hash = (hash + 1) % max_hash_size, num_runs++;

	if(num_runs >= max_hash_size) {
	  m.unlock(__FILE__, __LINE__);
	  return(false);
	}

	head = buckets[hash];
      }
    }

    m.unlock(__FILE__, __LINE__);

    return(false);
  }
}

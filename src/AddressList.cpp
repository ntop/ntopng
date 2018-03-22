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

/* **************************************** */

AddressList::AddressList() {
  memset(addressString, 0, sizeof(addressString));
}

/* ******************************************* */

bool AddressList::addAddress(char *_net) {
  char *net;
  int id = getNumAddresses();
  
  if(id >= CONST_MAX_NUM_NETWORKS) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many networks defined (%d): ignored %s",
				 id, _net);
    return(false);
  }
  
  if((net = strdup(_net)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    return(false);
  }

  tree.addAddresses(net);

  free(net);

  addressString[id] = strdup(_net);
  return(true);
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
bool AddressList::addAddresses(char *rule) {
  char *tmp, *net = strtok_r(rule, ",", &tmp);
  
  while(net != NULL) {
    if(!addAddress(net)) return false;
    net = strtok_r(NULL, ",", &tmp);   
  }
  
  return true;
}

/* **************************************** */

AddressList::~AddressList() {
  for(int i=0; i<CONST_MAX_NUM_NETWORKS; i++)
    if(addressString[i])
      free(addressString[i]);
    else
      break;
}


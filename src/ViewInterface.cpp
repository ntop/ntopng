/*
 *
 * (C) 2013-17 - ntop.org
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

/* **************************************************** */

ViewInterface::ViewInterface(const char *_endpoint) : NetworkInterface(_endpoint) {
  char *ifaces = strdup(&_endpoint[5]); /* Skip view: */

  if(ifaces) {
    char *tmp, *iface = strtok_r(ifaces, ",", &tmp);

    while(iface != NULL) {
      bool found = false;

      for(int i=0; i<MAX_NUM_INTERFACES; i++) {
	char *ifName;

	if((ifName = ntop->get_if_name(i)) == NULL)
	  continue;

	if(!strncmp(ifName, iface, MAX_INTERFACE_NAME_LEN)) {
	  found = true;
	  
	  if(numSubInterfaces < MAX_NUM_VIEW_INTERFACES) {
	    NetworkInterface *what = ntop->getInterfaceById(i);

	    if(what)
	      subInterfaces[numSubInterfaces++] = what;
	    else
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal Error: NULL interface [%s][%d]", ifName, i);
	  }
	  break;
	}
      }

      if(!found) 
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping view sub-interface %s: not found", iface);
      else if(numSubInterfaces == MAX_NUM_VIEW_INTERFACES)
	break; /* Upper interface limit reached */
      
      iface = strtok_r(NULL, ",", &tmp);
    }
    
    free(ifaces);
  }
}

/* **************************************************** */

bool ViewInterface::walker(WalkerType wtype,
			   bool (*walker)(GenericHashEntry *h, void *user_data),
			   void *user_data) {
  bool ret = false;

  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "VIEW: Iterating on subinterface %s [walker_flows: %u]",
    // 				 subInterfaces[s]->get_name(),
    // 				 wtype == walker_flows ? 1 : 0);
    ret |= subInterfaces[s]->walker(wtype, walker, user_data);
  }

  return(ret);
}


/* **************************************************** */

u_int32_t ViewInterface::getFlowsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getFlowsHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getMacsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    tot += subInterfaces[s]->getMacsHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getHostsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "VIEW: Iterating subInterface [%s][size: %u]",
    // 				 subInterfaces[s]->get_name(),
    // 				 subInterfaces[s]->getHostsHashSize());
    tot += subInterfaces[s]->getHostsHashSize();
  }

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getASesHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    tot += subInterfaces[s]->getASesHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getVLANsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    tot += subInterfaces[s]->getVLANsHashSize();

  return(tot);
}

/* **************************************************** */

Host* ViewInterface::getHost(char *host_ip, u_int16_t vlan_id) {
  Host *h = NULL;

  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    if((h = subInterfaces[s]->getHost(host_ip, vlan_id)))
      break;
  }

  return(h);
}

/* **************************************************** */

Flow* ViewInterface::findFlowByKey(u_int32_t key, AddressTree *allowed_hosts) {
  Flow *f = NULL;

  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    if((f = (Flow*)subInterfaces[s]->findFlowByKey(key, allowed_hosts)))
      break;
  }

  return(f);
}


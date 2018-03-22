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

bool ViewInterface::walker(u_int32_t *begin_slot,
			   bool walk_all,
			   WalkerType wtype,
			   bool (*walker)(GenericHashEntry *h, void *user_data, bool *matched),
			   void *user_data) {
  bool ret = false;

  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "VIEW: Iterating on subinterface %s [walker_flows: %u]",
    // 				 subInterfaces[s]->get_name(),
    // 				 wtype == walker_flows ? 1 : 0);
    ret |= subInterfaces[s]->walker(begin_slot, walk_all, wtype, walker, user_data);
  }

  return(ret);
}

/* **************************************************** */

u_int64_t ViewInterface::getNumPackets() {  
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumPackets();

  return(tot);
};

/* **************************************************** */

u_int32_t ViewInterface::getNumPacketDrops() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumDroppedPackets();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumFlows() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumFlows();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumL2Devices() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumL2Devices();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumHosts() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumHosts();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumLocalHosts() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumLocalHosts();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumHTTPHosts() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumHTTPHosts();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumMacs() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumMacs();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getNumBytes() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    tot += subInterfaces[s]->getNumBytes();

  return(tot);
}

/* **************************************************** */

u_int64_t ViewInterface::getCheckPointNumPackets() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getCheckPointNumPackets();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getCheckPointNumBytes() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getCheckPointNumBytes();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getCheckPointNumPacketDrops() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getCheckPointNumPacketDrops();

  return(tot);
};

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

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getMacsHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getHostsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    tot += subInterfaces[s]->getHostsHashSize();
  }

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getASesHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getASesHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getCountriesHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
    tot += subInterfaces[s]->getCountriesHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getVLANsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < numSubInterfaces; s++)
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

Mac* ViewInterface::getMac(u_int8_t _mac[6], bool createIfNotPresent) {
  Mac *ret = NULL;

  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    if((ret = subInterfaces[s]->getMac(_mac, false)))
      break;
  }

  return(ret);
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


/* *************************************** */

void ViewInterface::lua(lua_State *vm) {
  bool has_macs = false;

  NetworkInterface::lua(vm);
  for(u_int8_t s = 0; s < numSubInterfaces; s++) {
    if(subInterfaces[s]->hasSeenMacAddresses()) {
      has_macs = true;
      break;
    }
  }
  lua_push_bool_table_entry(vm, "has_macs", has_macs);
}

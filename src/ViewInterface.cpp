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
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* **************************************************** */

ViewInterface::ViewInterface(const char *_endpoint) : NetworkInterface(_endpoint) {
  memset(viewed_interfaces, 0, sizeof(viewed_interfaces));
  num_viewed_interfaces = 0;
  char *ifaces = strdup(&_endpoint[5]); /* Skip view: */

  if(ifaces) {
    char *tmp, *iface = strtok_r(ifaces, ",", &tmp);

    while(iface != NULL) {
      bool found = false;

      for(int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
	char *ifName;

	if((ifName = ntop->get_if_name(i)) == NULL)
	  continue;

	if(!strncmp(ifName, iface, MAX_INTERFACE_NAME_LEN)) {
	  found = true;
	  
	  if(num_viewed_interfaces < MAX_NUM_VIEW_INTERFACES) {
	    NetworkInterface *what = ntop->getInterfaceById(i);

	    if(!what)
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal Error: NULL interface [%s][%d]", ifName, i);
	    else if(what->isViewed())
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Interface already belonging to a view [%s][%d]", ifName, i);
	    else {
	      what->setViewed();
	      viewed_interfaces[num_viewed_interfaces++] = what;
	    }
	  }

	  break;
	}
      }

      if(!found) 
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping view sub-interface %s: not found", iface);
      else if(num_viewed_interfaces == MAX_NUM_VIEW_INTERFACES)
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

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "VIEW: Iterating on subinterface %s [walker_flows: %u]",
    // 				 viewed_interfaces[s]->get_name(),
    // 				 wtype == walker_flows ? 1 : 0);
    ret |= viewed_interfaces[s]->walker(begin_slot, walk_all, wtype, walker, user_data);
  }

  return(ret);
}

/* **************************************************** */

u_int64_t ViewInterface::getNumPackets() {  
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumPackets();

  return(tot);
};

/* **************************************************** */

u_int32_t ViewInterface::getNumPacketDrops() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumDroppedPackets();

  return(tot);
};

/* **************************************************** */

u_int ViewInterface::getNumFlows() {
  u_int tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumFlows();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getNumBytes() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s<num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getNumBytes();

  return(tot);
}

/* **************************************************** */

u_int64_t ViewInterface::getCheckPointNumPackets() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumPackets();

  return(tot);
};

/* **************************************************** */

u_int64_t ViewInterface::getCheckPointNumBytes() {
  u_int64_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumBytes();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getCheckPointNumPacketDrops() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCheckPointNumPacketDrops();

  return(tot);
};

/* **************************************************** */

u_int32_t ViewInterface::getFlowsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getFlowsHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getMacsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getMacsHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getHostsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    tot += viewed_interfaces[s]->getHostsHashSize();
  }

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getASesHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getASesHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getCountriesHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getCountriesHashSize();

  return(tot);
}

/* **************************************************** */

u_int32_t ViewInterface::getVLANsHashSize() {
  u_int32_t tot = 0;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++)
    tot += viewed_interfaces[s]->getVLANsHashSize();

  return(tot);
}

/* **************************************************** */

Host* ViewInterface::getHost(char *host_ip, u_int16_t vlan_id, bool isInlineCall) {
  Host *h = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((h = viewed_interfaces[s]->getHost(host_ip, vlan_id, isInlineCall)))
      break;
  }

  return(h);
}

/* **************************************************** */

Mac* ViewInterface::getMac(u_int8_t _mac[6], bool createIfNotPresent, bool isInlineCall) {
  Mac *ret = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((ret = viewed_interfaces[s]->getMac(_mac, false, isInlineCall)))
      break;
  }

  return(ret);
}

/* **************************************************** */

Flow* ViewInterface::findFlowByKey(u_int32_t key, AddressTree *allowed_hosts) {
  Flow *f = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((f = (Flow*)viewed_interfaces[s]->findFlowByKey(key, allowed_hosts)))
      break;
  }

  return(f);
}

/* **************************************************** */

Flow* ViewInterface::findFlowByTuple(u_int16_t vlan_id,
				     IpAddress *src_ip,  IpAddress *dst_ip,
				     u_int16_t src_port, u_int16_t dst_port,
				     u_int8_t l4_proto,
				     AddressTree *allowed_hosts) const {
  Flow *f = NULL;

  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if((f = (Flow*)viewed_interfaces[s]->findFlowByTuple(vlan_id, src_ip, dst_ip, src_port, dst_port, l4_proto, allowed_hosts)))
      break;
  }

  return(f);
}


/* *************************************** */

void ViewInterface::lua(lua_State *vm) {
  bool has_macs = false;

  NetworkInterface::lua(vm);
  for(u_int8_t s = 0; s < num_viewed_interfaces; s++) {
    if(viewed_interfaces[s]->hasSeenMacAddresses()) {
      has_macs = true;
      break;
    }
  }
  lua_push_bool_table_entry(vm, "has_macs", has_macs);
}

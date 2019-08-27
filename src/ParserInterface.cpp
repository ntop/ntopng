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

#ifndef HAVE_NEDGE

/* **************************************************** */

ParserInterface::ParserInterface(const char *endpoint, const char *custom_interface_type) : NetworkInterface(endpoint, custom_interface_type) {
  num_companion_interfaces = 0;
  companion_interfaces = new (std::nothrow) NetworkInterface*[MAX_NUM_COMPANION_INTERFACES]();
}

/* **************************************************** */

ParserInterface::~ParserInterface() {
  if(companion_interfaces)
    delete []companion_interfaces;
}

/* **************************************************** */

void ParserInterface::reloadCompanions() {
  char key[CONST_MAX_LEN_REDIS_KEY];
  int num_companions;
  char **companions = NULL;
  bool found;

  if(!ntop->getRedis()) return;

  snprintf(key, sizeof(key), CONST_IFACE_COMPANIONS_SET, get_id());
  num_companions = ntop->getRedis()->smembers(key, &companions);

  companions_lock.lock(__FILE__, __LINE__);

  if(num_companion_interfaces > 0) {
    /* Check and possibly remove old companions */
    for(int i = 0; i < MAX_NUM_COMPANION_INTERFACES; i++) {
      if(!companion_interfaces[i]) continue;

      found = false;
      for(int j = 0; j < num_companions; j++) {
	if(companion_interfaces[i]->get_id() == atoi(companions[j])) {
	  found = true;
	  break;
	}
      }

      if(!found) {
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Removed companion interface [interface: %s][companion: %s]",
	// 			     get_name(), companion_interfaces[i]->get_name());
	companion_interfaces[i] = NULL;
	num_companion_interfaces--;
      }
    }
  }

  if(num_companions > 0) {
    /* Check and possibly add new companions */
    for(int i = 0; i < num_companions; i++) {
      found = false;
      for(int j = 0; j < MAX_NUM_COMPANION_INTERFACES; j++) {
	if(companion_interfaces[j] && companion_interfaces[j]->get_id() == atoi(companions[i])) {
	  found = true;
	  break;
	}
      }

      if(!found) {
	if(num_companion_interfaces < MAX_NUM_COMPANION_INTERFACES) {
	  for(int j = 0; j < MAX_NUM_COMPANION_INTERFACES; j++) {
	    if(!companion_interfaces[j]) {
	      companion_interfaces[j] = ntop->getInterfaceById(atoi(companions[i]));

	      if(companion_interfaces[j]) {
		num_companion_interfaces++;
		// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Added new companion interface [interface: %s][companion: %s]",
		// 			     get_name(), companion_interfaces[j]->get_name());
	      }

	      break;
	    }
	  }
	} else
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many companion interfaces defined [interface: %s]", get_name());
      }

      free(companions[i]);
    }
  }

  companions_lock.unlock(__FILE__, __LINE__);

  if(companions)
    free(companions);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Companion interface reloaded [interface: %s][companion: %s]",
  // 			       get_name(), companion_interface ? companion_interface->get_name() : "NULL");
}

/* **************************************************** */

void ParserInterface::deliverFlowToCompanions(ParsedFlow * const flow) {
  if(num_companion_interfaces > 0) {
    NetworkInterface *flow_interface = flow->ifname ? ntop->getNetworkInterface(flow->ifname) : NULL;

    for(int i = 0; i < MAX_NUM_COMPANION_INTERFACES; i++) {
      NetworkInterface *cur_companion = companion_interfaces[i];

      if(!cur_companion) continue;

      if(cur_companion->isTrafficMirrored())
	cur_companion->enqueueFlowToCompanion(flow, true /* Skip loopback traffic */);
      else if(cur_companion == flow_interface)
	cur_companion->enqueueFlowToCompanion(flow, false /* do NOT skip loopback traffic */);
    }
  }
}

#endif

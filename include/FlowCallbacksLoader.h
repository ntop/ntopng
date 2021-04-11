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
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _FLOW_CALLBACKS_LOADER_H_
#define _FLOW_CALLBACKS_LOADER_H_

#include "ntop_includes.h"

class FlowCallbacksLoader : public CallbacksLoader { /* A single instance inside Ntop */
 private:
  /* These are callback instances, that is classes instantiated at runtime each one with a given configuration */
  std::map<std::string, FlowCallback*> cb_all; /* All the callbacks instantiated */

  std::list<FlowCallback*>* getCallbacks(NetworkInterface *iface, FlowCallbacks callback);
  void registerCallback(FlowCallback *cb);
  
  void registerCallbacks();
  void loadConfiguration();

 public:
  FlowCallbacksLoader();
  virtual ~FlowCallbacksLoader();

  void printCallbacks();

  inline std::list<FlowCallback*>* getProtocolDetectedCallbacks(NetworkInterface *iface) { return(getCallbacks(iface, flow_callback_protocol_detected)); }
  inline std::list<FlowCallback*>* getPeriodicUpdateCallbacks(NetworkInterface *iface)   { return(getCallbacks(iface, flow_callback_periodic_update));   }
  inline std::list<FlowCallback*>* getFlowEndCallbacks(NetworkInterface *iface)          { return(getCallbacks(iface, flow_callback_flow_end));          }
  inline std::list<FlowCallback*>* getNoneFlowCallbacks(NetworkInterface *iface)         { return(getCallbacks(iface, flow_callback_flow_none));         }
};

#endif /* _FLOW_CALLBACKS_LOADER_H_ */

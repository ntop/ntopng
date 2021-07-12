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

#ifndef _FLOW_CHECKS_LOADER_H_
#define _FLOW_CHECKS_LOADER_H_

#include "ntop_includes.h"

class FlowChecksLoader : public ChecksLoader { /* A single instance inside Ntop */
 private:
  /* nDPI risks not currently hanlded by registered checks */
  ndpi_risk unhandled_ndpi_risks;
  /* These are check instances, that is classes instantiated at runtime each one with a given configuration */
  std::map<std::string, FlowCheck*> cb_all; /* All the checks instantiated */

  std::list<FlowCheck*>* getChecks(NetworkInterface *iface, FlowChecks check);
  void registerCheck(FlowCheck *cb);
  
  void registerChecks();
  void loadConfiguration();

 public:
  FlowChecksLoader();
  virtual ~FlowChecksLoader();

  void printChecks();

  inline std::list<FlowCheck*>* getProtocolDetectedChecks(NetworkInterface *iface) { return(getChecks(iface, flow_check_protocol_detected)); }
  inline std::list<FlowCheck*>* getPeriodicUpdateChecks(NetworkInterface *iface)   { return(getChecks(iface, flow_check_periodic_update));   }
  inline std::list<FlowCheck*>* getFlowEndChecks(NetworkInterface *iface)          { return(getChecks(iface, flow_check_flow_end));          }
  inline std::list<FlowCheck*>* getNoneFlowChecks(NetworkInterface *iface)         { return(getChecks(iface, flow_check_flow_none));         }
  inline ndpi_risk getUnhandledRisks() const { return unhandled_ndpi_risks; };
  bool luaCheckInfo(lua_State* vm, std::string check_name) const;
};

#endif /* _FLOW_CHECKS_LOADER_H_ */

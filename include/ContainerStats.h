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

#ifndef _CONTAINER_STATS_H_
#define _CONTAINER_STATS_H_

#include "ntop_includes.h"

class ContainerStats {
 private:
  std::set<std::string> containers;
  u_int32_t num_flows_as_client, num_flows_as_server;
  double tot_rtt_as_client, tot_rtt_variance_as_client;
  double tot_rtt_as_server, tot_rtt_variance_as_server;

 public:
  ContainerStats();

  inline void addContainer(std::string container_id)        { containers.insert(container_id); }
  inline u_int32_t getNumContainers()                       { return(containers.size()); }
  inline void incNumFlowsAsClient()                         { num_flows_as_client++; }
  inline void incNumFlowsAsServer()                         { num_flows_as_server++; }
  inline u_int32_t getNumFlowsAsClient()                    { return(num_flows_as_client); }
  inline u_int32_t getNumFlowsAsServer()                    { return(num_flows_as_server); }
  inline double getRttAsClient()                            { return(num_flows_as_client ? (tot_rtt_as_client / num_flows_as_client) : 0); }
  inline double getRttAsServer()                            { return(num_flows_as_server ? (tot_rtt_as_server / num_flows_as_server) : 0); }
  inline double getRttVarianceAsClient()                    { return(num_flows_as_client ? (tot_rtt_variance_as_client / num_flows_as_client) : 0); }
  inline double getRttVarianceAsServer()                    { return(num_flows_as_server ? (tot_rtt_variance_as_server / num_flows_as_server) : 0); }
  void accountLatency(double rtt, double rtt_variance, bool as_client);

  void lua(lua_State* vm);
};

#endif

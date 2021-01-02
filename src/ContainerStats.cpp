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

#include "ntop_includes.h"

/* *************************************** */

ContainerStats::ContainerStats() {
  num_flows_as_client = num_flows_as_server = 0;
  tot_rtt_as_client = tot_rtt_variance_as_client = 0;
  tot_rtt_as_server = tot_rtt_variance_as_server = 0;
}

/* *************************************** */

void ContainerStats::accountLatency(double rtt, double rtt_variance, bool as_client) {
  if(as_client) {
    tot_rtt_as_client += rtt;
    tot_rtt_variance_as_client += rtt_variance;
  } else {
    tot_rtt_as_server += rtt;
    tot_rtt_variance_as_server += rtt_variance;
  }
}

/* *************************************** */

void ContainerStats::lua(lua_State* vm) {
  lua_newtable(vm);

  lua_push_int32_table_entry(vm, "num_containers", getNumContainers());
  lua_push_int32_table_entry(vm, "num_flows.as_client", getNumFlowsAsClient());
  lua_push_int32_table_entry(vm, "num_flows.as_server", getNumFlowsAsServer());

  /* Latency stats */
  lua_push_float_table_entry(vm, "rtt_as_client", getRttAsClient());
  lua_push_float_table_entry(vm, "rtt_as_server", getRttAsServer());
  lua_push_float_table_entry(vm, "rtt_variance_as_client", getRttVarianceAsClient());
  lua_push_float_table_entry(vm, "rtt_variance_as_server", getRttVarianceAsServer());
}

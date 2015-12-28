/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _SIMULATOR_INTERFACE_H_
#define _SIMULATOR_INTERFACE_H_

#include "ntop_includes.h"

class Lua;

class SimulatorInterface : public ParserInterface {
 private:
  ZMQ_Flow flow_template;
  u_int16_t num_flows_per_second;
  u_long avg_flow_interarrival_usecs;

  u_int8_t process_simulated_flow();

  u_int8_t template_randomize_src_dst_mac();
  u_int8_t template_randomize_src_dst_ip();
  u_int8_t template_randomize_first_last_switched();

  u_int8_t template_randomize();

 public:
  SimulatorInterface(const char *sim_conf);
  ~SimulatorInterface(){};

  void simulate_flows();

  inline const char* get_type()         { return(CONST_INTERFACE_TYPE_SIMULATOR);      };
  inline bool is_ndpi_enabled()         { return(false);      };
  void startPacketPolling();
  void shutdown();
  bool is_packet_interface()           { return(false); }
};

#endif /* _SIMULATOR_INTERFACE_H_ */


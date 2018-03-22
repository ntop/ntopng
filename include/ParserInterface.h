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

#ifndef _PARSER_INTERFACE_H_
#define _PARSER_INTERFACE_H_

#include "ntop_includes.h"

struct FlowFieldMap {
  char *key;
  int value;
  UT_hash_handle hh; /* makes this structure hashable */
};

class ParserInterface : public NetworkInterface {
 private:
  struct FlowFieldMap *map;
  bool once;
  u_int64_t zmq_initial_bytes, zmq_initial_pkts,
    zmq_remote_initial_exported_flows;
  ZMQ_RemoteStats *zmq_remote_stats, *zmq_remote_stats_shadow;

  int getKeyId(char *sym);
  void addMapping(const char *sym, int num);
  void parseSingleFlow(json_object *o, u_int8_t source_id, NetworkInterface *iface);
    
 public:
  ParserInterface(const char *endpoint, const char *custom_interface_type = NULL);
  ~ParserInterface();

  u_int8_t parseFlow(char *payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseEvent(char *payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseCounter(char *payload, int payload_size, u_int8_t source_id, void *data);

  virtual void setRemoteStats(ZMQ_RemoteStats *zrs);
  u_int32_t getNumDroppedPackets() { return zmq_remote_stats ? zmq_remote_stats->sflow_pkt_sample_drops : 0; };
  virtual void lua(lua_State* vm);
};

#endif /* _PARSER_INTERFACE_H_ */



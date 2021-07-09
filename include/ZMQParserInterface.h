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

#ifndef _ZMQ_PARSER_INTERFACE_H_
#define _ZMQ_PARSER_INTERFACE_H_

#include "ntop_includes.h"

class ZMQParserInterface : public ParserInterface {
 private:
  typedef std::pair<u_int32_t, u_int32_t> pen_value_t;
  typedef std::map<string, pen_value_t > labels_map_t;
  labels_map_t labels_map;
  bool once, is_sampled_traffic;
  u_int32_t flow_max_idle, returned_flow_max_idle;
  u_int64_t zmq_initial_bytes, zmq_initial_pkts,
    zmq_remote_initial_exported_flows;
  std::map<u_int8_t, ZMQ_RemoteStats*>source_id_last_zmq_remote_stats;
  ZMQ_RemoteStats *zmq_remote_stats, *zmq_remote_stats_shadow;
  u_int32_t remote_lifetime_timeout, remote_idle_timeout;
  struct timeval last_zmq_remote_stats_update;
  RwLock lock;
#ifdef NTOPNG_PRO
  CustomAppMaps *custom_app_maps;
#endif

  bool preprocessFlow(ParsedFlow *flow);
  bool getKeyId(char *sym, u_int32_t sym_len, u_int32_t * const pen, u_int32_t * const field) const;
  void addMapping(const char *sym, u_int32_t num, u_int32_t pen = 0);
  bool parsePENZeroField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const;
  bool parsePENNtopField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const;
  bool matchPENZeroField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const;
  bool matchPENNtopField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const;
  static bool parseContainerInfo(json_object *jo, ContainerInfo * const container_info);
  bool parseNProbeAgentField(ParsedFlow * const flow, const char * const key, ParsedValue *value, json_object * const jvalue) const;
  int parseSingleJSONFlow(json_object *o, u_int8_t source_id);
  int parseSingleTLVFlow(ndpi_deserializer *deserializer, u_int8_t source_id);
  void setFieldMap(const ZMQ_FieldMap * const field_map) const;
  void setFieldValueMap(const ZMQ_FieldValueMap * const field_value_map) const;

  u_int8_t parseOptionFieldMap(json_object * const jo) const;
  u_int8_t parseOptionFieldValueMap(json_object * const jo) const;

protected:
  struct {
    u_int32_t num_flows, /* flows processed */
      num_dropped_flows, /* flows unhandles (received but no room in the flow hash) */
      num_events, num_counters, num_hello,
      num_templates, num_options, num_network_events,
      zmq_msg_rcvd, zmq_msg_drops;
  } recvStats, recvStatsCheckpoint;
  inline void updateFlowMaxIdle() { returned_flow_max_idle = max(remote_idle_timeout, flow_max_idle); }
  
public:
  ZMQParserInterface(const char *endpoint, const char *custom_interface_type = NULL);
  ~ZMQParserInterface();

  virtual InterfaceType getIfType() const { return(interface_type_ZMQ); }
  virtual bool isSampledTraffic()   const { return(is_sampled_traffic); }

  bool matchField(ParsedFlow * const flow, const char * const key, ParsedValue * value);

  u_int8_t parseJSONFlow(const char * const payload, int payload_size, u_int8_t source_id);
  u_int8_t parseTLVFlow(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseEvent(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseCounter(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseTemplate(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseOption(const char * const payload, int payload_size, u_int8_t source_id, void *data);

  u_int32_t periodicStatsUpdateFrequency() const;
  virtual void setRemoteStats(ZMQ_RemoteStats *zrs);
#ifdef NTOPNG_PRO
  virtual bool getCustomAppDetails(u_int32_t remapped_app_id, u_int32_t *const pen, u_int32_t *const app_field, u_int32_t *const app_id);
#endif
  u_int32_t getNumDroppedPackets() { return zmq_remote_stats ? zmq_remote_stats->sflow_pkt_sample_drops : 0; };
  virtual void lua(lua_State* vm);
  inline u_int32_t getFlowMaxIdle() { return(returned_flow_max_idle); }
};

#endif /* _ZMQ_PARSER_INTERFACE_H_ */



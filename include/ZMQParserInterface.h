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

#ifndef _ZMQ_PARSER_INTERFACE_H_
#define _ZMQ_PARSER_INTERFACE_H_

#include "ntop_includes.h"

class ZMQParserInterface : public ParserInterface {
 private:
  Mutex companions_lock;
  u_int8_t num_companion_interfaces;
  NetworkInterface **companion_interfaces;
  typedef std::pair<u_int32_t, u_int32_t> pen_value_t;
  typedef std::map<string, pen_value_t > labels_map_t;
  labels_map_t labels_map;
  bool once;
  u_int64_t zmq_initial_bytes, zmq_initial_pkts,
    zmq_remote_initial_exported_flows;
  ZMQ_RemoteStats *zmq_remote_stats, *zmq_remote_stats_shadow;
#ifdef NTOPNG_PRO
  CustomAppMaps *custom_app_maps;
#endif
  virtual void reloadCompanions();
  void deliverFlowToCompanions(ParsedFlow * const flow);
  void preprocessFlow(ParsedFlow *flow, NetworkInterface *iface);
  bool getKeyId(char *sym, u_int32_t * const pen, u_int32_t * const field) const;
  void addMapping(const char *sym, u_int32_t num, u_int32_t pen = 0);
  bool parsePENZeroField(ParsedFlow * const flow, u_int32_t field, const char * const value, u_int32_t ivalue) const;
  bool parsePENNtopField(ParsedFlow * const flow, u_int32_t field, const char * const value, u_int32_t ivalue) const;
  static bool parseContainerInfo(json_object *jo, ContainerInfo * const container_info);
  bool parseNProbeMiniField(ParsedFlow * const flow, const char * const key, const char * const value, json_object * const jvalue) const;
  void parseSingleJSONFlow(json_object *o, u_int8_t source_id, NetworkInterface *iface);
  int parseSingleTLVFlow(ndpi_deserializer *deserializer, u_int8_t source_id, NetworkInterface *iface);
  void setFieldMap(const ZMQ_FieldMap * const field_map) const;
  void setFieldValueMap(const ZMQ_FieldValueMap * const field_value_map) const;

  u_int8_t parseOptionFieldMap(json_object * const jo) const;
  u_int8_t parseOptionFieldValueMap(json_object * const jo) const;
    
 public:
  ZMQParserInterface(const char *endpoint, const char *custom_interface_type = NULL);
  ~ZMQParserInterface();

  u_int8_t parseJSONFlow(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseTLVFlow(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseEvent(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseCounter(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseTemplate(const char * const payload, int payload_size, u_int8_t source_id, void *data);
  u_int8_t parseOption(const char * const payload, int payload_size, u_int8_t source_id, void *data);

  virtual void setRemoteStats(ZMQ_RemoteStats *zrs);
#ifdef NTOPNG_PRO
  virtual bool getCustomAppDetails(u_int32_t remapped_app_id, u_int32_t *const pen, u_int32_t *const app_field, u_int32_t *const app_id);
#endif
  u_int32_t getNumDroppedPackets() { return zmq_remote_stats ? zmq_remote_stats->sflow_pkt_sample_drops : 0; };
  virtual void lua(lua_State* vm);
};

#endif /* _ZMQ_PARSER_INTERFACE_H_ */



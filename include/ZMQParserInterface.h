/*
 *
 * (C) 2013-26 - ntop.org
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

struct In6AddrCompare {
  bool operator()(const struct in6_addr& lhs, const struct in6_addr& rhs) const {
    return std::memcmp(&lhs, &rhs, sizeof(struct in6_addr)) < 0;
  }
};

class ZMQParserInterface : public ParserInterface {
 private:
  typedef std::pair<u_int32_t, u_int32_t> pen_value_t;
  typedef std::pair<string, bool>
      description_value_t; /* < Description , Native Value > */
  typedef std::map<string, pen_value_t> labels_map_t;
  typedef std::map<pen_value_t, description_value_t> descriptions_map_t;
  typedef std::map<string, u_int32_t> counters_map_t;
  u_int16_t top_vlan_id;
  u_int32_t next_msg_time;
  std::unordered_map<std::string, u_int16_t> name_to_vlan;
  labels_map_t labels_map; /* Contains mappings between labels and integer IDs
                              (PEN and ID) */
  counters_map_t counters_map; /* Contains mappings between sFlow counter field
                                  labels and integer IDs */
  descriptions_map_t descriptions_map; /* Contains mappings between integer IDs
                                          and descriptions */
  u_int32_t polling_start_time;
  bool once, is_sampled_traffic;
  u_int32_t flow_max_idle, returned_flow_max_idle;

  /* Note: using a small structure to account cumulative stats from
   * all remote probes. This is accessed concurrently, thus please
   * consider a lock or shadow if you need to handle non-atomic access. */
  CumulativenProbeStats cumulative_remote_stats;
  struct timeval last_cumulative_remote_stats_update;

  u_int32_t remote_lifetime_timeout, remote_idle_timeout;

#ifdef NTOPNG_PRO
  CustomAppMaps* custom_app_maps;
#endif

  void loadVLANMappings();
  u_int16_t findVLANMapping(std::string name);

  bool preprocessFlow(ParsedFlow* flow);
  void addMapping(const char* sym, u_int32_t num, u_int32_t pen = 0,
                  const char* descr = NULL);
  void addCounterMapping(const char* sym, u_int32_t id);
  bool parsePENZeroField(ParsedFlow* const flow, u_int32_t field,
                         ParsedValue* value);
  bool parsePENNtopField(ParsedFlow* const flow, u_int32_t field,
                         ParsedValue* value);
  bool matchPENZeroField(ParsedFlow* const flow, u_int32_t field,
                         ParsedValue* value);
  bool matchPENNtopField(ParsedFlow* const flow, u_int32_t field,
                         ParsedValue* value);
  static bool parseContainerInfo(json_object* jo,
                                 ContainerInfo* const container_info);
  static void freeContainerInfo(ContainerInfo* const container_info);
  void addMappingFromRedis();
  bool parseNProbeAgentField(ParsedFlow* const flow, const char* key,
                             ParsedValue* value, json_object* const jvalue);
  int parseSingleJSONFlow(json_object* o);
  int parseSingleTLVFlow(ndpi_deserializer* deserializer, u_int32_t record_id);
  void setFieldMap(const ZMQ_FieldMap* const field_map) const;
  void setFieldValueMap(const ZMQ_FieldValueMap* const field_value_map) const;

  u_int8_t parseOptionFieldMap(json_object* const jo);
  u_int8_t parseOptionFieldValueMap(json_object* const jo);

 protected:
  struct {
    u_int64_t zmq_msg_rcvd, zmq_msg_drops, num_flows, /* flows processed */
        num_dropped_flows; /* flows unhandles (received but no room in the flow
                              hash) */
    u_int32_t num_events, num_counters, num_hello, num_listening_ports,
        num_templates, num_options, num_snmp_interfaces;
  } recvStats, recvStatsCheckpoint;
  inline void updateFlowMaxIdle() {
    returned_flow_max_idle = max(remote_idle_timeout, flow_max_idle);
  }

 public:
  ZMQParserInterface(const char* endpoint,
                     const char* custom_interface_type = NULL);
  ~ZMQParserInterface();

  virtual InterfaceType getIfType() const { return (interface_type_ZMQ); }
  virtual bool isSampledTraffic() const { return (is_sampled_traffic); }

  bool getKeyId(char* sym, u_int32_t sym_len, u_int32_t* const pen,
                u_int32_t* const field) const;
  const char* getKeyDescription(u_int32_t pen, u_int32_t field) const;
  void luaGetAllKeyDescription(lua_State* vm);
  bool matchField(ParsedFlow* const flow, const char* key, ParsedValue* value);

  bool getCounterId(char* sym, u_int32_t sym_len, u_int32_t* id) const;

  u_int8_t parseJSONFlows(const char* payload, int payload_size);
  u_int32_t parseTLVFlows(const char* payload, int payload_size, void* data);
  u_int8_t parseEvent(const char* payload, int payload_size,
                      bool check_clock_drift, void* data);
  u_int8_t parseTLVCounter(const char* payload, int payload_size);
  u_int8_t parseJSONCounter(const char* payload, int payload_size);
  u_int8_t parseJSONCustomIE(const char* payload, int payload_size);
  u_int8_t parseTemplate(const char* payload, int payload_size, void* data);
  u_int8_t parseOption(const char* payload, int payload_size, void* data);
  u_int8_t parseListeningPorts(const char* payload, int payload_size,
                               void* data);
  u_int8_t parseSNMPIntefaces(const char* payload, int payload_size,
                              void* data);

  u_int32_t periodicStatsUpdateFrequency() const;
  virtual void checkPointCounters(bool drops_only);
  virtual void setRemoteStats(nProbeStats* zrs);
#ifdef NTOPNG_PRO
  virtual bool getCustomAppDetails(u_int32_t remapped_app_id,
                                   u_int32_t* const pen,
                                   u_int32_t* const app_field,
                                   u_int32_t* const app_id);
#endif
  u_int32_t getNumDroppedPackets() {
    return cumulative_remote_stats.sflow_pkt_sample_drops;
  };
  virtual void lua(lua_State* vm, bool fullStats);
  virtual void probeLuaStats(lua_State* vm);
  inline u_int32_t getFlowMaxIdle() { return (returned_flow_max_idle); }
};

#endif /* _ZMQ_PARSER_INTERFACE_H_ */

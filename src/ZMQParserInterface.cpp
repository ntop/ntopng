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

#ifndef HAVE_NEDGE

// #define DEBUG_FLOW_DRIFT

/* **************************************************** */

/* IMPORTANT: keep it in sync with flow_fields_description part of flow_utils.lua */
ZMQParserInterface::ZMQParserInterface(const char *endpoint, const char *custom_interface_type) :
  ParserInterface(endpoint, custom_interface_type) {
  zmq_initial_bytes = 0, zmq_initial_pkts = 0;
  zmq_remote_stats = zmq_remote_stats_shadow = NULL;
  memset(&last_zmq_remote_stats_update, 0, sizeof(last_zmq_remote_stats_update));
  zmq_remote_initial_exported_flows = 0;
  remote_lifetime_timeout = remote_idle_timeout = 0;
  once = false, is_sampled_traffic = false;
  flow_max_idle = ntop->getPrefs()->get_pkt_ifaces_flow_max_idle();
#ifdef NTOPNG_PRO
  custom_app_maps = NULL;
#endif

  updateFlowMaxIdle();
  memset(&recvStats, 0, sizeof(recvStats));
  memset(&recvStatsCheckpoint, 0, sizeof(recvStatsCheckpoint));

  /* Populate defaults for @NTOPNG@ nProbe templates. No need to populate
     all the fields as nProbe will sent them periodically.

  This minimum set is required for backward compatibility. */
  addMapping("IN_SRC_MAC", IN_SRC_MAC);
  addMapping("OUT_SRC_MAC", OUT_SRC_MAC);
  addMapping("IN_DST_MAC", IN_DST_MAC);
  addMapping("OUT_DST_MAC", OUT_DST_MAC);
  addMapping("SRC_VLAN", SRC_VLAN);
  addMapping("DST_VLAN", DST_VLAN);
  addMapping("DOT1Q_SRC_VLAN", DOT1Q_SRC_VLAN);
  addMapping("DOT1Q_DST_VLAN", DOT1Q_DST_VLAN);
  addMapping("INPUT_SNMP", INPUT_SNMP);
  addMapping("OUTPUT_SNMP", OUTPUT_SNMP);
  addMapping("IPV4_SRC_ADDR", IPV4_SRC_ADDR);
  addMapping("IPV4_DST_ADDR", IPV4_DST_ADDR);
  addMapping("SRC_TOS", SRC_TOS);
  addMapping("DST_TOS", DST_TOS);
  addMapping("L4_SRC_PORT", L4_SRC_PORT);
  addMapping("L4_DST_PORT", L4_DST_PORT);
  addMapping("IPV6_SRC_ADDR", IPV6_SRC_ADDR);
  addMapping("IPV6_DST_ADDR", IPV6_DST_ADDR);
  addMapping("IP_PROTOCOL_VERSION", IP_PROTOCOL_VERSION);
  addMapping("PROTOCOL", PROTOCOL);
  addMapping("L7_PROTO", L7_PROTO, NTOP_PEN);
  addMapping("L7_PROTO_NAME", L7_PROTO_NAME, NTOP_PEN);
  addMapping("IN_BYTES", IN_BYTES);
  addMapping("IN_PKTS", IN_PKTS);
  addMapping("OUT_BYTES", OUT_BYTES);
  addMapping("OUT_PKTS", OUT_PKTS);
  addMapping("FIRST_SWITCHED", FIRST_SWITCHED);
  addMapping("LAST_SWITCHED", LAST_SWITCHED);
  addMapping("EXPORTER_IPV4_ADDRESS", EXPORTER_IPV4_ADDRESS);
  addMapping("EXPORTER_IPV6_ADDRESS", EXPORTER_IPV6_ADDRESS);
  addMapping("NPROBE_IPV4_ADDRESS", NPROBE_IPV4_ADDRESS, NTOP_PEN);
  addMapping("TCP_FLAGS", TCP_FLAGS);
  addMapping("INITIATOR_PKTS", INITIATOR_PKTS);
  addMapping("INITIATOR_OCTETS", INITIATOR_OCTETS);
  addMapping("RESPONDER_PKTS", RESPONDER_PKTS);
  addMapping("RESPONDER_OCTETS", RESPONDER_OCTETS);
  addMapping("SAMPLING_INTERVAL", SAMPLING_INTERVAL);
  addMapping("DIRECTION", DIRECTION);
  addMapping("POST_NAT_SRC_IPV4_ADDR", POST_NAT_SRC_IPV4_ADDR);
  addMapping("POST_NAT_DST_IPV4_ADDR", POST_NAT_DST_IPV4_ADDR);
  addMapping("POST_NAPT_SRC_TRANSPORT_PORT", POST_NAPT_SRC_TRANSPORT_PORT);
  addMapping("POST_NAPT_DST_TRANSPORT_PORT", POST_NAPT_DST_TRANSPORT_PORT);
  addMapping("OBSERVATION_POINT_ID", OBSERVATION_POINT_ID);
  addMapping("INGRESS_VRFID", INGRESS_VRFID);
  addMapping("IPV4_SRC_MASK", IPV4_SRC_MASK);
  addMapping("IPV4_DST_MASK", IPV4_DST_MASK);
  addMapping("IPV4_NEXT_HOP", IPV4_NEXT_HOP);
  addMapping("SRC_AS", SRC_AS);
  addMapping("DST_AS", DST_AS);
  addMapping("BGP_NEXT_ADJACENT_ASN", BGP_NEXT_ADJACENT_ASN);
  addMapping("BGP_PREV_ADJACENT_ASN", BGP_PREV_ADJACENT_ASN);
  addMapping("OOORDER_IN_PKTS", OOORDER_IN_PKTS, NTOP_PEN);
  addMapping("OOORDER_OUT_PKTS", OOORDER_OUT_PKTS, NTOP_PEN);
  addMapping("RETRANSMITTED_IN_PKTS", RETRANSMITTED_IN_PKTS, NTOP_PEN);
  addMapping("RETRANSMITTED_OUT_PKTS", RETRANSMITTED_OUT_PKTS, NTOP_PEN);
  addMapping("DNS_QUERY", DNS_QUERY, NTOP_PEN);
  addMapping("DNS_QUERY_TYPE", DNS_QUERY_TYPE, NTOP_PEN);
  addMapping("DNS_RET_CODE", DNS_RET_CODE, NTOP_PEN);
  addMapping("HTTP_URL", HTTP_URL, NTOP_PEN);
  addMapping("HTTP_SITE", HTTP_SITE, NTOP_PEN);
  addMapping("HTTP_RET_CODE", HTTP_RET_CODE, NTOP_PEN);
  addMapping("HTTP_METHOD", HTTP_METHOD, NTOP_PEN);
  addMapping("SSL_SERVER_NAME", SSL_SERVER_NAME, NTOP_PEN);
  addMapping("TLS_CIPHER", TLS_CIPHER, NTOP_PEN);
  addMapping("SSL_UNSAFE_CIPHER", SSL_UNSAFE_CIPHER, NTOP_PEN);
  addMapping("JA3C_HASH", JA3C_HASH, NTOP_PEN);
  addMapping("JA3S_HASH", JA3S_HASH, NTOP_PEN);
  addMapping("BITTORRENT_HASH", BITTORRENT_HASH, NTOP_PEN);
  addMapping("SRC_FRAGMENTS", SRC_FRAGMENTS, NTOP_PEN);
  addMapping("DST_FRAGMENTS", DST_FRAGMENTS, NTOP_PEN);
  addMapping("CLIENT_NW_LATENCY_MS", CLIENT_NW_LATENCY_MS, NTOP_PEN);
  addMapping("SERVER_NW_LATENCY_MS", SERVER_NW_LATENCY_MS, NTOP_PEN);
  addMapping("L7_PROTO_RISK", L7_PROTO_RISK, NTOP_PEN);
  addMapping("FLOW_VERDICT", FLOW_VERDICT, NTOP_PEN);
}

/* **************************************************** */

ZMQParserInterface::~ZMQParserInterface() {
  map<u_int8_t, ZMQ_RemoteStats*>::iterator it;

  if(zmq_remote_stats)        free(zmq_remote_stats);
  if(zmq_remote_stats_shadow) free(zmq_remote_stats_shadow);
#ifdef NTOPNG_PRO
  if(custom_app_maps)         delete(custom_app_maps);
#endif

  for(it = source_id_last_zmq_remote_stats.begin(); it != source_id_last_zmq_remote_stats.end(); ++it)
    free(it->second);
  
  source_id_last_zmq_remote_stats.clear();
}

/* **************************************************** */

void ZMQParserInterface::addMapping(const char *sym, u_int32_t num, u_int32_t pen) {
  string label(sym);
  labels_map_t::iterator it;

  if((it = labels_map.find(label)) == labels_map.end())
    labels_map.insert(make_pair(label, make_pair(pen, num)));
  else
    it->second.first = pen, it->second.second = num;
}

/* **************************************************** */

bool ZMQParserInterface::getKeyId(char *sym, u_int32_t sym_len, u_int32_t * const pen, u_int32_t * const field) const {
  u_int32_t cur_pen, cur_field;
  string label(sym);
  labels_map_t::const_iterator it;
  bool is_num, is_dotted;

  *pen = UNKNOWN_PEN, *field = UNKNOWN_FLOW_ELEMENT;

  is_num = Utils::isNumber(sym, sym_len, &is_dotted);

  if(is_num && is_dotted) {
    if(sscanf(sym, "%u.%u", &cur_pen, &cur_field) != 2)
      return false;
    *pen = cur_pen, *field = cur_field;
  } else if(is_num) {
    cur_field = atoi(sym);
    *pen = 0, *field = cur_field;
  } else if((it = labels_map.find(label)) != labels_map.end()) {
    *pen = it->second.first, *field = it->second.second;
  } else {
    return false;
  }

  return true;
}

/* **************************************************** */

u_int8_t ZMQParserInterface::parseEvent(const char * const payload, int payload_size,
					u_int8_t source_id, void *data) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  ZMQ_RemoteStats zrs;
  const u_int32_t max_timeout = 600;

  memset(&zrs, 0, sizeof(zrs));

  // payload[payload_size] = '\0';
  
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", payload);
  o = json_tokener_parse_verbose(payload, &jerr);

  if(o) {
    json_object *w, *z;

    zrs.source_id = source_id;
    zrs.local_time = (u_int32_t) time(NULL);

    if(json_object_object_get_ex(o, "time", &w))    zrs.remote_time  = (u_int32_t)json_object_get_int64(w);
    if(json_object_object_get_ex(o, "bytes", &w))   zrs.remote_bytes = (u_int64_t)json_object_get_int64(w);
    if(json_object_object_get_ex(o, "packets", &w)) zrs.remote_pkts  = (u_int64_t)json_object_get_int64(w);

    if(json_object_object_get_ex(o, "iface", &w)) {
      if(json_object_object_get_ex(w, "name", &z))
	snprintf(zrs.remote_ifname, sizeof(zrs.remote_ifname), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "speed", &z))
	zrs.remote_ifspeed = (u_int32_t)json_object_get_int64(z);
      if(json_object_object_get_ex(w, "ip", &z))
	snprintf(zrs.remote_ifaddress, sizeof(zrs.remote_ifaddress), "%s", json_object_get_string(z));
    }

    if(json_object_object_get_ex(o, "probe", &w)) {
      if(json_object_object_get_ex(w, "public_ip", &z))
	snprintf(zrs.remote_probe_public_address, sizeof(zrs.remote_probe_public_address), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "ip", &z))
	snprintf(zrs.remote_probe_address, sizeof(zrs.remote_probe_address), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "version", &z))
	snprintf(zrs.remote_probe_version, sizeof(zrs.remote_probe_version), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "osname", &z))
	snprintf(zrs.remote_probe_os, sizeof(zrs.remote_probe_os), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "license", &z))
	snprintf(zrs.remote_probe_license, sizeof(zrs.remote_probe_license), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "edition", &z))
	snprintf(zrs.remote_probe_edition, sizeof(zrs.remote_probe_edition), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "maintenance", &z))
	snprintf(zrs.remote_probe_maintenance, sizeof(zrs.remote_probe_maintenance), "%s", json_object_get_string(z));
    }

    if(json_object_object_get_ex(o, "avg", &w)) {
      if(json_object_object_get_ex(w, "bps", &z))
	zrs.avg_bps = (u_int32_t)json_object_get_int64(z);
      if(json_object_object_get_ex(w, "pps", &z))
	zrs.avg_pps = (u_int32_t)json_object_get_int64(z);
    }

    if(json_object_object_get_ex(o, "timeout", &w)) {
      if(json_object_object_get_ex(w, "lifetime", &z)) {
	zrs.remote_lifetime_timeout = (u_int32_t)json_object_get_int64(z);

	if(zrs.remote_lifetime_timeout > max_timeout)
	  zrs.remote_lifetime_timeout = max_timeout;
      }

      if(json_object_object_get_ex(w, "idle", &z)) {
	zrs.remote_idle_timeout = (u_int32_t)json_object_get_int64(z);

	if(zrs.remote_idle_timeout > max_timeout)
	  zrs.remote_idle_timeout = max_timeout;
      }

      if(json_object_object_get_ex(w, "collected_lifetime", &z))
	zrs.remote_collected_lifetime_timeout = (u_int32_t)json_object_get_int64(z);
    }

    if(json_object_object_get_ex(o, "drops", &w)) {
      if(json_object_object_get_ex(w, "export_queue_full", &z))
	zrs.export_queue_full = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "too_many_flows", &z))
	zrs.too_many_flows = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "elk_flow_drops", &z))
	zrs.elk_flow_drops = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "sflow_pkt_sample_drops", &z))
	zrs.sflow_pkt_sample_drops = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "flow_collection_drops", &z))
	zrs.flow_collection_drops = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "flow_collection_udp_socket_drops", &z))
	zrs.flow_collection_udp_socket_drops = (u_int32_t)json_object_get_int64(z);
    }

    if(json_object_object_get_ex(o, "flow_collection", &w)) {
      if(json_object_object_get_ex(w, "nf_ipfix_flows", &z))
	zrs.flow_collection.nf_ipfix_flows = (u_int64_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "sflow_samples", &z))
	zrs.flow_collection.sflow_samples = (u_int64_t)json_object_get_int64(z);
    }

    if(json_object_object_get_ex(o, "zmq", &w)) {
      if(json_object_object_get_ex(w, "num_flow_exports", &z))
	zrs.num_flow_exports = (u_int64_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "num_exporters", &z))
	zrs.num_exporters = (u_int8_t)json_object_get_int(z);
    }

#ifdef ZMQ_EVENT_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Event parsed "
				 "[iface: {name: %s, speed: %u, ip: %s}]"
				 "[probe: {public_ip: %s, ip: %s, version: %s, os: %s, license: %s, edition: %s, maintenance: %s}]"
				 "[avg: {bps: %u, pps: %u}]"
				 "[remote: {time: %u, bytes: %u, packets: %u, idle_timeout: %u, lifetime_timeout: %u,"
				 " collected_lifetime_timeout: %u }]"
				 "[zmq: {num_exporters: %u, num_flow_exports: %u}]",
				 zrs.remote_ifname, zrs.remote_ifspeed, zrs.remote_ifaddress,
				 zrs.remote_probe_version, zrs.remote_probe_os,
				 zrs.remote_probe_license, zrs.remote_probe_edition, zrs.remote_probe_maintenance,
				 zrs.remote_probe_public_address, zrs.remote_probe_address,
				 zrs.avg_bps, zrs.avg_pps,
				 zrs.remote_time, (u_int32_t)zrs.remote_bytes, (u_int32_t)zrs.remote_pkts,
				 zrs.remote_idle_timeout, zrs.remote_lifetime_timeout,
				 zrs.remote_collected_lifetime_timeout,
				 zrs.num_exporters, zrs.num_flow_exports);
#endif

    remote_lifetime_timeout = zrs.remote_lifetime_timeout, remote_idle_timeout = zrs.remote_idle_timeout;
    
    /* ntop->getTrace()->traceEvent(TRACE_WARNING, "%u/%u", avg_bps, avg_pps); */

    /* Process Flow */
    setRemoteStats(&zrs);

    for(std::map<u_int64_t, NetworkInterface*>::iterator it = flowHashing.begin(); it != flowHashing.end(); ++it) {
      ZMQParserInterface *z = (ZMQParserInterface*)it->second;

      z->setRemoteStats(&zrs);
    }

    /* Dispose memory */
    json_object_put(o);
  } else {
    // if o != NULL
    if(!once) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: "
				   "your nProbe sender is outdated, data encrypted, invalid JSON, or oom?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }
    once = true;
    if(o) json_object_put(o);
    return -1;
  }

  return 0;
}

/* **************************************************** */

bool ZMQParserInterface::parsePENZeroField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const {
  IpAddress ip_aux; /* used to check empty IPs */

  switch(field) {
  case IN_SRC_MAC:
  case OUT_SRC_MAC:
    /* Format 00:00:00:00:00:00 */
    Utils::parseMac(flow->src_mac, value->string);
    break;
  case IN_DST_MAC:
  case OUT_DST_MAC:
    Utils::parseMac(flow->dst_mac, value->string);
    break;
  case SRC_TOS:
    flow->src_tos = value->int_num;
    break;
  case DST_TOS:
    flow->dst_tos = value->int_num;
    break;
  case IPV4_SRC_ADDR:
  case IPV6_SRC_ADDR:
    /*
      The following check prevents an empty ip address (e.g., ::) to
      to overwrite another valid ip address already set.
      This can happen for example when nProbe is configured (-T) to export
      both %IPV4_SRC_ADDR and the %IPV6_SRC_ADDR. In that cases nProbe can
      export a valid ipv4 and an empty ipv6. Without the check, the empty
      v6 address may overwrite the non empty v4.
    */
    if(flow->src_ip.isEmpty()) {
      if(value->string)
	flow->src_ip.set((char *) value->string);
      else
	flow->src_ip.set(ntohl(value->int_num));
    } else {
      ip_aux.set((char *) value->string);

      if(!ip_aux.isEmpty()  && !ntop->getPrefs()->do_override_src_with_post_nat_src())
	/* tried to overwrite a non-empty IP with another non-empty IP */
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Attempt to set source ip multiple times. "
				     "Check exported fields");
    }
    break;
  case IP_PROTOCOL_VERSION:
    flow->version = value->int_num;
    break;

  case IPV4_DST_ADDR:
  case IPV6_DST_ADDR:
    if(flow->dst_ip.isEmpty()) {
      if(value->string)
	flow->dst_ip.set((char *) value->string);
      else
	flow->dst_ip.set(ntohl(value->int_num));
    } else {
      ip_aux.set((char *) value->string);
      if(!ip_aux.isEmpty()  && !ntop->getPrefs()->do_override_dst_with_post_nat_dst())
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Attempt to set destination ip multiple times. "
				     "Check exported fields");
    }
    break;
  case L4_SRC_PORT:
    if(!flow->src_port)
      flow->src_port = htons((u_int32_t) value->int_num);
    break;
  case L4_DST_PORT:
    if(!flow->dst_port)
      flow->dst_port = htons((u_int32_t) value->int_num);
    break;
  case SRC_VLAN:
  case DST_VLAN:
    flow->vlan_id = value->int_num;
    break;
  case DOT1Q_SRC_VLAN:
  case DOT1Q_DST_VLAN:
    if(flow->vlan_id == 0) {
      /* as those fields are the outer vlans in q-in-q
	 we set the vlan_id only if there is no inner vlan
	 value set
      */
     flow->vlan_id = value->int_num;
    }
    break;
  case PROTOCOL:
    flow->l4_proto = value->int_num;
    break;
  case TCP_FLAGS:
    flow->tcp.tcp_flags = value->int_num;
    break;
  case INITIATOR_PKTS:
    flow->absolute_packet_octet_counters = true;
    /* Don't break */
  case IN_PKTS:
    flow->in_pkts = value->int_num;
    break;
  case INITIATOR_OCTETS:
    flow->absolute_packet_octet_counters = true;
    /* Don't break */
  case IN_BYTES:
    flow->in_bytes = value->int_num;
    break;
  case RESPONDER_PKTS:
    flow->absolute_packet_octet_counters = true;
    /* Don't break */
  case OUT_PKTS:
    flow->out_pkts = value->int_num;
    break;
  case RESPONDER_OCTETS:
    flow->absolute_packet_octet_counters = true;
    /* Don't break */
  case OUT_BYTES:
    flow->out_bytes = value->int_num;
    break;
  case FIRST_SWITCHED:
    if(value->string != NULL)
      flow->first_switched = atoi(value->string);
    else
      flow->first_switched = value->int_num;
    break;
  case LAST_SWITCHED:
    if(value->string != NULL)
      flow->last_switched = atoi(value->string);
    else
      flow->last_switched = value->int_num;
    break;
  case SAMPLING_INTERVAL:
    flow->pkt_sampling_rate = value->int_num;
    break;
  case DIRECTION:
    if(value->string != NULL)
      flow->direction = atoi(value->string);
    else
      flow->direction = value->int_num;
    break;
  case EXPORTER_IPV4_ADDRESS:
    if(value->string != NULL) {
      /* Format: a.b.c.d, possibly overrides NPROBE_IPV4_ADDRESS */
      u_int32_t ip = ntohl(inet_addr(value->string));

      if(ip) {
        flow->device_ip = ip;
        return false; /* FIXX check why we are returning false here */
      }
    }
    break;
  case EXPORTER_IPV6_ADDRESS:
    if(value->string != NULL && strlen(value->string) > 0)
      inet_pton(AF_INET6, value->string, &flow->device_ipv6);
    break;
  case INPUT_SNMP:
    flow->inIndex = value->int_num;
    break;
  case OUTPUT_SNMP:
    flow->outIndex = value->int_num;
    break;
  case OBSERVATION_POINT_ID:
    flow->observationPointId = value->int_num;
    break;
  case POST_NAT_SRC_IPV4_ADDR:
    if(ntop->getPrefs()->do_override_src_with_post_nat_src()) {
      if(value->string) {
	IpAddress tmp;
	tmp.set(value->string);
	if(!tmp.isEmpty()) {
	  flow->src_ip.set((char *) value->string);
	}
      } else if(value->int_num) {
	flow->src_ip.set(ntohl(value->int_num));
      }
    }
    break;
  case POST_NAT_DST_IPV4_ADDR:
    if(ntop->getPrefs()->do_override_dst_with_post_nat_dst()) {
      if(value->string) {
	IpAddress tmp;
	tmp.set(value->string);
	if(!tmp.isEmpty()) {
	  flow->dst_ip.set((char *) value->string);
	}
      } else if(value->int_num) {
	flow->dst_ip.set(ntohl(value->int_num));
      }
    }
    break;
  case POST_NAPT_SRC_TRANSPORT_PORT:
    if(ntop->getPrefs()->do_override_src_with_post_nat_src())
      flow->src_port = htons((u_int16_t) value->int_num);
    break;
  case POST_NAPT_DST_TRANSPORT_PORT:
    if(ntop->getPrefs()->do_override_dst_with_post_nat_dst())
      flow->dst_port = htons((u_int16_t) value->int_num);
    break;
  case INGRESS_VRFID:
    flow->vrfId = value->int_num;
    break;
  case IPV4_SRC_MASK:
  case IPV4_DST_MASK:
    if(value->int_num != 0)
      return false;
    break;
  case IPV4_NEXT_HOP:
    if(value->string && strcmp(value->string, "0.0.0.0"))
      return false;
    break;
  case SRC_AS:
    flow->src_as = value->int_num;
    break;
  case DST_AS:
    flow->dst_as = value->int_num;
    break;
  case BGP_NEXT_ADJACENT_ASN:
    flow->next_adjacent_as = value->int_num;
    break;
  case BGP_PREV_ADJACENT_ASN:
    flow->prev_adjacent_as = value->int_num;
    break;
  default:
    ntop->getTrace()->traceEvent(TRACE_INFO, "Skipping no-PEN flow fieldId %u", field);
    return false;
  }

  return true;
}

/* **************************************************** */

bool ZMQParserInterface::parsePENNtopField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const {

  /* Check for backward compatibility to handle cases like field = 123 (CLIENT_NW_LATENCY_MS)
   * instead of field = 57595 (NTOP_BASE_ID + 123) */
  if(field < NTOP_BASE_ID)
    field += NTOP_BASE_ID;

  switch(field) {
  case L7_PROTO:
    if(value->string) {
      if(!strchr(value->string, '.')) {
        /* Old behaviour, only the app protocol */
        flow->l7_proto.app_protocol = atoi(value->string);
      } else {
        char *proto_dot;

        flow->l7_proto.master_protocol = (u_int16_t)strtoll(value->string, &proto_dot, 10);
        flow->l7_proto.app_protocol    = (u_int16_t)strtoll(proto_dot + 1, NULL, 10);
      }
    } else {
      flow->l7_proto.app_protocol = value->int_num;
    }

#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[value: %s][master: %u][app: %u]",
				 value->string ? value->string : "(int)",
				 flow->l7_proto.master_protocol,
				 flow->l7_proto.app_protocol);
#endif
    break;
    
  case L7_PROTO_NAME:
    break;
    
  case OOORDER_IN_PKTS:
    flow->tcp.ooo_in_pkts = value->int_num;
    break;
    
  case OOORDER_OUT_PKTS:
    flow->tcp.ooo_out_pkts = value->int_num;
    break;
    
  case RETRANSMITTED_IN_PKTS:
    flow->tcp.retr_in_pkts = value->int_num;
    break;
    
  case RETRANSMITTED_OUT_PKTS:
    flow->tcp.retr_out_pkts = value->int_num;
    break;
    
    /* TODO add lost in/out to nProbe and here */
  case CLIENT_NW_LATENCY_MS:
    {
      float client_nw_latency;
      client_nw_latency = value->double_num;
      flow->tcp.clientNwLatency.tv_sec = client_nw_latency / 1e3;
      flow->tcp.clientNwLatency.tv_usec = 1e3 * (client_nw_latency - flow->tcp.clientNwLatency.tv_sec * 1e3);
    }
    break;
    
  case SERVER_NW_LATENCY_MS:
    {
      float server_nw_latency;

      server_nw_latency = value->double_num;
      flow->tcp.serverNwLatency.tv_sec = server_nw_latency / 1e3;
      flow->tcp.serverNwLatency.tv_usec = 1e3 * (server_nw_latency - flow->tcp.serverNwLatency.tv_sec * 1e3);
    }
    break;
    
  case CLIENT_TCP_FLAGS:
    flow->tcp.client_tcp_flags = value->int_num;
    flow->tcp.tcp_flags        |= flow->tcp.client_tcp_flags;
    break;
    
  case SERVER_TCP_FLAGS:
    flow->tcp.server_tcp_flags = value->int_num;
    flow->tcp.tcp_flags        |= flow->tcp.server_tcp_flags;
    break;
    
  case APPL_LATENCY_MS:
    flow->tcp.applLatencyMsec = value->double_num;
    break;
    
  case TCP_WIN_MAX_IN:
    flow->tcp.in_window = value->int_num;
    break;
    
  case TCP_WIN_MAX_OUT:
    flow->tcp.out_window = value->int_num;
    break;
    
  case DNS_QUERY:
    if(value->string && value->string[0] && value->string[0] != '\n') {
      if(flow->dns_query) free(flow->dns_query);
      flow->dns_query = strdup(value->string);
    }
    break;
    
  case DNS_QUERY_TYPE:
    if(value->string)
      flow->dns_query_type = atoi(value->string);
    else
      flow->dns_query_type = value->int_num;
    break;
    
  case DNS_RET_CODE:
    if(value->string)
      flow->dns_ret_code = atoi(value->string);
    else
      flow->dns_ret_code = value->int_num;
    break;
    
  case HTTP_URL:
    if(value->string && value->string[0] && value->string[0] != '\n') {
      if(flow->http_url) free(flow->http_url);
      flow->http_url = strdup(value->string);
    }
    break;
    
  case HTTP_SITE:
    if(value->string && value->string[0] && value->string[0] != '\n') {
      if(flow->http_site) free(flow->http_site);
      flow->http_site = strdup(value->string);
    }
    break;
    
  case HTTP_RET_CODE:
    if(value->string)
      flow->http_ret_code = atoi(value->string);
    else
      flow->http_ret_code = value->int_num;
    break;
    
  case HTTP_METHOD:
    if(value->string && value->string[0] && value->string[0] != '\n')
      flow->http_method = ndpi_http_str2method(value->string, strlen(value->string));
    break;
    
  case SSL_SERVER_NAME:
    if(value->string && value->string[0] && value->string[0] != '\n') {
      if(flow->tls_server_name) free(flow->tls_server_name);
      flow->tls_server_name = strdup(value->string);
    }
    break;
    
  case JA3C_HASH:
    if(value->string && value->string[0]) {
      if(flow->ja3c_hash) free(flow->ja3c_hash);
      flow->ja3c_hash = strdup(value->string);
    }
    break;

  case JA3S_HASH:
    if(value->string && value->string[0]) {
      if(flow->ja3s_hash) free(flow->ja3s_hash);
      flow->ja3s_hash = strdup(value->string);
    }
    break;

  case TLS_CIPHER:
    flow->tls_cipher = value->int_num;
    break;

  case SSL_UNSAFE_CIPHER:
    flow->tls_unsafe_cipher = value->int_num;
    break;

  case L7_PROTO_RISK:
    flow->ndpi_flow_risk_bitmap = value->int_num;
    break;

  case FLOW_VERDICT:
    flow->flow_verdict = value->int_num;
    break;

  case BITTORRENT_HASH:
    if(value->string && value->string[0] && value->string[0] != '\n') {
      if(flow->bittorrent_hash) free(flow->bittorrent_hash);
      flow->bittorrent_hash = strdup(value->string);
    }
    break;

  case NPROBE_IPV4_ADDRESS:
    /* Do not override EXPORTER_IPV4_ADDRESS */
    if(value->string && flow->device_ip == 0 && (flow->device_ip = ntohl(inet_addr(value->string))))
      return false;
    break;

  case SRC_FRAGMENTS:
    flow->in_fragments = value->int_num;
    break;

  case DST_FRAGMENTS:
    flow->out_fragments = value->int_num;
    break;

  default:
    return false;
  }

  return true;
}

/* **************************************************** */

bool ZMQParserInterface::matchPENZeroField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const {
  IpAddress ip_aux; /* used to check empty IPs */

  switch(field) {
  case IN_SRC_MAC:
  case OUT_SRC_MAC:
  {
    u_int8_t mac[6];
    Utils::parseMac(mac, value->string);
    return (memcmp(flow->src_mac, mac, sizeof(mac)) == 0);
  }

  case IN_DST_MAC:
  case OUT_DST_MAC:
  {
    u_int8_t mac[6];
    Utils::parseMac(mac, value->string);
    return (memcmp(flow->dst_mac, mac, sizeof(mac)) == 0);
  }

  case SRC_TOS:
    if(value->string) return (flow->src_tos == atoi(value->string));
    else return (flow->src_tos == value->int_num);

  case DST_TOS:
    if(value->string) return (flow->dst_tos == atoi(value->string));
    else return (flow->dst_tos == value->int_num);

  case IPV4_SRC_ADDR:
  case IPV6_SRC_ADDR:
  {
    IpAddress ip;
    if(value->string) ip.set((char *) value->string);
    else ip.set(ntohl(value->int_num));
    return (flow->src_ip.compare(&ip) == 0);
  }

  case IP_PROTOCOL_VERSION:
    if(value->string)
      return (flow->version == atoi(value->string));
    else
      return (flow->version == value->int_num);

  case IPV4_DST_ADDR:
  case IPV6_DST_ADDR:
  {
    IpAddress ip;
    if(value->string) ip.set((char *) value->string);
    else ip.set(ntohl(value->int_num));
    return (flow->dst_ip.compare(&ip) == 0);
  }

  case L4_SRC_PORT:
    if(value->string) return (flow->src_port == htons((u_int32_t) atoi(value->string)));
    else return (flow->src_port == htons((u_int32_t) value->int_num));

  case L4_DST_PORT:
    if(value->string) return (flow->dst_port == htons((u_int32_t) atoi(value->string)));
    else return (flow->dst_port == htons((u_int32_t) value->int_num));

  case SRC_VLAN:
  case DST_VLAN:
  case DOT1Q_SRC_VLAN:
  case DOT1Q_DST_VLAN:
    if(value->string) return (flow->vlan_id == atoi(value->string));
    else return (flow->vlan_id == value->int_num);

  case PROTOCOL:
    if(value->string) return (flow->l4_proto == atoi(value->string));
    else return (flow->l4_proto == value->int_num);

  case DIRECTION:
    if(value->string) return (flow->direction == atoi(value->string));
    else return (flow->direction == value->int_num);

  case EXPORTER_IPV4_ADDRESS:
    return (flow->device_ip == ntohl(inet_addr(value->string)));

  case EXPORTER_IPV6_ADDRESS:
    if(value->string != NULL && strlen(value->string) > 0) {
      struct ndpi_in6_addr ipv6;

      if(inet_pton(AF_INET6, value->string, &ipv6) <= 0)

	return false;
      return (memcmp(&flow->device_ipv6, &ipv6, sizeof(flow->device_ipv6)) == 0);
    }

  case INPUT_SNMP:
    if(value->string) return (flow->inIndex == (u_int32_t)atoi(value->string));
    else return (flow->inIndex == value->int_num);

  case OUTPUT_SNMP:
    if(value->string) return (flow->outIndex == (u_int32_t)atoi(value->string));
    else return (flow->outIndex == value->int_num);

  case OBSERVATION_POINT_ID:
    if(value->string) return (flow->observationPointId == atoi(value->string));
    else return (flow->observationPointId == value->int_num);

  case INGRESS_VRFID:
    if(value->string) return (flow->vrfId == (u_int) atoi(value->string));
    else return (flow->vrfId == value->int_num);

  case SRC_AS:
    if(value->string) return (flow->src_as == (u_int32_t) atoi(value->string));
    else return (flow->src_as == value->int_num);

  case DST_AS:
    if(value->string) return (flow->dst_as == (u_int32_t) atoi(value->string));
    else return (flow->dst_as == value->int_num);

  case BGP_NEXT_ADJACENT_ASN:
    if(value->string) return (flow->next_adjacent_as == (u_int32_t) atoi(value->string));
    else return (flow->next_adjacent_as == value->int_num);

  case BGP_PREV_ADJACENT_ASN:
    if(value->string) return (flow->prev_adjacent_as == (u_int32_t) atoi(value->string));
    else return (flow->prev_adjacent_as == value->int_num);

  default:
    ntop->getTrace()->traceEvent(TRACE_INFO, "Skipping no-PEN flow fieldId %u", field);
    break;
  }

  return false;
}

/* **************************************************** */

bool ZMQParserInterface::matchPENNtopField(ParsedFlow * const flow, u_int32_t field, ParsedValue *value) const {

  /* Check for backward compatibility to handle cases like field = 123 (CLIENT_NW_LATENCY_MS)
   * instead of field = 57595 (NTOP_BASE_ID + 123) */
  if(field < NTOP_BASE_ID)
    field += NTOP_BASE_ID;

  switch(field) {
  case L7_PROTO:
  {
    ndpi_proto l7_proto = { 0 };
    if(value->string) {
      if(!strchr(value->string, '.')) {
        /* Old behaviour, only the app protocol */
        l7_proto.app_protocol = atoi(value->string);
      } else {
        char *proto_dot;
        l7_proto.master_protocol = (u_int16_t)strtoll(value->string, &proto_dot, 10);
        l7_proto.app_protocol    = (u_int16_t)strtoll(proto_dot + 1, NULL, 10);
      }
    } else {
      l7_proto.app_protocol = value->int_num;
    }
    return (flow->l7_proto.app_protocol == l7_proto.app_protocol);
  }

  case L7_PROTO_NAME:
    if(value->string) {
      /* This lookup should be optimized */
      u_int16_t app_protocol = ndpi_get_proto_by_name(get_ndpi_struct(), value->string);
      return (flow->l7_proto.app_protocol == app_protocol);
    } else
      return false;

  case DNS_QUERY:
    if(value->string && flow->dns_query)
      return (strcmp(flow->dns_query, value->string) == 0);
    else
      return false;

  case DNS_QUERY_TYPE:
    if(value->string) return (flow->dns_query_type == atoi(value->string));
    else return (flow->dns_query_type == value->int_num);

  case HTTP_URL:
    if(value->string && flow->http_url)
      return (strcmp(flow->http_url, value->string) == 0);
    else
      return false;

  case HTTP_SITE:
    if(value->string && flow->http_site)
      return (strcmp(flow->http_site, value->string) == 0);
    else
      return false;

  case SSL_SERVER_NAME:
    if(value->string && flow->tls_server_name)
      return (strcmp(flow->tls_server_name, value->string) == 0);
    else
      return false;

  case NPROBE_IPV4_ADDRESS:
    return (flow->device_ip == ntohl(inet_addr(value->string)));

  default:
    break;
  }

  ntop->getTrace()->traceEvent(TRACE_WARNING, "Field %u not supported by flow filtering", field);

  return false;
}

/* **************************************************** */

bool ZMQParserInterface::matchField(ParsedFlow * const flow, const char * const key, ParsedValue * value) {
  u_int32_t pen, key_id;
  bool res;

  if(!getKeyId((char*)key, strlen(key), &pen, &key_id)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Field %s not supported by flow filtering", key);
    return false;
  }

  switch(pen) {
    case 0: /* No PEN */
      res = matchPENZeroField(flow, key_id, value);
      break;
    case NTOP_PEN:
      res = matchPENNtopField(flow, key_id, value);
      break;
    case UNKNOWN_PEN:
    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Field %s not supported by flow filtering", key);
      res = false;
      break;
  }

  return res;
}

/* **************************************************** */

bool ZMQParserInterface::parseNProbeAgentField(ParsedFlow * const flow, const char * const key,
					       ParsedValue *value, json_object * const jvalue) const {
  bool ret = false;
  json_object *obj;

  if(!strncmp(key, "timestamp", 9)) {
    u_int32_t seconds, nanoseconds /* nanoseconds not currently used */;
    if(sscanf(value->string, "%u.%u", &seconds, &nanoseconds) == 2) {
      flow->first_switched = flow->last_switched = seconds;
      ret = true;
    }
  } else if(!strncmp(key, "IPV4_LOCAL_ADDR", 15)
	    || !strncmp(key, "IPV6_LOCAL_ADDR", 15)) {
    flow->src_ip.set(value->string); /* FIX: do not always assume Local == Client */
    ret = true;
  } else if(!strncmp(key, "IPV4_REMOTE_ADDR", 16)
	    || !strncmp(key, "IPV6_REMOTE_ADDR", 16)) {
    flow->dst_ip.set(value->string); /* FIX: do not always assume Remote == Server */
    ret = true;
  } else if(!strncmp(key, "L4_LOCAL_PORT", 13)) {
    flow->src_port = htons((u_int32_t) value->int_num);
    ret = true;
  } else if(!strncmp(key, "L4_REMOTE_PORT", 14)) {
    flow->dst_port = htons((u_int32_t) value->int_num);
    ret = true;
  } else if(!strncmp(key, "INTERFACE_NAME", 7) && strlen(key) == 14) {
    flow->ifname = (char*)json_object_get_string(jvalue);
    ret = true;
  } else if(strlen(key) >= 14 && !strncmp(&key[strlen(key) - 14], "FATHER_PROCESS", 14)) {
    if(json_object_object_get_ex(jvalue, "PID", &obj))   flow->process_info.father_pid = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "UID", &obj))      flow->process_info.father_uid = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "UID_NAME", &obj))    flow->process_info.father_uid_name = (char*)json_object_get_string(obj);
    if(json_object_object_get_ex(jvalue, "GID", &obj))     flow->process_info.father_gid = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "VM_SIZE", &obj))     flow->process_info.actual_memory = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "VM_PEAK", &obj))     flow->process_info.peak_memory = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "PROCESS_PATH", &obj)) flow->process_info.father_process_name = (char*)json_object_get_string(obj);
    if(!flow->process_info_set) flow->process_info_set = true;
    ret = true;

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Father Process [pid: %u][uid: %u][gid: %u][path: %s]",
    //					 flow->process_info.father_pid, flow->process_info.father_uid,
    //				 flow->process_info.father_gid,
    //				 flow->process_info.father_process_name);
  } else if(strlen(key) >= 7 && !strncmp(&key[strlen(key) - 7], "PROCESS", 7)) {
    if(json_object_object_get_ex(jvalue, "PID", &obj))   flow->process_info.pid = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "UID", &obj))      flow->process_info.uid = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "UID_NAME", &obj))    flow->process_info.uid_name = (char*)json_object_get_string(obj);
    if(json_object_object_get_ex(jvalue, "GID", &obj))     flow->process_info.gid = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "VM_SIZE", &obj))     flow->process_info.actual_memory = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "VM_PEAK", &obj))     flow->process_info.peak_memory = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "PROCESS_PATH", &obj)) flow->process_info.process_name = (char*)json_object_get_string(obj);
    if(!flow->process_info_set) flow->process_info_set = true;
    ret = true;

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Process [pid: %u][uid: %u][gid: %u][size/peak vm: %u/%u][path: %s]",
    //				 flow->process_info.pid, flow->process_info.uid, flow->process_info.gid,
    //				 flow->process_info.actual_memory, flow->process_info.peak_memory,
    //				 flow->process_info.process_name);
  } else if(strlen(key) >= 9 && !strncmp(&key[strlen(key) - 9], "CONTAINER", 9)) {
    if((ret = parseContainerInfo(jvalue, &flow->container_info)))
      flow->container_info_set = true;
  } else if(!strncmp(key, "TCP", 3) && strlen(key) == 3) {
    if(json_object_object_get_ex(jvalue, "CONN_STATE", &obj))     flow->tcp_info.conn_state = Utils::tcpStateStr2State(json_object_get_string(obj));

    if(json_object_object_get_ex(jvalue, "SEGS_IN", &obj))        flow->tcp_info.in_segs = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "SEGS_OUT", &obj))       flow->tcp_info.out_segs = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "UNACK_SEGMENTS", &obj)) flow->tcp_info.unacked_segs = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "RETRAN_PKTS", &obj))    flow->tcp_info.retx_pkts = (u_int32_t)json_object_get_int64(obj);
    if(json_object_object_get_ex(jvalue, "LOST_PKTS", &obj))      flow->tcp_info.lost_pkts = (u_int32_t)json_object_get_int64(obj);

    if(json_object_object_get_ex(jvalue, "RTT", &obj))            flow->tcp_info.rtt = json_object_get_double(obj);
    if(json_object_object_get_ex(jvalue, "RTT_VARIANCE", &obj))   flow->tcp_info.rtt_var = json_object_get_double(obj);

    if(json_object_object_get_ex(jvalue, "BYTES_RCVD", &obj))
      flow->out_bytes = flow->tcp_info.rcvd_bytes = (u_int64_t)json_object_get_int64(obj);

    if(json_object_object_get_ex(jvalue, "BYTES_ACKED", &obj))
      flow->in_bytes = flow->tcp_info.sent_bytes = (u_int64_t)json_object_get_int64(obj);

    if(!flow->tcp_info_set) flow->tcp_info_set = true;
    flow->absolute_packet_octet_counters = true;
    ret = true;

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "TCP INFO [conn state: %s][rcvd_bytes: %u][retx_pkts: %u][lost_pkts: %u]"
    //				 "[in_segs: %u][out_segs: %u][unacked_segs: %u]"
    //				 "[rtt: %f][rtt_var: %f]",
    //				 Utils::tcpState2StateStr(flow->tcp_info.conn_state),
    //				 flow->tcp_info.rcvd_bytes,
    //				 flow->tcp_info.retx_pkts,
    //				 flow->tcp_info.lost_pkts,
    //				 flow->tcp_info.in_segs,
    //				 flow->tcp_info.out_segs,
    //				 flow->tcp_info.unacked_segs,
    //				 flow->tcp_info.rtt,
    //				 flow->tcp_info.rtt_var);
  } else if((!strncmp(key, "TCP_EVENT_TYPE", 14) && strlen(key) == 14)
	    || (!strncmp(key, "UDP_EVENT_TYPE", 14) && strlen(key) == 14)) {
    flow->event_type = Utils::eBPFEventStr2Event(value->string);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Event Type [type: %s]", Utils::eBPFEvent2EventStr(flow->event_type));
  }

  return ret;
}

/* **************************************************** */

bool ZMQParserInterface::preprocessFlow(ParsedFlow *flow) {
  bool invalid_flow = false;
  bool rc = false;

  if(flow->vlan_id && ntop->getPrefs()->do_ignore_vlans())
    flow->vlan_id = 0;

  /* Handle zero IPv4/IPv6 discrepacies */
  if(!flow->hasParsedeBPF()) {
    if(flow->src_ip.getVersion() != flow->dst_ip.getVersion()) {
      if(flow->dst_ip.isIPv4() && flow->src_ip.isIPv6() && flow->src_ip.isEmpty())
	flow->src_ip.setVersion(4);
      else if(flow->src_ip.isIPv4() && flow->dst_ip.isIPv6() && flow->dst_ip.isEmpty())
	flow->dst_ip.setVersion(4);
      else if(flow->dst_ip.isIPv6() && flow->src_ip.isIPv4() && flow->src_ip.isEmpty())
	flow->src_ip.setVersion(6);
      else if(flow->src_ip.isIPv6() && flow->dst_ip.isIPv4() && flow->dst_ip.isEmpty())
	flow->dst_ip.setVersion(6);
      else {
	invalid_flow = true;
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "IP version mismatch: client:%d server:%d - flow will be ignored",
				     flow->src_ip.getVersion(), flow->dst_ip.getVersion());
      }
    }
  }

  if(!invalid_flow) {
    if(flow->hasParsedeBPF()) {
      /* Direction already reliable when the event is an accept or a connect.
         Heuristic is only used in the other cases. */
      if(flow->event_type != ebpf_event_type_tcp_accept
	 && flow->event_type != ebpf_event_type_tcp_connect
	 && ntohs(flow->src_port) < ntohs(flow->dst_port))
	flow->swap();
    } else if(ntohs(flow->src_port) < 1024
	      && ntohs(flow->src_port) < ntohs(flow->dst_port)
	      // && flow->in_pkts && flow->out_pkts /* Flows can be mono-directional, so can't use this condition */
	      && (flow->l4_proto != IPPROTO_TCP /* Not TCP or TCP but without SYN (See https://github.com/ntop/ntopng/issues/5058) */
		  /*
		    No SYN (cumulative flow->tcp.tcp_flags are NOT checked as they can contain a SYN but the direction is unknown),
		    do the swap as it is assumed the beginning of the TCP flow has not been seen
		   */
		  || !((flow->tcp.server_tcp_flags | flow->tcp.client_tcp_flags) & TH_SYN)
		  /*
		    The SYN is server to client, swapping is safe
		  */
		  || flow->tcp.server_tcp_flags & TH_SYN))
      /* Attempt to determine flow client and server using port numbers
	 useful when exported flows are mono-directional
	 https://github.com/ntop/ntopng/issues/1978 */
      flow->swap();


    if(flow->pkt_sampling_rate == 0)
      flow->pkt_sampling_rate = 1;

#if 0
    u_int32_t max_drift, boundary;

    /*
      Disabled as this causes timestamps to be altered at every run, invalidating
      first and last switched, as well as throughput data.
    */

    if(getTimeLastPktRcvdRemote() > 0) {
      /*
	Adjust time to make sure time won't break ntopng

	getTimeLastPktRcvdRemote() can be zero at boot so the if()...
      */
      max_drift = 2*flow_max_idle;
      boundary = getTimeLastPktRcvdRemote() - max_drift;
      if(flow->first_switched < boundary) {
#ifdef DEBUG_FLOW_DRIFT
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Fixing first_switched [current: %u][max: %u][drift: %u]",
				     flow->first_switched, boundary, boundary-flow->first_switched);
#endif
	flow->first_switched = boundary;

	if(flow->first_switched > flow->last_switched)
	  flow->last_switched = flow->first_switched;
      }

      boundary = getTimeLastPktRcvdRemote() + max_drift;
      if(flow->last_switched > boundary) {
#ifdef DEBUG_FLOW_DRIFT
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Fixing last_switched [current: %u][max: %u][drift: %u]",
				     flow->last_switched, boundary, flow->last_switched-boundary);
#endif
	flow->last_switched = boundary;

	if(flow->last_switched < flow->first_switched)
	  flow->last_switched = flow->first_switched;
      }
    }

    /* We need to fix the clock drift */
    time_t now = time(NULL);

    if(getTimeLastPktRcvdRemote() > 0) {
      int drift = now - getTimeLastPktRcvdRemote();

      if(drift >= 0)
	flow->last_switched += drift, flow->first_switched += drift;
      else {
	u_int32_t d = (u_int32_t)-drift;

	if(d < flow->last_switched || d < flow->first_switched)
	  flow->last_switched  += drift, flow->first_switched += drift;
      }

#ifdef DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "[first=%u][last=%u][duration: %u][drift: %d][now: %u][remote: %u]",
				   flow->first_switched,  flow->last_switched,
				   flow->last_switched-flow->first_switched, drift,
				   now, getTimeLastPktRcvdRemote());
#endif
    } else {
      /* Old nProbe */

      if(!getTimeLastPktRcvd())
	setTimeLastPktRcvd(now);

      /* NOTE: do not set TimeLastPktRcvdRemote here as doing so will trigger the
       * drift calculation above on next flows, leading to incorrect timestamps.
       */
    }
#endif

    /* Process Flow */
    PROFILING_SECTION_ENTER("processFlow", 30);
    rc = processFlow(flow);
    PROFILING_SECTION_EXIT(30);
  }

  if(!rc)
    recvStats.num_dropped_flows++;

  return rc;
}

/* **************************************************** */

int ZMQParserInterface::parseSingleJSONFlow(json_object *o, u_int8_t source_id) {
  ParsedFlow flow;
  struct json_object_iterator it = json_object_iter_begin(o);
  struct json_object_iterator itEnd = json_object_iter_end(o);
  int ret = 0;

  /* Reset data */
  flow.source_id = source_id;
  flow.direction = UNKNOWN_FLOW_DIRECTION;
  
  while(!json_object_iter_equal(&it, &itEnd)) {
    const char *key     = json_object_iter_peek_name(&it);
    json_object *jvalue = json_object_iter_peek_value(&it);
    json_object *additional_o = NULL;
    enum json_type type = json_object_get_type(jvalue);
    ParsedValue value = { 0 };
    bool add_to_additional_fields = false;

    switch(type) {
    case json_type_int:
      value.int_num = json_object_get_int64(jvalue);
      value.double_num = value.int_num;
      break;
    case json_type_double:
      value.double_num = json_object_get_double(jvalue);
      break;
    case json_type_string:
      value.string = json_object_get_string(jvalue);
      if(strcmp(key,"json") == 0)
	additional_o = json_tokener_parse(value.string);
      break;
    case json_type_object:
      /* This is handled by parseNProbeAgentField or addAdditionalField */
      break;
    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON type %u not supported [key: %s]\n", type, key);
      break;
    }

    if(key != NULL && jvalue != NULL) {
      u_int32_t pen, key_id;
      bool res;

      getKeyId((char*)key, strlen(key), &pen, &key_id);

      switch(pen) {
      case 0: /* No PEN */
	res = parsePENZeroField(&flow, key_id, &value);
	if(res)
	  break;
	/* Dont'break when res == false for backward compatibility: attempt to parse Zero-PEN as Ntop-PEN */
      case NTOP_PEN:
	res = parsePENNtopField(&flow, key_id, &value);
	break;
      case UNKNOWN_PEN:
      default:
	res = false;
	break;
      }

      if(!res) {
	switch(key_id) {
	case 0: //json additional object added by Flow::serialize()
	  if(additional_o != NULL) {
	    struct json_object_iterator additional_it = json_object_iter_begin(additional_o);
	    struct json_object_iterator additional_itEnd = json_object_iter_end(additional_o);

	    while(!json_object_iter_equal(&additional_it, &additional_itEnd)) {

	      const char *additional_key   = json_object_iter_peek_name(&additional_it);
	      json_object *additional_v    = json_object_iter_peek_value(&additional_it);
	      const char *additional_value = json_object_get_string(additional_v);

	      if((additional_key != NULL) && (additional_value != NULL)) {
                //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Additional field: %s", additional_key);
		flow.addAdditionalField(additional_key,
				        json_object_new_string(additional_value));
	      }
	      json_object_iter_next(&additional_it);
	    }
	  }
	  break;
	case UNKNOWN_FLOW_ELEMENT:
	  /* Attempt to parse it as an nProbe mini field */
	  if(parseNProbeAgentField(&flow, key, &value, jvalue)) {
	    if(!flow.hasParsedeBPF()) {
	      flow.setParsedeBPF();
	      flow.absolute_packet_octet_counters = true;
	    }
	    break;
	  }
	default:
#ifdef NTOPNG_PRO
	  if(custom_app_maps || (custom_app_maps = new(std::nothrow) CustomAppMaps()))
	    custom_app_maps->checkCustomApp(key, &value, &flow);
#endif
	  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Not handled ZMQ field %u/%s", key_id, key);
	  add_to_additional_fields = true;
	  break;
	} /* switch */
      }

      if(add_to_additional_fields) {
        //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Additional field: %s", key);
	flow.addAdditionalField(key, json_object_get(jvalue));
      }

      if(additional_o) json_object_put(additional_o);
    } /* if */

    /* Move to the next element */
    json_object_iter_next(&it);
  } // while json_object_iter_equal

  if(preprocessFlow(&flow))
    ret = 1;

  return ret;
}

/* **************************************************** */

int ZMQParserInterface::parseSingleTLVFlow(ndpi_deserializer *deserializer,
					   u_int8_t source_id) {
  ndpi_serialization_type kt, et;
  ParsedFlow flow;
  int ret = 0, rc;
  bool recordFound = false;

  /* Reset data */
  flow.source_id = source_id;
  flow.direction = UNKNOWN_FLOW_DIRECTION;
  
  PROFILING_SECTION_ENTER("Decode TLV", 9);
  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Processing TLV record");
  while((et = ndpi_deserialize_get_item_type(deserializer, &kt)) != ndpi_serialization_unknown) {
    ParsedValue value = { 0 };
    u_int32_t pen = 0, key_id = 0;
    u_int32_t v32 = 0;
    int32_t i32 = 0;
    float f = 0;
    u_int64_t v64 = 0;
    int64_t i64 = 0;
    ndpi_string key, vs;
    char key_str[64];
    u_int8_t vbkp = 0;
    bool add_to_additional_fields = false;
    bool key_is_string = false, value_is_string = false;

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "TLV key type = %u value type = %u", kt, et);

    if(et == ndpi_serialization_end_of_record) {
      ndpi_deserialize_next(deserializer);
      goto end_of_record;
    }

    recordFound = true;

    switch(kt) {
      case ndpi_serialization_uint32:
        ndpi_deserialize_key_uint32(deserializer, &key_id);
      break;
      case ndpi_serialization_string:
        ndpi_deserialize_key_string(deserializer, &key);
        key_is_string = true;
      break;
      default:
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Unsupported TLV key type %u: please update both ntopng and the probe to the same version", kt);
        ret = -1;
      goto error;
    }

    switch(et) {
    case ndpi_serialization_uint32:
      ndpi_deserialize_value_uint32(deserializer, &v32);
      value.double_num = value.int_num = v32;
      break;

    case ndpi_serialization_uint64:
      ndpi_deserialize_value_uint64(deserializer, &v64);
      value.double_num = value.int_num = v64;
      break;

    case ndpi_serialization_int32:
      ndpi_deserialize_value_int32(deserializer, &i32);
      value.double_num = value.int_num = i32;
      break;

    case ndpi_serialization_int64:
      ndpi_deserialize_value_int64(deserializer, &i64);
      value.double_num = value.int_num = i64;
      break;

    case ndpi_serialization_float:
      ndpi_deserialize_value_float(deserializer, &f);
      value.double_num = f;
      break;

    case ndpi_serialization_string:
      ndpi_deserialize_value_string(deserializer, &vs);
      value.string = vs.str;
      value_is_string = true;
      break;

    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unsupported TLV type %u\n", et);
      ret = -1;
      goto error;
    }

    if(key_is_string) {
      u_int8_t kbkp = key.str[key.str_len];
      key.str[key.str_len] = '\0';
      snprintf(key_str, sizeof(key_str), "%s", key.str);
      getKeyId(key.str, key.str_len, &pen, &key_id);
      key.str[key.str_len] = kbkp;
    }

    if(value_is_string) {
      /* Adding '\0' to the end of the string, backing up the character */
      vbkp = vs.str[vs.str_len];
      vs.str[vs.str_len] = '\0';
    }

    switch(pen) {
      case 0: /* No PEN */
        rc = parsePENZeroField(&flow, key_id, &value);
        if(rc)
          break;
        /* Dont'break when rc == false for backward compatibility: attempt to parse Zero-PEN as Ntop-PEN */
      case NTOP_PEN:
        rc = parsePENNtopField(&flow, key_id, &value);
      break;
      case UNKNOWN_PEN:
      default:
        rc = false;
      break;
    }

    if(!key_is_string) {
      if(pen) snprintf(key_str, sizeof(key_str), "%u.%u", pen, key_id);
      else    snprintf(key_str, sizeof(key_str), "%u", key_id);
    }

#if 0
    if(ntop->getTrace()->get_trace_level() >= TRACE_LEVEL_DEBUG) {
      switch(et) {
      case ndpi_serialization_uint32:
      case ndpi_serialization_uint64:
      case ndpi_serialization_int32:
      case ndpi_serialization_int64:
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Key: %s Key-ID: %u PEN: %u Value: %lld", key_str, key_id, pen, value.int_num);
        break;
      case ndpi_serialization_float:
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Key: %s Key-ID: %u PEN: %u Value: %.3f", key_str, key_id, pen, value.double_num);
        break;
      case ndpi_serialization_string:
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Key: %s Key-ID: %u PEN: %u Value: %s", key_str, key_id, pen, value.string);
        break;
      default:
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Key: %s Key-ID: %u PEN: %u Value: -", key_str, key_id, pen);
        break;
      }
    }
#endif

    if(!rc) { /* Not handled */
      switch (key_id) {
	case 0: //json additional object added by Flow::serialize()
          if(strcmp(key_str,"json") == 0 && value_is_string) {
            json_object *additional_o = json_tokener_parse(vs.str);

            if(additional_o) {
  	      struct json_object_iterator additional_it = json_object_iter_begin(additional_o);
  	      struct json_object_iterator additional_itEnd = json_object_iter_end(additional_o);

	      while(!json_object_iter_equal(&additional_it, &additional_itEnd)) {

	        const char *additional_key   = json_object_iter_peek_name(&additional_it);
	        json_object *additional_v    = json_object_iter_peek_value(&additional_it);
	        const char *additional_value = json_object_get_string(additional_v);

	        if((additional_key != NULL) && (additional_value != NULL)) {
                  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Additional field: %s", additional_key);
		  flow.addAdditionalField(additional_key, json_object_new_string(additional_value));
	        }
	        json_object_iter_next(&additional_it);
              }

              json_object_put(additional_o);
	    }
	  }
	  break;
	case UNKNOWN_FLOW_ELEMENT:
#if 0 // TODO
	  /* Attempt to parse it as an nProbe mini field */
	  if(parseNProbeAgentField(&flow, key_str, &value)) {
	    if(!flow.hasParsedeBPF()) {
	      flow.setParsedeBPF();
	      flow.absolute_packet_octet_counters = true;
	    }
	    break;
	  }
#endif
	default:
#ifdef NTOPNG_PRO
	  if(custom_app_maps || (custom_app_maps = new(std::nothrow) CustomAppMaps()))
	    custom_app_maps->checkCustomApp(key_str, &value, &flow);
#endif
	  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Not handled ZMQ field %u.%u", pen, key_id);
	  add_to_additional_fields = true;
	  break;
      } /* switch */
    }

    if(add_to_additional_fields) {
      //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Additional field: %s (Key-ID: %u PEN: %u)", key_str, key_id, pen);
#if 1
      flow.addAdditionalField(deserializer);
#else
      flow.addAdditionalField(key_str,
        value_is_string ? json_object_new_string(value.string) : json_object_new_int64(value.int_num));
#endif
    }

    /* Restoring backed up character at the end of the string in place of '\0' */
    if(value_is_string) vs.str[vs.str_len] = vbkp;

    /* Move to the next element */
    ndpi_deserialize_next(deserializer);

  } /* while */

 end_of_record:
  if(recordFound) {
    PROFILING_SECTION_EXIT(9); /* Closes Decode TLV */
    PROFILING_SECTION_ENTER("processFlow", 10);
    if(preprocessFlow(&flow))
      ret = 1;
    PROFILING_SECTION_EXIT(10);
  }

 error:
  return ret;
}

/* **************************************************** */

u_int8_t ZMQParserInterface::parseJSONFlow(const char * const payload, int payload_size, u_int8_t source_id) {
  json_object *f;
  enum json_tokener_error jerr = json_tokener_success;

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "JSON: '%s' [len=%lu]", payload, strlen(payload));
  printf("\n\n%s\n\n", payload);
#endif

  f = json_tokener_parse_verbose(payload, &jerr);

  if(f != NULL) {
    int n = 0, rc;

    if(json_object_get_type(f) == json_type_array) {
      /* Flow array */
      int id, num_elements = json_object_array_length(f);

      for(id = 0; id < num_elements; id++) {
	rc = parseSingleJSONFlow(json_object_array_get_idx(f, id), source_id);

        if(rc > 0)
          n++;
      }

    } else {
      rc = parseSingleJSONFlow(f, source_id);

      if(rc > 0)
        n++;
    }

    json_object_put(f);
    return n;
  } else {
    // if o != NULL
    if(!once) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: your nProbe sender is outdated, data encrypted or invalid JSON?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }

    once = true;
    return 0;
  }

  return 0;
}

/* **************************************************** */

u_int8_t ZMQParserInterface::parseTLVFlow(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
  ndpi_deserializer deserializer;
  ndpi_serialization_type kt;
  int n = 0, rc;

  rc = ndpi_init_deserializer_buf(&deserializer, (u_int8_t *) payload, payload_size);

  if(rc == -1)
    return 0;

  if(ndpi_deserialize_get_format(&deserializer) != ndpi_serialization_format_tlv) {
    if(!once) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
        "Invalid TLV message: the TLV generated by your probe does not match the version supported "
        "by ntopng, please update both the probe and ntopng to the latest version available");
      once = true;
    }
    return 0;
  }

  while(ndpi_deserialize_get_item_type(&deserializer, &kt) != ndpi_serialization_unknown) {
    rc = parseSingleTLVFlow(&deserializer, source_id);

    if(rc < 0)
      break;
    else if(rc > 0)
      n++;
  }

  return n;
}

/* **************************************************** */

bool ZMQParserInterface::parseContainerInfo(json_object *jo, ContainerInfo * const container_info) {
  json_object *obj, *obj2;

  if(json_object_object_get_ex(jo, "ID", &obj)) container_info->id = (char*)json_object_get_string(obj);

  if(json_object_object_get_ex(jo, "K8S", &obj)) {
    if(json_object_object_get_ex(obj, "POD", &obj2))  container_info->data.k8s.pod  = (char*)json_object_get_string(obj2);
    if(json_object_object_get_ex(obj, "NS", &obj2))   container_info->data.k8s.ns   = (char*)json_object_get_string(obj2);
    container_info->data_type = container_info_data_type_k8s;
  } else if(json_object_object_get_ex(jo, "DOCKER", &obj)) {
    container_info->data_type = container_info_data_type_k8s;
  } else
    container_info->data_type = container_info_data_type_unknown;

  if(obj) {
    if(json_object_object_get_ex(obj, "NAME", &obj2)) container_info->name = (char*)json_object_get_string(obj2);
  }

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Container [id: %s] [%s] [k8s.name: %s][k8s.pod: %s][k8s.ns: %s][docker.name: %s]",
  // 			       container_info->id ? container_info->id : "",
  // 			       container_info->data_type == container_info_data_type_k8s ? "K8S" : container_info->data_type == container_info_data_type_docker ? "DOCKER" : "UNKNOWN",
  // 			       container_info->data_type == container_info_data_type_k8s && container_info->data.k8s.name ? container_info->data.k8s.name : "",
  // 			       container_info->data_type == container_info_data_type_k8s && container_info->data.k8s.pod ? container_info->data.k8s.pod : "",
  // 			       container_info->data_type == container_info_data_type_k8s && container_info->data.k8s.ns ? container_info->data.k8s.ns : "",
  // 			       container_info->data_type == container_info_data_type_docker && container_info->data.docker.name ? container_info->data.docker.name : "");

  return true;
}

/* **************************************************** */

u_int8_t ZMQParserInterface::parseCounter(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  sFlowInterfaceStats stats;

  // payload[payload_size] = '\0';
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", payload);

  memset(&stats, 0, sizeof(stats));
  o = json_tokener_parse_verbose(payload, &jerr);

  if(o != NULL) {
    struct json_object_iterator it = json_object_iter_begin(o);
    struct json_object_iterator itEnd = json_object_iter_end(o);

    /* Reset data */
    memset(&stats, 0, sizeof(stats));

    while(!json_object_iter_equal(&it, &itEnd)) {
      const char *key   = json_object_iter_peek_name(&it);
      json_object *v    = json_object_iter_peek_value(&it);
      const char *value = json_object_get_string(v);

      if((key != NULL) && (value != NULL)) {
	if(!strcmp(key, "deviceIP")) stats.deviceIP = ntohl(inet_addr(value));
	else if(!strcmp(key, "ifIndex")) stats.ifIndex = (u_int32_t)json_object_get_int64(v);
	else if(!strcmp(key, "ifName")) stats.ifName = (char*)json_object_get_string(v);
	else if(!strcmp(key, "ifType")) stats.ifType = (u_int32_t)json_object_get_int64(v);
	else if(!strcmp(key, "ifSpeed")) stats.ifSpeed = (u_int32_t)json_object_get_int64(v);
	else if(!strcmp(key, "ifDirection")) stats.ifFullDuplex = (!strcmp(value, "Full")) ? true : false;
	else if(!strcmp(key, "ifAdminStatus")) stats.ifAdminStatus = (!strcmp(value, "Up")) ? true : false;
	else if(!strcmp(key, "ifOperStatus")) stats.ifOperStatus = (!strcmp(value, "Up")) ? true : false;
	else if(!strcmp(key, "ifInOctets")) stats.ifInOctets = json_object_get_int64(v);
	else if(!strcmp(key, "ifInPackets")) stats.ifInPackets = json_object_get_int64(v);
	else if(!strcmp(key, "ifInErrors")) stats.ifInErrors = json_object_get_int64(v);
	else if(!strcmp(key, "ifOutOctets")) stats.ifOutOctets = json_object_get_int64(v);
	else if(!strcmp(key, "ifOutPackets")) stats.ifOutPackets = json_object_get_int64(v);
	else if(!strcmp(key, "ifOutErrors")) stats.ifOutErrors = json_object_get_int64(v);
	else if(!strcmp(key, "ifPromiscuousMode")) stats.ifPromiscuousMode = (!strcmp(value, "1")) ? true : false;
	else if(strlen(key) >= 9 && !strncmp(&key[strlen(key) - 9], "CONTAINER", 9)) {
	  if(parseContainerInfo(v, &stats.container_info))
	    stats.container_info_set = true;
	}
      } /* if */

      /* Move to the next element */
      json_object_iter_next(&it);
    } // while json_object_iter_equal

    /* Process Flow */
    processInterfaceStats(&stats);

    json_object_put(o);
  } else {
    // if o != NULL
    if(!once)
{      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: your nProbe sender is outdated, data encrypted or invalid JSON?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }
    once = true;
    return -1;
  }

  return 0;
}

/* **************************************************** */

/*
 * Minimum set of fields expected by ntopng
 * NOTE:
 * - the following fields may or may not appear depending on the traffic:
 *   "IPV4_SRC_ADDR", "IPV4_DST_ADDR", "IPV6_SRC_ADDR", "IPV6_DST_ADDR"
 * - some fields may not appear when nprobe runs with --collector-passthrough
 *   "L7_PROTO"
 */
static std::string mandatory_template_fields[] = {
  "FIRST_SWITCHED", "LAST_SWITCHED",
  "L4_SRC_PORT", "L4_DST_PORT",
  "IP_PROTOCOL_VERSION", "PROTOCOL",
  "IN_BYTES", "IN_PKTS", "OUT_BYTES", "OUT_PKTS"
};

u_int8_t ZMQParserInterface::parseTemplate(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
  /* The format that is currently defined for templates is a JSON as follows:

     [{"PEN":0,"field":1,"len":4,"format":"formatted_uint","name":"IN_BYTES","descr":"Incoming flow bytes (src->dst)"},{"PEN":0,"field":2,"len":4,"format":"formatted_uint","name":"IN_PKTS","descr":"Incoming flow packets (src->dst)"},]
  */

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", payload);

  ZMQ_Template zmq_template;
  json_object *obj, *w, *z;
  enum json_tokener_error jerr = json_tokener_success;

  memset(&zmq_template, 0, sizeof(zmq_template));
  obj = json_tokener_parse_verbose(payload, &jerr);

  if(obj) {
    if(json_object_get_type(obj) == json_type_array) {
      int i, num_elements = json_object_array_length(obj);
      std::set<std::string> mandatory_fields(mandatory_template_fields,
	mandatory_template_fields + sizeof(mandatory_template_fields) / sizeof(mandatory_template_fields[0]));

      for(i = 0; i < num_elements; i++) {
	memset(&zmq_template, 0, sizeof(zmq_template));

	w = json_object_array_get_idx(obj, i);

	if(json_object_object_get_ex(w, "PEN", &z))
	  zmq_template.pen = (u_int32_t)json_object_get_int(z);

	if(json_object_object_get_ex(w, "field", &z))
	  zmq_template.field = (u_int32_t)json_object_get_int(z);

	if(json_object_object_get_ex(w, "format", &z))
	  zmq_template.format = json_object_get_string(z);

	if(json_object_object_get_ex(w, "name", &z))
	  zmq_template.name = json_object_get_string(z);

	if(json_object_object_get_ex(w, "descr", &z))
	  zmq_template.descr = json_object_get_string(z);

	if(zmq_template.name) {
	  addMapping(zmq_template.name, zmq_template.field, zmq_template.pen);

	  mandatory_fields.erase(zmq_template.name);
	}

	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Template [PEN: %u][field: %u][format: %s][name: %s][descr: %s]",
	//			     zmq_template.pen, zmq_template.field, zmq_template.format, zmq_template.name, zmq_template.descr)
	  ;
      }

      if(mandatory_fields.size() > 0) {
	static bool template_warning_sent = 0;

	if(!template_warning_sent) {
	  std::set<std::string>::iterator it;

	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Some mandatory fields are missing in the ZMQ template:");
	  template_warning_sent = true;

	  for(it = mandatory_fields.begin(); it != mandatory_fields.end(); ++it) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "\t%s", (*it).c_str());
	  }
	}
      }
    }
    json_object_put(obj);
  } else {
    // if o != NULL
    if(!once) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: your nProbe sender is outdated, data encrypted or invalid JSON?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }
    once = true;
    return -1;
  }

  return 0;
}

/* **************************************************** */

void ZMQParserInterface::setFieldMap(const ZMQ_FieldMap * const field_map) const {
  char hname[CONST_MAX_LEN_REDIS_KEY], key[32];
  snprintf(hname, sizeof(hname), CONST_FIELD_MAP_CACHE_KEY, get_id(), field_map->pen);
  snprintf(key, sizeof(key), "%u", field_map->field);

  ntop->getRedis()->hashSet(hname, key, field_map->map);
}

/* **************************************************** */

void ZMQParserInterface::setFieldValueMap(const ZMQ_FieldValueMap * const field_value_map) const {
  char hname[CONST_MAX_LEN_REDIS_KEY], key[32];
  snprintf(hname, sizeof(hname), CONST_FIELD_VALUE_MAP_CACHE_KEY, get_id(), field_value_map->pen, field_value_map->field);
  snprintf(key, sizeof(key), "%u", field_value_map->value);

  ntop->getRedis()->hashSet(hname, key, field_value_map->map);
}

/* **************************************************** */

u_int8_t ZMQParserInterface::parseOptionFieldMap(json_object * const jo) const {
  int arraylen = json_object_array_length(jo);
  json_object *w, *z;
  ZMQ_FieldMap field_map;
  memset(&field_map, 0, sizeof(field_map));

  for(int i = 0; i < arraylen; i++) {
    w = json_object_array_get_idx(jo, i);

    if(json_object_object_get_ex(w, "PEN", &z))
      field_map.pen = (u_int32_t)json_object_get_int(z);

    if(json_object_object_get_ex(w, "field", &z)) {
      field_map.field = (u_int32_t)json_object_get_int(z);

      if(json_object_object_get_ex(w, "map", &z)) {
	field_map.map = json_object_to_json_string(z);

	setFieldMap(&field_map);

#ifdef CUSTOM_APP_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Option FieldMap [PEN: %u][field: %u][map: %s]",
				     field_map.pen, field_map.field, field_map.map);
#endif
      }
    }
  }

  return 0;
}

/* **************************************************** */

u_int8_t ZMQParserInterface::parseOptionFieldValueMap(json_object * const w) const {
  json_object *z;
  ZMQ_FieldValueMap field_value_map;
  memset(&field_value_map, 0, sizeof(field_value_map));

  if(json_object_object_get_ex(w, "PEN", &z))
    field_value_map.pen = (u_int32_t)json_object_get_int(z);

  if(json_object_object_get_ex(w, "field", &z)) {
    field_value_map.field = (u_int32_t)json_object_get_int(z);

    if(json_object_object_get_ex(w, "value", &z)) {
      field_value_map.value = (u_int32_t)json_object_get_int(z);

      if(json_object_object_get_ex(w, "map", &z)) {
	field_value_map.map = json_object_to_json_string(z);

	setFieldValueMap(&field_value_map);

#ifdef CUSTOM_APP_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Option FieldValueMap [PEN: %u][field: %u][value: %u][map: %s]",
				     field_value_map.pen, field_value_map.field, field_value_map.value, field_value_map.map);
#endif
      }
    }
  }

  return 0;
}

/* **************************************************** */

u_int8_t ZMQParserInterface::parseOption(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
  /* The format that is currently defined for options is a JSON as follows:

    char opt[] = "
    "{\"PEN\":8741, \"field\": 22, \"value\":1, \"map\":{\"name\":\"Skype\"}},"
    "{\"PEN\":8741, \"field\": 22, \"value\":3, \"map\":{\"name\":\"Winni\"}}";

    parseOption(opt, strlen(opt), source_id, this);
  */

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", payload);

  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;

  o = json_tokener_parse_verbose(payload, &jerr);

  if(o != NULL) {
    parseOptionFieldValueMap(o);
    json_object_put(o);
  } else {
    // if o != NULL
    if(!once) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: your nProbe sender is outdated, data encrypted or invalid JSON?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }
    once = true;
    return -1;
  }

  return 0;
}

/* **************************************** */

u_int32_t ZMQParserInterface::periodicStatsUpdateFrequency() const {
  ZMQ_RemoteStats *zrs = zmq_remote_stats;
  u_int32_t update_freq;
  u_int32_t update_freq_min = ntop->getPrefs()->get_housekeeping_frequency();

  if(zrs)
    update_freq = max_val(max_val(zrs->remote_lifetime_timeout, zrs->remote_idle_timeout), zrs->remote_collected_lifetime_timeout);
  else
    update_freq = update_freq_min;

  return max_val(update_freq, update_freq_min);
}

/* **************************************** */

void ZMQParserInterface::setRemoteStats(ZMQ_RemoteStats *zrs) {
  ZMQ_RemoteStats *last_zrs, *cumulative_zrs;
  map<u_int8_t, ZMQ_RemoteStats*>::iterator it;
  u_int32_t last_time = zrs->local_time;
  struct timeval now;

  gettimeofday(&now, NULL);

  /* Store stats for the current exporter */

  lock.wrlock(__FILE__, __LINE__);
  
  if(source_id_last_zmq_remote_stats.find(zrs->source_id) == source_id_last_zmq_remote_stats.end()) {
    last_zrs = (ZMQ_RemoteStats*)malloc(sizeof(ZMQ_RemoteStats));

    if(!last_zrs) {
      lock.unlock(__FILE__, __LINE__);
      return;
    }
    
    source_id_last_zmq_remote_stats[zrs->source_id] = last_zrs;
  } else
    last_zrs = source_id_last_zmq_remote_stats[zrs->source_id];  

  memcpy(last_zrs, zrs, sizeof(ZMQ_RemoteStats));

  lock.unlock(__FILE__, __LINE__);
  
  if(Utils::msTimevalDiff(&now, &last_zmq_remote_stats_update) < 1000) {
    /* Do not update cumulative stats more frequently than once per second.
     * Note: this also avoids concurrent access (use after free) of shadow */
    return;
  }

  /* Sum stats from all exporters */

  cumulative_zrs = (ZMQ_RemoteStats*) calloc(1, sizeof(ZMQ_RemoteStats));
  if(!cumulative_zrs)
    return;

  lock.wrlock(__FILE__, __LINE__); /* Need write lock due to (*) */

  for(it = source_id_last_zmq_remote_stats.begin(); it != source_id_last_zmq_remote_stats.end(); ) {
    ZMQ_RemoteStats *zrs_i = it->second;

    if(zrs_i->local_time < last_time - 3 /* sec */) {
      /* do not account inactive exporters, release them */
      free(zrs_i);
      source_id_last_zmq_remote_stats.erase(it++); /* (*) */
    } else {
      cumulative_zrs->num_exporters += zrs_i->num_exporters;
      cumulative_zrs->remote_bytes += zrs_i->remote_bytes;
      cumulative_zrs->remote_pkts += zrs_i->remote_pkts;
      cumulative_zrs->num_flow_exports += zrs_i->num_flow_exports;
      cumulative_zrs->remote_ifspeed = max_val(cumulative_zrs->remote_ifspeed, zrs_i->remote_ifspeed);
      cumulative_zrs->remote_time = max_val(cumulative_zrs->remote_time, zrs_i->remote_time);
      cumulative_zrs->local_time = max_val(cumulative_zrs->local_time, zrs_i->local_time);
      cumulative_zrs->avg_bps += zrs_i->avg_bps;
      cumulative_zrs->avg_pps += zrs_i->avg_pps;
      cumulative_zrs->remote_lifetime_timeout = max_val(cumulative_zrs->remote_lifetime_timeout, zrs_i->remote_lifetime_timeout);
      cumulative_zrs->remote_collected_lifetime_timeout = max_val(cumulative_zrs->remote_collected_lifetime_timeout, zrs_i->remote_collected_lifetime_timeout);
      cumulative_zrs->remote_idle_timeout = max_val(cumulative_zrs->remote_idle_timeout, zrs_i->remote_idle_timeout);
      cumulative_zrs->export_queue_full += zrs_i->export_queue_full;
      cumulative_zrs->too_many_flows += zrs_i->too_many_flows;
      cumulative_zrs->elk_flow_drops += zrs_i->elk_flow_drops;
      cumulative_zrs->sflow_pkt_sample_drops += zrs_i->sflow_pkt_sample_drops;
      cumulative_zrs->flow_collection_drops += zrs_i->flow_collection_drops;
      cumulative_zrs->flow_collection_udp_socket_drops += zrs_i->flow_collection_udp_socket_drops;
      cumulative_zrs->flow_collection.nf_ipfix_flows += zrs_i->flow_collection.nf_ipfix_flows;
      cumulative_zrs->flow_collection.sflow_samples += zrs_i->flow_collection.sflow_samples;

      ++it;
    }
  }

  lock.unlock(__FILE__, __LINE__);

  ifSpeed = cumulative_zrs->remote_ifspeed;
  last_pkt_rcvd = 0;
  last_pkt_rcvd_remote = cumulative_zrs->remote_time;
  last_remote_pps = cumulative_zrs->avg_pps;
  last_remote_bps = cumulative_zrs->avg_bps;
  if(cumulative_zrs->flow_collection.sflow_samples > 0)
    is_sampled_traffic = true;

  /* Recalculate the flow max idle according to the timeouts received */
  flow_max_idle = max(cumulative_zrs->remote_lifetime_timeout, cumulative_zrs->remote_collected_lifetime_timeout) + 10 /* Safe margin */;
  updateFlowMaxIdle();
  
  if((zmq_initial_pkts == 0) /* ntopng has been restarted */
     || (cumulative_zrs->remote_bytes < zmq_initial_bytes) /* nProbe has been restarted */
     ) {
    /* Start over */
    zmq_initial_bytes = cumulative_zrs->remote_bytes, zmq_initial_pkts = cumulative_zrs->remote_pkts;
  }

  if(zmq_remote_initial_exported_flows == 0 /* ntopng has been restarted */
     || cumulative_zrs->num_flow_exports < zmq_remote_initial_exported_flows) /* nProbe has been restarted */
    zmq_remote_initial_exported_flows = cumulative_zrs->num_flow_exports;

  if(zmq_remote_stats_shadow) free(zmq_remote_stats_shadow);
  zmq_remote_stats_shadow = zmq_remote_stats;
  zmq_remote_stats = cumulative_zrs;

  memcpy(&last_zmq_remote_stats_update, &now, sizeof(now));

  /*
   * Don't override ethStats here, these stats are properly updated
   * inside NetworkInterface::processFlow for ZMQ interfaces.
   * Overriding values here may cause glitches and non-strictly-increasing counters
   * yielding negative rates.
   ethStats.setNumBytes(cumulative_zrs->remote_bytes), ethStats.setNumPackets(cumulative_zrs->remote_pkts);
   *
   */
}

/* **************************************************** */

#ifdef NTOPNG_PRO
bool ZMQParserInterface::getCustomAppDetails(u_int32_t remapped_app_id, u_int32_t *const pen, u_int32_t *const app_field, u_int32_t *const app_id) {
  return custom_app_maps && custom_app_maps->getCustomAppDetails(remapped_app_id, pen, app_field, app_id);
}
#endif

/* **************************************************** */

void ZMQParserInterface::lua(lua_State* vm) {
  ZMQ_RemoteStats *zrs = zmq_remote_stats;
  std::map<u_int8_t, ZMQ_RemoteStats*>::iterator it;
  
  NetworkInterface::lua(vm);

  /* ************************************* */
  
  lua_newtable(vm);

  lock.rdlock(__FILE__, __LINE__);
  
  for(it = source_id_last_zmq_remote_stats.begin(); it != source_id_last_zmq_remote_stats.end(); ++it) {
    ZMQ_RemoteStats *zrs = it->second;

    lua_newtable(vm);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s (%u)", zrs->remote_ifname, it->first);
    
    lua_push_str_table_entry(vm, "remote.name", zrs->remote_ifname);
    lua_push_str_table_entry(vm, "remote.if_addr",zrs->remote_ifaddress);
    lua_push_uint64_table_entry(vm, "remote.ifspeed", zrs->remote_ifspeed);
    lua_push_str_table_entry(vm, "probe.ip", zrs->remote_probe_address);
    lua_push_str_table_entry(vm, "probe.public_ip", zrs->remote_probe_public_address);
    lua_push_str_table_entry(vm, "probe.probe_version", zrs->remote_probe_version);
    lua_push_str_table_entry(vm, "probe.probe_os", zrs->remote_probe_os);
    lua_push_str_table_entry(vm, "probe.probe_license", zrs->remote_probe_license);
    lua_push_str_table_entry(vm, "probe.probe_edition", zrs->remote_probe_edition);
    lua_push_str_table_entry(vm, "probe.probe_maintenance", zrs->remote_probe_maintenance);
    
    lua_pushinteger(vm, it->first);
    lua_insert(vm, -2);
    lua_settable(vm, -3);      
  }

  lock.unlock(__FILE__, __LINE__);
  
  lua_pushstring(vm, "probes");
  lua_insert(vm, -2);
  lua_settable(vm, -3);  

  /* ************************************* */
  
  if(zrs) {
    lua_push_uint64_table_entry(vm, "probe.remote_time", zrs->remote_time); /* remote time when last event has been sent */
    lua_push_uint64_table_entry(vm, "probe.local_time", zrs->local_time); /* local time when last event has been received */

    lua_push_uint64_table_entry(vm, "zmq.num_flow_exports", zrs->num_flow_exports - zmq_remote_initial_exported_flows);
    lua_push_uint64_table_entry(vm, "zmq.num_exporters", zrs->num_exporters);

    if(zrs->export_queue_full > 0)
      lua_push_uint64_table_entry(vm, "zmq.drops.export_queue_full", zrs->export_queue_full);
    if(zrs->flow_collection_drops)
      lua_push_uint64_table_entry(vm, "zmq.drops.flow_collection_drops", zrs->flow_collection_drops);
    if(zrs->flow_collection_udp_socket_drops)
      lua_push_uint64_table_entry(vm, "zmq.drops.flow_collection_udp_socket_drops", zrs->flow_collection_udp_socket_drops);

    lua_push_uint64_table_entry(vm, "timeout.lifetime", zrs->remote_lifetime_timeout);
    lua_push_uint64_table_entry(vm, "timeout.collected_lifetime", zrs->remote_collected_lifetime_timeout);
    lua_push_uint64_table_entry(vm, "timeout.idle", zrs->remote_idle_timeout);
  }
}

/* **************************************************** */

#endif

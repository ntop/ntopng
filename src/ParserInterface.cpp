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

#include "ntop_includes.h"

#ifndef HAVE_NEDGE

/* **************************************************** */

/* IMPORTANT: keep it in sync with flow_fields_description part of flow_utils.lua */
ParserInterface::ParserInterface(const char *endpoint, const char *custom_interface_type) : NetworkInterface(endpoint, custom_interface_type) {
  zmq_initial_bytes = 0, zmq_initial_pkts = 0;
  zmq_remote_stats = zmq_remote_stats_shadow = NULL;
  zmq_remote_initial_exported_flows = 0;
  once = false;
#ifdef NTOPNG_PRO
  custom_app_maps = NULL;
#endif

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
  addMapping("L4_SRC_PORT", L4_SRC_PORT);
  addMapping("L4_DST_PORT", L4_DST_PORT);
  addMapping("IPV6_SRC_ADDR", IPV6_SRC_ADDR);
  addMapping("IPV6_DST_ADDR", IPV6_DST_ADDR);
  addMapping("IP_PROTOCOL_VERSION", IP_PROTOCOL_VERSION);
  addMapping("PROTOCOL", PROTOCOL);
  addMapping("L7_PROTO", L7_PROTO, NTOP_PEN);
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
  addMapping("INGRESS_VRFID", INGRESS_VRFID);
  addMapping("IPV4_SRC_MASK", IPV4_SRC_MASK);
  addMapping("IPV4_DST_MASK", IPV4_DST_MASK);
  addMapping("IPV4_NEXT_HOP", IPV4_NEXT_HOP);
  addMapping("OOORDER_IN_PKTS", OOORDER_IN_PKTS, NTOP_PEN);
  addMapping("OOORDER_OUT_PKTS", OOORDER_OUT_PKTS, NTOP_PEN);
  addMapping("RETRANSMITTED_IN_PKTS", RETRANSMITTED_IN_PKTS, NTOP_PEN);
  addMapping("RETRANSMITTED_OUT_PKTS", RETRANSMITTED_OUT_PKTS, NTOP_PEN);
  addMapping("DNS_QUERY", DNS_QUERY, NTOP_PEN);
  addMapping("HTTP_URL", HTTP_URL, NTOP_PEN);
  addMapping("HTTP_SITE", HTTP_SITE, NTOP_PEN);
  addMapping("SSL_SERVER_NAME", SSL_SERVER_NAME, NTOP_PEN);
  addMapping("BITTORRENT_HASH", BITTORRENT_HASH, NTOP_PEN);
}

/* **************************************************** */

ParserInterface::~ParserInterface() {
  if(zmq_remote_stats)        free(zmq_remote_stats);
  if(zmq_remote_stats_shadow) free(zmq_remote_stats_shadow);
#ifdef NTOPNG_PRO
  if(custom_app_maps)         delete(custom_app_maps);
#endif
}

/* **************************************************** */

void ParserInterface::addMapping(const char *sym, u_int32_t num, u_int32_t pen) {
  string label(sym);
  labels_map_t::iterator it;

  if((it = labels_map.find(label)) == labels_map.end())
    labels_map.insert(make_pair(label, make_pair(pen, num)));
  else
    it->second.first = pen, it->second.second = num;
}

/* **************************************************** */

bool ParserInterface::getKeyId(char *sym, u_int32_t * const pen, u_int32_t * const field) const {
  u_int32_t cur_pen, cur_field;
  string label(sym);
  labels_map_t::const_iterator it;

  *pen = UNKNOWN_PEN, *field = UNKNOWN_FLOW_ELEMENT;

  if(sscanf(sym, "%u.%u", &cur_pen, &cur_field) == 2)
    *pen = cur_pen, *field = cur_field;
  else if(sscanf(sym, "%u", &cur_field) == 1)
    *pen = 0, *field = cur_field;
  else if((it = labels_map.find(label)) != labels_map.end())
    *pen = it->second.first, *field = it->second.second;
  else
    return false;

  return true;
}

/* **************************************************** */

u_int8_t ParserInterface::parseEvent(const char * const payload, int payload_size,
				     u_int8_t source_id, void *data) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  NetworkInterface * iface = (NetworkInterface*)data;
  ZMQ_RemoteStats *zrs = NULL;
  memset((void*)&zrs, 0, sizeof(zrs));

  // payload[payload_size] = '\0';

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", payload);
  o = json_tokener_parse_verbose(payload, &jerr);

  if(o && (zrs = (ZMQ_RemoteStats*)calloc(1, sizeof(ZMQ_RemoteStats)))) {
    json_object *w, *z;

    if(json_object_object_get_ex(o, "time", &w))    zrs->remote_time  = (u_int32_t)json_object_get_int64(w);
    if(json_object_object_get_ex(o, "bytes", &w))   zrs->remote_bytes = (u_int64_t)json_object_get_int64(w);
    if(json_object_object_get_ex(o, "packets", &w)) zrs->remote_pkts  = (u_int64_t)json_object_get_int64(w);

    if(json_object_object_get_ex(o, "iface", &w)) {
      if(json_object_object_get_ex(w, "name", &z))
	snprintf(zrs->remote_ifname, sizeof(zrs->remote_ifname), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "speed", &z))
	zrs->remote_ifspeed = (u_int32_t)json_object_get_int64(z);
      if(json_object_object_get_ex(w, "ip", &z))
	snprintf(zrs->remote_ifaddress, sizeof(zrs->remote_ifaddress), "%s", json_object_get_string(z));
    }

    if(json_object_object_get_ex(o, "probe", &w)) {
      if(json_object_object_get_ex(w, "public_ip", &z))
	snprintf(zrs->remote_probe_public_address, sizeof(zrs->remote_probe_public_address), "%s", json_object_get_string(z));
      if(json_object_object_get_ex(w, "ip", &z))
	snprintf(zrs->remote_probe_address, sizeof(zrs->remote_probe_address), "%s", json_object_get_string(z));
    }

    if(json_object_object_get_ex(o, "avg", &w)) {
      if(json_object_object_get_ex(w, "bps", &z))
	zrs->avg_bps = (u_int32_t)json_object_get_int64(z);
      if(json_object_object_get_ex(w, "pps", &z))
	zrs->avg_pps = (u_int32_t)json_object_get_int64(z);
    }

    if(json_object_object_get_ex(o, "timeout", &w)) {
      if(json_object_object_get_ex(w, "lifetime", &z))
	zrs->remote_lifetime_timeout = (u_int32_t)json_object_get_int64(z);
      if(json_object_object_get_ex(w, "idle", &z))
	zrs->remote_idle_timeout = (u_int32_t)json_object_get_int64(z);
    }

    if(json_object_object_get_ex(o, "drops", &w)) {
      if(json_object_object_get_ex(w, "export_queue_full", &z))
	zrs->export_queue_full = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "too_many_flows", &z))
	zrs->too_many_flows = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "elk_flow_drops", &z))
	zrs->elk_flow_drops = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "sflow_pkt_sample_drops", &z))
	zrs->sflow_pkt_sample_drops = (u_int32_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "flow_collection_drops", &z))
	zrs->flow_collection_drops = (u_int32_t)json_object_get_int64(z);
    }

    if(json_object_object_get_ex(o, "zmq", &w)) {
      if(json_object_object_get_ex(w, "num_flow_exports", &z))
	zrs->num_flow_exports = (u_int64_t)json_object_get_int64(z);

      if(json_object_object_get_ex(w, "num_exporters", &z))
	zrs->num_exporters = (u_int8_t)json_object_get_int(z);
    }

#ifdef ZMQ_EVENT_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Event parsed "
				 "[iface: {name: %s, speed: %u, ip:%s}]"
				 "[probe: {public_ip: %s, ip: %s}]"
				 "[avg: {bps: %u, pps: %u}]"
				 "[remote: {time: %u, bytes: %u, packets: %u, idle_timeout: %u, lifetime_timeout:%u}]"
				 "[zmq: {num_exporters: %u, num_flow_exports: %u}]",
				 zrs->remote_ifname, zrs->remote_ifspeed, zrs->remote_ifaddress,
				 zrs->remote_probe_public_address, zrs->remote_probe_address,
				 zrs->avg_bps, zrs->avg_pps,
				 zrs->remote_time, (u_int32_t)zrs->remote_bytes, (u_int32_t)zrs->remote_pkts,
				 zrs->remote_idle_timeout, zrs->remote_lifetime_timeout,
				 zrs->num_exporters, zrs->num_flow_exports);
#endif

    /* ntop->getTrace()->traceEvent(TRACE_WARNING, "%u/%u", avg_bps, avg_pps); */

    /* Process Flow */
    static_cast<ParserInterface*>(iface)->setRemoteStats(zrs);
    if(flowHashing) {
      FlowHashing *current, *tmp;

      HASH_ITER(hh, flowHashing, current, tmp) {
	ZMQ_RemoteStats *zrscopy = (ZMQ_RemoteStats*)malloc(sizeof(ZMQ_RemoteStats));

	if(zrscopy)
	  memcpy(zrscopy, zrs, sizeof(ZMQ_RemoteStats));

	static_cast<ParserInterface*>(current->iface)->setRemoteStats(zrscopy);
      }
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

bool ParserInterface::parsePENZeroField(ZMQ_Flow * const flow, u_int32_t field, const char * const value) const {
  IpAddress ip_aux; /* used to check empty IPs */

  switch(field) {
  case IN_SRC_MAC:
  case OUT_SRC_MAC:
    /* Format 00:00:00:00:00:00 */
    Utils::parseMac(flow->core.src_mac, value);
    break;
  case IN_DST_MAC:
  case OUT_DST_MAC:
    Utils::parseMac(flow->core.dst_mac, value);
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
    if(flow->core.src_ip.isEmpty()) {
      flow->core.src_ip.set((char*)value);
    } else {
      ip_aux.set((char*)value);
      if(!ip_aux.isEmpty()  && !ntop->getPrefs()->do_override_src_with_post_nat_src())
	/* tried to overwrite a non-empty IP with another non-empty IP */
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Attempt to set source ip multiple times. "
				     "Check exported fields");
    }
    break;
  case IP_PROTOCOL_VERSION:
    flow->core.version = atoi(value);
    break;

  case IPV4_DST_ADDR:
  case IPV6_DST_ADDR:
    if(flow->core.dst_ip.isEmpty()) {
      flow->core.dst_ip.set((char*)value);
    } else {
      ip_aux.set((char*)value);
      if(!ip_aux.isEmpty()  && !ntop->getPrefs()->do_override_dst_with_post_nat_dst())
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Attempt to set destination ip multiple times. "
				     "Check exported fields");
    }
    break;
  case L4_SRC_PORT:
    if(!flow->core.src_port) flow->core.src_port = htons(atoi(value));
    break;
  case L4_DST_PORT:
    if(!flow->core.dst_port) flow->core.dst_port = htons(atoi(value));
    break;
  case SRC_VLAN:
  case DST_VLAN:
    flow->core.vlan_id = atoi(value);
    break;
  case DOT1Q_SRC_VLAN:
  case DOT1Q_DST_VLAN:
    if (flow->core.vlan_id == 0)
      /* as those fields are the outer vlans in q-in-q
	 we set the vlan_id only if there is no inner vlan
	 value set
      */
      flow->core.vlan_id = atoi(value);
    break;
  case PROTOCOL:
    flow->core.l4_proto = atoi(value);
    break;
  case TCP_FLAGS:
    flow->core.tcp_flags = atoi(value);
    break;
  case INITIATOR_PKTS:
    flow->core.absolute_packet_octet_counters = true;
    /* Don't break */
  case IN_PKTS:
    flow->core.in_pkts = atol(value);
    break;
  case INITIATOR_OCTETS:
    flow->core.absolute_packet_octet_counters = true;
    /* Don't break */
  case IN_BYTES:
    flow->core.in_bytes = atol(value);
    break;
  case RESPONDER_PKTS:
    flow->core.absolute_packet_octet_counters = true;
    /* Don't break */
  case OUT_PKTS:
    flow->core.out_pkts = atol(value);
    break;
  case RESPONDER_OCTETS:
    flow->core.absolute_packet_octet_counters = true;
    /* Don't break */
  case OUT_BYTES:
    flow->core.out_bytes = atol(value);
    break;
  case FIRST_SWITCHED:
    flow->core.first_switched = atol(value);
    break;
  case LAST_SWITCHED:
    flow->core.last_switched = atol(value);
    break;
  case SAMPLING_INTERVAL:
    flow->core.pkt_sampling_rate = atoi(value);
    break;
  case DIRECTION:
    flow->core.direction = atoi(value);
    break;
  case EXPORTER_IPV4_ADDRESS:
    /* Format: a.b.c.d, possibly overrides NPROBE_IPV4_ADDRESS */
    if(ntohl(inet_addr(value)) && (flow->core.deviceIP = ntohl(inet_addr(value))))
      return false;
    break;
  case INPUT_SNMP:
    flow->core.inIndex = atoi(value);
    break;
  case OUTPUT_SNMP:
    flow->core.outIndex = atoi(value);
    break;
  case POST_NAT_SRC_IPV4_ADDR:
    if(ntop->getPrefs()->do_override_src_with_post_nat_src()) {
      IpAddress ip;

      ip.set((char*)value);
      memcpy(&flow->core.src_ip, ip.getIP(), sizeof(flow->core.src_ip));
    }
    break;
  case POST_NAT_DST_IPV4_ADDR:
    if(ntop->getPrefs()->do_override_dst_with_post_nat_dst()) {
      IpAddress ip;

      ip.set((char*)value);
      memcpy(&flow->core.dst_ip, ip.getIP(), sizeof(flow->core.dst_ip));
    }
    break;
  case POST_NAPT_SRC_TRANSPORT_PORT:
    if(ntop->getPrefs()->do_override_src_with_post_nat_src())
      flow->core.src_port = htons(atoi(value));
    break;
  case POST_NAPT_DST_TRANSPORT_PORT:
    if(ntop->getPrefs()->do_override_dst_with_post_nat_dst())
      flow->core.dst_port = htons(atoi(value));
    break;
  case INGRESS_VRFID:
    flow->core.vrfId = atoi(value);
    break;
  case IPV4_SRC_MASK:
  case IPV4_DST_MASK:
    if(strcmp(value, "0"))
      return false;
    break;
  case IPV4_NEXT_HOP:
    if(strcmp(value, "0.0.0.0"))
      return false;
    break;

  default:
    return false;
  }

  return true;
}

/* **************************************************** */

bool ParserInterface::parsePENNtopField(ZMQ_Flow * const flow, u_int32_t field, const char * const value) const {
  switch(field) {
  case L7_PROTO:
    if(!strchr(value, '.')) {
      /* Old behaviour, only the app protocol */
      flow->core.l7_proto.app_protocol = atoi(value);
    } else {
      char *proto_dot;

      flow->core.l7_proto.master_protocol = (u_int16_t)strtoll(value, &proto_dot, 10);
      flow->core.l7_proto.app_protocol    = (u_int16_t)strtoll(proto_dot + 1, NULL, 10);
    }

#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[value: %s][master: %u][app: %u]",
				 value,
				 flow->core.l7_proto.master_protocol,
				 flow->core.l7_proto.app_protocol);
#endif
    break;
  case OOORDER_IN_PKTS:
    flow->core.tcp.ooo_in_pkts = atol(value);
    break;
  case OOORDER_OUT_PKTS:
    flow->core.tcp.ooo_out_pkts = atol(value);
    break;
  case RETRANSMITTED_IN_PKTS:
    flow->core.tcp.retr_in_pkts = atol(value);
    break;
  case RETRANSMITTED_OUT_PKTS:
    flow->core.tcp.retr_out_pkts = atol(value);
    break;
    /* TODO add lost in/out to nProbe and here */
  case CLIENT_NW_LATENCY_MS:
    {
      float client_nw_latency = atof(value);
      flow->core.tcp.clientNwLatency.tv_sec = client_nw_latency / 1e3;
      flow->core.tcp.clientNwLatency.tv_usec = 1e3 * (client_nw_latency - flow->core.tcp.clientNwLatency.tv_sec * 1e3);
      break;
    }
  case SERVER_NW_LATENCY_MS:
    {
      float server_nw_latency = atof(value);
      flow->core.tcp.serverNwLatency.tv_sec = server_nw_latency / 1e3;
      flow->core.tcp.serverNwLatency.tv_usec = 1e3 * (server_nw_latency - flow->core.tcp.serverNwLatency.tv_sec * 1e3);
      break;
    }
  case APPL_LATENCY_MS:
    flow->core.tcp.applLatencyMsec = atof(value);
    break;
  case DNS_QUERY:
    flow->dns_query = strdup(value);
    break;
  case HTTP_URL:
    flow->http_url = strdup(value);
    break;
  case HTTP_SITE:
    flow->http_site = strdup(value);
    break;
  case SSL_SERVER_NAME:
    flow->ssl_server_name = strdup(value);
    break;
  case BITTORRENT_HASH:
    flow->bittorrent_hash = strdup(value);
    break;
  case NPROBE_IPV4_ADDRESS:
    /* Do not override EXPORTER_IPV4_ADDRESS */
    if(flow->core.deviceIP == 0 && (flow->core.deviceIP = ntohl(inet_addr(value))))
      return false;
    break;
  default:
    return false;
  }

  return true;
}

/* **************************************************** */

void ParserInterface::parseSingleFlow(json_object *o,
				      u_int8_t source_id,
				      NetworkInterface *iface) {
  ZMQ_Flow flow;
  IpAddress ip_aux; /* used to check empty IPs */
  struct json_object_iterator it = json_object_iter_begin(o);
  struct json_object_iterator itEnd = json_object_iter_end(o);
  bool invalid_flow = false;

  /* Reset data */
  memset(&flow, 0, sizeof(flow));
  flow.core.l7_proto.master_protocol = flow.core.l7_proto.app_protocol = NDPI_PROTOCOL_UNKNOWN;
  flow.core.l7_proto.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;
  flow.additional_fields = json_object_new_object();
  flow.core.pkt_sampling_rate = 1; /* 1:1 (no sampling) */
  flow.core.source_id = source_id, flow.core.vlan_id = 0;

  while(!json_object_iter_equal(&it, &itEnd)) {
    const char *key   = json_object_iter_peek_name(&it);
    json_object *v    = json_object_iter_peek_value(&it);
    const char *value = json_object_get_string(v);
    bool add_to_additional_fields = false;

    if((key != NULL) && (value != NULL)) {
      u_int32_t pen, key_id;
      json_object *additional_o = json_tokener_parse(value);
      bool res;

      getKeyId((char*)key, &pen, &key_id);

      switch(pen) {
      case 0: /* No PEN */
	res = parsePENZeroField(&flow, key_id, value);
	if(res)
	  break;
	/* Dont'break when res == false for backward compatibility: attempt to parse Zero-PEN as Ntop-PEN */
      case NTOP_PEN:
	res = parsePENNtopField(&flow, key_id, value);
	break;
      case UNKNOWN_PEN:
      default:
	res = false;
	break;
      }

      if(!res) {
	switch(key_id) {
	case 0: //json additional object added by Flow::serialize()
	  if((additional_o != NULL) && (strcmp(key,"json") == 0)) {
	    struct json_object_iterator additional_it = json_object_iter_begin(additional_o);
	    struct json_object_iterator additional_itEnd = json_object_iter_end(additional_o);

	    while(!json_object_iter_equal(&additional_it, &additional_itEnd)) {

	      const char *additional_key   = json_object_iter_peek_name(&additional_it);
	      json_object *additional_v    = json_object_iter_peek_value(&additional_it);
	      const char *additional_value = json_object_get_string(additional_v);

	      if((additional_key != NULL) && (additional_value != NULL)) {
		json_object_object_add(flow.additional_fields, additional_key,
				       json_object_new_string(additional_value));
	      }
	      json_object_iter_next(&additional_it);
	    }
	  }
	  break;
	default:
#ifdef NTOPNG_PRO
	  if(custom_app_maps || (custom_app_maps = new(std::nothrow) CustomAppMaps()))
	    custom_app_maps->checkCustomApp(key, value, &flow);
#endif
	  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Not handled ZMQ field %u/%s", key_id, key);
	  add_to_additional_fields = true;
	  break;
	} /* switch */
      }

      if(add_to_additional_fields)
	json_object_object_add(flow.additional_fields,
			       key, json_object_new_string(value));

      if(additional_o) json_object_put(additional_o);
    } /* if */

    /* Move to the next element */
    json_object_iter_next(&it);
  } // while json_object_iter_equal

  if(flow.core.vlan_id && ntop->getPrefs()->do_ignore_vlans())
    flow.core.vlan_id = 0;

  /* Handle zero IPv4/IPv6 discrepacies */
  if(flow.core.version == 0) {
    if(flow.core.src_ip.getVersion() != flow.core.dst_ip.getVersion()) {
      if(flow.core.dst_ip.isIPv4() && flow.core.src_ip.isIPv6() && flow.core.src_ip.isEmpty())
	flow.core.src_ip.setVersion(4);
      else if(flow.core.src_ip.isIPv4() && flow.core.dst_ip.isIPv6() && flow.core.dst_ip.isEmpty())
	flow.core.dst_ip.setVersion(4);
      else if(flow.core.dst_ip.isIPv6() && flow.core.src_ip.isIPv4() && flow.core.src_ip.isEmpty())
	flow.core.src_ip.setVersion(6);
      else if(flow.core.src_ip.isIPv6() && flow.core.dst_ip.isIPv4() && flow.core.dst_ip.isEmpty())
	flow.core.dst_ip.setVersion(6);
      else {
	invalid_flow = true;
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "IP version mismatch: client:%d server:%d - flow will be ignored",
				     flow.core.src_ip.getVersion(), flow.core.dst_ip.getVersion());
      }
    }
  } else
    flow.core.src_ip.setVersion(flow.core.version), flow.core.dst_ip.setVersion(flow.core.version);

  if(!invalid_flow) {
    /* Process Flow */
    iface->processFlow(&flow);
  }

  /* Dispose memory */
  if(flow.dns_query) free(flow.dns_query);
  if(flow.http_url)  free(flow.http_url);
  if(flow.http_site) free(flow.http_site);
  if(flow.ssl_server_name) free(flow.ssl_server_name);
  if(flow.bittorrent_hash) free(flow.bittorrent_hash);

  // json_object_put(o);
  json_object_put(flow.additional_fields);
}

/* **************************************************** */

u_int8_t ParserInterface::parseFlow(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
  json_object *f;
  enum json_tokener_error jerr = json_tokener_success;
  NetworkInterface *iface = (NetworkInterface*)data;

  // payload[payload_size] = '\0';
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", payload);

  f = json_tokener_parse_verbose(payload, &jerr);

  if(f != NULL) {
    int rc;

    if(json_object_get_type(f) == json_type_array) {
      /* Flow array */
      int id, num_elements = json_object_array_length(f);

      for(id = 0; id < num_elements; id++)
	parseSingleFlow(json_object_array_get_idx(f, id), source_id, iface);

      rc = num_elements;
    } else {
      parseSingleFlow(f, source_id, iface);
      rc = 1;
    }

    json_object_put(f);
    return(rc);
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

u_int8_t ParserInterface::parseCounter(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  NetworkInterface * iface = (NetworkInterface*)data;
  sFlowInterfaceStats stats;

  // payload[payload_size] = '\0';

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
	else if(!strcmp(key, "ifIndex")) stats.ifIndex = atol(value);
	else if(!strcmp(key, "ifType")) stats.ifType = atol(value);
	else if(!strcmp(key, "ifSpeed")) stats.ifSpeed = atol(value);
	else if(!strcmp(key, "ifDirection")) stats.ifFullDuplex = (!strcmp(value, "Full")) ? true : false;
	else if(!strcmp(key, "ifAdminStatus")) stats.ifAdminStatus = (!strcmp(value, "Up")) ? true : false;
	else if(!strcmp(key, "ifOperStatus")) stats.ifOperStatus = (!strcmp(value, "Up")) ? true : false;
	else if(!strcmp(key, "ifInOctets")) stats.ifInOctets = atoll(value);
	else if(!strcmp(key, "ifInPackets")) stats.ifInPackets = atoll(value);
	else if(!strcmp(key, "ifInErrors")) stats.ifInErrors = atoll(value);
	else if(!strcmp(key, "ifOutOctets")) stats.ifOutOctets = atoll(value);
	else if(!strcmp(key, "ifOutPackets")) stats.ifOutPackets = atoll(value);
	else if(!strcmp(key, "ifOutErrors")) stats.ifOutErrors = atoll(value);
	else if(!strcmp(key, "ifPromiscuousMode")) stats.ifPromiscuousMode = (!strcmp(value, "1")) ? true : false;
      } /* if */

      /* Move to the next element */
      json_object_iter_next(&it);
    } // while json_object_iter_equal

    /* Process Flow */
    iface->processInterfaceStats(&stats);

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

u_int8_t ParserInterface::parseTemplate(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
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

	if(zmq_template.name)
	  addMapping(zmq_template.name, zmq_template.field, zmq_template.pen);

	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "Template [PEN: %u][field: %u][format: %s][name: %s][descr: %s]",
	//			     zmq_template.pen, zmq_template.field, zmq_template.format, zmq_template.name, zmq_template.descr)
	  ;
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

void ParserInterface::setFieldMap(const ZMQ_FieldMap * const field_map) const {
  char hname[CONST_MAX_LEN_REDIS_KEY], key[32];
  snprintf(hname, sizeof(hname), CONST_FIELD_MAP_CACHE_KEY, get_id(), field_map->pen);
  snprintf(key, sizeof(key), "%u", field_map->field);

  ntop->getRedis()->hashSet(hname, key, field_map->map);
}

/* **************************************************** */

void ParserInterface::setFieldValueMap(const ZMQ_FieldValueMap * const field_value_map) const {
  char hname[CONST_MAX_LEN_REDIS_KEY], key[32];
  snprintf(hname, sizeof(hname), CONST_FIELD_VALUE_MAP_CACHE_KEY, get_id(), field_value_map->pen, field_value_map->field);
  snprintf(key, sizeof(key), "%u", field_value_map->value);

  ntop->getRedis()->hashSet(hname, key, field_value_map->map);
}

/* **************************************************** */

u_int8_t ParserInterface::parseOptionFieldMap(json_object * const jo) const {
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

u_int8_t ParserInterface::parseOptionFieldValueMap(json_object * const w) const {
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

u_int8_t ParserInterface::parseOption(const char * const payload, int payload_size, u_int8_t source_id, void *data) {
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

void ParserInterface::setRemoteStats(ZMQ_RemoteStats *zrs) {
  if(!zrs) return;

  ifSpeed = zrs->remote_ifspeed, last_pkt_rcvd = 0, last_pkt_rcvd_remote = zrs->remote_time,
    last_remote_pps = zrs->avg_pps, last_remote_bps = zrs->avg_bps;

  if((zmq_initial_pkts == 0) /* ntopng has been restarted */
     || (zrs->remote_bytes < zmq_initial_bytes) /* nProbe has been restarted */
     ) {
    /* Start over */
    zmq_initial_bytes = zrs->remote_bytes, zmq_initial_pkts = zrs->remote_pkts;
  }

  if(zmq_remote_initial_exported_flows == 0 /* ntopng has been restarted */
     || zrs->num_flow_exports < zmq_remote_initial_exported_flows) /* nProbe has been restarted */
    zmq_remote_initial_exported_flows = zrs->num_flow_exports;

  if(zmq_remote_stats_shadow) free(zmq_remote_stats_shadow);
  zmq_remote_stats_shadow = zmq_remote_stats;
  zmq_remote_stats = zrs;

  /*
   * Don't override ethStats here, these stats are properly updated
   * inside NetworkInterface::processFlow for ZMQ interfaces.
   * Overriding values here may cause glitches and non-strictly-increasing counters
   * yielding negative rates.
   ethStats.setNumBytes(zrs->remote_bytes), ethStats.setNumPackets(zrs->remote_pkts);
   *
   */
}

/* **************************************************** */

#ifdef NTOPNG_PRO
bool ParserInterface::getCustomAppDetails(u_int32_t remapped_app_id, u_int32_t *const pen, u_int32_t *const app_field, u_int32_t *const app_id) {
  return custom_app_maps && custom_app_maps->getCustomAppDetails(remapped_app_id, pen, app_field, app_id);
}
#endif

/* **************************************************** */

void ParserInterface::lua(lua_State* vm) {
  ZMQ_RemoteStats *zrs = zmq_remote_stats;

  NetworkInterface::lua(vm);

  if(zrs) {
    if(zrs->remote_ifname[0] != '\0')
      lua_push_str_table_entry(vm, "remote.name", zrs->remote_ifname);
    if(zrs->remote_ifaddress[0] != '\0')
      lua_push_str_table_entry(vm, "remote.if_addr",zrs->remote_ifaddress);
    if(zrs->remote_probe_address[0] != '\0')
      lua_push_str_table_entry(vm, "probe.ip", zrs->remote_probe_address);
    if(zrs->remote_probe_public_address[0] != '\0')
      lua_push_str_table_entry(vm, "probe.public_ip", zrs->remote_probe_public_address);

    lua_push_uint64_table_entry(vm, "zmq.num_flow_exports", zrs->num_flow_exports - zmq_remote_initial_exported_flows);
    lua_push_uint64_table_entry(vm, "zmq.num_exporters", zrs->num_exporters);

    if(zrs->export_queue_full > 0)
      lua_push_uint64_table_entry(vm, "zmq.drops.export_queue_full", zrs->export_queue_full);
    lua_push_uint64_table_entry(vm, "zmq.drops.flow_collection_drops", zrs->flow_collection_drops);

    lua_push_uint64_table_entry(vm, "timeout.lifetime", zrs->remote_lifetime_timeout);
    lua_push_uint64_table_entry(vm, "timeout.idle", zrs->remote_idle_timeout);
  }
}

/* **************************************************** */

#endif

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

#include "ntop_includes.h"

/* *************************************** */

ParsedFlow::ParsedFlow() : ParsedFlowCore(), ParsedeBPF() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  additional_fields_json = NULL;
  additional_fields_tlv = NULL;
  l7_info = NULL, memset(&l7_proto, 0, sizeof(l7_proto));
  is_swapped = false;
  http_url = http_site = http_user_agent = NULL;
  http_method = NDPI_HTTP_METHOD_UNKNOWN;
  dns_query = tls_server_name = end_reason = NULL;
  dhcp_client_name = NULL, sip_call_id = NULL;
  ja4c_hash = NULL;
  next_hop.reset();
  external_alert = NULL;
  flow_risk_info = NULL;
  ot_info = NULL;
  tls_cipher = tls_unsafe_cipher = http_ret_code = 0;
  dns_query_type = dns_ret_code = dns_query_id = 0;
  ndpi_flow_risk_bitmap = 0;
  ndpi_flow_risk_name = NULL;
  smtp_rcp_to = NULL;
  smtp_mail_from = NULL;
  flow_verdict = 0; /* Unknown */
  src_port_pre_nat = dst_port_pre_nat = src_port_post_nat = dst_port_post_nat =
      0;
  tcp_fingerprint = bittorrent_hash = NULL;
  l7_error_code = 0;
  confidence = NDPI_CONFIDENCE_UNKNOWN;
  os_hint = ndpi_os_unknown;
  flow_source = packet_to_flow;
  src_ip_addr_pre_nat = dst_ip_addr_pre_nat = src_ip_addr_post_nat =
      dst_ip_addr_post_nat = 0;
  memset(&custom_app, 0, sizeof(custom_app));
  wlan_ssid = bgp_info = NULL;
  memset(&wtp_mac_address, 0, sizeof(wtp_mac_address));
  l7_json = NULL;
  has_parsed_ebpf = false;
  memset(&qoe, 0, sizeof(qoe));
  tcp_stats_src_to_dst = tcp_stats_dst_to_src = 0;
}

/* *************************************** */

ParsedFlow::ParsedFlow(const ParsedFlow& pf)
    : ParsedFlowCore(pf), ParsedeBPF(pf) {
  /* Currently we avoid TLV additional fields in the copy constructor */
  additional_fields_tlv = NULL;

  if (pf.additional_fields_json != NULL)
    additional_fields_json = Utils::cloneJSONSimple(pf.additional_fields_json);
  else
    additional_fields_json = NULL;

  if (pf.l7_info)
    l7_info = strdup(pf.l7_info);
  else
    l7_info = NULL;

  if (pf.http_url)
    http_url = strdup(pf.http_url);
  else
    http_url = NULL;

  if (pf.http_site)
    http_site = strdup(pf.http_site);
  else
    http_site = NULL;

  if (pf.http_user_agent)
    http_user_agent = strdup(pf.http_user_agent);
  else
    http_user_agent = NULL;

  http_method = pf.http_method;

  if (pf.dns_query)
    dns_query = strdup(pf.dns_query);
  else
    dns_query = NULL;

  if (pf.end_reason)
    end_reason = strdup(pf.end_reason);
  else
    end_reason = NULL;

  if (pf.tls_server_name)
    tls_server_name = strdup(pf.tls_server_name);
  else
    tls_server_name = NULL;

  if (pf.bittorrent_hash)
    bittorrent_hash = strdup(pf.bittorrent_hash);
  else
    bittorrent_hash = NULL;

  if (pf.tcp_fingerprint)
    tcp_fingerprint = strdup(pf.tcp_fingerprint);
  else
    tcp_fingerprint = NULL;

  if (pf.ja4c_hash)
    ja4c_hash = strdup(pf.ja4c_hash);
  else
    ja4c_hash = NULL;

  if (pf.external_alert)
    external_alert = strdup(pf.external_alert);
  else
    external_alert = NULL;

  if (pf.flow_risk_info)
    flow_risk_info = strdup(pf.flow_risk_info);
  else
    flow_risk_info = NULL;

  if (pf.ot_info)
    ot_info = strdup(pf.ot_info);
  else
    ot_info = NULL;

  if (pf.ndpi_flow_risk_name)
    ndpi_flow_risk_name = strdup(pf.ndpi_flow_risk_name);
  else
    ndpi_flow_risk_name = NULL;

  if (pf.smtp_rcp_to)
    smtp_rcp_to = strdup(pf.smtp_rcp_to);
  else
    smtp_rcp_to = NULL;

  if (pf.smtp_mail_from)
    smtp_mail_from = strdup(pf.smtp_mail_from);
  else
    smtp_mail_from = NULL;

  if (pf.dhcp_client_name)
    dhcp_client_name = strdup(pf.dhcp_client_name);
  else
    dhcp_client_name = NULL;

  if (pf.sip_call_id)
    sip_call_id = strdup(pf.sip_call_id);
  else
    sip_call_id = NULL;

  if (pf.wlan_ssid)
    wlan_ssid = strdup(pf.wlan_ssid);
  else
    wlan_ssid = NULL;

  if (pf.bgp_info)
    bgp_info= strdup(pf.bgp_info);
  else
    bgp_info = NULL;

  if (pf.l7_json)
    l7_json = strdup(pf.l7_json);
  else
    l7_json = NULL;

  memcpy(&wtp_mac_address, &pf.wtp_mac_address, sizeof(wtp_mac_address));

  tls_cipher = pf.tls_cipher;
  tls_unsafe_cipher = pf.tls_unsafe_cipher;
  ndpi_flow_risk_bitmap = pf.ndpi_flow_risk_bitmap;
  http_ret_code = pf.http_ret_code;
  dns_query_type = pf.dns_query_type;
  dns_ret_code = pf.dns_ret_code;
  dns_query_id = pf.dns_query_id;
  os_hint = pf.os_hint;

  /* Only IPv4 supported, in case the ipv4 is 0 it's already handled inside
   * IpAddress class */
  src_ip_addr_pre_nat = pf.src_ip_addr_pre_nat;
  dst_ip_addr_pre_nat = pf.dst_ip_addr_pre_nat;
  src_ip_addr_post_nat = pf.src_ip_addr_post_nat;
  dst_ip_addr_post_nat = pf.dst_ip_addr_post_nat;

  /* 0 by default */
  src_port_pre_nat = pf.src_port_pre_nat;
  dst_port_pre_nat = pf.dst_port_pre_nat;
  src_port_post_nat = pf.src_port_post_nat;
  dst_port_post_nat = pf.dst_port_post_nat;

  memcpy(&custom_app, &pf.custom_app, sizeof(custom_app));
  has_parsed_ebpf = pf.has_parsed_ebpf;
  is_swapped = pf.is_swapped;
  flow_verdict = pf.flow_verdict;
  confidence = pf.confidence;
  flow_source = pf.flow_source;
  l7_error_code = pf.l7_error_code;

  memcpy(&qoe, &pf.qoe, sizeof(qoe));
}

/* *************************************** */

void ParsedFlow::fromLua(lua_State* L, int index) {
  lua_pushnil(L);

  while (lua_next(L, index) != 0) {
    const char* key = lua_tostring(L, -2);
    int t = lua_type(L, -1);

    switch (t) {
      case LUA_TSTRING:
        if (!strcmp(key, "src_ip")) {
          src_ip.set(lua_tostring(L, -1));
        } else if (!strcmp(key, "dst_ip")) {
          dst_ip.set(lua_tostring(L, -1));
        } else if (!strcmp(key, "http_method")) {
          http_method = ndpi_http_str2method(lua_tostring(L, -1),
                                             strlen(lua_tostring(L, -1)));
        } else if (!strcmp(key, "http_site")) {
          if (http_site) free(http_site);
          http_site = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "http_user_agent")) {
          if (http_user_agent) free(http_user_agent);
          http_user_agent = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "l7_info")) {
          if (l7_info) free(l7_info);
          l7_info = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "http_url")) {
          if (http_url) free(http_url);
          http_url = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "tls_server_name")) {
          if (tls_server_name) free(tls_server_name);
          tls_server_name = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "dns_query")) {
          if (dns_query) free(dns_query);
          dns_query = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "ja4c_hash")) {
          if (ja4c_hash) free(ja4c_hash);
          ja4c_hash = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "tcp_fingerprint")) {
          if (tcp_fingerprint) free(tcp_fingerprint);
          tcp_fingerprint = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "bittorrent_hash")) {
          if (bittorrent_hash) free(bittorrent_hash);
          bittorrent_hash = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "external_alert")) {
          if (external_alert) free(external_alert);
          external_alert = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "flow_risk_info")) {
          if (flow_risk_info) free(flow_risk_info);
          flow_risk_info = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "ot_info")) {
          if (ot_info) free(ot_info);
          ot_info = strdup(lua_tostring(L, -1));
        } else if (!strcmp(key, "first_switched_iso8601")) {
          first_switched = Utils::str2epoch(lua_tostring(L, -1));
        } else if (!strcmp(key, "last_switched_iso8601")) {
          last_switched = Utils::str2epoch(lua_tostring(L, -1));
        } else if (!strcmp(key, "l4_proto")) {
          l4_proto = Utils::l4name2proto(lua_tostring(L, -1));
        } else if (!strcmp(key, "l7_json")) {
          if (l7_json) free(l7_json);
          l7_json = strdup(lua_tostring(L, -1));
        } else {
          addAdditionalField(key, json_object_new_string(lua_tostring(L, -1)));
          ntop->getTrace()->traceEvent(TRACE_DEBUG,
                                       "Key '%s' (string) not supported", key);
        }
        break;

      case LUA_TNUMBER:
        if (!strcmp(key, "vlan_id"))
          vlan_id = lua_tonumber(L, -1);
        else if (!strcmp(key, "version"))
          version = htons(lua_tointeger(L, -1));
        else if (!strcmp(key, "src_port"))
          src_port = htons(lua_tointeger(L, -1));
        else if (!strcmp(key, "dst_port"))
          dst_port = htons(lua_tointeger(L, -1));
        else if (!strcmp(key, "l4_proto"))
          l4_proto = lua_tonumber(L, -1);
        else if (!strcmp(key, "tcp_flags"))
          tcp.tcp_flags = htons(lua_tointeger(L, -1));
        else if (!strcmp(key, "direction"))
          direction = htons(lua_tointeger(L, -1));
        else if (!strcmp(key, "first_switched"))
          first_switched = lua_tonumber(L, -1);
        else if (!strcmp(key, "last_switched"))
          last_switched = lua_tonumber(L, -1);
        else if (!strcmp(key, "in_pkts"))
          in_pkts = lua_tonumber(L, -1);
        else if (!strcmp(key, "in_bytes"))
          in_bytes = lua_tonumber(L, -1);
        else if (!strcmp(key, "out_pkts"))
          out_pkts = lua_tonumber(L, -1);
        else if (!strcmp(key, "out_bytes"))
          out_bytes = lua_tonumber(L, -1);
        else if (!strcmp(key, "master_protocol"))
          l7_proto.proto.master_protocol = lua_tonumber(L, -1);
        else if (!strcmp(key, "app_protocol"))
          l7_proto.proto.app_protocol = lua_tonumber(L, -1);
        else if (!strcmp(key, "confidence"))
          confidence = (ndpi_confidence_t)lua_tonumber(L, -1);
        else if (!strcmp(key, "dns_query_type"))
          dns_query_type = lua_tonumber(L, -1);
        else if (!strcmp(key, "dns_ret_code"))
          dns_ret_code = lua_tonumber(L, -1);
        else if (!strcmp(key, "dns_query_id"))
          dns_query_id = lua_tonumber(L, -1);
        else if (!strcmp(key, "http_ret_code"))
          http_ret_code = lua_tonumber(L, -1);
        else if (!strcmp(key, "tcp_stats_src_to_dst"))
          tcp_stats_src_to_dst = lua_tonumber(L, -1);
        else if (!strcmp(key, "tcp_stats_dst_to_src"))
          tcp_stats_dst_to_src = lua_tonumber(L, -1);
        else {
          addAdditionalField(key, json_object_new_int64(lua_tonumber(L, -1)));
          ntop->getTrace()->traceEvent(TRACE_DEBUG,
                                       "Key '%s' (number) not supported", key);
        }
        break;

      case LUA_TBOOLEAN:
        addAdditionalField(key, json_object_new_boolean(lua_toboolean(L, -1)));
        ntop->getTrace()->traceEvent(TRACE_DEBUG,
                                     "Key '%s' (boolean) not supported", key);
        break;

      default:
        ntop->getTrace()->traceEvent(TRACE_ERROR,
                                     "Internal error: type %d not handled", t);
        break;
    }

    lua_pop(L, 1);
  }
}

/* *************************************** */

ParsedFlow::~ParsedFlow() { freeMemory(); }

/* *************************************** */

void ParsedFlow::freeMemory() {
  if (additional_fields_json) json_object_put(additional_fields_json);

  if (additional_fields_tlv) {
    ndpi_term_serializer(additional_fields_tlv);
    free(additional_fields_tlv);
    additional_fields_tlv = NULL;
  }

  if (l7_info) {
    free(l7_info);
    l7_info = NULL;
  }
  if (http_url) {
    free(http_url);
    http_url = NULL;
  }
  if (http_site) {
    free(http_site);
    http_site = NULL;
  }
  if (http_user_agent) {
    free(http_user_agent);
    http_user_agent = NULL;
  }
  if (dns_query) {
    free(dns_query);
    dns_query = NULL;
  }
  if (end_reason) {
    free(end_reason);
    end_reason = NULL;
  }
  if (tls_server_name) {
    free(tls_server_name);
    tls_server_name = NULL;
  }
  if (bittorrent_hash) {
    free(bittorrent_hash);
    bittorrent_hash = NULL;
  }
  if (tcp_fingerprint) {
    free(tcp_fingerprint);
    tcp_fingerprint = NULL;
  }
  if (ja4c_hash) {
    free(ja4c_hash);
    ja4c_hash = NULL;
  }
  if (external_alert) {
    free(external_alert);
    external_alert = NULL;
  }
  if (flow_risk_info) {
    free(flow_risk_info);
    flow_risk_info = NULL;
  }
  if (ot_info) {
    free(ot_info);
    ot_info = NULL;
  }
  if (ndpi_flow_risk_name) {
    free(ndpi_flow_risk_name);
    ndpi_flow_risk_name = NULL;
  }
  if (smtp_rcp_to) {
    free(smtp_rcp_to);
    smtp_rcp_to = NULL;
  }
  if (smtp_mail_from) {
    free(smtp_mail_from);
    smtp_mail_from = NULL;
  }
  if (dhcp_client_name) {
    free(dhcp_client_name);
    dhcp_client_name = NULL;
  }
  if (sip_call_id) {
    free(sip_call_id);
    sip_call_id = NULL;
  }
  if (wlan_ssid) {
    free(wlan_ssid);
    wlan_ssid = NULL;
  }
  if (bgp_info) {
    free(bgp_info);
    bgp_info = NULL;
  }
  if (l7_json) {
    free(l7_json);
    l7_json = NULL;
  }
}

/* *************************************** */

void ParsedFlow::swap() {
  if (!ntop->getPrefs()->isFlowSwapHeuristicEnabled()) return;
  u_int8_t tmp_qoe_c2s, tmp_qoe_s2c;

  ParsedFlowCore::swap();
  ParsedeBPF::swap();

  tmp_qoe_c2s = qoe.src_to_dst, tmp_qoe_s2c = qoe.dst_to_src;
  qoe.src_to_dst = tmp_qoe_s2c, qoe.dst_to_src = tmp_qoe_c2s;

  is_swapped = true;
}

/* *************************************** */

u_int32_t ParsedFlow::get_private_flow_id() {
  u_int32_t private_flow_id = 0;

  if (getSIPCallId()) {
    size_t len = strlen(getSIPCallId());
    private_flow_id =
        ndpi_quick_hash((const unsigned char*)getSIPCallId(), len);
  } else if (getDNSQueryId()) {
    private_flow_id = getDNSQueryId();
  }

  return private_flow_id;
}

/* *************************************** */

void ParsedFlow::addAdditionalField(const char* key, json_object* field) {
  if (!additional_fields_json)
    additional_fields_json = json_object_new_object();
  if (additional_fields_json)
    json_object_object_add(additional_fields_json, key, field);
}

/* *************************************** */

void ParsedFlow::addAdditionalField(ndpi_deserializer* deserializer) {
  if (!additional_fields_tlv) {
    additional_fields_tlv =
        (ndpi_serializer*)calloc(1, sizeof(ndpi_serializer));
    if (additional_fields_tlv) {
      if (ndpi_init_serializer_ll(additional_fields_tlv,
                                  ndpi_serialization_format_tlv, 64) != 0) {
        ntop->getTrace()->traceEvent(TRACE_WARNING,
                                     "Failure allocating TLV serializer");
        free(additional_fields_tlv);
        additional_fields_tlv = NULL;
      }
    }
  }

  if (additional_fields_tlv)
    ndpi_deserialize_clone_item(deserializer, additional_fields_tlv);
}

/* *************************************** */

void ParsedFlow::print() {
  char buf1[32], buf2[32];

  src_ip.print(buf1, sizeof(buf1));
  dst_ip.print(buf2, sizeof(buf2));

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "[src-ip: %s][src-port: %u][dst-ip: "
                               "%s][dst-port: %u][first: %u][last: %u]",
                               src_ip.print(buf1, sizeof(buf1)),
                               ntohs(src_port),
                               dst_ip.print(buf2, sizeof(buf2)),
                               ntohs(dst_port), first_switched, last_switched);
}

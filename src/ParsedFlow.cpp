/*
 *
 * (C) 2013-20 - ntop.org
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
  additional_fields_json = NULL;
  additional_fields_tlv = NULL;
  http_url = http_site = http_method = NULL;
  dns_query = tls_server_name = NULL;
  ja3c_hash = ja3s_hash = NULL;
  external_alert = NULL;

  tls_cipher = tls_unsafe_cipher = http_ret_code = 0;
  dns_query_type = dns_ret_code = 0;
 
  bittorrent_hash = NULL;
  memset(&custom_app, 0, sizeof(custom_app));

  has_parsed_ebpf = false;
}

/* *************************************** */

ParsedFlow::ParsedFlow(const ParsedFlow &pf) : ParsedFlowCore(pf), ParsedeBPF(pf) {

  /* Currently we avoid TLV additional fields in the copy constructor */
  additional_fields_tlv = NULL; 

  if (pf.additional_fields_json != NULL)
    additional_fields_json = Utils::cloneJSONSimple(pf.additional_fields_json);
  else
    additional_fields_json = NULL; 

  if(pf.http_url)  http_url = strdup(pf.http_url); else http_url = NULL;
  if(pf.http_site) http_site = strdup(pf.http_site); else http_site = NULL;
  if(pf.http_method) http_method = strdup(pf.http_method); else http_method = NULL;
  if(pf.dns_query) dns_query = strdup(pf.dns_query); else dns_query = NULL;
  if(pf.tls_server_name) tls_server_name = strdup(pf.tls_server_name); else tls_server_name = NULL;
  if(pf.bittorrent_hash) bittorrent_hash = strdup(pf.bittorrent_hash); else bittorrent_hash = NULL;
  if(pf.ja3c_hash) ja3c_hash = strdup(pf.ja3c_hash); else ja3c_hash = NULL;
  if(pf.ja3s_hash) ja3s_hash = strdup(pf.ja3s_hash); else ja3s_hash = NULL;
  if(pf.external_alert) external_alert = strdup(pf.external_alert); else external_alert = NULL;

  tls_cipher = pf.tls_cipher;
  tls_unsafe_cipher = pf.tls_unsafe_cipher;
  http_ret_code = pf.http_ret_code;
  dns_query_type = pf.dns_query_type;
  dns_ret_code = pf.dns_ret_code;

  memcpy(&custom_app, &pf.custom_app, sizeof(custom_app));
  has_parsed_ebpf = pf.has_parsed_ebpf;
}

/* *************************************** */

void ParsedFlow::fromLua(lua_State *L, int index) {
  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
      const char *key = lua_tostring(L, -2);
      int t = lua_type(L, -1);

      switch(t) {
      case LUA_TSTRING:
	if(!strcmp(key, "src_ip")) {
           src_ip.set(lua_tostring(L, -1));
	} else if(!strcmp(key, "dst_ip")) {
           dst_ip.set(lua_tostring(L, -1));
	} else if(!strcmp(key, "http_method")) {
          if(http_method) free(http_method);
          http_method = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "http_site")) {
          if(http_site) free(http_site);
          http_site = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "http_url")) {
          if(http_url) free(http_url);
          http_url = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "tls_server_name")) {
          if(tls_server_name) free(tls_server_name);
          tls_server_name = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "dns_query")) {
          if(dns_query) free(dns_query);
          dns_query = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "ja3c_hash")) {
          if(ja3c_hash) free(ja3c_hash);
          ja3c_hash = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "ja3s_hash")) {
          if(ja3s_hash) free(ja3s_hash);
          ja3s_hash = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "external_alert")) {
	  if(external_alert) free(external_alert);
	  external_alert = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "first_switched_iso8601")) {
	  first_switched = Utils::str2epoch(lua_tostring(L, -1));
	} else if(!strcmp(key, "last_switched_iso8601")) {
	  last_switched = Utils::str2epoch(lua_tostring(L, -1));
	} else if(!strcmp(key, "l4_proto")) {
	  l4_proto = Utils::l4name2proto(lua_tostring(L, -1));
	} else {
          addAdditionalField(key, json_object_new_string(lua_tostring(L, -1)));
          ntop->getTrace()->traceEvent(TRACE_DEBUG, "Key '%s' (string) not supported", key);
        }
	break;

      case LUA_TNUMBER:
	if(!strcmp(key, "vlan_id"))
	  vlan_id = lua_tonumber(L, -1);
	else if(!strcmp(key, "version"))
	  version = htons(lua_tointeger(L, -1));
	else if(!strcmp(key, "src_port"))
	  src_port = htons(lua_tointeger(L, -1));
	else if(!strcmp(key, "dst_port"))
	  dst_port = htons(lua_tointeger(L, -1));
	else if(!strcmp(key, "l4_proto"))
	  l4_proto = lua_tonumber(L, -1);
	else if(!strcmp(key, "tcp_flags"))
	  tcp.tcp_flags = htons(lua_tointeger(L, -1));
	else if(!strcmp(key, "direction"))
	  direction = htons(lua_tointeger(L, -1));
	else if(!strcmp(key, "first_switched"))
	  first_switched = lua_tonumber(L, -1);
	else if(!strcmp(key, "last_switched"))
	  last_switched = lua_tonumber(L, -1);
	else if(!strcmp(key, "in_pkts"))
	  in_pkts = lua_tonumber(L, -1);
	else if(!strcmp(key, "in_bytes"))
	  in_bytes = lua_tonumber(L, -1);
	else if(!strcmp(key, "out_pkts"))
	  out_pkts = lua_tonumber(L, -1);
	else if(!strcmp(key, "out_bytes"))
	  out_bytes = lua_tonumber(L, -1);
	else if(!strcmp(key, "app_protocol"))
	  l7_proto.app_protocol = lua_tonumber(L, -1);
	else if(!strcmp(key, "dns_query_type"))
	  dns_query_type = lua_tonumber(L, -1);
	else if(!strcmp(key, "dns_ret_code"))
	  dns_ret_code = lua_tonumber(L, -1);
	else if(!strcmp(key, "http_ret_code"))
	  http_ret_code = lua_tonumber(L, -1);
	else {
          addAdditionalField(key, json_object_new_int64(lua_tonumber(L, -1)));
          ntop->getTrace()->traceEvent(TRACE_DEBUG, "Key '%s' (number) not supported", key);
        }
	break;

      case LUA_TBOOLEAN:
        addAdditionalField(key, json_object_new_boolean(lua_toboolean(L, -1)));
        ntop->getTrace()->traceEvent(TRACE_DEBUG, "Key '%s' (boolean) not supported", key);
	break;

      default:
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: type %d not handled", t);
	break;
      }

    lua_pop(L, 1);
  }
}

/* *************************************** */

ParsedFlow::~ParsedFlow() {
  if(additional_fields_json)
    json_object_put(additional_fields_json);

  if(additional_fields_tlv) {
    ndpi_term_serializer(additional_fields_tlv);
    free(additional_fields_tlv);
  }

  if(http_url) free(http_url);
  if(http_site) free(http_site);
  if(http_method) free(http_method);
  if(dns_query) free(dns_query);
  if(tls_server_name) free(tls_server_name);
  if(bittorrent_hash) free(bittorrent_hash);
  if(ja3c_hash) free(ja3c_hash);
  if(ja3s_hash) free(ja3s_hash);
  if(external_alert) free(external_alert);
}

/* *************************************** */

void ParsedFlow::swap() {
  ParsedFlowCore::swap();
  ParsedeBPF::swap();
}

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


/* ****************************************** */

static Flow* ntop_flow_get_context_flow(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return c->flow;
}

/* ****************************************** */

static int ntop_flow_get_status(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getStatusBitmap().get());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_set_status(lua_State* vm) {
  FlowStatus new_status;
  u_int16_t flow_score, cli_score, srv_score;
  Flow *f = ntop_flow_get_context_flow(vm);
  char *script_key;

  if(!f) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  new_status = (FlowStatus)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  flow_score = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  cli_score = (u_int16_t)lua_tonumber(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  srv_score = (u_int16_t)lua_tonumber(vm, 4);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  script_key = (char*)lua_tostring(vm, 5);

  lua_pushboolean(vm, f->setStatus(new_status, flow_score, cli_score, srv_score, script_key));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_clear_status(lua_State* vm) {
  FlowStatus new_status;
  Bitmap old_bitmap;
  Flow *f = ntop_flow_get_context_flow(vm);
  bool changed = false;

  if(!f) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  new_status = (FlowStatus)lua_tonumber(vm, 1);

  old_bitmap = f->getStatusBitmap();

  if(old_bitmap.issetBit(new_status)) {
    f->clearStatus(new_status);
    changed = true;
  }

  lua_pushboolean(vm, changed);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_status_set(lua_State* vm) {
  FlowStatus status;
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  status = (FlowStatus)lua_tonumber(vm, 1);

  lua_pushboolean(vm, f->getStatusBitmap().issetBit(status));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_client_unicast(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, (f->get_cli_ip_addr() && !f->get_cli_ip_addr()->isBroadMulticastAddress()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_server_unicast(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, (f->get_srv_ip_addr() && !f->get_srv_ip_addr()->isBroadMulticastAddress()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_unicast(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  const IpAddress *cli_ip, *srv_ip;

  if(!f) return(CONST_LUA_ERROR);

  cli_ip = f->get_cli_ip_addr();
  srv_ip = f->get_srv_ip_addr();

  lua_pushboolean(vm, (cli_ip && srv_ip &&
      !cli_ip->isBroadMulticastAddress() && !srv_ip->isBroadMulticastAddress()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_remote_to_remote(lua_State* vm) {
  Host *cli_host, *srv_host;
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  cli_host = f->get_cli_host();
  srv_host = f->get_srv_host();

  lua_pushboolean(vm, (cli_host && srv_host &&
      !cli_host->isLocalHost() && !srv_host->isLocalHost()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_local_to_remote(lua_State* vm) {
  Host *cli_host, *srv_host;
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  cli_host = f->get_cli_host();
  srv_host = f->get_srv_host();

  lua_pushboolean(vm, (cli_host && srv_host &&
      cli_host->isLocalHost() && !srv_host->isLocalHost()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_remote_to_local(lua_State* vm) {
  Host *cli_host, *srv_host;
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  cli_host = f->get_cli_host();
  srv_host = f->get_srv_host();

  lua_pushboolean(vm, (cli_host && srv_host &&
      !cli_host->isLocalHost() && srv_host->isLocalHost()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_ndpi_cat_name(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->get_protocol_category_name());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_ndpi_protocol_name(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  char buf[64];

  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->get_detected_protocol_name(buf, sizeof(buf)));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_ndpi_category_id(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_protocol_category());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_ndpi_master_proto_id(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_detected_protocol().master_protocol);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_ndpi_app_proto_id(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_detected_protocol().app_protocol);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_cli_tcp_issues(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getCliTcpIssues());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_srv_tcp_issues(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getSrvTcpIssues());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_retrieve_external_alert_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  f->luaRetrieveExternalAlert(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  f->lua_get_min_info(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_full_info(lua_State* vm) {
  AddressTree *ptree = get_allowed_nets(vm);
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  f->lua(vm, ptree, details_high, false);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_unicast_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  f->lua_get_unicast_info(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_key(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->key());

  return(CONST_LUA_OK);
}
/* ****************************************** */

static int ntop_flow_get_hash_entry_id(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_hash_entry_id());

  return(CONST_LUA_OK);
}

/* ****************************************** */

/* Get ICMP information that is specific for the serialization of ICMP data
 * into the flow status_info */
static int ntop_flow_get_icmp_status_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  if(f->isICMP()) {
    u_int8_t icmp_type, icmp_code;

    f->getICMP(&icmp_type, &icmp_code);

    lua_newtable(vm);
    lua_push_int32_table_entry(vm, "type", icmp_type);
    lua_push_int32_table_entry(vm, "code", icmp_code);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_alerted_status_score(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushnumber(vm, f->getAlertedStatusScore());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_local(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  bool is_local = false;

  if(!f) return(CONST_LUA_ERROR);

  if(f->get_cli_host() && f->get_srv_host())
    is_local = f->get_cli_host()->isLocalHost() && f->get_srv_host()->isLocalHost();

  lua_pushboolean(vm, is_local);
  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef NTOPNG_PRO

static int ntop_flow_get_score(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getScore());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_score_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  const char *status_info;

  if(!f) return(CONST_LUA_ERROR);

  status_info = f->getStatusInfo();

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "status_map", f->getStatusBitmap().get());
  lua_push_int32_table_entry(vm, "score", f->getScore());
  if(status_info) lua_push_str_table_entry(vm, "status_info", status_info);

  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

static int ntop_flow_is_not_purged(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->isNotPurged());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_tls_version(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getTLSVersion());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_tcp_stats(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  f->lua_get_tcp_stats(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_blacklisted_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_newtable(vm);

  if(f->isBlacklistedClient())
    lua_push_bool_table_entry(vm, "blacklisted.cli", true);
  if(f->isBlacklistedServer())
    lua_push_bool_table_entry(vm, "blacklisted.srv", true);
  if(f->get_protocol_category() == CUSTOM_CATEGORY_MALWARE)
    lua_push_bool_table_entry(vm, "blacklisted.cat", true);

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef HAVE_NEDGE

static int ntop_flow_is_pass_verdict(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->isPassVerdict());
  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

static int ntop_flow_get_first_seen(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_first_seen());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_last_seen(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_last_seen());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_duration(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_duration());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_twh_ok(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->isThreeWayHandshakeOK());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_bidirectional(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->isBidirectional());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_packets_sent(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_packets_cli2srv());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_packets_rcvd(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_packets_srv2cli());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_packets(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_packets_cli2srv() + f->get_packets_srv2cli());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_bytes_sent(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_bytes_cli2srv());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_bytes_rcvd(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_bytes_srv2cli());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_bytes(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_bytes());
  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_flow_get_goodput_bytes(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_goodput_bytes());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_client_key(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  Host *h;
  char buf[64];

  if(!f) return(CONST_LUA_ERROR);

  h = f->get_cli_host();
  lua_pushstring(vm, h ? h->get_hostkey(buf, sizeof(buf), true /* force VLAN, required by flow.lua */) : "");

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_server_key(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  Host *h;
  char buf[64];

  if(!f) return(CONST_LUA_ERROR);

  h = f->get_srv_host();
  lua_pushstring(vm, h ? h->get_hostkey(buf, sizeof(buf), true /* force VLAN, required by flow.lua */) : "");

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_dp_not_allowed(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, !f->isDeviceAllowedProtocol());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_tcp_connection_refused(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, (f->isTCPRefused()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_tcp_connecting(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, (f->isTCPConnecting()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_ssl_cipher_class(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  const char *rv;

  if(!f) return(CONST_LUA_ERROR);

  rv = f->getServerCipherClass();

  if(rv)
    lua_pushstring(vm, rv);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_icmp_type(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getICMPType());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_max_seen_icmp_size(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getICMPPayloadSize());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_dns_query_invalid_chars(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->hasInvalidDNSQueryChars());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_dns_query(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->getDNSQuery());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_proto_breed(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->get_protocol_breed_name());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_has_malicious_tls_signature(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->hasMaliciousSignature());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_client_country(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  if(!f->get_cli_host() || !f->get_cli_host()->getCountryStats())
    lua_pushnil(vm);
  else
    lua_pushstring(vm, f->get_cli_host()->getCountryStats()->get_country_name());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_server_country(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  if(!f->get_srv_host() || !f->get_srv_host()->getCountryStats())
    lua_pushnil(vm);
  else
    lua_pushstring(vm, f->get_srv_host()->getCountryStats()->get_country_name());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_device_proto_allowed_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  f->lua_device_protocol_allowed_info(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static const char* mud_pref_2_str(MudRecording mud_pref) {
  switch(mud_pref) {
  case mud_recording_general_purpose:
    return(MUD_RECORDING_GENERAL_PURPOSE);
  case mud_recording_special_purpose:
    return(MUD_RECORDING_SPECIAL_PURPOSE);
  case mud_recording_disabled:
    return(MUD_RECORDING_DISABLED);
  default:
    return(MUD_RECORDING_DEFAULT);
  }
}

static int ntop_flow_get_mud_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  Host *cli_host, *srv_host;
  char buf[32];

  if(!f) return(CONST_LUA_ERROR);

  lua_newtable(vm);

  cli_host = f->get_cli_host();
  srv_host = f->get_srv_host();

  if(!cli_host || !srv_host)
    return(CONST_LUA_OK);

  lua_push_str_table_entry(vm, "host_server_name", f->getFlowServerInfo());
  lua_push_str_table_entry(vm, "protos.dns.last_query", f->getDNSQuery());
  lua_push_bool_table_entry(vm, "is_local", cli_host->isLocalHost() && srv_host->isLocalHost());

  lua_push_str_table_entry(vm, "cli.mud_recording", mud_pref_2_str(cli_host->getMUDRecording()));
  lua_push_str_table_entry(vm, "srv.mud_recording", mud_pref_2_str(srv_host->getMUDRecording()));
  lua_push_bool_table_entry(vm, "cli.serialize_by_mac", cli_host->serializeByMac());
  lua_push_bool_table_entry(vm, "srv.serialize_by_mac", srv_host->serializeByMac());
  lua_push_str_table_entry(vm, "cli.mac", Utils::formatMac(cli_host->get_mac(), buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "srv.mac", Utils::formatMac(srv_host->get_mac(), buf, sizeof(buf)));
  lua_push_int32_table_entry(vm, "cli.devtype", cli_host->getDeviceType());
  lua_push_int32_table_entry(vm, "srv.devtype", srv_host->getDeviceType());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_predominant_status(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getPredominantStatus());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_trigger_alert(lua_State* vm) {
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);
  Flow *f = ntop_flow_get_context_flow(vm);
  FlowStatus status;
  AlertType atype;
  AlertLevel severity;
  bool triggered = false;
  const char *status_info = NULL;
  u_int32_t buflen;
  time_t now;
  bool first_alert;

  if(!f) return(CONST_LUA_ERROR);

  first_alert = !f->isFlowAlerted();

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  status = (FlowStatus)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  atype = (AlertType)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  severity = (AlertLevel)lua_tointeger(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
    now = (time_t) lua_tonumber(vm, 4);

  if(lua_type(vm, 5) == LUA_TSTRING)
    status_info = lua_tostring(vm, 5);

  if(f->triggerAlert(status, atype, severity, status_info)) {
    /* The alert was successfully triggered */
    FifoStringsQueue *sqlite_queue = ntop->getSqliteAlertsQueue();
    FifoStringsQueue *notif_queue = ntop->getAlertsNotificationsQueue();

    triggered = true;

    if(sqlite_queue->canEnqueue() || notif_queue->canEnqueue()) {
      ndpi_serializer flow_json;
      const char *flow_str;

      ndpi_init_serializer(&flow_json, ndpi_serialization_format_json);

      /* Only proceed if there is some space in the queues */
      f->flow2alertJson(&flow_json, now);
      if(!first_alert)
        ndpi_serialize_string_boolean(&flow_json, "replace_alert", true);

      flow_str = ndpi_serializer_get_buffer(&flow_json, &buflen);

      if(flow_str) {
        if(!sqlite_queue->enqueue((char*)flow_str)) {
          f->getInterface()->incNumDroppedAlerts(1);
	  
          if(ctx->threaded_activity_stats)
            ctx->threaded_activity_stats->setAlertsDrops();
        }

        notif_queue->enqueue((char*)flow_str);
      }

      ndpi_term_serializer(&flow_json);
    } else {
      f->getInterface()->incNumDroppedAlerts(1);

      if(ctx->threaded_activity_stats)
        ctx->threaded_activity_stats->setAlertsDrops();
    }
  }

  lua_pushboolean(vm, triggered);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_is_blacklisted(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->isBlacklistedFlow());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int  ntop_flow_get_dir_iat(lua_State* vm, bool cli2srv) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) f->lua_get_dir_iat(vm, cli2srv);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int  ntop_flow_get_cli2srv_iat(lua_State* vm) {
  return ntop_flow_get_dir_iat(vm, true /* Client to Server */);
}

/* ****************************************** */

static int  ntop_flow_get_srv2cli_iat(lua_State* vm) {
  return ntop_flow_get_dir_iat(vm,  false /* Server to Client */);
}

/* ****************************************** */

static int  ntop_flow_get_tls_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) f->lua_get_tls_info(vm);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int  ntop_flow_get_ssh_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) f->lua_get_ssh_info(vm);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int  ntop_flow_get_http_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) f->lua_get_http_info(vm);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_flow_get_dns_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) f->lua_get_dns_info(vm);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_flow_risk_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) f->lua_get_risk_info(vm, false);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_flow_has_risk(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(f && ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) == CONST_LUA_OK)
    lua_pushboolean(vm, f->hasRisk((ndpi_risk_enum)lua_tointeger(vm, 1)));
  else
    lua_pushboolean(vm, false);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_flow_set_custom_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(f && ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) == CONST_LUA_OK) {
    f->setCustomFlowInfo((char*)lua_tostring(vm, 1));
    lua_pushboolean(vm, true);
  } else
    lua_pushboolean(vm, false);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_flow_get_ndpi_match_packet(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) {
    u_int16_t payload_len;
    u_int8_t *payload;

    f->getnDPIMatchPacket(&payload_len, &payload);
    lua_push_int32_table_entry(vm, "payload_len", payload_len);

    if(payload_len == 0)
      lua_push_nil_table_entry(vm, "payload");
    else
      lua_push_rawdata_table_entry(vm, "payload", payload_len, payload);
  }
  
  return CONST_LUA_OK;
}

/* **************************************************************** */

static const luaL_Reg ntop_flow_reg[] = {
/* Public User Scripts API, documented at doc/src/api/lua_c/flow_user_scripts/flow.lua */
  { "getStatus",                ntop_flow_get_status                 },
  { "setStatus",                ntop_flow_set_status                 },
  { "clearStatus",              ntop_flow_clear_status               },
  { "isStatusSet",              ntop_flow_is_status_set              },
  { "getPredominantStatus",     ntop_flow_get_predominant_status     },
  
  { "isClientUnicast",          ntop_flow_is_client_unicast          },
  { "isServerUnicast",          ntop_flow_is_server_unicast          },
  { "isUnicast",                ntop_flow_is_unicast                 },
  { "isRemoteToRemote",         ntop_flow_is_remote_to_remote        },
  { "isLocalToRemote",          ntop_flow_is_local_to_remote         },
  { "isRemoteToLocal",          ntop_flow_is_remote_to_local         },
  { "isLocal",                  ntop_flow_is_local                   },
  { "isBlacklisted",            ntop_flow_is_blacklisted             },
  { "isTwhOK",                  ntop_flow_is_twh_ok                  },
  { "isBidirectional",          ntop_flow_is_bidirectional           },
  { "getFullInfo",              ntop_flow_get_full_info              },
  { "getKey",                   ntop_flow_get_key                    },
  { "getFirstSeen",             ntop_flow_get_first_seen             },
  { "getLastSeen",              ntop_flow_get_last_seen              },
  { "getDuration",              ntop_flow_get_duration               },
  { "getPacketsSent",           ntop_flow_get_packets_sent           },
  { "getPacketsRcvd",           ntop_flow_get_packets_rcvd           },
  { "getPackets",               ntop_flow_get_packets                },
  { "getBytesSent",             ntop_flow_get_bytes_sent             },
  { "getBytesRcvd",             ntop_flow_get_bytes_rcvd             },
  { "getBytes",                 ntop_flow_get_bytes                  },
  { "getGoodputBytes",          ntop_flow_get_goodput_bytes          },
  { "getClientKey",             ntop_flow_get_client_key             },
  { "getServerKey",             ntop_flow_get_server_key             },
  { "getnDPICategoryName",      ntop_flow_get_ndpi_cat_name          },
  { "getnDPIProtocolName",      ntop_flow_get_ndpi_protocol_name     },
  { "getnDPICategoryId",        ntop_flow_get_ndpi_category_id       },
  { "getnDPIMasterProtoId",     ntop_flow_get_ndpi_master_proto_id   },
  { "getnDPIAppProtoId",        ntop_flow_get_ndpi_app_proto_id      },
  { "getDnsQuery",              ntop_flow_get_dns_query              },
  { "getClientCountry",         ntop_flow_get_client_country         },
  { "getServerCountry",         ntop_flow_get_server_country         },
  { "getTLSVersion",            ntop_flow_get_tls_version            },
  { "getnDPIMatchPacket",       ntop_flow_get_ndpi_match_packet      },
  
#ifdef NTOPNG_PRO
  { "getScore",                 ntop_flow_get_score                  },
#endif
#ifdef HAVE_NEDGE
  { "isPassVerdict",            ntop_flow_is_pass_verdict            },
#endif
/* END Public API */

  { "getInfo",                  ntop_flow_get_info                   },
  { "getUnicastInfo",           ntop_flow_get_unicast_info           },
  { "triggerAlert",             ntop_flow_trigger_alert              },
  { "getHashEntryId",           ntop_flow_get_hash_entry_id          },
  { "getICMPStatusInfo",        ntop_flow_get_icmp_status_info       },
  { "getAlertedStatusScore",    ntop_flow_get_alerted_status_score   },
  { "getClientTCPIssues",       ntop_flow_get_cli_tcp_issues         },
  { "getServerTCPIssues",       ntop_flow_get_srv_tcp_issues         },
  { "isDeviceProtocolNotAllowed", ntop_flow_is_dp_not_allowed        },
  { "isTCPConnectionRefused",   ntop_flow_is_tcp_connection_refused  },
  { "isTCPConnecting",          ntop_flow_is_tcp_connecting          },
  { "getServerCipherClass",     ntop_flow_get_ssl_cipher_class       },
  { "getICMPType",              ntop_flow_get_icmp_type              },
  { "getMaxSeenIcmpPayloadSize", ntop_flow_get_max_seen_icmp_size    },
  { "dnsQueryHasInvalidChars",  ntop_flow_dns_query_invalid_chars    },
  { "getProtoBreed",            ntop_flow_get_proto_breed            },
  { "hasMaliciousTlsSignature", ntop_flow_has_malicious_tls_signature },
  { "getMUDInfo",               ntop_flow_get_mud_info               },
  { "isNotPurged",              ntop_flow_is_not_purged              },
  { "getTCPStats",              ntop_flow_get_tcp_stats              },
  { "getBlacklistedInfo",       ntop_flow_get_blacklisted_info       },
#ifdef NTOPNG_PRO
  { "getScoreInfo",             ntop_flow_get_score_info             },
#endif
  { "retrieveExternalAlertInfo", ntop_flow_retrieve_external_alert_info },
  { "getDeviceProtoAllowedInfo", ntop_flow_get_device_proto_allowed_info},
  { "getClient2ServerIAT",      ntop_flow_get_cli2srv_iat            },
  { "getServer2ClientIAT",      ntop_flow_get_srv2cli_iat            },
  { "getTLSInfo",               ntop_flow_get_tls_info               },
  { "getSSHInfo",               ntop_flow_get_ssh_info               },
  { "getHTTPInfo",              ntop_flow_get_http_info              },
  { "getDNSInfo",               ntop_flow_get_dns_info               },
  { "getRiskInfo",              ntop_flow_risk_info                  },
  { "hasRisk",                  ntop_flow_has_risk                   },
  { "setCustomInfo",            ntop_flow_set_custom_info            },
  
  { NULL,                       NULL }
};



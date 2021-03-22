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

/* ****************************************** */

static Flow* ntop_flow_get_context_flow(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return c->flow;
}

/* ****************************************** */

static int ntop_flow_get_status(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  if(!f) return(CONST_LUA_ERROR);

  f->getAlertBitmap().lua(vm, "alert_map");

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

static int ntop_flow_get_protocol(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_protocol());
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

static int ntop_flow_get_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  f->lua_get_min_info(vm);

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

#endif

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

static int ntop_flow_is_bidirectional(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, f->isBidirectional());
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

static int ntop_flow_get_bytes(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->get_bytes());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_ip(lua_State* vm, bool client) {
  Flow *f = ntop_flow_get_context_flow(vm);
  char buf[64];

  if(!f) return(CONST_LUA_ERROR);

  if(client)
    lua_pushstring(vm, f->get_cli_ip_addr()->print(buf, sizeof(buf)));
  else
    lua_pushstring(vm, f->get_srv_ip_addr()->print(buf, sizeof(buf)));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_client_ip(lua_State* vm) {
  return ntop_flow_get_ip(vm, true /* Client */);
}

/* ****************************************** */

static int ntop_flow_get_server_ip(lua_State* vm) {
  return ntop_flow_get_ip(vm, false /* Server */);
}

/* ****************************************** */

static int ntop_flow_get_port(lua_State* vm, bool client) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  if(client)
    lua_pushinteger(vm, f->get_cli_port());
  else
    lua_pushinteger(vm, f->get_srv_port());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flow_get_client_port(lua_State* vm) {
  return ntop_flow_get_port(vm, true /* Client */);
}

/* ****************************************** */

static int ntop_flow_get_server_port(lua_State* vm) {
  return ntop_flow_get_port(vm, false /* Server */);
}

/* ****************************************** */

static int ntop_flow_get_key(lua_State* vm, bool client) {
  Flow *f = ntop_flow_get_context_flow(vm);
  Host *h;
  char buf[64];

  if(!f) return(CONST_LUA_ERROR);

  h = client ? f->get_cli_host() : f->get_srv_host();
  lua_pushstring(vm, h ? h->get_hostkey(buf, sizeof(buf), true /* force VLAN, required by flow.lua */) : "");

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

static int ntop_flow_get_icmp_type(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getICMPType());
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

/* ****************************************** */

static int ntop_flow_get_alert(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getPredominantAlert().id);
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

static int  ntop_flow_get_tls_info(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_newtable(vm);

  if(f) f->lua_get_tls_info(vm);

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

static int ntop_flow_get_risk_bitmap(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(f) lua_pushinteger(vm, f->getRiskBitmap());

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_flow_has_risk(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);

  if(f) {
    if(lua_type(vm, 1) == LUA_TNUMBER)
      lua_pushboolean(vm, f->hasRisk((ndpi_risk_enum)lua_tointeger(vm, 1)));
    else
      /* If there's no risk parameter specified, return true if a flow has any risk */
      lua_pushboolean(vm, f->hasRisks());
  } else
    lua_pushboolean(vm, false);

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_get_flow_info_field(lua_State* vm) {
  char buf[256];
  Flow *f = ntop_flow_get_context_flow(vm);

  lua_pushstring(vm, f ? f->getFlowInfo(buf, sizeof(buf)) : "");

  return CONST_LUA_OK;
}

/* ****************************************** */

void lua_push_rawdata_table_entry(lua_State *L, const char *key, u_int32_t len, u_int8_t *payload) {
  if(L) {
    lua_pushstring(L, key);
    lua_pushlstring(L, (const char*)payload, (size_t)len);
    lua_settable(L, -3);
  }
}

/* **************************************************************** */

static luaL_Reg _ntop_flow_reg[] = {
/* Public User Scripts API, documented at doc/src/api/lua_c/flow_user_scripts/flow.lua */
  { "getStatus",                ntop_flow_get_status                 },
  { "getPredominantAlert",         ntop_flow_get_alert               },
  { "isLocalToRemote",          ntop_flow_is_local_to_remote         },
  { "isRemoteToLocal",          ntop_flow_is_remote_to_local         },
  { "isLocal",                  ntop_flow_is_local                   },
  { "isBlacklisted",            ntop_flow_is_blacklisted             },
  { "isBidirectional",          ntop_flow_is_bidirectional           },
  { "getKey",                   ntop_flow_get_key                    },
  { "getFirstSeen",             ntop_flow_get_first_seen             },
  { "getLastSeen",              ntop_flow_get_last_seen              },
  { "getPackets",               ntop_flow_get_packets                },
  { "getBytes",                 ntop_flow_get_bytes                  },
  { "getClientIp",              ntop_flow_get_client_ip              },
  { "getServerIp",              ntop_flow_get_server_ip              },
  { "getClientPort",            ntop_flow_get_client_port            },
  { "getServerPort",            ntop_flow_get_server_port            },
  { "getProtocol",              ntop_flow_get_protocol               },
  { "getnDPICategoryName",      ntop_flow_get_ndpi_cat_name          },
  { "getnDPICategoryId",        ntop_flow_get_ndpi_category_id       },
  { "getnDPIMasterProtoId",     ntop_flow_get_ndpi_master_proto_id   },
  { "getnDPIAppProtoId",        ntop_flow_get_ndpi_app_proto_id      },
  { "getTLSVersion",            ntop_flow_get_tls_version            },
  
#ifdef NTOPNG_PRO
  { "getScore",                 ntop_flow_get_score                  },
#endif
#ifdef HAVE_NEDGE
  { "isPassVerdict",            ntop_flow_is_pass_verdict            },
#endif
/* END Public API */

  { "getInfo",                  ntop_flow_get_info                   },
  { "isTCPConnecting",          ntop_flow_is_tcp_connecting          },
  { "getICMPType",              ntop_flow_get_icmp_type              },
  { "getTCPStats",              ntop_flow_get_tcp_stats              },
  { "getBlacklistedInfo",       ntop_flow_get_blacklisted_info       },
  { "getTLSInfo",               ntop_flow_get_tls_info               },
  { "getHTTPInfo",              ntop_flow_get_http_info              },
  { "getDNSInfo",               ntop_flow_get_dns_info               },
  { "getRiskBitmap",            ntop_flow_get_risk_bitmap            },
  { "hasRisk",                  ntop_flow_has_risk                   },
  { "getFlowInfoField",         ntop_get_flow_info_field             },
  
  { NULL,                       NULL }
};

luaL_Reg *ntop_flow_reg = _ntop_flow_reg;

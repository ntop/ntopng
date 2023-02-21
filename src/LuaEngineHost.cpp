/*
 *
 * (C) 2013-23 - ntop.org
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

/*
  This file implements the host.**** class
*/

/* **************************************************************** */

static int ntop_host_get_ip(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    char buf[64];

    lua_pushstring(vm, h->printMask(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_mac(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    Mac *cur_mac = h->getMac();
    const u_int8_t *mac = cur_mac ? cur_mac->get_mac() : NULL;
    char buf[64];

    lua_pushstring(vm, Utils::formatMac(mac ? mac : NULL, buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_name(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    char buf[64];

    lua_pushstring(vm, h->get_visual_name(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_vlan_id(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->get_vlan_id());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_is_local(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isLocalHost() : false);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_is_unicast(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;
  IpAddress *ip = h ? h->get_ip() : NULL;

  lua_pushboolean(vm, ip ? (!ip->isBroadMulticastAddress()) : true);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_is_multicast(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;
  IpAddress *ip = h ? h->get_ip() : NULL;

  lua_pushboolean(vm, ip ? ip->isMulticastAddress() : false);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_is_broadcast(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;
  IpAddress *ip = h ? h->get_ip() : NULL;

  lua_pushboolean(vm, ip ? ip->isBroadcastAddress() : false);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_is_blacklisted(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isBlacklisted() : false);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_is_rx_only(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isRxOnlyHost() : false);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_blacklist(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) h->blacklistHost();
  
  lua_pushboolean(vm, h ? true : false);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_bytes_sent(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->getNumBytesSent());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_bytes_rcvd(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->getNumBytesRcvd());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_bytes_total(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->getNumBytesSent() + h->getNumBytesRcvd());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_l7_stats(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    nDPIStats *stats = h->get_ndpi_stats();

    if(stats) {
      lua_newtable(vm);
      stats->lua(h->getInterface(), vm, false, false, false);
    } else
      lua_pushnil(vm);
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_skip_visited_host(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    h->setCustomHostScriptAlreadyEvaluated();

  lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_trigger_host_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    u_int32_t value;
    char *msg;

    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    value = (u_int32_t) lua_tointeger(vm, 1);

    if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    msg = (char*)lua_tostring(vm, 2);

    h->triggerCustomHostAlert(value, msg);
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_get_num_contacted_peers_as_client_tcp_notx(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->getNumContactedPeersAsClientTCPNoTX());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_get_unidirectional_tcp_flows_stats(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    h->lua_unidirectional_tcp_flows(vm, false);
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_get_num_contacts_from_peers_as_server_tcp_notx(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->getNumContactsFromPeersAsServerTCPNoTX());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_get_num_contacted_tcp_server_ports_notx(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->getNumContactedTCPServerPortsNoTX());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_is_first_check_run(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isCustomHostScriptFirstRun() : false);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static luaL_Reg _ntop_host_reg[] = {
  { "ip",               ntop_host_get_ip               },
  { "mac",              ntop_host_get_mac              },
  { "name",             ntop_host_get_name             },
  { "vlan_id",          ntop_host_get_vlan_id          },

  { "is_local",         ntop_host_is_local             },
  { "is_unicast",       ntop_host_is_unicast           },
  { "is_multicast",     ntop_host_is_multicast         },
  { "is_broadcast",     ntop_host_is_broadcast         },
  { "is_blacklisted",   ntop_host_is_blacklisted       },
  { "is_rx_only",       ntop_host_is_rx_only           },

  { "bytes_sent",       ntop_host_get_bytes_sent       },
  { "bytes_rcvd",       ntop_host_get_bytes_rcvd       },
  { "bytes",            ntop_host_get_bytes_total      },
  { "l7",               ntop_host_get_l7_stats         },

  { "blacklistHost",    ntop_host_blacklist            },
    
  { "skipVisitedHost",  ntop_skip_visited_host         },
  { "triggerAlert",     ntop_trigger_host_alert        },

  { "isFirstCheckRun",                        ntop_is_first_check_run                             },
  { "getUnidirectionalTCPFlowsStats",         ntop_get_unidirectional_tcp_flows_stats             },
  { "getNumContactedPeersAsClientTCPNoTX",    ntop_get_num_contacted_peers_as_client_tcp_notx     },
  { "getNumContactsFromPeersAsServerTCPNoTX", ntop_get_num_contacts_from_peers_as_server_tcp_notx },
  { "getNumContactedTCPServerPortsNoTX",      ntop_get_num_contacted_tcp_server_ports_notx        },

  { NULL,               NULL                           }
};

luaL_Reg *ntop_host_reg = _ntop_host_reg;

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

/*
  This file implements the flow.**** class
*/

/* ****************************************** */

/* @brief Returns total bytes (client→server + server→client) transferred by this flow.  Lua: flow.bytes() → integer */
static int ntop_flow_get_bytes(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_bytes());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns bytes transferred from client to server for this flow.  Lua: flow.cli2srv_bytes() → integer */
static int ntop_flow_get_cli2srv_bytes(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_bytes_cli2srv());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns bytes transferred from server to client for this flow.  Lua: flow.srv2cli_bytes() → integer */
static int ntop_flow_get_srv2cli_bytes(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_bytes_srv2cli());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the client (initiator) IP address string for this flow.  Lua: flow.cli() → string */
static int ntop_flow_get_client(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f && f->get_cli_ip_addr()) {
    char buf[64];

    lua_pushstring(vm, f->get_cli_ip_addr()->print(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the client (initiator) TCP/UDP port number for this flow.  Lua: flow.cli_port() → integer */
static int ntop_flow_get_client_port(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_cli_port());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the server (responder) IP address string for this flow.  Lua: flow.srv() → string */
static int ntop_flow_get_server(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f && f->get_srv_ip_addr()) {
    char buf[64];

    lua_pushstring(vm, f->get_srv_ip_addr()->print(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the server (responder) TCP/UDP port number for this flow.  Lua: flow.srv_port() → integer */
static int ntop_flow_get_server_port(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_srv_port());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the L4 protocol number (e.g. 6=TCP, 17=UDP) for this flow.  Lua: flow.protocol() → integer */
static int ntop_flow_get_protocol(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_protocol());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the VLAN ID associated with this flow (0 if untagged).  Lua: flow.vlan_id() → integer */
static int ntop_flow_get_vlan_id(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_vlan_id());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the nDPI master (encapsulating) protocol ID for this flow (e.g. HTTP in HTTP.Facebook).  Lua: flow.l7_master_proto() → integer */
static int ntop_flow_get_l7_master_proto(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_detected_protocol().proto.master_protocol);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the nDPI application protocol ID for this flow (e.g. Facebook in HTTP.Facebook).  Lua: flow.l7_proto() → integer */
static int ntop_flow_get_l7_proto(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f)
    lua_pushinteger(vm, f->get_detected_protocol().proto.app_protocol);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the locality direction string for this flow: "local@local", "local@remote", "remote@local", or "remote2remote".  Lua: flow.direction() → string */
static int ntop_flow_get_direction(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f) {
    const char* rsp;

    if (f->isRemoteToRemote())
      rsp = "remote2remote";
    else if (f->isLocalToRemote())
      rsp = "local@remote";
    else if (f->isRemoteToLocal())
      rsp = "remote@local";
    else if (f->isLocalToLocal())
      rsp = "local@local";
    else
      rsp = "unknown";

    lua_pushstring(vm, rsp);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if only one direction of this flow has seen traffic (no reply packets).  Lua: flow.is_oneway() → boolean */
static int ntop_flow_is_oneway(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  lua_pushboolean(vm, f ? f->isOneWay() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if both endpoints of this flow are unicast addresses (not broadcast/multicast).  Lua: flow.is_unicast() → boolean */
static int ntop_flow_is_unicast(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  lua_pushboolean(vm, f ? f->isUnicast() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the full human-readable nDPI protocol name for this flow (e.g. "HTTP.Facebook").  Lua: flow.l7_proto_name() → string */
static int ntop_flow_get_l7_proto_name(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f) {
    char buf[64];

    lua_pushstring(vm, f->get_detected_protocol_name(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns a table with HTTP-specific flow metadata (method, URL, response code, content-type, etc.).  Lua: flow.http() → table */
static int ntop_flow_get_l7_proto_http(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f) {
    lua_newtable(vm);
    f->lua_get_http_info(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns a table with DNS-specific flow metadata (query name, query type, response code, reply IPs, etc.).  Lua: flow.dns() → table */
static int ntop_flow_get_l7_proto_dns(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f) {
    lua_newtable(vm);
    f->lua_get_dns_info(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns a table with SSH-specific flow metadata (client/server hassh fingerprints, etc.).  Lua: flow.ssh() → table */
static int ntop_flow_get_l7_proto_ssh(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f) {
    lua_newtable(vm);
    f->lua_get_ssh_info(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns a table with TLS/QUIC-specific flow metadata (SNI, certificate subject/issuer, JA3/JA4/JA5 fingerprints, etc.).  Lua: flow.tls_quic() → table */
static int ntop_flow_get_l7_proto_tls_quic(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f) {
    lua_newtable(vm);
    f->lua_get_tls_info(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Triggers a custom alert on the current flow with a numeric value and message string.  Lua: flow.triggerAlert(value, msg) → nil */
static int ntop_trigger_flow_alert(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Flow* f = c ? c->flow : NULL;

  if (f) {
    u_int32_t value;
    char* msg;

    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    value = (u_int32_t)lua_tointeger(vm, 1);

    if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    msg = (char*)lua_tostring(vm, 2);

    f->triggerCustomFlowAlert(value, msg);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

static luaL_Reg _ntop_flow_reg[] = {
    {"cli", ntop_flow_get_client},
    {"cli_port", ntop_flow_get_client_port},
    {"srv", ntop_flow_get_server},
    {"srv_port", ntop_flow_get_server_port},
    {"protocol", ntop_flow_get_protocol},
    {"vlan_id", ntop_flow_get_vlan_id},
    {"is_oneway", ntop_flow_is_oneway},
    {"is_unicast", ntop_flow_is_unicast},

    {"cli2srv_bytes", ntop_flow_get_cli2srv_bytes},
    {"srv2cli_bytes", ntop_flow_get_srv2cli_bytes},
    {"bytes", ntop_flow_get_bytes},

    {"l7_master_proto", ntop_flow_get_l7_master_proto},
    {"l7_proto", ntop_flow_get_l7_proto},
    {"l7_proto_name", ntop_flow_get_l7_proto_name},

    /* Layer-7 Protocols */
    {"http", ntop_flow_get_l7_proto_http},
    {"dns", ntop_flow_get_l7_proto_dns},
    {"ssh", ntop_flow_get_l7_proto_ssh},
    {"tls_quic", ntop_flow_get_l7_proto_tls_quic},

    {"direction", ntop_flow_get_direction},

    {"triggerAlert", ntop_trigger_flow_alert},

    {NULL, NULL}};

luaL_Reg* ntop_flow_reg = _ntop_flow_reg;

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
  This file implements the host.**** class
*/

/* **************************************************************** */

/* @brief Returns the IP address (or IP/mask) string of the current host.  Lua: host.ip() → string */
static int ntop_host_get_ip(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h) {
    char buf[64];

    lua_pushstring(vm, h->printMask(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the MAC address string associated with the current host, or an empty/zero MAC if unknown.  Lua: host.mac() → string */
static int ntop_host_get_mac(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h) {
    Mac* cur_mac = h->getMac();
    const u_int8_t* mac = cur_mac ? cur_mac->get_mac() : NULL;
    char buf[64];

    lua_pushstring(vm, Utils::formatMac(mac ? mac : NULL, buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the visual (display) name for the current host — resolved hostname, custom name, or IP string.  Lua: host.name() → string */
static int ntop_host_get_name(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h) {
    char buf[64];

    lua_pushstring(vm, h->get_visual_name(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the VLAN ID associated with the current host (0 if untagged).  Lua: host.vlan_id() → integer */
static int ntop_host_get_vlan_id(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->get_vlan_id());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the current alert score for the current host (sum of all active alert scores).  Lua: host.score() → integer */
static int ntop_host_get_score(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->getScore());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if the current host belongs to a locally configured network.  Lua: host.is_local() → boolean */
static int ntop_host_is_local(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isLocalHost() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if the current host's IP is a unicast address (not broadcast or multicast).  Lua: host.is_unicast() → boolean */
static int ntop_host_is_unicast(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;
  IpAddress* ip = h ? h->get_ip() : NULL;

  lua_pushboolean(vm, ip ? (!ip->isBroadMulticastAddress()) : true);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if the current host's IP is a multicast address.  Lua: host.is_multicast() → boolean */
static int ntop_host_is_multicast(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;
  IpAddress* ip = h ? h->get_ip() : NULL;

  lua_pushboolean(vm, ip ? ip->isMulticastAddress() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if the current host's IP is a broadcast address.  Lua: host.is_broadcast() → boolean */
static int ntop_host_is_broadcast(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;
  IpAddress* ip = h ? h->get_ip() : NULL;

  lua_pushboolean(vm, ip ? ip->isBroadcastAddress() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if the current host's IP appears on a configured blacklist.  Lua: host.is_blacklisted() → boolean */
static int ntop_host_is_blacklisted(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isBlacklisted() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if the current host has only been seen receiving traffic (no sent packets).  Lua: host.is_rx_only() → boolean */
static int ntop_host_is_rx_only(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isRxOnlyHost() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the total bytes sent (uploaded) by the current host since it was first seen.  Lua: host.bytes_sent() → integer */
static int ntop_host_get_bytes_sent(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->getNumBytesSent());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the total bytes received (downloaded) by the current host since it was first seen.  Lua: host.bytes_rcvd() → integer */
static int ntop_host_get_bytes_rcvd(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->getNumBytesRcvd());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the total bytes (sent + received) for the current host since it was first seen.  Lua: host.bytes() → integer */
static int ntop_host_get_bytes_total(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->getNumBytesSent() + h->getNumBytesRcvd());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns a table of per-nDPI-protocol byte/flow statistics for the current host.  Lua: host.l7() → table */
static int ntop_host_get_l7_stats(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h) {
    nDPIStats* stats = h->get_ndpi_stats();

    if (stats) {
      lua_newtable(vm);
      stats->lua(h->getInterface(), vm, false, false, false);
    } else
      lua_pushnil(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Marks the current host to skip (or un-skip) re-evaluation by the custom host check script, optionally until a given Unix timestamp.  Lua: host.skipVisitedHost([skip[, skip_until]]) → nil */
static int ntop_skip_visited_host(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h) {
    bool skip_host = false;
    u_int32_t skip_until = (u_int32_t)-1; /* Forever */
    ;

    /* Optional arguments */
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) == CONST_LUA_OK) {
      skip_host = (bool)lua_toboolean(vm, 1);

      if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) == CONST_LUA_OK)
        skip_until = (u_int32_t)lua_tonumber(vm, 2);
    }

    h->setCustomHostScriptAlreadyEvaluated(skip_host, skip_until);
  }

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Triggers a custom alert on the current host with a numeric value and message string.  Lua: host.triggerAlert(value, msg) → nil */
static int ntop_trigger_host_alert(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h) {
    u_int32_t value;
    char* msg;

    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    value = (u_int32_t)lua_tointeger(vm, 1);

    if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    msg = (char*)lua_tostring(vm, 2);

    h->triggerCustomHostAlert(value, msg);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the number of distinct TCP/UDP server peers this host contacted but never received a reply from (no-TX peers as client).  Lua: host.getNumContactedPeersAsClientTCPUDPNoTX() → integer */
static int ntop_get_num_contacted_peers_as_client_tcp_udp_notx(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->getNumContactedPeersAsClientTCPUDPNoTX());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns a table with counts of unidirectional (no-reply) TCP/UDP flows for the current host, broken down by client/server role.  Lua: host.getUnidirectionalTCPUDPFlowsStats() → table */
static int ntop_get_unidirectional_tcp_udp_flows_stats(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    h->lua_unidirectional_tcp_udp_flows(vm, false);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the number of distinct TCP/UDP clients that contacted this host as server but received no reply (no-TX peers as server).  Lua: host.getNumContactsFromPeersAsServerTCPUDPNoTX() → integer */
static int ntop_get_num_contacts_from_peers_as_server_tcp_udp_notx(
    lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->getNumContactsFromPeersAsServerTCPUDPNoTX());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns the number of distinct TCP/UDP server ports this host contacted but received no reply from (useful for port-scan detection).  Lua: host.getNumContactedTCPUDPServerPortsNoTX() → integer */
static int ntop_get_num_contacted_tcp_udp_server_ports_notx(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h)
    lua_pushinteger(vm, h->getNumContactedTCPUDPServerPortsNoTX());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Resets all peer-contact counters for the current host (contacted peers, server ports, unidirectional flows).  Lua: host.resetHostContacts() → nil */
static int ntop_reset_host_contacts(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  if (h) h->resetHostContacts();

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Returns true if this is the very first time the host check script has run for this host (useful for initialization logic).  Lua: host.isFirstCheckRun() → boolean */
static int ntop_is_first_check_run(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  Host* h = c ? c->host : NULL;

  lua_pushboolean(vm, h ? h->isCustomHostScriptFirstRun() : false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

static luaL_Reg _ntop_host_reg[] = {
    {"ip", ntop_host_get_ip},
    {"mac", ntop_host_get_mac},
    {"name", ntop_host_get_name},
    {"vlan_id", ntop_host_get_vlan_id},

    {"is_local", ntop_host_is_local},
    {"is_unicast", ntop_host_is_unicast},
    {"is_multicast", ntop_host_is_multicast},
    {"is_broadcast", ntop_host_is_broadcast},
    {"is_blacklisted", ntop_host_is_blacklisted},
    {"is_rx_only", ntop_host_is_rx_only},

    {"bytes_sent", ntop_host_get_bytes_sent},
    {"bytes_rcvd", ntop_host_get_bytes_rcvd},
    {"bytes", ntop_host_get_bytes_total},
    {"l7", ntop_host_get_l7_stats},
    {"score", ntop_host_get_score},

    {"skipVisitedHost", ntop_skip_visited_host},
    {"triggerAlert", ntop_trigger_host_alert},

    {"isFirstCheckRun", ntop_is_first_check_run},
    {"getUnidirectionalTCPUDPFlowsStats",
     ntop_get_unidirectional_tcp_udp_flows_stats},
    {"getNumContactedPeersAsClientTCPUDPNoTX",
     ntop_get_num_contacted_peers_as_client_tcp_udp_notx},
    {"getNumContactsFromPeersAsServerTCPUDPNoTX",
     ntop_get_num_contacts_from_peers_as_server_tcp_udp_notx},
    {"getNumContactedTCPUDPServerPortsNoTX",
     ntop_get_num_contacted_tcp_udp_server_ports_notx},
    {"resetHostContacts", ntop_reset_host_contacts},
    {NULL, NULL}
};

luaL_Reg* ntop_host_reg = _ntop_host_reg;

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
#include "host_alerts_includes.h" /* Due to ntop_interface_trigger_traffic_alert */

/* ****************************************** */

static NetworkInterface* handle_null_interface(lua_State* vm) {
  char allowed_ifname[MAX_INTERFACE_NAME_LEN];

  // this is normal, no need to generate a trace
  // ntop->getTrace()->traceEvent(TRACE_INFO, "NULL interface: did you restart
  // ntopng in the meantime?");

  if (ntop->getInterfaceAllowed(vm, allowed_ifname))
    return ntop->getNetworkInterface(allowed_ifname);

  return (ntop->getFirstInterface());
}

/* ****************************************** */

NetworkInterface* getCurrentInterface(lua_State* vm) {
  NetworkInterface* curr_iface;

  curr_iface = getLuaVMUserdata(vm, iface);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && !curr_iface->isEnabled()) curr_iface = NULL;

  if (!curr_iface) curr_iface = handle_null_interface(vm);

  return (curr_iface);
}

/* ****************************************** */

bool matches_allowed_ifname(char* allowed_ifname, char* iface) {
  return (
      ((allowed_ifname == NULL) ||
       (allowed_ifname[0] == '\0')) /* Periodic script / unrestricted user */
      || (!strncmp(allowed_ifname, iface, strlen(allowed_ifname))));
}

/* ****************************************** */

/* @brief Returns a table mapping interface IDs to names; optionally excludes viewed sub-interfaces.  Lua: interface.getIfNames([exclude_viewed]) → table */
static int ntop_get_interface_names(lua_State* vm) {
  char* allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);
  bool exclude_viewed_interfaces = false;

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    exclude_viewed_interfaces = lua_toboolean(vm, 1) ? true : false;

  lua_newtable(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  for (int i = 0; i < ntop->get_num_interfaces(); i++) {
    NetworkInterface* iface;
    /*
      We should not call ntop->getInterfaceAtId() as it
      manipulates the vm that has been already modified with
      lua_newtable(vm) a few lines above.
    */

    if ((iface = ntop->getInterface(i)) != NULL) {
      char num[8], *ifname = iface->get_name();

      if (!iface->isEnabled()) continue;

      if (matches_allowed_ifname(allowed_ifname, ifname) &&
          (!exclude_viewed_interfaces || !iface->isViewed())) {
        ntop->getTrace()->traceEvent(TRACE_DEBUG, "Returning name [%d][%s]", i,
                                     ifname);
        snprintf(num, sizeof(num), "%d", iface->get_id());
        lua_push_str_table_entry(vm, num, ifname);
      }
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the numeric ID of the first available network interface.  Lua: interface.getFirstInterfaceId() → integer */
static int ntop_get_first_interface_id(lua_State* vm) {
  NetworkInterface* iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  iface = ntop->getFirstInterface();

  if (iface) {
    lua_pushinteger(vm, iface->get_id());
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Selects the active interface for subsequent interface.* calls in this Lua VM.  Lua: interface.select(ifid) → nil */
static int ntop_select_interface(lua_State* vm) {
  char* ifname;
  bool already_set = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNIL)
    ifname = (char*)"any";
  else {
    if (lua_type(vm, 1) == LUA_TSTRING)
      ifname = (char*)lua_tostring(vm, 1);
    else if (lua_type(vm, 1) == LUA_TNUMBER) {
      int ifid = lua_tonumber(vm, 1);

      getLuaVMUservalue(vm, iface) = ntop->getNetworkInterface(vm, ifid);
      already_set = true;
    } else
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (!already_set)
    getLuaVMUservalue(vm, iface) = ntop->getNetworkInterface(ifname, vm);

  // lua_pop(vm, 1); /* Cleanup the Lua stack */
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the hardware MAC address of the currently selected interface.  Lua: interface.getIfMac() → string */
static int ntop_get_interface_mac(lua_State* vm) {
  NetworkInterface* iface;
  char buf[32];
  u_int8_t* ifMac;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((iface = getCurrentInterface(vm)) == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  ifMac = iface->getIfMac();

  lua_pushstring(vm, Utils::formatMac(ifMac, buf, sizeof(buf)));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the numeric ID of the currently selected interface.  Lua: interface.getId() → integer */
static int ntop_get_interface_id(lua_State* vm) {
  NetworkInterface* iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((iface = getCurrentInterface(vm)) == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  lua_pushinteger(vm, iface->get_id());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}


/* ****************************************** */

/* @brief Returns the numeric network ID of numeric IP address */
static int ntop_get_ip_network_id(lua_State* vm) {
  NetworkInterface* iface;
  char *ip_addr;
  
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    ip_addr = (char*)lua_tostring(vm, 1);

  if ((ip_addr == NULL)
      || ((iface = getCurrentInterface(vm)) == NULL)) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  lua_pushinteger(vm, iface->getNetworkId(ip_addr));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the ID of the parent (master) interface for a sub-interface.  Lua: interface.getMasterInterfaceId() → integer */
static int ntop_get_master_interface_id(lua_State* vm) {
  NetworkInterface* iface = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    const char* ifname = lua_tostring(vm, 1);
    iface = ntop->getNetworkInterface(ifname, vm);

  } else if (lua_type(vm, 1) == LUA_TNUMBER) {
    int ifid = lua_tointeger(vm, 1);
    iface = ntop->getNetworkInterface(vm, ifid);

  } else {
    iface = getCurrentInterface(vm);
  }

  if (iface == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (iface->isSubInterface())
    lua_pushinteger(vm, iface->getMasterInterface()->get_id());
  else
    lua_pushinteger(vm, iface->get_id());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the name of the currently selected interface.  Lua: interface.getName() → string */
static int ntop_get_interface_name(lua_State* vm) {
  NetworkInterface* iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((iface = getCurrentInterface(vm)) == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  lua_pushstring(vm, iface->get_name());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the given interface ID or name corresponds to an existing interface.  Lua: interface.isValidIfId(ifid) → boolean */
static int ntop_is_valid_interface_id(lua_State* vm) {
  int ifid;
  bool valid_int = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    errno = 0; /* Reset as possibly set by strtol. This is thread-safe. */
    ifid = strtol(lua_tostring(vm, 1), NULL,
                  0); /* Sets errno when the conversion fails, e.g., string is
                         NaN once converted */
    if (!errno) valid_int = true;
  } else if (lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    valid_int = true;
  }

  lua_pushboolean(vm, valid_int ? ntop->getInterfaceById(ifid) != NULL : false);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the configured maximum speed (bps) of an interface.  Lua: interface.getMaxIfSpeed([ifname_or_id]) → integer */
static int ntop_get_max_if_speed(lua_State* vm) {
  char* ifname = NULL;
  int ifid;
  NetworkInterface* iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    ifname = (char*)lua_tostring(vm, 1);
    lua_pushinteger(vm, Utils::getMaxIfSpeed(ifname));
  } else if (lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);

    if ((iface = ntop->getInterfaceById(ifid)) != NULL) {
      lua_pushinteger(vm, iface->getMaxSpeed());
    } else {
      lua_pushnil(vm);
    }
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

#ifdef NTOPNG_PRO
/**
 * @brief Get the SNMP statistics of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
/* @brief Returns SNMP-polled statistics for the current interface (Pro only).  Lua: interface.getSNMPStats() → table */
static int ntop_interface_get_snmp_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  nDPIStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getFlowInterfacesStats()) {
    curr_iface->getFlowInterfacesStats()->lua(vm, curr_iface);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else {
    lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }
}
#endif

/* ****************************************** */

/* @brief Returns true if the interface has observed VLAN-tagged traffic.  Lua: interface.hasVLANs() → boolean */
static int ntop_interface_has_vlans(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    lua_pushboolean(vm, curr_iface->hasSeenVLANTaggedPackets());
  else
    lua_pushboolean(vm, 0);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the interface has received eBPF process-level events.  Lua: interface.hasEBPF() → boolean */
static int ntop_interface_has_ebpf(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    lua_pushboolean(vm, curr_iface->hasSeenEBPFEvents());
  else
    lua_pushboolean(vm, 0);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the interface has received external (injected) alerts.  Lua: interface.hasExternalAlerts() → boolean */
static int ntop_interface_has_external_alerts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    lua_pushboolean(vm, curr_iface->hasSeenExternalAlerts());
  else
    lua_pushboolean(vm, 0);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

// *** API ***
/* @brief Returns true if this is a live packet-capture interface (not ZMQ/sFlow/eBPF).  Lua: interface.isPacketInterface() → boolean */
static int ntop_interface_is_packet_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  lua_pushboolean(vm, curr_iface->isPacketInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

// *** API ***
/* @brief Returns true if network discovery is supported on this interface.  Lua: interface.isDiscoverableInterface() → boolean */
static int ntop_interface_is_discoverable_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  lua_pushboolean(vm, curr_iface->isDiscoverableInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this interface is operating in nEdge bridge/inline mode.  Lua: interface.isBridgeInterface() → boolean */
static int ntop_interface_is_bridge_interface(lua_State* vm) {
  int ifid;
  NetworkInterface* iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((lua_type(vm, 1) == LUA_TNUMBER)) {
    ifid = lua_tointeger(vm, 1);

    if (ifid < 0 || !(iface = ntop->getInterfaceById(ifid)))
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  lua_pushboolean(vm, iface->is_bridge_interface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this interface is a PCAP replay/dump interface.  Lua: interface.isPcapDumpInterface() → boolean */
static int ntop_interface_is_pcap_dump_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getIfType() == interface_type_PCAP_DUMP)
    rv = true;

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this is a ClickHouse/DB view interface.  Lua: interface.isDatabaseViewInterface() → boolean */
static int ntop_interface_is_database_view_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getIfType() == interface_type_DB_VIEW)
    rv = true;

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this interface receives flows via ZMQ (nProbe integration).  Lua: interface.isZMQInterface() → boolean */
static int ntop_interface_is_zmq_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getIfType() == interface_type_ZMQ) rv = true;
#ifdef NTOPNG_PRO
  else if (curr_iface->getIfType() == interface_type_VIEW) {
    /*
      In case of a view interface we need to check if at least
      one of the sub-intefaces is of type ZMQ
    */

    rv = ntop->viewHasZMQInterface(curr_iface);
  }
#endif

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this is an aggregated view interface covering multiple sub-interfaces.  Lua: interface.isView() → boolean */
static int ntop_interface_is_view(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isView();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the ID of the view interface that aggregates this interface, or nil.  Lua: interface.viewedBy() → integer */
static int ntop_interface_viewed_by(lua_State* vm) {
#ifdef NTOPNG_PRO
  NetworkInterface* curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
#ifdef NTOPNG_PRO
  if (curr_iface && curr_iface->isViewed())
    lua_pushinteger(vm, curr_iface->viewedBy()->get_id());
  else
#endif
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this interface is aggregated by a view interface.  Lua: interface.isViewed() → boolean */
static int ntop_interface_is_viewed(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isViewed();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this interface is aggregated by a view interface.  Lua: interface.isViewed() → boolean */
static int ntop_interface_is_sampled_traffic(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isSampledTraffic();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if this is a loopback interface.  Lua: interface.isLoopback() → boolean */
static int ntop_interface_is_loopback(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isLoopback();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the interface capture thread is currently running.  Lua: interface.isRunning() → boolean */
static int ntop_interface_is_running(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isRunning();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the interface is idle (no recent traffic).  Lua: interface.isIdle() → boolean */
static int ntop_interface_is_idle(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->idle();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Sets the idle state of the interface (used by management scripts).  Lua: interface.setInterfaceIdleState(is_idle) → nil */
static int ntop_interface_set_idle(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool state;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((!curr_iface) || (!ntop->isUserAdministrator(vm))) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  state = lua_toboolean(vm, 1) ? true : false;

  curr_iface->setIdleState(state);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a table listing active live-capture sessions on this interface.  Lua: interface.dumpLiveCaptures() → table */
static int ntop_interface_dump_live_captures(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  iface->dumpLiveCaptures(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

AddressTree* get_allowed_nets(lua_State* vm) {
  AddressTree* ptree;

  ptree = getLuaVMUserdata(vm, allowedNets);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return (ptree);
}

/* ****************************************** */

/* @brief Adds asset attributes to a local host's discovery record.  Lua: interface.addDataToLocalHostAssets(ip, data_table) → nil */
static int ntop_add_data_to_assets(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  char *host = NULL, *field = NULL, *value = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TSTRING) /* Host provided in IP@VLAN format */
    host = (char*)lua_tostring(vm, 1);

  if (host != NULL && strlen(host) > 0) {
    Host* h;
    char host_ip[64];
    char* key;
    u_int16_t vlan_id = 0;

    get_host_vlan_info(host, &key, &vlan_id, host_ip, sizeof(host_ip));

    if ((!iface) ||
        ((h = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                  getLuaVMUservalue(vm, observationPointId))) ==
         NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate host %s",
                                   host_ip);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    }

    if (h->isLocalHost()) {
      /* Available only for local hosts */
      if (lua_type(vm, 2) == LUA_TSTRING) /* Field provided */
        field = (char*)lua_tostring(vm, 2);

      if (lua_type(vm, 3) == LUA_TSTRING) /* Value provided */
        value = (char*)lua_tostring(vm, 3);

      if (!h->addDataToAssets(field, value)) {
        ntop->getTrace()->traceEvent(
            TRACE_WARNING,
            "Error while updating [%s] Asset Map [field: %s][value :%s]",
            host ? host : "NULL", field ? field : "NULL",
            value ? value : "NULL");
        return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
      }
    }
  }
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Removes a local host's asset discovery record.  Lua: interface.removeDataFromLocalHostAssets(ip) → nil */
static int ntop_remove_data_from_assets(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  char *host = NULL, *field = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TSTRING) /* Host provided in IP@VLAN format */
    host = (char*)lua_tostring(vm, 1);

  if (host != NULL && strlen(host) > 0) {
    Host* h;
    char host_ip[64];
    char* key;
    u_int16_t vlan_id = 0;

    get_host_vlan_info(host, &key, &vlan_id, host_ip, sizeof(host_ip));

    if ((!iface) ||
        ((h = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                  getLuaVMUservalue(vm, observationPointId))) ==
         NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate host %s",
                                   host_ip);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    }

    if (h->isLocalHost()) {
      /* Available only for local hosts */
      if (lua_type(vm, 2) == LUA_TSTRING) /* Field provided */
        field = (char*)lua_tostring(vm, 2);

      if (!h->removeDataFromAssets(field)) {
        ntop->getTrace()->traceEvent(
            TRACE_WARNING, "Error while updating [%s] Asset Map [field: %s]",
            host ? host : "NULL", field ? field : "NULL");
        return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
      }
    }
  }
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Starts a live packet capture session on the interface; returns session info.  Lua: interface.liveCapture(params_table) → table */
static int ntop_interface_live_capture(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  NtopngLuaContext* c;
  int capture_id, duration;
  char* host = NULL;
  char* bpf = NULL;
  NetworkInterface* iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (!ntop->isPcapDownloadAllowed(vm, curr_iface->get_name()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TSTRING) /* Host provided */
    host = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  duration = (u_int32_t)lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  bpf = (char*)lua_tostring(vm, 3);

  if (host != NULL && strlen(host) > 0) {
    Host* h;
    char host_ip[64];
    char* key;
    u_int16_t vlan_id = 0;

    get_host_vlan_info(host, &key, &vlan_id, host_ip, sizeof(host_ip));

    if ((!curr_iface) ||
        ((h = curr_iface->findHostByIP(
              get_allowed_nets(vm), host_ip, vlan_id,
              getLuaVMUservalue(vm, observationPointId))) == NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate host %s",
                                   host_ip);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    } else {
      c->live_capture.matching_host = h;
    }
  }

  c->live_capture.capture_until = time(NULL) + duration;
  c->live_capture.capture_max_pkts = CONST_MAX_NUM_PACKETS_PER_LIVE;
  c->live_capture.num_captured_packets = 0;
  c->live_capture.stopped = c->live_capture.pcaphdr_sent = false;
  c->live_capture.bpfFilterSet = false;

  bpf = ntop->preparePcapDownloadFilter(vm, bpf);

  if (bpf == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Failure building the capture filter");
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Using capture filter '%s'",
  // bpf);

  if (bpf[0] != '\0') {
    pcap_t* pcap_handle = pcap_open_dead(iface->get_datalink(), 65535);
    if (pcap_handle) {
      if (pcap_compile(pcap_handle, &c->live_capture.fcode, bpf, 0,
                       PCAP_NETMASK_UNKNOWN) == -1)
        ntop->getTrace()->traceEvent(
            TRACE_WARNING, "Unable to set capture filter %s. Filter ignored.",
            bpf);
      else
        c->live_capture.bpfFilterSet = true;
      pcap_close(pcap_handle);
    }
  }

  Utils::flushHTTPBuffer(vm);

  if (curr_iface->registerLiveCapture(c, &capture_id)) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Starting live capture id %d",
                                 capture_id);

    while (!c->live_capture.stopped) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "Capturing....");
      sleep(1);
    }

    ntop->getTrace()->traceEvent(TRACE_INFO, "Capture completed");
  }

  free(bpf);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Stops a running live capture session by its ID.  Lua: interface.stopLiveCapture(capture_id) → nil */
static int ntop_interface_stop_live_capture(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  int capture_id;
  bool rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  capture_id = (int)lua_tointeger(vm, 1);

  rc = curr_iface->stopLiveCapture(capture_id);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Stopping live capture %d: %s",
                               capture_id, rc ? "stopped" : "error");

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Converts an interface name string to its numeric ID.  Lua: interface.name2id(ifname) → integer */
static int ntop_interface_name2id(lua_State* vm) {
  char* if_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNIL)
    if_name = NULL;
  else {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    if_name = (char*)lua_tostring(vm, 1);
  }

  lua_pushinteger(vm, ntop->getInterfaceIdByName(vm, if_name));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Resets all learned broadcast domain state for the interface.  Lua: interface.resetBroadcastDomains() → nil */
static int ntop_interface_reset_broadcast_domains(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->resetBroacastDomains();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Resets traffic counters for the interface (optionally only drop counters).  Lua: interface.resetCounters([only_drops]) → nil */
static int ntop_interface_reset_counters(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool only_drops = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    only_drops = lua_toboolean(vm, 1) ? true : false;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->checkPointCounters(only_drops);
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Resets all traffic statistics for a specific host (internal helper for resetHostStats).  Lua: interface.resetHostStats(host, vlan) → nil */
static int ntop_interface_reset_host_stats(lua_State* vm, bool delete_data) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char buf[64], *host_ip;
  Host* host;
  u_int16_t vlan_id;
  bool reset_blacklisted = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if (lua_type(vm, 2) == LUA_TBOOLEAN) {
    reset_blacklisted = lua_toboolean(vm, 2) ? true : false;
  }

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  host = curr_iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                  getLuaVMUservalue(vm, observationPointId));

  if (host) {
    if (reset_blacklisted == true) {
      host->blacklistedStatsResetRequested();
    } else {
      if (delete_data)
        host->requestDataReset();
      else
        host->requestStatsReset();
    }
  }

  lua_pushboolean(vm, (host != NULL));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static inline int ntop_interface_reset_host_stats(lua_State* vm) {
  return (ntop_interface_reset_host_stats(vm, false));
}

/* ****************************************** */

/* @brief Permanently deletes all stored data for a specific host.  Lua: interface.deleteHostData(host, vlan) → nil */
static int ntop_interface_delete_host_data(lua_State* vm) {
  return (ntop_interface_reset_host_stats(vm, true));
}

/* ****************************************** */

/* @brief Resets all traffic statistics for a specific MAC address (internal helper).  Lua: interface.resetMacStats(mac) → nil */
static int ntop_interface_reset_mac_stats(lua_State* vm, bool delete_data) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  mac = (char*)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushboolean(vm, curr_iface->resetMacStats(vm, mac, delete_data));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static inline int ntop_interface_reset_mac_stats(lua_State* vm) {
  return (ntop_interface_reset_mac_stats(vm, false));
}

/* ****************************************** */

/* @brief Permanently deletes all stored data for a specific MAC address.  Lua: interface.deleteMacData(mac) → nil */
static int ntop_interface_delete_mac_data(lua_State* vm) {
  return (ntop_interface_reset_mac_stats(vm, true));
}

/* ****************************************** */

/* @brief Executes a SQL query against the interface's local SQLite database.  Lua: interface.execSQLQuery(sql) → table */
static int ntop_interface_exec_sql_query(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool limit_rows = true;  // honour the limit by default
  bool wait_for_db_created = true;
  char* sql;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((sql = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 2) == LUA_TBOOLEAN) {
    limit_rows = lua_toboolean(vm, 2) ? true : false;
  }

  if (lua_type(vm, 3) == LUA_TBOOLEAN) {
    wait_for_db_created = lua_toboolean(vm, 3) ? true : false;
  }

  /* In case the users login is disabled, the users have not the ability to run
   * queries, check if the users login is enabled or not
   */
  if (!ntop->hasCapability(vm, capability_historical_flows) &&
      ntop->getPrefs()->is_users_login_enabled()) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "User is not allowed to run query: %s", sql);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  curr_iface->execSQLQuery(vm, sql, limit_rows, wait_for_db_created);

  /* stack top: [result_table_or_nil, error_or_nil] */
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_TWO_RETURN_VALUES));
}

/* ****************************************** */

/* @brief Returns statistics for Kubernetes pods observed on this interface (eBPF).  Lua: interface.getPodsStats() → table */
static int ntop_interface_get_pods_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->getPodsStats(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns statistics for containers observed on this interface (eBPF).  Lua: interface.getContainersStats() → table */
static int ntop_interface_get_containers_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* pod_filter = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TSTRING) pod_filter = (char*)lua_tostring(vm, 1);

  curr_iface->getContainersStats(vm, pod_filter);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}
/* ****************************************** */

/* @brief Reloads companion interface assignments from Redis configuration.  Lua: interface.reloadCompanions() → nil */
static int ntop_interface_reload_companions(lua_State* vm) {
  int ifid;
  NetworkInterface* iface;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return CONST_LUA_ERROR;
  ifid = lua_tonumber(vm, 1);

  if ((iface = ntop->getInterfaceById(ifid))) iface->reloadCompanions();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

int ntop_get_alerts(lua_State* vm, AlertableEntity* entity) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  u_int idx = 0;
  ScriptPeriodicity periodicity = no_periodicity;

  if (!entity)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TNUMBER)
    periodicity = (ScriptPeriodicity)lua_tointeger(vm, 1);

  lua_newtable(vm);
  entity->getAlerts(vm, periodicity, alert_none, alert_level_none,
                    alert_role_is_any, &idx);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns alerts matching the given filter criteria for this interface.  Lua: interface.getAlerts(params_table) → table */
static int ntop_interface_get_alerts(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);

  return ntop_get_alerts(vm, c->iface);
}

/* ****************************************** */

/* @brief Stores an externally generated alert into the interface alert store.  Lua: interface.triggerExternalAlert(alert_table) → nil */
static int ntop_interface_store_external_alert(lua_State* vm) {
  AlertEntity entity;
  const char* entity_value;
  const char* key;
  NetworkInterface* iface = getCurrentInterface(vm);
  int idx = 1;

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  entity = (AlertEntity)lua_tointeger(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  entity_value = lua_tostring(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  key = lua_tostring(vm, idx++);

  /* Note: other parameters are not handled here
   * See idx passed to processExternalAlertable -> ntop_store_triggered_alert */

  iface->processExternalAlertable(entity, entity_value, key, vm, idx,
                                  true /* store alert */);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Marks a triggered alert as resolved/released.  Lua: interface.releaseTriggeredAlert(alert_id) → nil */
static int ntop_interface_release_triggered_alert(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);

  return (ntop_release_triggered_alert(vm, c->iface, 1));
}

/* ****************************************** */

/* @brief Marks an external alert as resolved/released.  Lua: interface.releaseExternalAlert(alert_id) → nil */
static int ntop_interface_release_external_alert(lua_State* vm) {
  AlertEntity entity;
  const char* entity_value;
  const char* key;
  NetworkInterface* iface = getCurrentInterface(vm);
  int idx = 1;

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  entity = (AlertEntity)lua_tointeger(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  entity_value = lua_tostring(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  key = lua_tostring(vm, idx++);

  iface->processExternalAlertable(entity, entity_value, key, vm, idx,
                                  false /* release alert */);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns all currently engaged (active/unresolved) alerts for this interface.  Lua: interface.getEngagedAlerts([params_table]) → table */
static int ntop_interface_get_engaged_alerts(lua_State* vm) {
  AlertEntity entity_type = alert_entity_none;
  const char* entity_value = NULL;
  AlertType alert_type = alert_none;
  AlertLevel alert_severity = alert_level_none;
  AlertRole role_filter = alert_role_is_any;
  NetworkInterface* iface = getCurrentInterface(vm);
  AddressTree* allowed_nets = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TNUMBER)
    entity_type = (AlertEntity)lua_tointeger(vm, 1);
  if (lua_type(vm, 2) == LUA_TSTRING) entity_value = (char*)lua_tostring(vm, 2);
  if (lua_type(vm, 3) == LUA_TNUMBER)
    alert_type = (AlertType)lua_tointeger(vm, 3);
  if (lua_type(vm, 4) == LUA_TNUMBER)
    alert_severity = (AlertLevel)lua_tointeger(vm, 4);
  if (lua_type(vm, 5) == LUA_TNUMBER)
    role_filter = (AlertRole)lua_tointeger(vm, 5);

  iface->getEngagedAlerts(vm, entity_type, entity_value, alert_type,
                          alert_severity, role_filter, allowed_nets);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Increments a named syslog processing statistics counter.  Lua: interface.incSyslogStats(stat_name, n) → nil */
static int ntop_interface_inc_syslog_stats(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  u_int32_t num_received_events;
  u_int32_t num_malformed;
  u_int32_t num_unhandled;
  u_int32_t num_alerts;
  u_int32_t num_host_correlations;
  u_int32_t num_collected_flows;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  num_received_events = lua_tonumber(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  num_malformed = lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  num_unhandled = lua_tonumber(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  num_alerts = lua_tonumber(vm, 4);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  num_host_correlations = lua_tonumber(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  num_collected_flows = lua_tonumber(vm, 6);

  iface->incSyslogStats(0, num_malformed, num_received_events, num_unhandled,
                        num_alerts, num_host_correlations, num_collected_flows);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Executes a SQL write statement on the interface alert database. Lua: interface.alert_store_write(query[,ifid]) → boolean */
static int ntop_interface_alert_store_write(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  char* query = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Query */
  if (lua_type(vm, 1) == LUA_TSTRING) query = (char*)lua_tostring(vm, 1);

  /* Optional: interface id */
  if (lua_type(vm, 2) == LUA_TNUMBER) {
    int ifid = lua_tointeger(vm, 2);

    iface = ntop->getInterfaceById(ifid);
  }

  if (!iface || !query) {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (ntop->getPrefs()->are_alerts_disabled()) {
    lua_pushboolean(vm, true);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }

  lua_pushboolean(vm, iface->alert_store_write(query));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Executes a raw SQL query on the interface alert database and streams JSON to HTTP response.  Lua: interface.alert_store_query(query[,limit_rows]) → nil */
static int ntop_interface_alert_store_query(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  char* query = NULL;
  bool limit_rows = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Query */
  if (lua_type(vm, 1) == LUA_TSTRING) query = (char*)lua_tostring(vm, 1);

  /* Optional: interface id */
  if (lua_type(vm, 2) == LUA_TNUMBER) {
    int ifid = lua_tointeger(vm, 2);

    iface = ntop->getInterfaceById(ifid);
  }

  /* Optional: limit rows  */
  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    limit_rows = lua_toboolean(vm, 3) ? true : false;

  if (!iface || !query)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop->getPrefs()->are_alerts_disabled())
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  iface->alert_store_query(vm, query, limit_rows);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_TWO_RETURN_VALUES));
}

/* ****************************************** */

#ifndef HAVE_NEDGE
/* @brief Injects a flow record from ZMQ/sFlow into the interface for processing (non-nEdge).  Lua: interface.processFlow(flow_table) → nil */
static int ntop_process_flow(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) != LUA_TTABLE)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (!dynamic_cast<ParserInterface*>(curr_iface))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TTABLE) {
    ParserInterface* ntop_parser_interface =
        dynamic_cast<ParserInterface*>(curr_iface);
    ParsedFlow flow;
    flow.fromLua(vm, 1);
    ntop_parser_interface->processFlow(&flow);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Reloads syslog producer configuration for this interface (non-nEdge).  Lua: interface.updateSyslogProducers() → nil */
static int ntop_update_syslog_producers(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  SyslogParserInterface* syslog_parser_interface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  syslog_parser_interface = dynamic_cast<SyslogParserInterface*>(curr_iface);
  if (!syslog_parser_interface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  syslog_parser_interface->updateProducersMapping();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns descriptions of all ZMQ flow template fields (non-nEdge).  Lua: interface.getAllZMQFlowFieldDescr() → table */
static int ntop_get_all_zmq_flow_field_descr(lua_State* vm) {
#ifdef HAVE_ZMQ
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ZMQParserInterface* zmq_curr_iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface ||
      !(zmq_curr_iface = dynamic_cast<ZMQParserInterface*>(curr_iface)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  zmq_curr_iface->luaGetAllKeyDescription(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
#else
  return (-1);
#endif
}

/* ****************************************** */

/* @brief Returns description of a specific ZMQ flow field (non-nEdge).  Lua: interface.getZMQFlowFieldDescr(field_id) → table */
static int ntop_get_zmq_flow_field_descr(lua_State* vm) {
#ifdef HAVE_ZMQ
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ZMQParserInterface* zmq_curr_iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface ||
      !(zmq_curr_iface = dynamic_cast<ZMQParserInterface*>(curr_iface)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  char* key = (char*)lua_tostring(vm, 1);
  u_int32_t pen = UNKNOWN_PEN, field = UNKNOWN_FLOW_ELEMENT;
  const char* descr;

  if (zmq_curr_iface->getKeyId((char*)key, strlen(key), &pen, &field) &&
      (descr = zmq_curr_iface->getKeyDescription(pen, field)))
    lua_pushstring(vm, descr);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
#else
  return (-1);
#endif
}
#endif

/* ****************************************** */

/* @brief Returns configuration and member counts for all host pools on this interface.  Lua: interface.getHostPoolsInfo() → table */
static int ntop_get_host_pools_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (curr_iface && curr_iface->getHostPools()) {
    lua_newtable(vm);
    curr_iface->getHostPools()->lua(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/**
 * @brief Get the Host Pool statistics of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
/* @brief Returns traffic statistics for all host pools on this interface.  Lua: interface.getHostPoolsStats() → table */
static int ntop_get_host_pools_interface_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getHostPools()) {
    curr_iface->luaHostPoolsStats(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/**
 * @brief Get the Host Pool statistics for a pool of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
/* @brief Returns traffic statistics for a specific host pool.  Lua: interface.getHostPoolStats(pool_id) → table */
static int ntop_get_host_pool_interface_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  HostPools* hp;
  u_int64_t pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  pool_id = (u_int16_t)lua_tonumber(vm, 1);

  if (curr_iface && (hp = curr_iface->getHostPools())) {
    lua_newtable(vm);
    hp->luaStats(vm, pool_id);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

#ifdef HAVE_NEDGE

/**
 * @brief Get the Host statistics corresponding to the amount of host quotas
 * used
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
/* @brief Returns quota usage statistics for a specific host (nEdge Pro).  Lua: interface.getHostUsedQuotasStats(host, vlan) → table */
static int ntop_get_host_used_quotas_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  Host* h;
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[128];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((!curr_iface))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if ((h = curr_iface->getHost(host_ip, vlan_id,
                               getLuaVMUservalue(vm, observationPointId),
                               false /* Not an inline call */)))
    h->luaUsedQuotas(vm);
  else
    lua_newtable(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

#endif

/* ****************************************** */

/* @brief Returns per-protocol flow count statistics for this interface.  Lua: interface.getnDPIFlowsCount() → table */
static int ntop_get_ndpi_interface_flows_count(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) {
    lua_newtable(vm);
    curr_iface->getnDPIFlowsCount(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns flow status distribution (normal, warning, alert) for this interface.  Lua: interface.getFlowsStatus() → table */
static int ntop_get_ndpi_interface_flows_status(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) {
    lua_newtable(vm);
    curr_iface->getFlowsStatus(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the human-readable name for an nDPI protocol ID.  Lua: interface.getnDPIProtoName(proto_id) → string */
static int ntop_get_ndpi_protocol_name(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  proto = (int)lua_tonumber(vm, 1);

  if (proto == HOST_FAMILY_ID)
    lua_pushstring(vm, "Host-to-Host Contact");
  else {
    if (curr_iface)
      lua_pushstring(vm, curr_iface->get_ndpi_proto_name(proto));
    else
      lua_pushnil(vm);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the full hierarchical name (e.g. 'HTTP.Facebook') for an nDPI protocol.  Lua: interface.getnDPIFullProtoName(proto_id) → string */
static int ntop_get_ndpi_full_protocol_name(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ndpi_protocol proto;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  proto.proto.master_protocol = (u_int32_t)lua_tonumber(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  proto.proto.app_protocol = (u_int32_t)lua_tonumber(vm, 2);

  if (curr_iface)
    lua_pushstring(
        vm, curr_iface->get_ndpi_full_proto_name(proto, buf, sizeof(buf)));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the nDPI protocol ID for a given protocol name string.  Lua: interface.getnDPIProtoId(proto_name) → integer */
static int ntop_get_ndpi_protocol_id(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  char* proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  proto = (char*)lua_tostring(vm, 1);

  if (curr_iface && proto)
    lua_pushinteger(vm, curr_iface->get_ndpi_proto_id(proto));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the nDPI category ID for a given category name string.  Lua: interface.getnDPICategoryId(category_name) → integer */
static int ntop_get_ndpi_category_id(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  char* category;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  category = (char*)lua_tostring(vm, 1);

  if (curr_iface && category)
    lua_pushinteger(vm, curr_iface->get_ndpi_category_id(category));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the human-readable name for an nDPI category ID.  Lua: interface.getnDPICategoryName(category_id) → string */
static int ntop_get_ndpi_category_name(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  ndpi_protocol_category_t category;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  category = (ndpi_protocol_category_t)((int)lua_tonumber(vm, 1));

  if (curr_iface)
    lua_pushstring(vm, curr_iface->get_ndpi_category_name(category));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/**
 * @brief Same as ntop_get_ndpi_protocol_name() with the exception that the
 * protocol breed is returned
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if curr_iface is null, CONST_LUA_OK otherwise.
 */
/* @brief Returns the nDPI breed (e.g. 'Safe', 'Unsafe') for a protocol.  Lua: interface.getnDPIProtoBreed(proto_id) → string */
static int ntop_get_ndpi_protocol_breed(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  proto = (u_int32_t)lua_tonumber(vm, 1);

  if (proto == HOST_FAMILY_ID)
    lua_pushstring(vm, "Unrated-to-Host Contact");
  else {
    if (curr_iface)
      lua_pushstring(vm, curr_iface->get_ndpi_proto_breed_name(proto));
    else
      lua_pushnil(vm);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* This function is used by lua/rest/v2/charts/host/map.lua */

/* @brief Returns all hosts active on this interface as a flat array.  Lua: interface.getInterfaceHosts([include_details]) → table */
static int ntop_get_interface_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  HostWalkMode host_walk_mode = ALL_FLOWS;
  u_int32_t maxHits = CONST_MAX_NUM_HITS;
  bool localHostsOnly = true, treeMapMode = false;
  int32_t networkIdFilter = -1 /* All networks */;

  if (lua_type(vm, 1) == LUA_TNUMBER)
    host_walk_mode = (HostWalkMode)lua_tonumber(vm, 1);
  if (lua_type(vm, 2) == LUA_TNUMBER) maxHits = (u_int32_t)lua_tonumber(vm, 2);
  if (lua_type(vm, 3) == LUA_TNUMBER)
    networkIdFilter = (int32_t)lua_tonumber(vm, 3);
  if (lua_type(vm, 4) == LUA_TBOOLEAN)
    localHostsOnly = lua_toboolean(vm, 4) ? true : false;
  if (lua_type(vm, 5) == LUA_TBOOLEAN)
    treeMapMode = lua_toboolean(vm, 5) ? true : false;

  if ((curr_iface != NULL) &&
      (curr_iface->walkActiveHosts(vm, host_walk_mode, maxHits, networkIdFilter,
                                   localHostsOnly, treeMapMode) >= 0))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Internal helper implementing batched host enumeration with pagination.  Lua: (internal batched helper) → table */
static int ntop_get_batched_interface_hosts(lua_State* vm,
                                            LocationPolicy location,
                                            bool tsLua = false,
                                            bool get_checkpoint_only = false) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool show_details = true, filtered_hosts = false, blacklisted_hosts = false;
  char *sortColumn = (char*)"column_ip", *country = NULL, *mac_filter = NULL;
  ndpi_os os_filter = ndpi_os_MAX_OS;
  bool a2zSortOrder = true;
  u_int16_t vlan_filter = (u_int16_t)-1;
  u_int32_t asn_filter = (u_int32_t)-1;
  int32_t network_filter = -2;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t ipver_filter = 0;
  int proto_filter = -1;
  TrafficType traffic_type_filter = traffic_type_all;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int32_t begin_slot = 0;
  bool walk_all = false;
  bool anomalousOnly = false;
  bool dhcpOnly = false;
  bool alertedHost = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNUMBER)
    begin_slot = (u_int32_t)lua_tonumber(vm, 1);
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    show_details = lua_toboolean(vm, 2) ? true : false;
  if (lua_type(vm, 3) == LUA_TNUMBER) maxHits = (u_int32_t)lua_tonumber(vm, 3);
  if (lua_type(vm, 4) == LUA_TBOOLEAN) anomalousOnly = lua_toboolean(vm, 4);
  /* If parameter 5 is true, the caller wants to iterate all hosts, including
     those with unidirectional traffic. If parameter 5 is false, then the caller
     only wants host withs bidirectional traffic */
  if (lua_type(vm, 5) == LUA_TBOOLEAN)
    traffic_type_filter =
        lua_toboolean(vm, 5) ? traffic_type_all : traffic_type_bidirectional;
  if (lua_type(vm, 6) == LUA_TBOOLEAN) alertedHost = lua_toboolean(vm, 6);

  if ((!curr_iface) ||
      curr_iface->getActiveHostsList(
          vm, &begin_slot, walk_all,
          0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
          get_allowed_nets(vm), show_details, location, country, mac_filter,
          vlan_filter, os_filter, asn_filter, network_filter, pool_filter,
          filtered_hosts, blacklisted_hosts, ipver_filter, proto_filter,
          traffic_type_filter, 0 /* probe ip */,
          tsLua /* host->tsLua | host->lua */, anomalousOnly, dhcpOnly,
          NULL /* cidr filter */, alertedHost, sortColumn, maxHits, toSkip,
          a2zSortOrder, false, get_checkpoint_only) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static u_int8_t str_2_location(const char* s) {
  if (!strcmp(s, "lan"))
    return located_on_lan_interface;
  else if (!strcmp(s, "wan"))
    return located_on_wan_interface;
  else if (!strcmp(s, "unknown"))
    return located_on_unknown_interface;
  return (u_int8_t)-1;
}

/* ****************************************** */

/* @brief Internal helper implementing host filtering by various criteria.  Lua: (internal criteria helper) → table */
static int ntop_get_interface_hosts_criteria(lua_State* vm,
                                             LocationPolicy location) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool show_details = true, filtered_hosts = false, blacklisted_hosts = false;
  char *sortColumn = (char*)"column_ip", *country = NULL, *mac_filter = NULL;
  bool a2zSortOrder = true;
  ndpi_os os_filter = ndpi_os_MAX_OS;
  u_int16_t vlan_filter = (u_int16_t)-1;
  u_int32_t asn_filter = (u_int32_t)-1;
  int32_t network_filter = -2;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t ipver_filter = 0;
  TrafficType traffic_type_filter = traffic_type_all;
  int proto_filter = -1;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  struct ndpi_in6_addr device_ip;
  u_int32_t begin_slot = 0;
  u_int8_t location_filter = (u_int8_t)-1;
  bool walk_all = true;
  bool anomalousOnly = false;
  bool dhcpOnly = false, cidr_filter_enabled = false;
  bool alertedHost = false;
  AddressTree cidr_filter;
  bool arrayFormat = false;
  char* map_search = NULL;
  u_int64_t label_filter = (u_int64_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  memset(&device_ip, 0, sizeof(struct ndpi_in6_addr));
  
  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    show_details = lua_toboolean(vm, 1) ? true : false;
  if (lua_type(vm, 2) == LUA_TSTRING) sortColumn = (char*)lua_tostring(vm, 2);
  if (lua_type(vm, 3) == LUA_TNUMBER) maxHits = (u_int32_t)lua_tonumber(vm, 3);
  if (lua_type(vm, 4) == LUA_TNUMBER) toSkip = (u_int32_t)lua_tonumber(vm, 4);
  if (lua_type(vm, 5) == LUA_TBOOLEAN)
    a2zSortOrder = lua_toboolean(vm, 5) ? true : false;
  if (lua_type(vm, 6) == LUA_TSTRING) country = (char*)lua_tostring(vm, 6);
  if (lua_type(vm, 7) == LUA_TNUMBER) os_filter = (ndpi_os)lua_tointeger(vm, 7);
  if (lua_type(vm, 8) == LUA_TNUMBER)
    vlan_filter = (u_int16_t)lua_tonumber(vm, 8);
  if (lua_type(vm, 9) == LUA_TNUMBER)
    asn_filter = (u_int32_t)lua_tonumber(vm, 9);
  if (lua_type(vm, 10) == LUA_TNUMBER)
    network_filter = (int32_t)lua_tonumber(vm, 10);
  if (lua_type(vm, 11) == LUA_TSTRING) mac_filter = (char*)lua_tostring(vm, 11);
  if (lua_type(vm, 12) == LUA_TNUMBER)
    pool_filter = (u_int16_t)lua_tonumber(vm, 12);
  if (lua_type(vm, 13) == LUA_TNUMBER)
    ipver_filter = (u_int8_t)lua_tonumber(vm, 13);
  if (lua_type(vm, 14) == LUA_TNUMBER) proto_filter = (int)lua_tonumber(vm, 14);
  if (lua_type(vm, 15) == LUA_TNUMBER)
    traffic_type_filter = (TrafficType)lua_tointeger(vm, 15);
  if (lua_type(vm, 16) == LUA_TBOOLEAN) filtered_hosts = lua_toboolean(vm, 16);
  if (lua_type(vm, 17) == LUA_TBOOLEAN)
    blacklisted_hosts = lua_toboolean(vm, 17);
  if (lua_type(vm, 18) == LUA_TBOOLEAN) anomalousOnly = lua_toboolean(vm, 18);
  if (lua_type(vm, 19) == LUA_TBOOLEAN) dhcpOnly = lua_toboolean(vm, 19);
  if (lua_type(vm, 20) == LUA_TSTRING)
    cidr_filter.addAddress(lua_tostring(vm, 20)), cidr_filter_enabled = true;
  if (lua_type(vm, 21) == LUA_TSTRING) Utils::parseIPv4v6Address(lua_tostring(vm, 21), &device_ip);								
  if (lua_type(vm, 22) == LUA_TBOOLEAN) arrayFormat = (lua_toboolean(vm, 22));
  if (lua_type(vm, 23) == LUA_TBOOLEAN) alertedHost = lua_toboolean(vm, 23);
  if (lua_type(vm, 24) == LUA_TSTRING)
    location_filter = str_2_location(lua_tostring(vm, 24));
  if (lua_type(vm, 25) == LUA_TSTRING) map_search = (char*)lua_tostring(vm, 25);
  if (lua_type(vm, 26) == LUA_TNUMBER)
    label_filter = (u_int64_t)1 << (u_int8_t)lua_tointeger(vm, 26);

  if ((!curr_iface) ||
      curr_iface->getActiveHostsList(
          vm, &begin_slot, walk_all,
          0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
          get_allowed_nets(vm), show_details, location, country, mac_filter,
          vlan_filter, os_filter, asn_filter, network_filter, pool_filter,
          filtered_hosts, blacklisted_hosts, ipver_filter, proto_filter,
          traffic_type_filter, &device_ip, false /* host->lua */, anomalousOnly,
          dhcpOnly, cidr_filter_enabled ? &cidr_filter : NULL, alertedHost,
          sortColumn, maxHits, toSkip, a2zSortOrder, arrayFormat, false,
          location_filter, map_search, label_filter) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* Receives in input a Lua table, having mac address as keys and tables as
 * values. Every IP address found for a mac is inserted into the table as an
 * 'ip' field. */
/* @brief Forces re-association of MAC addresses with their known IP addresses.  Lua: interface.addMacsIpAddresses() → nil */
static int ntop_add_macs_ip_addresses(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TTABLE) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((!curr_iface) || curr_iface->getMacsIpAddresses(vm, 1) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns currently active MAC addresses on the interface.  Lua: interface.getActiveMacs([vlan_id]) → table */
static int ntop_get_interface_active_macs(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    curr_iface->getActiveMacs(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Returns detailed information for MAC addresses on the interface.  Lua: interface.getMacsInfo([params]) → table */
static int ntop_get_interface_macs_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* sortColumn = (char*)"column_mac";
  const char* manufacturer = NULL;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t devtype_filter = (u_int8_t)-1;
  bool a2zSortOrder = true, sourceMacsOnly = false;
  u_int8_t location_filter = (u_int8_t)-1;
  u_int32_t begin_slot = 0;
  time_t min_first_seen = 0;
  bool walk_all = true;
  const char* map_search = NULL;

  if (lua_type(vm, 1) == LUA_TSTRING) sortColumn = (char*)lua_tostring(vm, 1);
  if (lua_type(vm, 2) == LUA_TNUMBER) maxHits = (u_int16_t)lua_tonumber(vm, 2);
  if (lua_type(vm, 3) == LUA_TNUMBER) toSkip = (u_int16_t)lua_tonumber(vm, 3);
  if (lua_type(vm, 4) == LUA_TBOOLEAN) a2zSortOrder = lua_toboolean(vm, 4);
  if (lua_type(vm, 5) == LUA_TBOOLEAN) sourceMacsOnly = lua_toboolean(vm, 5);
  if (lua_type(vm, 6) == LUA_TSTRING) manufacturer = lua_tostring(vm, 6);
  if (lua_type(vm, 7) == LUA_TNUMBER)
    pool_filter = (u_int16_t)lua_tonumber(vm, 7);
  if (lua_type(vm, 8) == LUA_TNUMBER)
    devtype_filter = (u_int8_t)lua_tonumber(vm, 8);
  if (lua_type(vm, 9) == LUA_TSTRING)
    location_filter = str_2_location(lua_tostring(vm, 9));
  if (lua_type(vm, 10) == LUA_TNUMBER) min_first_seen = lua_tonumber(vm, 10);
  if (lua_type(vm, 11) == LUA_TSTRING) map_search = lua_tostring(vm, 11);

  if (!curr_iface ||
      curr_iface->getActiveMacList(
          vm, &begin_slot, walk_all,
          0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
          sourceMacsOnly, manufacturer, sortColumn, maxHits, toSkip,
          a2zSortOrder, pool_filter, devtype_filter, location_filter,
          min_first_seen, map_search) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a paginated batch of MAC address records.  Lua: interface.getBatchedMacsInfo(cursor, count) → table */
static int ntop_get_batched_interface_macs_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* sortColumn = (char*)"column_mac";
  const char* manufacturer = NULL;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t devtype_filter = (u_int8_t)-1;
  bool a2zSortOrder = true, sourceMacsOnly = false;
  u_int8_t location_filter = (u_int8_t)-1;
  time_t min_first_seen = 0;
  u_int32_t begin_slot = 0;
  bool walk_all = false;

  if (lua_type(vm, 1) == LUA_TNUMBER)
    begin_slot = (u_int16_t)lua_tonumber(vm, 1);

  if (!curr_iface ||
      curr_iface->getActiveMacList(
          vm, &begin_slot, walk_all,
          0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
          sourceMacsOnly, manufacturer, sortColumn, maxHits, toSkip,
          a2zSortOrder, pool_filter, devtype_filter, location_filter,
          min_first_seen) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the given MAC address is currently active.  Lua: interface.isMacActive(mac) → boolean */
static int ntop_is_mac_active(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  mac = (char*)lua_tostring(vm, 1);

  lua_pushboolean(vm, curr_iface->isMacActive(mac));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns detailed information for a specific MAC address.  Lua: interface.getMacInfo(mac) → table */
static int ntop_get_interface_mac_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac = NULL;

  if (lua_type(vm, 1) == LUA_TSTRING) mac = (char*)lua_tostring(vm, 1);

  if ((!curr_iface) || (!mac) || (!curr_iface->getMacInfo(vm, mac)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

#ifdef HAVE_NEDGE
/* @brief Appends a captive-portal event (login/logout) for a MAC address (nEdge).  Lua: interface.appendMacEvent(mac, event_type) → nil */
static int ntop_append_mac_event(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char *mac, *event_message;
  u_int32_t _mac[6];

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    mac = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    event_message = (char*)lua_tostring(vm, 2);

  if ((!curr_iface) || (!mac) || (!event_message) ||
      (!sscanf(mac, "%02X:%02X:%02X:%02X:%02X:%02X", &_mac[0], &_mac[1],
               &_mac[2], &_mac[3], &_mac[4], &_mac[5])))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    Mac* m;
    u_int8_t maca[6];

    for (int i = 0; i < 6; i++) maca[i] = (u_int8_t)_mac[i];

    m = curr_iface->getMac(maca, false /* create_if_not_present */,
                           false /* is_inline_call*/);

    if (!m)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    else
      m->logMacEvent(event_message);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}
#endif

/* ****************************************** */

/* @brief Returns all hosts associated with a given MAC address.  Lua: interface.getMacHosts(mac) → table */
static int ntop_get_interface_mac_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac = NULL;
  bool verbose = false;

  if (lua_type(vm, 1) == LUA_TSTRING) mac = (char*)lua_tostring(vm, 1);
  if (lua_type(vm, 2) == LUA_TBOOLEAN) verbose = (bool)lua_toboolean(vm, 2);

  lua_newtable(vm);

  if (curr_iface) curr_iface->getActiveMacHosts(vm, mac, verbose);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Overrides the detected operating system for a host.  Lua: interface.setHostOperatingSystem(host, vlan, os_id) → nil */
static int ntop_set_host_operating_system(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char *host_ip = NULL, buf[64];
  u_int16_t vlan_id = 0;
  ndpi_os os = ndpi_os_unknown;
  Host* host;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  os = (ndpi_os)lua_tointeger(vm, 2);

  host = curr_iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                  getLuaVMUservalue(vm, observationPointId));

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[iface: %s][host_ip: %s][vlan_id: %u][host: %p][os: %u]",
			       curr_iface->get_name(), host_ip, vlan_id, host, os);
#endif

  if (curr_iface && host && (os < ndpi_os_MAX_OS) && (os != ndpi_os_unknown))
    host->setOS(os, os_learning_user_set_via_lua);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Sets the resolved DNS name for a host.  Lua: interface.setHostResolvedName(host, vlan, name) → nil */
static int ntop_set_host_resolved_name(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char *host_ip = NULL, buf[64];
  u_int16_t vlan_id = 0;
  char* host_name = NULL;
  Host* host;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  host_name = (char*)lua_tostring(vm, 2);

  host = curr_iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                  getLuaVMUservalue(vm, observationPointId));

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[iface: %s][host_ip: %s][vlan_id: %u][host: %p][os: %u]",
			       curr_iface->get_name(), host_ip, vlan_id, host, os);
#endif

  if (curr_iface && host && host_name) host->setResolvedName(host_name);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the count of currently active local hosts.  Lua: interface.getNumLocalHosts() → integer */
static int ntop_get_num_local_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushinteger(vm, curr_iface->getNumLocalHosts());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the count of local hosts seen only in receive direction.  Lua: interface.getNumLocalRxOnlyHosts() → integer */
static int ntop_get_num_local_rxonly_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushinteger(vm, curr_iface->getNumLocalRxOnlyHosts());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the total count of active hosts (local + remote).  Lua: interface.getNumHosts() → integer */
static int ntop_get_num_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushinteger(vm, curr_iface->getNumHosts());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the total count of active flows on this interface.  Lua: interface.getNumFlows() → integer */
static int ntop_get_num_flows(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushinteger(vm, curr_iface->getNumFlows());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a mapping of MAC device type IDs to their names and counts.  Lua: interface.getMacDeviceTypes() → table */
static int ntop_get_mac_device_types(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t maxHits = CONST_MAX_NUM_HITS;
  bool sourceMacsOnly = false;
  char* manufacturer = NULL;
  u_int8_t location_filter = (u_int8_t)-1;

  if (lua_type(vm, 1) == LUA_TNUMBER) maxHits = (u_int16_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    sourceMacsOnly = lua_toboolean(vm, 2) ? true : false;

  if (lua_type(vm, 3) == LUA_TSTRING) manufacturer = (char*)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    location_filter = str_2_location(lua_tostring(vm, 4));

  if ((!curr_iface) || (curr_iface->getActiveDeviceTypes(
                            vm, sourceMacsOnly, 0 /* bridge_iface_idx - TODO */,
                            maxHits, manufacturer, location_filter) < 0))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns statistics for all Autonomous Systems observed on this interface.  Lua: interface.getASesInfo([params]) → table */
static int ntop_get_interface_ases_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool diff = false;
  ASType as_type = all;
  Paginator* p = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TTABLE) p->readOptions(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 2) ? true : false;

  if (lua_type(vm, 3) == LUA_TNUMBER) as_type = (ASType)lua_tointeger(vm, 3);

  if (curr_iface->getActiveASList(vm, p, diff, as_type) < 0) {
    if (p) delete (p);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (p) delete (p);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns statistics for all Autonomous Systems observed on this interface.  Lua: interface.getASesInfo([params]) → table */
static int ntop_get_interface_as_list(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->getASList(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns statistics for all observation points seen on this interface.  Lua: interface.getObsPointsInfo([params]) → table */
static int ntop_get_interface_obs_points_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  Paginator* p = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TTABLE) p->readOptions(vm, 1);

  if (curr_iface->getActiveObsPointsList(vm, p) < 0) {
    if (p) delete (p);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (p) delete (p);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Inserts an IP CIDR rule into the interface ACL (allow or block).  Lua: interface.insertIPACL(cidr, is_allow) → nil */
static int ntop_interface_insert_ip_acl(lua_State* vm) {
  bool res = false;
#ifdef NTOPNG_PRO
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int8_t protocol = 0;
  u_int16_t l7_proto = 0;
  bool is_allowed = true;
  char *src, *dst, *port = NULL;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  protocol = (u_int8_t)lua_tointeger(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  src = (char*)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  dst = (char*)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING) port = (char*)lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TNUMBER)
    l7_proto = (u_int16_t)lua_tointeger(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  is_allowed = (bool)lua_toboolean(vm, 6);

  if (curr_iface)
    res =
        curr_iface->insertIPACL(protocol, src, dst, port, l7_proto, is_allowed);
#endif
  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Removes an IP CIDR rule from the interface ACL.  Lua: interface.removeIPACL(cidr) → nil */
static int ntop_interface_remove_ip_acl(lua_State* vm) {
  bool res = false;

#ifdef NTOPNG_PRO
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int8_t protocol = 0;
  u_int16_t l7_proto = 0;
  char *src, *dst, *port = NULL;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  protocol = (u_int8_t)lua_tointeger(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  src = (char*)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  dst = (char*)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING) port = (char*)lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TNUMBER)
    l7_proto = (u_int16_t)lua_tointeger(vm, 5);

  if (curr_iface)
    res = curr_iface->removeIPACL(protocol, src, dst, port, l7_proto);
#endif

  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Inserts a MAC address rule into the interface ACL (allow or block).  Lua: interface.insertMacACL(mac, is_allow) → nil */
static int ntop_interface_insert_mac_acl(lua_State* vm) {
  bool res = false;
#ifdef NTOPNG_PRO
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac_string;
  u_int32_t _mac[6];
  bool is_allowed = true;
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  mac_string = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN) is_allowed = (bool)lua_toboolean(vm, 2);

  if (sscanf(mac_string, "%02X:%02X:%02X:%02X:%02X:%02X", &_mac[0], &_mac[1],
             &_mac[2], &_mac[3], &_mac[4], &_mac[5])) {
    u_int8_t mac[6];
    for (int i = 0; i < 6; i++) mac[i] = (u_int8_t)_mac[i];
    if (curr_iface) res = curr_iface->insertMacACL(mac, is_allowed);
  }
#endif
  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Removes a MAC address rule from the interface ACL.  Lua: interface.removeMacACL(mac) → nil */
static int ntop_interface_remove_mac_acl(lua_State* vm) {
  bool res = false;
#ifdef NTOPNG_PRO
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac_string;
  u_int32_t _mac[6];
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  mac_string = (char*)lua_tostring(vm, 1);

  if (sscanf(mac_string, "%02X:%02X:%02X:%02X:%02X:%02X", &_mac[0], &_mac[1],
             &_mac[2], &_mac[3], &_mac[4], &_mac[5])) {
    u_int8_t mac[6];
    for (int i = 0; i < 6; i++) mac[i] = (u_int8_t)_mac[i];
    if (curr_iface) res = curr_iface->removeMacACL(mac);
  }
#endif
  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the current IP and MAC ACL rules for this interface.  Lua: interface.getACLInfo() → table */
static int ntop_interface_get_acl_info(lua_State* vm) {
  lua_newtable(vm);
#ifdef NTOPNG_PRO
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  if (curr_iface) {
    curr_iface->getACLInfo(vm);
  }
#endif
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns current throughput (bps/pps) in both directions for this interface.  Lua: interface.getThroughput() → table */
static int ntop_interface_get_throughput(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_push_float_table_entry(vm, "throughput_bps",
                             curr_iface->getThroughputBps());
  lua_push_float_table_entry(vm, "throughput_pps",
                             curr_iface->getThroughputPps());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns per-L4-protocol flow and byte statistics.  Lua: interface.getProtocolFlowsStats() → table */
static int ntop_get_protocol_flows_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->getFilteredLiveFlowsStats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns per-VLAN flow and byte statistics.  Lua: interface.getVLANFlowsStats() → table */
static int ntop_get_vlan_flows_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->getVLANFlowsStats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a list of server ports used by hosts on this interface.  Lua: interface.getHostsPorts(params) → table */
static int ntop_get_hosts_ports(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->getHostsPorts(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns hosts using the specified server port and transport protocol.  Lua: interface.getHostsByPort(port, proto) → table */
static int ntop_get_hosts_by_port(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->getHostsByPort(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* Function used to start the accounting of an Host */
/* @brief Sends a RADIUS Accounting-Start packet for a captive-portal session.  Lua: interface.radiusAccountingStart(params) → nil */
static int ntop_radius_accounting_start(lua_State* vm) {
  bool res = false;

#ifdef HAVE_RADIUS
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  RadiusTraffic traffic_data;

  memset(&traffic_data, 0, sizeof(traffic_data));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TSTRING)
    traffic_data.username = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING)
    traffic_data.mac = (char*)lua_tostring(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING)
    traffic_data.session_id = (char*)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    traffic_data.last_ip = (char*)lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TSTRING)
    traffic_data.time = (u_int32_t)lua_tonumber(vm, 5);

  traffic_data.nas_port_name = curr_iface->get_name();
  traffic_data.nas_port_id = curr_iface->get_id();

  res = ntop->radiusAccountingStart(&traffic_data);
#endif

  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Sends a RADIUS Accounting-Stop packet for a captive-portal session.  Lua: interface.radiusAccountingStop(params) → nil */
static int ntop_radius_accounting_stop(lua_State* vm) {
  bool res = false;

#ifdef HAVE_RADIUS
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  RadiusTraffic traffic_data;

  memset(&traffic_data, 0, sizeof(traffic_data));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TSTRING)
    traffic_data.username = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING)
    traffic_data.session_id = (char*)lua_tostring(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING)
    traffic_data.mac = (char*)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    traffic_data.last_ip = (char*)lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TNUMBER)
    traffic_data.bytes_sent = (u_int32_t)lua_tonumber(vm, 5);

  if (lua_type(vm, 6) == LUA_TNUMBER)
    traffic_data.bytes_rcvd = (u_int32_t)lua_tonumber(vm, 6);

  if (lua_type(vm, 7) == LUA_TNUMBER)
    traffic_data.packets_sent = (u_int32_t)lua_tonumber(vm, 7);

  if (lua_type(vm, 8) == LUA_TNUMBER)
    traffic_data.packets_rcvd = (u_int32_t)lua_tonumber(vm, 8);

  if (lua_type(vm, 9) == LUA_TNUMBER)
    traffic_data.terminate_cause = (u_int32_t)lua_tonumber(vm, 9);

  if (lua_type(vm, 10) == LUA_TNUMBER)
    traffic_data.time = (u_int32_t)lua_tonumber(vm, 10);

  traffic_data.nas_port_name = curr_iface->get_name();
  traffic_data.nas_port_id = curr_iface->get_id();

  /* First reset the stats then start the accounting */
  curr_iface->resetMacStats(vm, traffic_data.mac, false);
  res = ntop->radiusAccountingStop(&traffic_data);

#endif

  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns hosts using a specific application service.  Lua: interface.getHostsByService(service_name) → table */
static int ntop_get_hosts_by_service(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->getHostsByService(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Sends a RADIUS Accounting-Update (Interim-Update) for an active session.  Lua: interface.radiusAccountingUpdate(params) → nil */
static int ntop_radius_accounting_update(lua_State* vm) {
  bool res = false;
#ifdef HAVE_RADIUS
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  RadiusTraffic traffic_data;

  memset(&traffic_data, 0, sizeof(traffic_data));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TSTRING)
    traffic_data.mac = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING)
    traffic_data.session_id = (char*)lua_tostring(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING)
    traffic_data.username = (char*)lua_tostring(vm, 3);

  /* Unused
     if (lua_type(vm, 4) == LUA_TSTRING)
     password = (const char *)lua_tostring(vm, 4);
  */

  if (lua_type(vm, 5) == LUA_TSTRING)
    traffic_data.last_ip = (char*)lua_tostring(vm, 5);

  if (lua_type(vm, 6) == LUA_TNUMBER)
    traffic_data.bytes_sent = (u_int32_t)lua_tonumber(vm, 6);

  if (lua_type(vm, 7) == LUA_TNUMBER)
    traffic_data.bytes_rcvd = (u_int32_t)lua_tonumber(vm, 7);

  if (lua_type(vm, 8) == LUA_TNUMBER)
    traffic_data.packets_sent = (u_int32_t)lua_tonumber(vm, 8);

  if (lua_type(vm, 9) == LUA_TNUMBER)
    traffic_data.packets_rcvd = (u_int32_t)lua_tonumber(vm, 9);

  if (lua_type(vm, 10) == LUA_TNUMBER)
    traffic_data.time = (u_int32_t)lua_tonumber(vm, 10);

  traffic_data.nas_port_name = curr_iface->get_name();
  traffic_data.nas_port_id = curr_iface->get_id();

  res = ntop->radiusAccountingUpdate(&traffic_data);
#endif

  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a table of currently active behavioral anomalies on this interface.  Lua: interface.getAnomalies() → table */
static int ntop_get_interface_anomalies(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->luaAnomalies(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns per-protocol byte/flow statistics, optionally filtered to a host.  Lua: interface.getnDPIStats([host,vlan]) → table */
static int ntop_get_ndpi_interface_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool diff = false;

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 4) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 1) ? true : false;

  curr_iface->luaNdpiStats(vm, diff);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the current alert score breakdown for this interface.  Lua: interface.getScore() → table */
static int ntop_get_interface_score(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->luaScore(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns per-country traffic statistics observed on this interface.  Lua: interface.getCountriesInfo([params]) → table */
static int ntop_get_interface_countries_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  Paginator* p = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TTABLE) p->readOptions(vm, 1);

  if (curr_iface->getActiveCountriesList(vm, p) < 0) {
    if (p) delete (p);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (p) delete (p);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Converts a 2-letter ISO country code string to a 16-bit integer.  Lua: interface.convertCountryCode2U16(code) → integer */
static int ntop_convert_country_code_to_u16(lua_State* vm) {
  const char* country_code;
  u_int16_t country_u16;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  country_code = lua_tostring(vm, 1);

  country_u16 = Utils::countryCode2U16(country_code);
  lua_pushinteger(vm, country_u16);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Converts a 16-bit country integer back to its ISO country code string.  Lua: interface.convertCountryU162Code(n) → string */
static int ntop_convert_country_u16_to_code(lua_State* vm) {
  char country_code[3];
  u_int16_t country_u16;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  country_u16 = lua_tonumber(vm, 1);

  lua_pushstring(vm, Utils::countryU162Code(country_u16, country_code,
                                            sizeof(country_code)));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns traffic statistics for a specific country on this interface.  Lua: interface.getCountryInfo(country_code) → table */
static int ntop_get_interface_country_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  const char* country;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  country = lua_tostring(vm, 1);

  if ((!curr_iface) || (!curr_iface->getCountryInfo(vm, country)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a list of VLAN IDs seen on this interface.  Lua: interface.getVLANsList() → table */
static int ntop_get_interface_vlans_list(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if ((!curr_iface) || curr_iface->getActiveVLANList(
                           vm, (char*)"column_vlan", CONST_MAX_NUM_HITS, 0,
                           true, details_normal /* Minimum details */) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns per-VLAN traffic statistics for this interface.  Lua: interface.getVLANsInfo([params]) → table */
static int ntop_get_interface_vlans_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* sortColumn = (char*)"column_vlan";
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  bool a2zSortOrder = true;
  DetailsLevel details_level = details_higher;

  if (lua_type(vm, 1) == LUA_TSTRING) {
    sortColumn = (char*)lua_tostring(vm, 1);

    if (lua_type(vm, 2) == LUA_TNUMBER) {
      maxHits = (u_int16_t)lua_tonumber(vm, 2);

      if (lua_type(vm, 3) == LUA_TNUMBER) {
        toSkip = (u_int16_t)lua_tonumber(vm, 3);

        if (lua_type(vm, 4) == LUA_TBOOLEAN) {
          a2zSortOrder = lua_toboolean(vm, 4) ? true : false;

          if (lua_type(vm, 5) == LUA_TBOOLEAN) {
            details_level =
                lua_toboolean(vm, 4) ? details_higher : details_high;
          }
        }
      }
    }
  }

  if (!curr_iface ||
      curr_iface->getActiveVLANList(vm, sortColumn, maxHits, toSkip,
                                    a2zSortOrder, details_level) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns traffic statistics for a specific Autonomous System number.  Lua: interface.getASInfo(asn) → table */
static int ntop_get_interface_as_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int32_t asn;
  DetailsLevel details_level = details_higher;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  asn = (u_int32_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN) {
    details_level = lua_toboolean(vm, 2) ? details_normal : details_higher;
  }

  if ((!curr_iface) || (!curr_iface->getASInfo(vm, asn, details_level)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns statistics for a specific observation point.  Lua: interface.getObsPointInfo(obs_point_id) → table */
static int ntop_get_interface_obs_point_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t obs_point;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  obs_point = (u_int16_t)lua_tonumber(vm, 1);

  if ((!curr_iface) || (!curr_iface->getObsPointInfo(vm, obs_point)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns traffic statistics for a specific VLAN.  Lua: interface.getVLANInfo(vlan_id) → table */
static int ntop_get_interface_vlan_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t vlan_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  vlan_id = (u_int16_t)lua_tonumber(vm, 1);

  if ((!curr_iface) || (!curr_iface->getVLANInfo(vm, vlan_id)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a grouped count of MAC addresses by their OUI manufacturer.  Lua: interface.getMacManufacturers([params]) → table */
static int ntop_get_interface_macs_manufacturers(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int32_t maxHits = CONST_MAX_NUM_HITS;
  u_int8_t devtype_filter = (u_int8_t)-1;
  bool sourceMacsOnly = false;
  u_int8_t location_filter = (u_int8_t)-1;

  if (lua_type(vm, 1) == LUA_TNUMBER) maxHits = (u_int16_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    sourceMacsOnly = lua_toboolean(vm, 2) ? true : false;

  if (lua_type(vm, 3) == LUA_TNUMBER)
    devtype_filter = (u_int8_t)lua_tonumber(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    location_filter = str_2_location(lua_tostring(vm, 4));

  if (!curr_iface ||
      curr_iface->getActiveMacManufacturers(
          vm, 0, /* bridge_iface_idx - TODO */
          sourceMacsOnly, maxHits, devtype_filter, location_filter) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns detailed information for all active flows on the interface.  Lua: interface.getFlowsInfo([params_table]) → table */
static int ntop_get_interface_flows_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  Host *host = NULL, *talking_with_host = NULL, *client = NULL, *server = NULL;
  char *host_ip = NULL, *talking_with_ip = NULL, *server_ip = NULL,
       *client_ip = NULL, *search = NULL, *flow_info = NULL;
  char buf[64];
  u_int16_t vlan_id = (u_int16_t)-1;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  Paginator* p = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                       sizeof(buf));
    host = curr_iface->getHost(host_ip, vlan_id,
                               getLuaVMUservalue(vm, observationPointId),
                               false /* Not an inline call */);
  }

  if (lua_type(vm, 2) == LUA_TTABLE) p->readOptions(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 3), &talking_with_ip, &vlan_id,
                       buf, sizeof(buf));
    talking_with_host = curr_iface->getHost(
        talking_with_ip, vlan_id, getLuaVMUservalue(vm, observationPointId),
        false /* Not an inline call */);
  }

  if (lua_type(vm, 4) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 4), &client_ip, &vlan_id, buf,
                       sizeof(buf));
    client = curr_iface->getHost(client_ip, vlan_id,
                                 getLuaVMUservalue(vm, observationPointId),
                                 false /* Not an inline call */);
  }

  if (lua_type(vm, 5) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 5), &server_ip, &vlan_id, buf,
                       sizeof(buf));
    server = curr_iface->getHost(server_ip, vlan_id,
                                 getLuaVMUservalue(vm, observationPointId),
                                 false /* Not an inline call */);
  }

  if (lua_type(vm, 6) == LUA_TSTRING) {
    char* tmp = ((char*)lua_tostring(vm, 6));
    if (strlen(tmp) > 0) flow_info = tmp;
  }

  if (lua_type(vm, 7) == LUA_TSTRING) {
    /* Search parameter, only correct if not empty */
    char* tmp = ((char*)lua_tostring(vm, 7));
    if (tmp && strlen(tmp) > 0) search = tmp;
  }

  if ((curr_iface) && (!host_ip || host))
    curr_iface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm), host,
                         talking_with_host, client, server, flow_info, p,
                         search);
  else
    lua_pushnil(vm);

  if (p) delete p;
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a paginated batch of active flow records.  Lua: interface.getBatchedFlowsInfo(cursor, count[,filter]) → table */
static int ntop_get_batched_interface_flows_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  Paginator* p = NULL;
  u_int32_t begin_slot = 0;
  bool walk_all = false;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNUMBER)
    begin_slot = (u_int32_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) == LUA_TTABLE) p->readOptions(vm, 2);

  if (curr_iface)
    curr_iface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm), NULL,
                         NULL, NULL, NULL, NULL, p);
  else
    lua_pushnil(vm);

  if (p) delete p;
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns flows aggregated (grouped) by a specified key field.  Lua: interface.getGroupedFlows(params_table) → table */
static int ntop_get_interface_get_grouped_flows(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  Paginator* p = NULL;
  const char* group_col;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK ||
      (p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  group_col = lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TTABLE) p->readOptions(vm, 2);

  if (curr_iface)
    curr_iface->getFlowsGroup(vm, get_allowed_nets(vm), p, group_col);
  else
    lua_pushnil(vm);

  delete p;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns aggregate flow statistics counts for the interface.  Lua: interface.getFlowsStats() → table */
static int ntop_get_interface_flows_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) curr_iface->getFlowsStats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns per-local-network traffic statistics.  Lua: interface.getNetworksStats() → table */
static int ntop_get_interface_networks_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool diff = false;
  bool fullStats = false;

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 1) ? true : false;

  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    fullStats = lua_toboolean(vm, 2) ? true : false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface)
    curr_iface->getNetworksStats(vm, get_allowed_nets(vm), diff, fullStats);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns server ports observed on local hosts for a given L4 protocol.  Lua: interface.getLocalServerPorts(proto) → table */
static int ntop_get_local_server_ports(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    curr_iface->localHostsServerPorts(vm);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns traffic statistics for a specific local network by ID.  Lua: interface.getNetworkStats(network_id) → table */
static int ntop_get_interface_network_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int32_t network_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  network_id = (u_int32_t)lua_tointeger(vm, 1);

  if (curr_iface) {
    lua_newtable(vm);
    curr_iface->getNetworkStats(vm, network_id, get_allowed_nets(vm));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the specified host is currently active on this interface.  Lua: interface.isHostActive(host[,vlan]) → boolean */
static int ntop_is_host_active(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  lua_pushboolean(
      vm, curr_iface->isHostActive(get_allowed_nets(vm), host_ip, vlan_id));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns comprehensive information for a specific host.  Lua: interface.getHostInfo(host[,vlan]) → table */
static int ntop_get_interface_host_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if ((!curr_iface) ||
      !curr_iface->getHostInfo(vm, get_allowed_nets(vm), host_ip, vlan_id))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Resets the top-sites statistics for a specific host.  Lua: interface.resetHostTopSites(host, vlan) → nil */
static int ntop_reset_interface_host_top_sites(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if ((!curr_iface) ||
      !curr_iface->resetHostTopSites(get_allowed_nets(vm), host_ip, vlan_id,
                                     getLuaVMUservalue(vm, observationPointId)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the 2-letter country code for a host's IP via GeoIP.  Lua: interface.getHostCountry(host[,vlan]) → string */
static int ntop_get_interface_host_country(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  Host* h = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if ((!curr_iface) ||
      ((h = curr_iface->findHostByIP(
            get_allowed_nets(vm), host_ip, vlan_id,
            getLuaVMUservalue(vm, observationPointId))) == NULL))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    lua_pushstring(vm, h->get_country(buf, sizeof(buf)));
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Marks an observation point for deletion (first step of two-step delete).  Lua: interface.prepareDeleteObsPoint(obs_point_id) → nil */
static int ntop_prepare_delete_interface_observation_point(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t obs_point_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  obs_point_id = ((u_int16_t)lua_tonumber(vm, 1));

  if ((!curr_iface) || !(curr_iface->prepareDeleteObsPoint(obs_point_id)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Completes deletion of a previously prepared observation point.  Lua: interface.deleteObsPoint(obs_point_id) → nil */
static int ntop_delete_interface_observation_point(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t obs_point_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  obs_point_id = ((u_int16_t)lua_tonumber(vm, 1));

  if ((!curr_iface) || !(curr_iface->deleteObsPoint(obs_point_id)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

#ifdef NTOPNG_PRO
/* @brief Returns flow exporters (NetFlow/IPFIX probes) seen on this interface (Pro).  Lua: interface.getFlowDevices() → table */
static int ntop_get_flow_devices(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  ;
  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    curr_iface->getFlowDevices(vm);

    /* Return a table with key, the interface id and as value,
     * a table with the IPs of the interface
     */
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Returns detailed information for a specific flow-exporting device (Pro).  Lua: interface.getFlowDeviceInfo(device_ip) → table */
static int ntop_get_flow_device_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int32_t device_id;
  bool showAllStats = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  device_id = (u_int32_t)lua_tonumber(vm, 1);
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    showAllStats = (bool)lua_toboolean(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    curr_iface->getFlowDeviceInfo(vm, device_id, showAllStats);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Returns flow device information looked up by IP address (Pro).  Lua: interface.getFlowDeviceInfoByIP(ip) → table */
static int ntop_get_flow_device_info_by_ip(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* device_ip;
  bool showAllStats = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  device_ip = (char*)lua_tostring(vm, 1);
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    showAllStats = (bool)lua_toboolean(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    struct ndpi_in6_addr addr;

    if (!Utils::parseIPv4v6Address(device_ip, &addr))
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

    curr_iface->getFlowDeviceInfoByIP(vm, &addr, showAllStats);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}
#endif

/* ****************************************** */

/* @brief Triggers active host discovery (ping sweep) on the interface.  Lua: interface.discoverHosts(timeout_ms) → table */
static int ntop_discover_iface_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int timeout = 3; /* sec */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TNUMBER) timeout = (u_int)lua_tonumber(vm, 1);

  if (curr_iface->getNetworkDiscovery()) {
    /* TODO: do it periodically and not inline */

    try {
      curr_iface->getNetworkDiscovery()->discover(vm, timeout);
    } catch (...) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to perform network discovery");
    }

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Triggers ARP scan discovery of hosts on the interface.  Lua: interface.arpScanHosts() → table */
static int ntop_arpscan_iface_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (curr_iface->getMDNS()) {
    /* This is a device we can use for network discovery */

    try {
      NetworkDiscovery* d;

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && \
    !defined(HAVE_NEDGE)
      if (Utils::gainWriteCapabilities() == -1)
        ntop->getTrace()->traceEvent(TRACE_ERROR,
                                     "Unable to enable capabilities");
#endif

      d = curr_iface->getNetworkDiscovery();

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && \
    !defined(HAVE_NEDGE)
      Utils::dropWriteCapabilities();
#endif

      if (d) d->arpScan(vm);
    } catch (...) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to perform network scan");
#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && \
    !defined(HAVE_NEDGE)
      Utils::dropWriteCapabilities();
#endif
    }

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Queues an mDNS ANY query for a service type for background resolution.  Lua: interface.mdnsQueueAnyQuery(service_type) → nil */
static int ntop_mdns_batch_any_query(lua_State* vm) {
  char *query, *target;
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((target = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((query = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->mdnsSendAnyQuery(target, query);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Queues an mDNS/Bonjour name resolution request.  Lua: interface.mdnsQueueNameToResolve(name) → nil */
static int ntop_mdns_queue_name_to_resolve(lua_State* vm) {
  char* numIP;
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((numIP = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->mdnsQueueResolveIPv4(inet_addr(numIP), true);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Reads and returns pending mDNS resolution results.  Lua: interface.mdnsReadQueuedResponses() → table */
static int ntop_mdns_read_queued_responses(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->mdnsFetchResolveResponses(vm, 2);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns sFlow agent devices seen on this interface.  Lua: interface.getSFlowDevices() → table */
static int ntop_getsflowdevices(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    curr_iface->getSFlowDevices(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Returns per-port statistics for a specific sFlow agent.  Lua: interface.getSFlowDeviceInfo(agent_ip) → table */
static int ntop_getsflowdeviceinfo(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* device_ip;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  device_ip = (char*)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    in_addr_t addr = inet_addr(device_ip);

    curr_iface->getSFlowDeviceInfo(vm, ntohl(addr));
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Computes the hash key for a flow 5-tuple.  Lua: interface.getFlowKey(src_ip, src_port, dst_ip, dst_port, proto[,vlan]) → integer */
static int ntop_get_interface_flow_key(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  Host *cli, *srv;
  char* cli_name = NULL;
  u_int16_t cli_port = 0;
  char* srv_name = NULL;
  u_int16_t srv_port = 0;
  u_int16_t cli_vlan = 0, srv_vlan = 0;
  u_int16_t protocol;
  char cli_buf[256], srv_buf[256];

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) !=
       CONST_LUA_OK) /* cli_host@cli_vlan */
      || (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) !=
          CONST_LUA_OK) /* cli port          */
      || (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) !=
          CONST_LUA_OK) /* srv_host@srv_vlan */
      || (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) !=
          CONST_LUA_OK) /* srv port          */
      || (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) !=
          CONST_LUA_OK) /* protocol          */
  )
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  get_host_vlan_info((char*)lua_tostring(vm, 1), &cli_name, &cli_vlan, cli_buf,
                     sizeof(cli_buf));
  cli_port = htons((u_int16_t)lua_tonumber(vm, 2));

  get_host_vlan_info((char*)lua_tostring(vm, 3), &srv_name, &srv_vlan, srv_buf,
                     sizeof(srv_buf));
  srv_port = htons((u_int16_t)lua_tonumber(vm, 4));

  protocol = (u_int16_t)lua_tonumber(vm, 5);

  if (cli_vlan != srv_vlan) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Client and Server vlans don't match.");
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (cli_name == NULL || srv_name == NULL ||
      (cli = curr_iface->getHost(cli_name, cli_vlan,
                                 getLuaVMUservalue(vm, observationPointId),
                                 false /* Not an inline call */)) == NULL ||
      (srv = curr_iface->getHost(srv_name, srv_vlan,
                                 getLuaVMUservalue(vm, observationPointId),
                                 false /* Not an inline call */)) == NULL) {
    lua_pushnil(vm);
  } else
    lua_pushinteger(
        vm, Flow::key(cli, cli_port, srv, srv_port, cli_vlan,
                      getLuaVMUservalue(vm, observationPointId), protocol));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Finds and returns an active flow by its hash key and bucket ID.  Lua: interface.findFlowByKeyAndHashId(key, hash_id) → table */
static int ntop_get_interface_find_flow_by_key_and_hash_id(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int32_t key;
  u_int hash_id;
  Flow* f;
  AddressTree* ptree = get_allowed_nets(vm);
  bool set_context = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  /* Optional: set context */
  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    set_context = lua_toboolean(vm, 3) ? true : false;

  key = (u_int32_t)lua_tonumber(vm, 1);
  hash_id = (u_int)lua_tonumber(vm, 2);

  if (!curr_iface) return (false);

  f = curr_iface->findFlowByKeyAndHashId(key, hash_id, ptree);

  if (f == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    f->lua(vm, ptree, details_high, false);

    if (set_context) {
      NtopngLuaContext* c = getLuaVMContext(vm);

      c->flow = f, c->iface = f->getInterface();
    }

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Finds and returns an active flow by its 5-tuple.  Lua: interface.findFlowByTuple(src_ip, src_port, dst_ip, dst_port, proto[,vlan]) → table */
static int ntop_get_interface_find_flow_by_tuple(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  IpAddress src_ip_addr, dst_ip_addr;
  u_int16_t vlan_id, src_port, dst_port;
  u_int8_t l4_proto;
  u_int32_t private_flow_id = 0 /* FIX */;
  char *src_ip, *dst_ip;
  Flow* f;
  AddressTree* ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) return (false);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  src_ip = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  dst_ip = (char*)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  vlan_id = (u_int16_t)lua_tonumber(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  src_port = (u_int16_t)lua_tonumber(vm, 4);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  dst_port = (u_int16_t)lua_tonumber(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  l4_proto = (u_int8_t)lua_tonumber(vm, 6);

  src_ip_addr.set(src_ip), dst_ip_addr.set(dst_ip);

  f = curr_iface->findFlowByTuple(vlan_id,
                                  getLuaVMUservalue(vm, observationPointId),
                                  private_flow_id, NULL, NULL, /* TODO MAC */
                                  &src_ip_addr, &dst_ip_addr, htons(src_port),
                                  htons(dst_port), l4_proto, ptree);

  if (f == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    f->lua(vm, ptree, details_high, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

#ifdef HAVE_NEDGE

/* Set policy to drop for the specified flow */
/* @brief Marks a specific flow for traffic dropping (nEdge inline mode).  Lua: interface.dropFlowTraffic(key, hash_id) → nil */
static int ntop_drop_flow_traffic(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int32_t key;
  u_int hash_id;
  Flow* f;
  AddressTree* ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  key = (u_int32_t)lua_tonumber(vm, 1);
  hash_id = (u_int)lua_tonumber(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  f = curr_iface->findFlowByKeyAndHashId(key, hash_id, ptree);

  if (f) {
    f->setDropVerdict(DROP_REASON_USER_ACTION);
    lua_pushboolean(vm, true);
  } else
    lua_pushboolean(vm, false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/*
  Drops all flows where the specified IP is either client or server,
  and return the flow number
*/
/* @brief Marks all traffic for a host for dropping (nEdge inline mode).  Lua: interface.dropHostTraffic(host, vlan) → nil */
static int ntop_drop_host_traffic(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  AddressTree* ptree = get_allowed_nets(vm);
  char* host;
  u_int32_t num_dropped_flows;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    host = (char*)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  num_dropped_flows = curr_iface->dropHostTraffic(host, ptree);
  // if(num_dropped_flows > 0)  iface->setPolicyChanged();

  lua_pushinteger(vm, num_dropped_flows);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Drops traffic for multiple flows at once (nEdge inline mode).  Lua: interface.dropMultipleFlowsTraffic(flows_table) → nil */
static int ntop_drop_multiple_flows_traffic(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  Paginator* p = NULL;
  AddressTree* ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TTABLE))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  p->readOptions(vm, 1);

  if (curr_iface->dropFlowsTraffic(ptree, p) < 0)
    lua_pushboolean(vm, false);
  else
    lua_pushboolean(vm, true);

  if (p) delete p;
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

#endif

/* ****************************************** */

/* @brief Returns active flows associated with a specific process ID (eBPF).  Lua: interface.findPidFlows(pid) → table */
static int ntop_get_interface_find_pid_flows(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int32_t pid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  pid = (u_int32_t)lua_tonumber(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->findPidFlows(vm, pid);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns active flows associated with a process name (eBPF).  Lua: interface.findNameFlows(proc_name) → table */
static int ntop_get_interface_find_proc_name_flows(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* proc_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  proc_name = (char*)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->findProcNameFlows(vm, proc_name);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a list of hosts with active HTTP/HTTPS flows.  Lua: interface.listHTTPhosts([filter]) → table */
static int ntop_list_http_hosts(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) != LUA_TSTRING) /* Optional */
    key = NULL;
  else
    key = (char*)lua_tostring(vm, 1);

  curr_iface->listHTTPHosts(vm, key);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Finds a host by IP or name and returns its info, or nil if not active.  Lua: interface.findHost(host[,vlan]) → table */
static int ntop_get_interface_find_host(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  key = (char*)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->findHostsByName(vm, get_allowed_nets(vm), key);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Finds a host by its MAC address and returns its info.  Lua: interface.findHostByMac(mac) → table */
static int ntop_get_interface_find_host_by_mac(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac;
  u_int8_t _mac[6];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  mac = (char*)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  Utils::parseMac(_mac, mac);

  curr_iface->findHostsByMac(vm, _mac);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if the given MAC address is a multicast/broadcast address.  Lua: interface.isMulticastMac(mac) → boolean */
static int ntop_is_multicast_mac(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* mac;
  u_int8_t _mac[6];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  mac = (char*)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  Utils::parseMac(_mac, mac);

  lua_pushboolean(vm, Utils::isMulticastMac(_mac));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Updates the traffic-mirrored flag for the interface.  Lua: interface.updateTrafficMirrored(enabled) → nil */
static int ntop_update_traffic_mirrored(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateTrafficMirrored();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Updates the smart-recording setting for the interface.  Lua: interface.updateSmartRecording(enabled) → nil */
static int ntop_update_smart_recording(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateSmartRecording();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Updates the dynamic traffic policy for this interface.  Lua: interface.updateDynIfaceTrafficPolicy(policy) → nil */
static int ntop_update_dynamic_interface_traffic_policy(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateDynIfaceTrafficPolicy();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Updates push-filter settings (e.g. BPF rules) for the interface.  Lua: interface.updatePushFiltersSettings(params) → nil */
static int ntop_update_push_filters_settings(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updatePushFiltersSettings();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Updates the local broadcast domain host identifier (IP vs MAC).  Lua: interface.updateLbdIdentifier(use_mac) → nil */
static int ntop_update_lbd_identifier(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateLbdIdentifier();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Sets the flows-only flag (no host tracking) on the interface.  Lua: interface.updateFlowsOnlyInterface(enabled) → nil */
static int ntop_update_flows_only_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateFlowsOnlyInterface();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Forces a traffic policy refresh for a specific host.  Lua: interface.updateHostTrafficPolicy(host, vlan) → nil */
static int ntop_update_host_traffic_policy(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (!curr_iface) return CONST_LUA_ERROR;

  lua_pushboolean(vm, curr_iface->updateHostTrafficPolicy(get_allowed_nets(vm),
                                                          host_ip, vlan_id));
  return CONST_LUA_OK;
}

/* ****************************************** */

// *** API ***
/* @brief Returns the capture endpoint/source string (e.g. 'eth0', 'tcp://...').  Lua: interface.getEndpoint() → string */
static int ntop_get_interface_endpoint(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int8_t id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) != LUA_TNUMBER) /* Optional */
    id = 0;
  else
    id = (u_int8_t)lua_tonumber(vm, 1);

  if (curr_iface) {
    char* endpoint = curr_iface->getEndpoint(id); /* CHECK */

    lua_pushfstring(vm, "%s", endpoint ? endpoint : "");
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns all nDPI protocol IDs and names, optionally filtered by category.  Lua: interface.getnDPIProtocols([category_id]) → table */
static int ntop_get_ndpi_protocols(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ndpi_protocol_category_t category_filter = NDPI_PROTOCOL_ANY_CATEGORY;
  bool skip_critical = false;

  if (curr_iface == NULL) curr_iface = getCurrentInterface(vm);

  if (curr_iface == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((lua_type(vm, 1) == LUA_TNUMBER)) {
    category_filter = (ndpi_protocol_category_t)lua_tointeger(vm, 1);

    if (category_filter >= NDPI_PROTOCOL_NUM_CATEGORIES) {
      lua_pushnil(vm);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
    }
  }
  if ((lua_type(vm, 2) == LUA_TBOOLEAN)) skip_critical = lua_toboolean(vm, 2);

  curr_iface->getnDPIProtocols(vm, category_filter, skip_critical);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns all nDPI category IDs and their names.  Lua: interface.getnDPICategories() → table */
static int ntop_get_ndpi_categories(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }

  lua_newtable(vm);

  for (int i = 0; i < NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
    char buf[8];
    const char* cat_name =
        curr_iface->get_ndpi_category_name((ndpi_protocol_category_t)i);

    if (cat_name && *cat_name) {
      snprintf(buf, sizeof(buf), "%d", i);
      lua_push_str_table_entry(vm, cat_name, buf);
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Reloads interface throughput scaling factor preferences from Redis.  Lua: interface.loadScalingFactorPrefs() → nil */
static int ntop_load_scaling_factor_prefs(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  curr_iface->loadScalingFactorPrefs();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Reloads the list of known gateway MAC addresses from Redis.  Lua: interface.reloadGwMacs() → nil */
static int ntop_reload_gw_macs(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  curr_iface->requestGwMacsReload();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Reloads DHCP address ranges from Redis configuration.  Lua: interface.reloadDhcpRanges() → nil */
static int ntop_reload_dhcp_ranges(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  curr_iface->reloadDhcpRanges();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Reloads per-host preference overrides from Redis for a specific host.  Lua: interface.reloadHostPrefs(host[,vlan]) → nil */
static int ntop_reload_host_prefs(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char buf[64], *host_ip;
  Host* host;
  u_int16_t vlan_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if ((host = curr_iface->getHost(host_ip, vlan_id,
                                  getLuaVMUservalue(vm, observationPointId),
                                  false /* Not an inline call */)))
    host->reloadPrefs();

  lua_pushboolean(vm, (host != NULL));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static void* pcapDumpLoop(void* ptr) {
  NtopngLuaContext* c = (NtopngLuaContext*)ptr;
  char name[16];

  snprintf(name, sizeof(name), "pcap-dump");
  ntop->registerThread(name, pthread_self());

  while (c->pkt_capture.captureInProgress) {
    u_char* pkt;
    struct pcap_pkthdr* h;
    int rc = pcap_next_ex(c->pkt_capture.pd, &h, (const u_char**)&pkt);

    if (rc > 0) {
      pcap_dump((u_char*)c->pkt_capture.dumper, (const struct pcap_pkthdr*)h,
                pkt);

      if (h->ts.tv_sec > (time_t)c->pkt_capture.end_capture) break;
    } else if (rc < 0) {
      break;
    } else if (rc == 0) {
      if (time(NULL) > (time_t)c->pkt_capture.end_capture) break;
    }
  } /* while */

  if (c->pkt_capture.dumper) {
    pcap_dump_close(c->pkt_capture.dumper);
    c->pkt_capture.dumper = NULL;
  }

  if (c->pkt_capture.pd) {
    pcap_close(c->pkt_capture.pd);
    c->pkt_capture.pd = NULL;
  }

  c->pkt_capture.captureInProgress = false;

  return (NULL);
}

/* ****************************************** */

/* @brief Starts a PCAP file capture session with BPF filter and duration.  Lua: interface.captureToPcap(params_table) → nil */
static int ntop_capture_to_pcap(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int8_t capture_duration;
  char *bpfFilter = NULL, ftemplate[64];
  char errbuf[PCAP_ERRBUF_SIZE];
  struct bpf_program fcode;
  NtopngLuaContext* c;
  int rc;

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (c->pkt_capture.pd != NULL /* Another capture is in progress */)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  capture_duration = (u_int32_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) != LUA_TSTRING) /* Optional */
    bpfFilter = (char*)lua_tostring(vm, 2);

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
  if (Utils::gainWriteCapabilities() == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

  if ((c->pkt_capture.pd = pcap_open_live(curr_iface->get_name(), 1514,
                                          0 /* promisc */, 500, errbuf)) ==
      NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to open %s for capture: %s",
                                 curr_iface->get_name(), errbuf);
#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
    Utils::dropWriteCapabilities();
#endif

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  if (bpfFilter != NULL) {
    if (pcap_compile(c->pkt_capture.pd, &fcode, bpfFilter, 1, 0xFFFFFF00) < 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "pcap_compile error: '%s'",
                                   pcap_geterr(c->pkt_capture.pd));
    } else {
      rc = pcap_setfilter(c->pkt_capture.pd, &fcode);

      pcap_freecode(&fcode);

      if (rc < 0)
        ntop->getTrace()->traceEvent(TRACE_WARNING,
                                     "pcap_setfilter error: '%s'",
                                     pcap_geterr(c->pkt_capture.pd));
    }
  }

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
  Utils::dropWriteCapabilities();
#endif

  snprintf(ftemplate, sizeof(ftemplate), "/tmp/ntopng_%s_%u.pcap",
           curr_iface->get_name(), (unsigned int)time(NULL));
  c->pkt_capture.dumper =
      pcap_dump_open(pcap_open_dead(DLT_EN10MB, 1514 /* MTU */), ftemplate);

  if (c->pkt_capture.dumper == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to create dump file %s\n", ftemplate);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }

  /* Capture sessions can't be longer than 30 sec */
  if (capture_duration > 30) capture_duration = 30;

  c->pkt_capture.end_capture = time(NULL) + capture_duration;

  c->pkt_capture.captureInProgress = true;
  pthread_create(&c->pkt_capture.captureThreadLoop, NULL, pcapDumpLoop,
                 (void*)c);

  lua_pushstring(vm, ftemplate);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if a PCAP file capture session is currently active.  Lua: interface.isCaptureRunning() → boolean */
static int ntop_is_capture_running(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  NtopngLuaContext* c;

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushboolean(
      vm, (c->pkt_capture.pd != NULL /* Another capture is in progress */)
              ? true
              : false);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Stops the currently running PCAP file capture session.  Lua: interface.stopRunningCapture() → nil */
static int ntop_stop_running_capture(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  NtopngLuaContext* c;

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  c->pkt_capture.end_capture = 0;

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns information for all hosts (local + remote) on the interface.  Lua: interface.getHostsInfo([params]) → table */
static int ntop_get_interface_hosts_info(lua_State* vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_all));
}

/* @brief Returns information for local hosts only.  Lua: interface.getLocalHostsInfo([params]) → table */
static int ntop_get_interface_local_hosts_info(lua_State* vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_local_only));
}

/* @brief Returns local hosts that have received but not sent any traffic.  Lua: interface.getLocalHostsInfoNoTX([params]) → table */
static int ntop_get_interface_local_hosts_no_tx_info(lua_State* vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_local_only_no_tx));
}

/* @brief Returns local hosts that have not sent any TCP traffic.  Lua: interface.getLocalHostsInfoNoTXTCP([params]) → table */
static int ntop_get_interface_local_hosts_no_tcp_tx_info(lua_State* vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_local_only_no_tcp_tx));
}

/* @brief Returns information for remote (non-local) hosts only.  Lua: interface.getRemoteHostsInfo([params]) → table */
static int ntop_get_interface_remote_hosts_info(lua_State* vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_remote_only));
}

/* @brief Returns remote hosts that have received but not sent any traffic.  Lua: interface.getRemoteHostsInfoNoTX([params]) → table */
static int ntop_get_interface_remote_hosts_no_tx_info(lua_State* vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_remote_only_no_tx));
}

/* @brief Returns remote hosts that have not sent any TCP traffic.  Lua: interface.getRemoteHostsInfoNoTXTCP([params]) → table */
static int ntop_get_interface_remote_hosts_no_tcp_tx_info(lua_State* vm) {
  return (
      ntop_get_interface_hosts_criteria(vm, location_remote_only_no_tcp_tx));
}

/* @brief Returns hosts that are part of broadcast domains on this interface.  Lua: interface.getBroadcastDomainHostsInfo([params]) → table */
static int ntop_get_interface_broadcast_domain_hosts_info(lua_State* vm) {
  return (
      ntop_get_interface_hosts_criteria(vm, location_broadcast_domain_only));
}

/* @brief Returns broadcast/multicast group hosts on this interface.  Lua: interface.getBroadcastMulticastHostsInfo([params]) → table */
static int ntop_get_interface_broadcast_multicast_hosts_info(lua_State* vm) {
  return (
      ntop_get_interface_hosts_criteria(vm, location_broadcat_multicast_only));
}

/* @brief Returns hosts with public (routable) IP addresses.  Lua: interface.getPublicHostsInfo([params]) → table */
static int ntop_get_public_hosts_info(lua_State* vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_public_only));
}

/* ****************************************** */

/* @brief Returns hosts that have only been seen in the receive direction.  Lua: interface.getRxOnlyHostsList() → table */
static int ntop_get_rxonly_hosts_list(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool local_host_rx_only = false, list_host_peers = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    local_host_rx_only = lua_toboolean(vm, 1) ? true : false;
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    list_host_peers = lua_toboolean(vm, 2) ? true : false;

  curr_iface->getRxOnlyHostsList(vm, local_host_rx_only, list_host_peers);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a paginated batch of host records for all hosts.  Lua: interface.getBatchedHostsInfo(cursor, count) → table */
static int ntop_get_batched_interface_hosts_info(lua_State* vm) {
  return (ntop_get_batched_interface_hosts(vm, location_all, false, true));
}

/* @brief Returns a paginated batch of local host records.  Lua: interface.getBatchedLocalHostsInfo(cursor, count) → table */
static int ntop_get_batched_interface_local_hosts_info(lua_State* vm) {
  return (
      ntop_get_batched_interface_hosts(vm, location_local_only, false, false));
}

/* @brief Returns a paginated batch of remote host records.  Lua: interface.getBatchedRemoteHostsInfo(cursor, count) → table */
static int ntop_get_batched_interface_remote_hosts_info(lua_State* vm) {
  return (
      ntop_get_batched_interface_hosts(vm, location_remote_only, false, false));
}

/* @brief Returns a paginated batch of local host time-series data.  Lua: interface.getBatchedLocalHostsTs(cursor, count) → table */
static int ntop_get_batched_interface_local_hosts_ts(lua_State* vm) {
  return (ntop_get_batched_interface_hosts(vm, location_local_only,
                                           true /* timeseries */, false));
}

/* ****************************************** */

/* @brief Stores a triggered alert record in the interface alert database.  Lua: interface.storeTriggeredAlert(alert_table) → nil */
static int ntop_interface_store_triggered_alert(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);

  return (ntop_store_triggered_alert(vm, c->iface, 1 /* 1st argument of vm */));
}

/* ****************************************** */

/* @brief Returns comprehensive real-time statistics for the interface.  Lua: interface.getStats() → table */
static int ntop_get_interface_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool full_stats = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    full_stats = lua_toboolean(vm, 1) ? true : false;

  curr_iface->lua(vm, full_stats);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Forces an update of per-direction (upload/download) statistics.  Lua: interface.updateDirectionStats() → nil */
static int ntop_update_interface_direction_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->updateDirectionStats();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Triggers a refresh of the top-sites (popular domains) tracking.  Lua: interface.updateTopSites() → nil */
static int ntop_update_interface_top_sites(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  curr_iface->updateSitesStats();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the statistics update frequency in seconds for this interface.  Lua: interface.getStatsUpdateFreq() → integer */
static int ntop_get_interface_stats_update_freq(lua_State* vm) {
  NetworkInterface* curr_iface = NULL;
  int ifid;

  if (lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    curr_iface = ntop->getInterfaceById(ifid);
  } else
    curr_iface = getCurrentInterface(vm);

  if (curr_iface)
    lua_pushinteger(vm, curr_iface->periodicStatsUpdateFrequency());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns seconds elapsed since the interface first received traffic.  Lua: interface.getSecsToFirstData() → integer */
static int ntop_get_secs_to_first_data(lua_State* vm) {
  NetworkInterface* curr_iface = NULL;
  int ifid;

  if (lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    curr_iface = ntop->getInterfaceById(ifid);
  } else
    curr_iface = getCurrentInterface(vm);

  if (curr_iface) {
    /*
      Compute when the first data is available. Since stats refresh every
      interface_refresh_rate seconds initial data becomes available after 2 *
      interface_refresh_rate as two samples are required for deltas (such as
      throughputs) to be calculated
    */
    u_int32_t secs_to_first_data = 0,
              interface_refresh_rate =
                  curr_iface->periodicStatsUpdateFrequency(),
              secs_since_startup = ntop->getGlobals()->getUptime();

    if (interface_refresh_rate * 2 > secs_since_startup)
      secs_to_first_data = (interface_refresh_rate * 2) - secs_since_startup;

    lua_pushinteger(vm, secs_to_first_data);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns size and usage statistics for the interface hash tables (hosts, flows, etc.).  Lua: interface.getHashTablesStats() → table */
static int ntop_get_interface_hash_tables_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (curr_iface)
    curr_iface->lua_hash_tables_stats(vm);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns timing stats for all periodic scripts on this interface.  Lua: interface.getPeriodicActivitiesStats() → table */
static int ntop_get_interface_periodic_activities_stats(lua_State* vm) {
  NetworkInterface* curr_iface = NULL;
  int ifid;

  if (lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    curr_iface = ntop->getInterfaceById(ifid);
  } else
    curr_iface = getCurrentInterface(vm);

  if (curr_iface)
    curr_iface->lua_periodic_activities_stats(vm);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns enqueue/dequeue statistics for internal interface queues.  Lua: interface.getQueuesStats() → table */
static int ntop_get_interface_queues_stats(lua_State* vm) {
  NetworkInterface* curr_iface = NULL;
  int ifid;

  if (lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    curr_iface = ntop->getInterfaceById(ifid);
  } else
    curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (curr_iface) curr_iface->lua_queues_stats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Updates the completion percentage for a running periodic script.  Lua: interface.setPeriodicActivityProgress(activity, progress_pct) → nil */
static int ntop_set_interface_periodic_activity_progress(lua_State* vm) {
  int progress;
  NtopngLuaContext* ctx = getLuaVMContext(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  progress = (int)lua_tonumber(vm, 1);

  if (ctx && ctx->threaded_activity_stats)
    ctx->threaded_activity_stats->setCurrentProgress(progress);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* This function reads live ASN information from flows
 * by iterating all the currently active flows
 */
/* @brief Returns live (real-time) traffic statistics for a specific ASN.  Lua: interface.getLiveASNStats(asn) → table */
static int ntop_get_live_asn_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ASNStats asn_stats;
  Paginator* p = NULL;

  /* Non mandatory paginator parameter */
  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (lua_type(vm, 1) == LUA_TTABLE) p->readOptions(vm, 1);

  if (curr_iface) {
    curr_iface->getLiveASNStats(&asn_stats, get_allowed_nets(vm), p, vm);
  } else
    lua_pushnil(vm);

  if (p) delete p;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns statistics on currently active flows grouped by various dimensions.  Lua: interface.getActiveFlowsStats([params]) → table */
static int ntop_get_active_flows_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  nDPIStats ndpi_stats;
  FlowStats stats;
  char *host_ip = NULL, *talking_with_ip = NULL, *server_ip = NULL,
       *client_ip = NULL;
  u_int16_t vlan_id = 0;
  char buf[64];
  bool only_traffic_stats = false;
  Host *host = NULL, *talking_with_host = NULL, *client = NULL, *server = NULL;
  char* flow_info = NULL;
  Paginator* p = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  /* Optional host */
  if (lua_type(vm, 1) == LUA_TSTRING) {
    char* tmp = (char*)lua_tostring(vm, 1);
    if (strlen(tmp) > 0) {
      get_host_vlan_info(tmp, &host_ip, &vlan_id, buf, sizeof(buf));
      host = curr_iface->getHost(host_ip, vlan_id,
                                 getLuaVMUservalue(vm, observationPointId),
                                 false /* Not an inline call */);
    }
  }

  if (lua_type(vm, 2) == LUA_TTABLE) p->readOptions(vm, 2);

  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    only_traffic_stats = (bool)lua_toboolean(vm, 3);

  /* Optional talking with host, available only for the host flows */
  if (lua_type(vm, 4) == LUA_TSTRING) {
    char* tmp = (char*)lua_tostring(vm, 4);
    if (strlen(tmp) > 0) {
      get_host_vlan_info(tmp, &talking_with_ip, &vlan_id, buf, sizeof(buf));
      talking_with_host = curr_iface->getHost(
          talking_with_ip, vlan_id, getLuaVMUservalue(vm, observationPointId),
          false /* Not an inline call */);
    }
  }

  if (lua_type(vm, 5) == LUA_TSTRING) {
    char* tmp = (char*)lua_tostring(vm, 5);
    if (strlen(tmp) > 0) {
      get_host_vlan_info(tmp, &client_ip, &vlan_id, buf, sizeof(buf));
      client = curr_iface->getHost(client_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId),
                                   false /* Not an inline call */);
    }
  }

  if (lua_type(vm, 6) == LUA_TSTRING) {
    char* tmp = (char*)lua_tostring(vm, 6);
    if (strlen(tmp) > 0) {
      get_host_vlan_info(tmp, &server_ip, &vlan_id, buf, sizeof(buf));
      server = curr_iface->getHost(server_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId),
                                   false /* Not an inline call */);
    }
  }

  if (lua_type(vm, 7) == LUA_TSTRING) {
    char* tmp = (char*)lua_tostring(vm, 7);
    if (strlen(tmp) > 0) {
      flow_info = tmp;
    }
  }

  if (curr_iface) {
    curr_iface->getActiveFlowsStats(&ndpi_stats, &stats, get_allowed_nets(vm),
                                    host, talking_with_host, client, server,
                                    flow_info, p, vm, only_traffic_stats);
  } else
    lua_pushnil(vm);

  if (p) delete p;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* curl -i -XPOST "http://localhost:8086/write?precision=s&db=ntopng"
 * --data-binary 'profile:traffic,ifid=0,profile=a profile bytes=2506351
 * 1559634840' */
/* @brief Appends time-series data points to the InfluxDB write queue.  Lua: interface.appendInfluxDB(json_points) → nil */
static int ntop_append_influx_db(lua_State* vm) {
  bool rv = false;
  NetworkInterface* curr_iface;

  if ((curr_iface = getCurrentInterface(vm)) &&
      curr_iface->getInfluxDBTSExporter() &&
      curr_iface->getInfluxDBTSExporter()->enqueueData(vm))
    rv = true;

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Enqueues an RRD update for background writing.  Lua: interface.rrd_enqueue(rrd_path, value, step) → nil */
static int ntop_rrd_queue_push(lua_State* vm) {
  bool rv = false;
  NetworkInterface* curr_iface;
  TimeseriesExporter* ts_exporter;

  if ((curr_iface = getCurrentInterface(vm)) &&
      (ts_exporter = curr_iface->getRRDTSExporter())) {
    rv = ts_exporter->enqueueData(vm);
  }

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Dequeues a pending RRD update task.  Lua: interface.rrd_dequeue() → table */
static int ntop_rrd_queue_pop(lua_State* vm) {
  int ifid;
  NetworkInterface* iface;
  TimeseriesExporter* ts_exporter;
  char* ts_point;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ifid = lua_tointeger(vm, 1);

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(ts_exporter = iface->getRRDTSExporter()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ts_point = ts_exporter->dequeueData();

  if (ts_point) {
    lua_pushstring(vm, ts_point);
    free(ts_point);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the number of pending items in the RRD update queue.  Lua: interface.rrd_queue_length() → integer */
static int ntop_rrd_queue_length(lua_State* vm) {
  int ifid;
  NetworkInterface* iface;
  TimeseriesExporter* ts_exporter;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ifid = lua_tointeger(vm, 1);

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(ts_exporter = iface->getRRDTSExporter()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushinteger(vm, ts_exporter->queueLength());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

#ifdef NTOPNG_PRO
#ifdef HAVE_NEDGE
/* NOTE: do no call this directly - use host_pools_utils.resetPoolsQuotas
 * instead */
/* @brief Resets traffic quota counters for all or a specific host pool (nEdge Pro).  Lua: interface.resetPoolsQuotas([pool_id]) → nil */
static int ntop_reset_pools_quotas(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t pool_id_filter = (u_int16_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNUMBER)
    pool_id_filter = (u_int16_t)lua_tonumber(vm, 1);

  if (curr_iface) {
    curr_iface->resetPoolsStats(pool_id_filter);

    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Clears the dynamic blacklist for a host pool (nEdge Pro).  Lua: interface.flushPoolDynamicBlacklist(pool_id) → nil */
static int ntop_flush_pool_dynamic_blacklist(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t pool_id = (u_int16_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  pool_id = (u_int16_t)lua_tonumber(vm, 1);

  if (curr_iface) {
    HostPools* hp = curr_iface->getHostPools();
    AddressTree* at = hp->getDynamicBlacklist(pool_id);

    hp->setDynamicBlacklist(pool_id, new AddressTree());

    if (at != NULL) {
      sleep(1);
      delete at;
    }

    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns blacklist statistics for a host pool (nEdge Pro).  Lua: interface.getPoolDynamicBlacklistStats(pool_id) → table */
static int ntop_get_pool_dynamic_blacklist_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t pool_id = (u_int16_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  pool_id = (u_int16_t)lua_tonumber(vm, 1);

  if (curr_iface) {
    HostPools* hp = curr_iface->getHostPools();
    AddressTree* at = hp->getDynamicBlacklist(pool_id);

    lua_pushinteger(vm, at ? at->getNumAddresses() : 0);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the current dynamic blacklist members for a pool (nEdge Pro).  Lua: interface.getPoolDynamicBlacklistMembers(pool_id) → table */
static int ntop_get_pool_dynamic_blacklist_members(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int16_t pool_id = (u_int16_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  pool_id = (u_int16_t)lua_tonumber(vm, 1);

  if (curr_iface) {
    HostPools* hp = curr_iface->getHostPools();
    AddressTree* at = hp->getDynamicBlacklist(pool_id);

    lua_newtable(vm);
    at->getAddresses(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

#endif /* HAVE_NEDGE */
#endif /* NTOPNG_PRO */

/* ****************************************** */

/* @brief Returns the host pool ID that a host belongs to.  Lua: interface.findMemberPool(host[,vlan]) → integer */
static int ntop_find_member_pool(lua_State* vm) {
  NetworkInterface* curr_iface;
  char* address;
  u_int16_t vlan_id = 0;
  bool is_mac;
  ndpi_patricia_node_t* target_node = NULL;
  u_int16_t pool_id = 0;
  bool pool_found;
  char buf[64];

  /* Note: pools are global, selecting the current interface prvents
   * this from working on the system interface, thus we are selecting
   * the first interface */
  // curr_iface = getCurrentInterface(vm);
  curr_iface = ntop->getFirstInterface();

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((address = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  is_mac = lua_toboolean(vm, 3);

  if (curr_iface && curr_iface->getHostPools()) {
    if (is_mac) {
      u_int8_t mac_bytes[6];
      Utils::parseMac(mac_bytes, address);
      pool_found = curr_iface->getHostPools()->findMacPool(mac_bytes, &pool_id);
    } else {
      IpAddress ip;
      ip.set(address);

      pool_found = curr_iface->getHostPools()->findIpPool(
          &ip, vlan_id, &pool_id, &target_node);
    }

    if (pool_found) {
      lua_newtable(vm);
      lua_push_uint64_table_entry(vm, "pool_id", pool_id);

      if (target_node != NULL) {
        ndpi_prefix_t* prefix = ndpi_patricia_get_node_prefix(target_node);
        lua_push_str_table_entry(
            vm, "matched_prefix",
            (char*)inet_ntop(prefix->family,
                             (prefix->family == AF_INET6)
                                 ? (void*)(&prefix->add.sin6)
                                 : (void*)(&prefix->add.sin),
                             buf, sizeof(buf)));
        lua_push_uint64_table_entry(vm, "matched_bitmask",
                                    ndpi_patricia_get_node_bits(target_node));
      }
    } else
      lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* *******************************************/

/* @brief Returns the host pool ID that a MAC address belongs to.  Lua: interface.findMacPool(mac) → integer */
static int ntop_find_mac_pool(lua_State* vm) {
  const char* mac;
  u_int8_t mac_parsed[6];
  u_int16_t pool_id;

  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  mac = lua_tostring(vm, 1);

  Utils::parseMac(mac_parsed, mac);

  if (curr_iface && curr_iface->getHostPools()) {
    if (curr_iface->getHostPools()->findMacPool(mac_parsed, &pool_id))
      lua_pushinteger(vm, pool_id);
    else
      lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* *******************************************/

#ifdef HAVE_NEDGE

/* @brief Reloads L7 (nDPI-based) shaping rules for a host pool (nEdge).  Lua: interface.reloadL7Rules(pool_id) → nil */
static int ntop_reload_l7_rules(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (curr_iface) {
    u_int16_t host_pool_id = (u_int16_t)lua_tonumber(vm, 1);

#ifdef SHAPER_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%i)", __FUNCTION__,
                                 host_pool_id);
#endif

    curr_iface->refreshL7Rules();
    curr_iface->updateHostsL7Policy(host_pool_id);
    curr_iface->updateFlowsL7Policy();

    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Reloads traffic shaper configurations from Redis (nEdge).  Lua: interface.reloadShapers() → nil */
static int ntop_reload_shapers(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) {
#ifdef NTOPNG_PRO
    curr_iface->refreshShapers();
#endif
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
}

#endif

/* ****************************************** */

/* @brief Retrieves a cached alert context value by key for this interface.  Lua: interface.getCachedAlertValue(key) → string */
static int ntop_interface_get_cached_alert_value(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  char* key;
  std::string val;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!c->iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 2)) >=
      MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  val = c->iface->getAlertCachedValue(std::string(key), periodicity);
  lua_pushstring(vm, val.c_str());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Stores a cached alert context value for this interface.  Lua: interface.setCachedAlertValue(key, value[, expiry]) → nil */
static int ntop_interface_set_cached_alert_value(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  char *key, *value;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!c->iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((value = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 3)) >=
      MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((!key) || (!value))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  c->iface->setAlertCacheValue(std::string(key), std::string(value),
                               periodicity);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Validates and initializes alert context for a script execution.  Lua: interface.checkContext(context_key) → nil */
static int ntop_interface_check_context(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  char* entity_val;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((entity_val = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((c->iface == NULL) ||
      (strcmp(c->iface->getEntityValue().c_str(), entity_val)) != 0) {
    /* NOTE: setting a context for a differnt interface is currently not
     * supported */
    ntop->getTrace()->traceEvent(
        TRACE_DEBUG,
        "Bad context - expected interface %s, found %s (%s) in context",
        entity_val,
        c->iface == NULL ? "NULL" : c->iface->getEntityValue().c_str(),
        c->iface == NULL ? "NULL" : c->iface->get_name());

    lua_pushboolean(vm, false);
  } else
    lua_pushboolean(vm, true);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Bulk-releases engaged alerts matching a script key and type.  Lua: interface.releaseEngagedAlerts(script_key, subtype, alert_type) → nil */
static int ntop_interface_release_engaged_alerts(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  // iface->releaseAllEngagedAlerts();
  /* TODO: implement this function in lua for interface and for local networks
   */

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static int ntop_interface_get_host_tags(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  Host *host;
  char *host_ip, buf[64];
  u_int16_t vlan_id = 0;
  u_int64_t bitmap = 0;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  host = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId));

  if (host) { /* Host online - read from host */
    bitmap = host->getTags();
  } else { /* Host offline - lookup on redis */
    char key_buf[CONST_MAX_LEN_REDIS_KEY];
    snprintf(key_buf, sizeof(key_buf), HOST_SERIALIZED_SHORT_KEY,
             iface->get_id(), host_ip, vlan_id);
    bitmap = iface->getPersistentHostTags(key_buf);
  }

  lua_pushinteger(vm, (lua_Integer)bitmap);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static int ntop_interface_get_user_defined_host_tags(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  Host *host;
  char *host_ip, buf[64];
  u_int16_t vlan_id = 0;
  u_int64_t bitmap = 0;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  host = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId));

  if (host) {
    bitmap = host->getUserTags();
  } else {
    char key_buf[CONST_MAX_LEN_REDIS_KEY];
    snprintf(key_buf, sizeof(key_buf), HOST_SERIALIZED_SHORT_KEY,
             iface->get_id(), host_ip, vlan_id);
    bitmap = iface->getPersistentHostTags(key_buf) & HOST_USER_TAGS_MASK;
  }

  lua_pushinteger(vm, (lua_Integer)bitmap);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static int ntop_interface_set_host_tags(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  Host *host;
  char *host_ip, buf[64];
  u_int16_t vlan_id = 0;
  u_int64_t bitmap;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));
  bitmap = (u_int64_t)lua_tonumber(vm, 2);

  host = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId));

  if (host) { /* Host online - set to the host (host will update redis) */
    host->setUserTags(bitmap);
  } else { /* Host offline - set on redis */
    char key_buf[CONST_MAX_LEN_REDIS_KEY];
    snprintf(key_buf, sizeof(key_buf), HOST_SERIALIZED_SHORT_KEY,
             iface->get_id(), host_ip, vlan_id);
    iface->setPersistentHostTags(key_buf, bitmap);
  }

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns classification attributes for a host (device type, OS, category).  Lua: interface.getHostAttributes(host, vlan) → table */
static int ntop_interface_get_host_attributes(lua_State* vm) {
  NetworkInterface* iface = getCurrentInterface(vm);
  u_int16_t vlan_id = 0;
  char buf[64], *host_ip;
  Host* h;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  h = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                          getLuaVMUservalue(vm, observationPointId));

  if (h) {
    ndpi_serializer* serializer =
        (ndpi_serializer*)malloc(sizeof(ndpi_serializer));
    if (serializer == NULL) {
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    } else {
      if (ndpi_init_serializer(serializer, ndpi_serialization_format_json) ==
          -1) {
        free(serializer);
        return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
      } else {
        char* attr = NULL;
        u_int32_t attr_len;

        h->serializeAttributes(serializer);
        attr = ndpi_serializer_get_buffer(serializer, &attr_len);
        lua_pushstring(vm, attr);

        ndpi_term_serializer(serializer);
        free(serializer);
      }
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static void ntop_get_maps_filters(lua_State* vm, MapsFilters* filters) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  filters->iface = curr_iface;
  filters->ip = NULL;
  filters->mac = NULL;
  filters->vlan_id = 0;
  filters->host_pool_id = (u_int16_t)-1;
  filters->ndpi_proto = (u_int16_t)-1;
  filters->first_seen = 0;
  filters->status = (ServiceAcceptance)service_unknown;
  filters->maxHits = (u_int32_t)-1;
  filters->startingHit = (u_int32_t)0;
  filters->unicast = false;
  filters->network_id = (int32_t)-1;
  filters->cli_location = (u_int8_t)-1;
  filters->srv_location = (u_int8_t)-1;
  filters->sort_column = (mapSortingColumn)map_column_last_seen;
  filters->sort_order = (sortingOrder)desc;
  filters->standard_view = true;
  u_int8_t direction = -1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    const char* addr = lua_tostring(vm, 1);
    if (strchr(addr, ':')) { /* This is a MAC address */
      filters->mac = new (std::nothrow) u_int8_t[6]();
      if (filters->mac) Utils::parseMac(filters->mac, addr);
    } else { /* This is an IP address */
      filters->ip = new (std::nothrow) IpAddress();
      if (filters->ip) filters->ip->set(addr);
    }
  }

  if (lua_type(vm, 2) == LUA_TNUMBER)
    filters->vlan_id = (u_int16_t)lua_tonumber(vm, 2);
  if (lua_type(vm, 3) == LUA_TNUMBER)
    filters->host_pool_id = (u_int16_t)lua_tonumber(vm, 3);
  if (lua_type(vm, 4) == LUA_TBOOLEAN)
    filters->unicast = (bool)lua_toboolean(vm, 4);
  if (lua_type(vm, 5) == LUA_TNUMBER)
    filters->first_seen = (u_int32_t)lua_tonumber(vm, 5);
  if (lua_type(vm, 6) == LUA_TSTRING)
    filters->ndpi_proto = ndpi_get_proto_by_name(curr_iface->get_ndpi_struct(),
                                                 (char*)lua_tostring(vm, 6));

  if (lua_type(vm, 7) == LUA_TNUMBER)
    filters->network_id = (int32_t)lua_tonumber(vm, 7);
  if (lua_type(vm, 8) == LUA_TNUMBER)
    filters->status = (ServiceAcceptance)lua_tonumber(vm, 8);
  if (lua_type(vm, 9) == LUA_TNUMBER) direction = (u_int8_t)lua_tonumber(vm, 9);
  if (lua_type(vm, 10) == LUA_TSTRING) {
    char* str = (char*)lua_tostring(vm, 10);

    if (str)
      snprintf(filters->host_to_search, sizeof(filters->host_to_search), "%s",
               str);
  }

  if (lua_type(vm, 11) == LUA_TNUMBER)
    filters->maxHits = (u_int32_t)lua_tonumber(vm, 11);
  if (lua_type(vm, 12) == LUA_TNUMBER)
    filters->startingHit = (u_int32_t)lua_tonumber(vm, 12);
  if (lua_type(vm, 13) == LUA_TNUMBER)
    filters->sort_column = (mapSortingColumn)lua_tonumber(vm, 13);
  if (lua_type(vm, 14) == LUA_TNUMBER)
    filters->sort_order = (sortingOrder)lua_tonumber(vm, 14);
  if (lua_type(vm, 15) == LUA_TBOOLEAN)
    filters->standard_view = (bool)lua_toboolean(vm, 15);

  switch (direction) {
    case 0:
      filters->cli_location = 0, filters->srv_location = 0;
      break;
    case 1:
      filters->cli_location = 1, filters->srv_location = 1;
      break;
    case 2:
      filters->cli_location = 0, filters->srv_location = 1;
      break;
    case 3:
      filters->cli_location = 1, filters->srv_location = 0;
      break;
  }
}

/* ****************************************** */

/* @brief Internal helper for periodicity and service map queries.  Lua: (internal map helper) → table */
static int ntop_get_interface_map(lua_State* vm, bool periodicity) {
  MapsFilters filters;

  memset(&filters, 0, sizeof(filters));

  ntop_get_maps_filters(vm, &filters);

  if (filters.iface) {
    if (periodicity) {
      filters.periodicity_or_service = true;
      filters.iface->luaPeriodicityMap(vm, &filters);
    } else {
      filters.periodicity_or_service = false;
      filters.iface->luaServiceMap(vm, &filters);
    }
  } else
    lua_pushnil(vm);

  if (filters.ip) delete filters.ip;
  if (filters.mac) delete[] filters.mac;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Internal helper returning filter list for periodicity/service maps.  Lua: (internal map filter helper) → table */
static int ntop_get_interface_map_filter_list(lua_State* vm, bool periodicity) {
  MapsFilters filters;

  memset(&filters, 0, sizeof(filters));

  filters.periodicity_or_service = periodicity;
  ntop_get_maps_filters(vm, &filters);

  if (filters.iface) {
    if (periodicity) {
      filters.iface->luaPeriodicityFilteringMenu(vm, &filters);
    } else {
      filters.iface->luaServiceFilteringMenu(vm, &filters);
    }
  } else
    lua_pushnil(vm);

  if (filters.ip) delete filters.ip;
  if (filters.mac) delete[] filters.mac;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns available filter options for the periodicity map view.  Lua: interface.periodicityMapFilterList() → table */
static int ntop_get_interface_periodicity_map_filter_list(lua_State* vm) {
  return ntop_get_interface_map_filter_list(vm, true /* periodicity */);
}

/* ****************************************** */

/* @brief Returns available filter options for the service map view.  Lua: interface.serviceMapFilterList() → table */
static int ntop_get_interface_service_map_filter_list(lua_State* vm) {
  return ntop_get_interface_map_filter_list(vm, false /* service */);
}

/* ****************************************** */

/* @brief Returns the periodicity map data for hosts and protocols on this interface.  Lua: interface.periodicityMap([params]) → table */
static int ntop_get_interface_periodicity_map(lua_State* vm) {
  return ntop_get_interface_map(vm, true /* periodicity */);
}

/* ****************************************** */

/* @brief Returns the service map data (host-to-service relationships) for this interface.  Lua: interface.serviceMap([params]) → table */
static int ntop_get_interface_service_map(lua_State* vm) {
  return ntop_get_interface_map(vm, false /* service */);
}

/* ****************************************** */

/* @brief Clears all learned periodicity map data for this interface.  Lua: interface.flushPeriodicityMap() → nil */
static int ntop_flush_interface_periodicity_map(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface* curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  curr_iface->flushPeriodicityMap();
#endif

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Clears all learned service map data for this interface.  Lua: interface.flushServiceMap() → nil */
static int ntop_flush_interface_service_map(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface* curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  curr_iface->flushServiceMap();
#endif

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Sets the learning/active status for a single service map entry.  Lua: interface.serviceMapSetStatus(key, status) → nil */
static int ntop_interface_service_map_set_status(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int64_t hash_id;
  ServiceAcceptance status;
  char* buff;
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  if (curr_iface) {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    if ((buff = (char*)lua_tostring(vm, 1)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    hash_id = strtoull(buff, NULL, 10);

    if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    status = (ServiceAcceptance)lua_tonumber(vm, 2);

    if (curr_iface->getServiceMap())
      curr_iface->getServiceMap()->setStatus(hash_id, status);
    else
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  }
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Sets status for multiple service map entries in a single call.  Lua: interface.serviceMapSetMultipleStatus(entries_table) → nil */
static int ntop_interface_service_map_set_multiple_status(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  ServiceAcceptance current_status = service_unknown,
                    new_status = service_unknown;
  u_int16_t proto_id = 0xFF;
  char* l7_proto = NULL;
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  if (curr_iface) {
    if (lua_type(vm, 1) == LUA_TSTRING) l7_proto = (char*)lua_tostring(vm, 1);
    if (lua_type(vm, 2) == LUA_TNUMBER)
      current_status = (ServiceAcceptance)lua_tonumber(vm, 2);
    if (lua_type(vm, 3) == LUA_TNUMBER)
      new_status = (ServiceAcceptance)lua_tonumber(vm, 3);

    if (l7_proto != NULL)
      proto_id =
          ndpi_get_proto_by_name(curr_iface->get_ndpi_struct(), l7_proto);

    curr_iface->getServiceMap()->setBatchStatus(proto_id, current_status,
                                                new_status);
  }
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns whether the service map is in learning or enforcement mode.  Lua: interface.serviceMapLearningStatus() → table */
static int ntop_interface_service_map_learning_status(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface* curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  if (curr_iface)
    curr_iface->luaServiceMapStatus(vm);
  else
    lua_pushnil(vm);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns true if behavioral analysis (periodicity/service maps) is available.  Lua: interface.isBehaviourAnalysisAvailable() → boolean */
static int ntop_is_behaviour_analysis_available(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  lua_pushboolean(vm, curr_iface->isPeriodicityMapEnabled() ||
                          curr_iface->isServiceMapEnabled());
#else
  lua_pushboolean(vm, false);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns comprehensive address information (DNS, geolocation, ASN) for an IP or hostname.  Lua: interface.getAddressInfo(ip_or_name) → table */
static int ntop_get_address_info(lua_State* vm) {
  char* addr;
  IpAddress ip;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  addr = (char*)lua_tostring(vm, 1);

  ip.set(addr);

  lua_newtable(vm);
  lua_push_bool_table_entry(vm, "is_blacklisted", ip.isBlacklistedAddress());
  lua_push_bool_table_entry(vm, "is_broadcast", ip.isBroadcastAddress());
  lua_push_bool_table_entry(vm, "is_multicast", ip.isMulticastAddress());
  lua_push_bool_table_entry(vm, "is_private", ip.isPrivateAddress());
  lua_push_bool_table_entry(vm, "is_local", ip.isLocalHost());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns per-protocol nDPI traffic statistics for a specific host.  Lua: interface.getnDPIHostStats(host, vlan) → table */
static int ntop_get_ndpi_host_stats(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else {
    if (!curr_iface->getHostMinInfo(vm, get_allowed_nets(vm), host_ip, vlan_id,
                                    true))
      ntop_get_address_info(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

/* @brief Returns minimal host info (bytes, packets, score) for lightweight polling.  Lua: interface.getHostMinInfo(host[,vlan]) → table */
static int ntop_get_interface_get_host_min_info(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  } else {
    if (!curr_iface->getHostMinInfo(vm, get_allowed_nets(vm), host_ip, vlan_id,
                                    false))
      lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
  }
}

/* ****************************************** */

#ifdef HAVE_NEDGE

/* @brief Triggers an update of traffic shaper state for all active flows (nEdge).  Lua: interface.updateFlowsShapers() → nil */
static int ntop_update_flows_shapers(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (curr_iface) curr_iface->updateFlowsL7Policy();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns a monotonic counter incremented on each policy change (nEdge).  Lua: interface.getPolicyChangeMarker() → integer */
static int ntop_get_policy_change_marker(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (curr_iface && (curr_iface->getIfType() == interface_type_NETFILTER))
    lua_pushinteger(vm,
                    ((NetfilterInterface*)curr_iface)->getPolicyChangeMarker());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Adds an IP/CIDR to the LAN address list for nEdge routing decisions.  Lua: interface.addLanIPAddress(ip_cidr) → nil */
static int ntop_add_lan_ip_address(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  const char* ip = lua_tostring(vm, 1);

  if (curr_iface && (curr_iface->getIfType() == interface_type_NETFILTER))
    ((NetfilterInterface*)curr_iface)->addLanIPAddress(inet_addr(ip));

  if (ntop->get_HTTPserver())
    ntop->get_HTTPserver()->addCaptiveRedirectAddress(ip);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns the L7 policy rules for a host pool (nEdge).  Lua: interface.getl7PolicyInfo(pool_id) → table */
static int ntop_get_l7_policy_info(lua_State* vm) {
  u_int16_t pool_id;
  u_int8_t shaper_id;
  ndpi_protocol proto;
  DeviceType dev_type;
  bool as_client;
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  L7PolicySource_t policy_source;
  DeviceProtoStatus device_proto_status;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface || !curr_iface->getL7Policer())
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  pool_id = (u_int16_t)lua_tointeger(vm, 1);

  proto.proto.master_protocol = (u_int16_t)lua_tointeger(vm, 2);
  proto.proto.app_protocol = proto.proto.master_protocol;

  proto.category =
      NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;  // important for
                                           // ndpi_get_proto_category below
  proto.category = ndpi_get_proto_category(
      curr_iface->get_ndpi_struct(),
      proto);  // set appropriate category based on the protocols

  dev_type = (DeviceType)lua_tointeger(vm, 3);
  as_client = lua_toboolean(vm, 4);

  if (ntop->getPrefs()->are_device_protocol_policies_enabled() &&
      ((device_proto_status = ntop->getDeviceAllowedProtocolStatus(
            dev_type, proto, pool_id, as_client)) != device_proto_allowed)) {
    shaper_id = DROP_ALL_SHAPER_ID;
    policy_source = policy_source_device_protocol;
  } else {
    shaper_id = curr_iface->getL7Policer()->getShaperIdForPool(pool_id, proto,
                                                               &policy_source);
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "shaper_id", shaper_id);
  lua_push_str_table_entry(vm, "policy_source",
                           (char*)Utils::policySource2Str(policy_source));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

#endif

/* ****************************************** */

// *** API ***
/* @brief Returns true if this is a disaggregated sub-interface.  Lua: interface.isSubInterface() → boolean */
static int ntop_interface_is_sub_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushboolean(vm, curr_iface->isSubInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

// *** API ***
/* @brief Returns true if this interface receives syslog events.  Lua: interface.isSyslogInterface() → boolean */
static int ntop_interface_is_syslog_interface(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  lua_pushboolean(vm, curr_iface->isSyslogInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Executes a ClickHouse SQL query and streams CSV results to the HTTP response.  Lua: interface.clickhouseExecCSVQuery(sql) → nil */
static int ntop_clickhouse_exec_csv_query(lua_State* vm) {
#ifdef HAVE_CLICKHOUSE
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  const char* sql;
  const char* delimiter = "|";
  const char* null_value = " ";
  bool use_json = false, remove_headers = false;
  struct mg_connection* conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((!curr_iface) || (!conn))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  sql = lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN) /* optional */
    use_json = lua_toboolean(vm, 2) ? true : false;

  if (lua_type(vm, 3) == LUA_TSTRING) /* optional */
    delimiter = lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING) /* optional */
    null_value = lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TBOOLEAN) /* optional */
    remove_headers = lua_toboolean(vm, 5);

  Utils::flushHTTPBuffer(vm);
  curr_iface->execSQLQuery2CSV(sql, delimiter, null_value, use_json,
                               remove_headers, conn);
#endif

  lua_pushnil(vm); /* Data is pushed via the HTTP server */

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Triggers archival of old interface data to ClickHouse storage.  Lua: interface.clickhouseArchiveData() → nil */
static int ntop_clickhouse_archive_data(lua_State* vm) {
#ifdef HAVE_CLICKHOUSE
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  time_t epoch_begin, epoch_end;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  epoch_begin = (time_t)lua_tointeger(vm, 1);
  epoch_end = (time_t)lua_tointeger(vm, 2);

  curr_iface->archiveDBData(epoch_begin, epoch_end);
#endif

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Records a protocol observation for a host to the nDPI dump table.  Lua: interface.dumpnDPIProtocolId(host, vlan, proto_id) → nil */
static int ntop_dump_host_based_protocol_id(lua_State* vm) {
  NetworkInterface* curr_iface = getLuaVMUserdata(vm, iface);
  struct mg_connection* conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && conn) {
    Utils::flushHTTPBuffer(vm);
    curr_iface->nDPIDumpHostBasedProtocols(conn);
  }
  
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}
/* ****************************************** */

/* @brief Records a category observation for a host to the nDPI dump table.  Lua: interface.dumpnDPICategoryId(host, vlan, cat_id) → nil */
static int ntop_dump_host_based_category_id(lua_State* vm) {
  NetworkInterface* curr_iface = getLuaVMUserdata(vm, iface);
  struct mg_connection* conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && conn) {
    Utils::flushHTTPBuffer(vm);
    curr_iface->nDPIDumpHostBasedCategories(conn);
  }
  
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Swaps the hostname-to-IP cache with a newly built version.  Lua: interface.swapHostnameIPCache() → nil */
static int ntop_swap_hostname_ip_cache(lua_State* vm) {
  NetworkInterface* curr_iface = getLuaVMUserdata(vm, iface);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && !curr_iface->isEnabled())
    ndpi_cache_hostname_ip_swap(curr_iface->get_ndpi_struct());

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Triggers aggregation of flows by Autonomous System Number.  Lua: interface.aggregateASNFlows() → nil */
static int ntop_aggregate_asn_flows(lua_State* vm) {
  NetworkInterface* curr_iface = getLuaVMUserdata(vm, iface);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, curr_iface->aggregateASNModeFlows(vm));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

#ifdef NTOPNG_PRO
/* @brief Triggers aggregation of flows by site/organization (Pro).  Lua: interface.aggregateSiteFlows() → nil */
static int ntop_aggregate_site_flows(lua_State* vm) {
#ifdef NTOPNG_PRO
  NetworkInterface* curr_iface = getLuaVMUserdata(vm, iface);
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  curr_iface->aggregateSiteFlows(vm);
#else
  lua_pushnil(vm);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}
#endif

/* ****************************************** */

/*
 * Execute a ClickHouse statement with no result expected (e.g. INSERT)
 */
/* @brief Executes a SQL write statement on the ClickHouse interface database.  Lua: interface.execSQLWrite(sql) → nil */
static int ntop_clickhouse_exec_sql_write(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  const char* sql;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  sql = lua_tostring(vm, 1);

  lua_pushboolean(vm, curr_iface->execSQLWrite(sql) == 0);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* Enqueue a timeseries row into the interface ClickHouse TS queue.
 * Serialises the point to line protocol via CHTimeseriesExporter::enqueueData.
 * Lua signature: interface.chTsEnqueue(schema, timestamp, tags, metrics) ->
 * boolean */
/* @brief Enqueues a ClickHouse time-series data batch for async insertion.  Lua: interface.chTsEnqueue(json_data) → nil */
static int ntop_interface_ch_ts_enqueue(lua_State* vm) {
  bool rv = false;
  NetworkInterface* curr_iface;
  TimeseriesExporter* ts_exporter;

  if ((curr_iface = getCurrentInterface(vm)) &&
      (ts_exporter = curr_iface->getCHTSExporter()))
    rv = ts_exporter->enqueueData(vm);

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* Dequeue one line-protocol-encoded timeseries row from the ClickHouse TS
 * queue. Returns the string on success, nil if the queue is empty. Lua
 * signature: interface.chTsDequeue() -> string|nil */
/* @brief Dequeues a pending ClickHouse time-series data batch.  Lua: interface.chTsDequeue() → string */
static int ntop_interface_ch_ts_dequeue(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  TimeseriesExporter* ts_exporter = curr_iface->getCHTSExporter();
  char* item = ts_exporter ? ts_exporter->dequeueData() : NULL;

  if (item) {
    lua_pushstring(vm, item);
    free(item);
  } else {
    lua_pushnil(vm);
  }
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* Return the current length of the ClickHouse TS queue.
 * Lua signature: interface.chTsQueueLen() -> integer */
/* @brief Returns the number of pending ClickHouse time-series batches in the queue.  Lua: interface.chTsQueueLen() → integer */
static int ntop_interface_ch_ts_queue_len(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  TimeseriesExporter* ts_exporter = curr_iface->getCHTSExporter();
  lua_pushinteger(vm,
                  ts_exporter ? (lua_Integer)ts_exporter->queueLength() : 0);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Executes a SQL query against the in-memory flow/host tables.  Lua: interface.execInMemoryQuery(sql) → table */
static int ntop_exec_in_memory_sql_query(lua_State* vm) {
  char* sql;
  InMemorySQLiteDB* db = getLuaVMUserdata(vm, db);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  sql = (char*)lua_tostring(vm, 1);

  if (db == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  db->execSQLQuery(vm, sql, false, false);
  
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_TWO_RETURN_VALUES));
}

/* ****************************************** */

/* @brief Handles an IP address reassignment event (DHCP lease change).  Lua: interface.updateIPReassignment(params_table) → nil */
static int ntop_interface_update_ip_reassignment(lua_State* vm) {
  NetworkInterface* iface = NULL;
  int ifid = -1;
  bool ip_reassignment_enabled = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ifid = (int)lua_tointeger(vm, 1);
  iface = ntop->getInterfaceById(ifid);

  ip_reassignment_enabled = (bool)lua_toboolean(vm, 2);
  iface->enable_ip_reassignment_alerts(ip_reassignment_enabled);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Triggers a traffic-threshold alert with configurable severity and details.  Lua: interface.triggerTrafficAlert(params_table) → nil */
static int ntop_interface_trigger_traffic_alert(lua_State* vm) {
  u_int32_t frequency_sec;
  bool t_sign = true;
  char *metric, *ipaddress, ip_buf[64], *host_ip, *tmp, *value, *threshold;
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool rc = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  ipaddress = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  metric = (char*)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  frequency_sec = (u_int32_t)lua_tointeger(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  threshold = (char*)lua_tostring(vm, 4);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  value = (char*)lua_tostring(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  t_sign = (u_int32_t)lua_toboolean(vm, 6);

  snprintf(ip_buf, sizeof(ip_buf), "%s", ipaddress);
  host_ip = strtok_r(ipaddress, "@", &tmp);

  if (host_ip) {
    char* vlan_str = strtok_r(NULL, "@", &tmp);
    u_int16_t vlan_id = 0;
    AddressTree ptree;
    Host* h;
    u_int16_t observation_point_id = 0;
    if (vlan_str) vlan_id = atoi(vlan_str);

    /* No host search restrictions */
    ptree.addAddresses("0.0.0.0/0,::/0");

    /* Find the host in memory */
    h = curr_iface->findHostByIP(&ptree, ipaddress, vlan_id,
                                 observation_point_id);

    if (h != NULL) {
      HostAlert* alert;
      time_t now = time(NULL);
      time_t alert_timeout =
          now + frequency_sec + 120; /* interval + 2 min tolerance */

      /* FIXX a lock on HostAlertableEntity.engaged_alerts_lock is probably
       * required to handle concurrency with HostChecksExecutor */

      /* Check if already engaged */
      alert = h->getCheckEngagedAlert(host_check_traffic_volume);

      if (alert) {
        alert->setTimeout(alert_timeout); /* refresh timeout */

        /*
          TrafficVolumeAlert *tvalert =
          dynamic_cast<TrafficVolumeAlert*>(alert);
          ntop->getTrace()->traceEvent(TRACE_NORMAL, "Skipping host alert %s@%d
          (%s), already engaged for %s@%d (%s)", ipaddress, vlan_id, metric,
          ipaddress, vlan_id, tvalert->getMetric().c_str());
        */
      } else {
        /* Build new alert */
        alert = new TrafficVolumeAlert(
            host_check_traffic_volume, h, CLIENT_FULL_RISK_PERCENTAGE,
            std::string(metric), frequency_sec, threshold, value, t_sign);

        if (alert) {
          /* Specify when the alert will auto-release if not continuously
           * triggered */
          alert->setTimeout(alert_timeout);

          h->triggerAlert(alert); /* Trigger an engaged host alert */
          ntop->getTrace()->traceEvent(TRACE_INFO,
                                       "Triggered host alert %s@%d (%s)",
                                       ipaddress, vlan_id, metric);
        }
      }

      rc = true; /* All went well */
    }
  }

  lua_pushboolean(vm, rc);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

/* @brief Updates the site/host ranking data for this interface (Pro).  Lua: interface.updateRanking(ranking_table) → nil */
static int ntop_update_ranking(lua_State* vm) {
#ifdef NTOPNG_PRO
  u_int32_t epoch;
  char *key, *values;
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    epoch = (u_int32_t)lua_tonumber(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    key = (char*)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  else
    values = (char*)lua_tostring(vm, 3);

  curr_iface->updateRanking(vm, epoch, key, values);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

static luaL_Reg _ntop_interface_reg[] = {
    {"getIfNames", ntop_get_interface_names},
    {"getIfMac", ntop_get_interface_mac},
    {"getFirstInterfaceId", ntop_get_first_interface_id},
    {"select", ntop_select_interface},
    {"getId", ntop_get_interface_id},
    {"getName", ntop_get_interface_name},
    {"isValidIfId", ntop_is_valid_interface_id},
    {"getMaxIfSpeed", ntop_get_max_if_speed},
    {"hasVLANs", ntop_interface_has_vlans},
    {"hasEBPF", ntop_interface_has_ebpf},
    {"hasExternalAlerts", ntop_interface_has_external_alerts},
    {"getStats", ntop_get_interface_stats},
    {"getStatsUpdateFreq", ntop_get_interface_stats_update_freq},
    {"getSecsToFirstData", ntop_get_secs_to_first_data},
    {"updateDirectionStats", ntop_update_interface_direction_stats},
    {"updateTopSites", ntop_update_interface_top_sites},
    {"resetCounters", ntop_interface_reset_counters},
    {"resetHostStats", ntop_interface_reset_host_stats},
    {"deleteHostData", ntop_interface_delete_host_data},
    {"resetMacStats", ntop_interface_reset_mac_stats},
    {"deleteMacData", ntop_interface_delete_mac_data},
    {"resetBroadcastDomains", ntop_interface_reset_broadcast_domains},

    /* Functions related to the management of per-interface queues */
    {"getQueuesStats", ntop_get_interface_queues_stats},

    /* Functions related to the management of the internal hash tables */
    {"getHashTablesStats", ntop_get_interface_hash_tables_stats},

    /* Functions to get and reset the duration of periodic threaded activities
     */
    {"getPeriodicActivitiesStats",
     ntop_get_interface_periodic_activities_stats},
    {"setPeriodicActivityProgress",
     ntop_set_interface_periodic_activity_progress},

#ifndef HAVE_NEDGE
    {"processFlow", ntop_process_flow},
    {"updateSyslogProducers", ntop_update_syslog_producers},
    {"getZMQFlowFieldDescr", ntop_get_zmq_flow_field_descr},
    {"getAllZMQFlowFieldDescr", ntop_get_all_zmq_flow_field_descr},
#endif

    {"getActiveFlowsStats", ntop_get_active_flows_stats},
    {"getLiveASNStats", ntop_get_live_asn_stats},
    {"getnDPIProtoName", ntop_get_ndpi_protocol_name},
    {"getnDPIFullProtoName", ntop_get_ndpi_full_protocol_name},
    {"getnDPIProtoId", ntop_get_ndpi_protocol_id},
    {"getnDPICategoryId", ntop_get_ndpi_category_id},
    {"getnDPICategoryName", ntop_get_ndpi_category_name},
    {"getnDPIFlowsCount", ntop_get_ndpi_interface_flows_count},
    {"getnDPIStats", ntop_get_ndpi_interface_stats},
    {"getnDPIHostStats", ntop_get_ndpi_host_stats},
    {"getFlowsStatus", ntop_get_ndpi_interface_flows_status},
    {"getnDPIProtoBreed", ntop_get_ndpi_protocol_breed},
    {"getnDPIProtocols", ntop_get_ndpi_protocols},
    {"getnDPICategories", ntop_get_ndpi_categories},
    {"dumpnDPIProtocolId", ntop_dump_host_based_protocol_id},
    {"dumpnDPICategoryId", ntop_dump_host_based_category_id},
    {"getHostsInfo", ntop_get_interface_hosts_info},
    {"getLocalHostsInfo", ntop_get_interface_local_hosts_info},
    {"getLocalHostsInfoNoTX", ntop_get_interface_local_hosts_no_tx_info},
    {"getLocalHostsInfoNoTXTCP", ntop_get_interface_local_hosts_no_tcp_tx_info},
    {"getRemoteHostsInfo", ntop_get_interface_remote_hosts_info},
    {"getRemoteHostsInfoNoTX", ntop_get_interface_remote_hosts_no_tx_info},
    {"getRemoteHostsInfoNoTXTCP",
     ntop_get_interface_remote_hosts_no_tcp_tx_info},
    {"getRxOnlyHostsList", ntop_get_rxonly_hosts_list},
    {"getBroadcastDomainHostsInfo",
     ntop_get_interface_broadcast_domain_hosts_info},
    {"getBroadcastMulticastHostsInfo",
     ntop_get_interface_broadcast_multicast_hosts_info},
    {"getPublicHostsInfo", ntop_get_public_hosts_info},
    {"getBatchedFlowsInfo", ntop_get_batched_interface_flows_info},
    {"getBatchedHostsInfo", ntop_get_batched_interface_hosts_info},
    {"getBatchedLocalHostsInfo", ntop_get_batched_interface_local_hosts_info},
    {"getBatchedRemoteHostsInfo", ntop_get_batched_interface_remote_hosts_info},
    {"getBatchedLocalHostsTs", ntop_get_batched_interface_local_hosts_ts},
    {"getInterfaceHosts", ntop_get_interface_hosts},
    {"isHostActive", ntop_is_host_active},
    {"getHostInfo", ntop_get_interface_host_info},
    {"getHostMinInfo", ntop_get_interface_get_host_min_info},
    {"getHostCountry", ntop_get_interface_host_country},
    {"addMacsIpAddresses", ntop_add_macs_ip_addresses},
    {"getNetworksStats", ntop_get_interface_networks_stats},
    {"getLocalServerPorts", ntop_get_local_server_ports},
    {"getNetworkStats", ntop_get_interface_network_stats},
    {"getFlowsInfo", ntop_get_interface_flows_info},
    {"getGroupedFlows", ntop_get_interface_get_grouped_flows},
    {"getFlowsStats", ntop_get_interface_flows_stats},
    {"getFlowKey", ntop_get_interface_flow_key},
    {"getIPNetworkId", ntop_get_ip_network_id},
    {"getScore", ntop_get_interface_score},
    {"findFlowByKeyAndHashId", ntop_get_interface_find_flow_by_key_and_hash_id},
    {"findFlowByTuple", ntop_get_interface_find_flow_by_tuple},
    {"findPidFlows", ntop_get_interface_find_pid_flows},
    {"findNameFlows", ntop_get_interface_find_proc_name_flows},
    {"listHTTPhosts", ntop_list_http_hosts},
    {"findHost", ntop_get_interface_find_host},
    {"findHostByMac", ntop_get_interface_find_host_by_mac},
    {"resetHostTopSites", ntop_reset_interface_host_top_sites},
    {"updateTrafficMirrored", ntop_update_traffic_mirrored},
    {"updateSmartRecording", ntop_update_smart_recording},
    {"updateDynIfaceTrafficPolicy",
     ntop_update_dynamic_interface_traffic_policy},
    {"updatePushFiltersSettings", ntop_update_push_filters_settings},
    {"updateLbdIdentifier", ntop_update_lbd_identifier},
    {"updateHostTrafficPolicy", ntop_update_host_traffic_policy},
    {"updateFlowsOnlyInterface", ntop_update_flows_only_interface},
    {"getEndpoint", ntop_get_interface_endpoint},
    {"isPacketInterface", ntop_interface_is_packet_interface},
    {"isDiscoverableInterface", ntop_interface_is_discoverable_interface},
    {"isBridgeInterface", ntop_interface_is_bridge_interface},
    {"isPcapDumpInterface", ntop_interface_is_pcap_dump_interface},
    {"isDatabaseViewInterface", ntop_interface_is_database_view_interface},
    {"isZMQInterface", ntop_interface_is_zmq_interface},
    {"isView", ntop_interface_is_view},
    {"isViewed", ntop_interface_is_viewed},
    {"isSampledTraffic", ntop_interface_is_sampled_traffic},
    {"viewedBy", ntop_interface_viewed_by},
    {"isLoopback", ntop_interface_is_loopback},
    {"isRunning", ntop_interface_is_running},
    {"isIdle", ntop_interface_is_idle},
    {"setInterfaceIdleState", ntop_interface_set_idle},
    {"name2id", ntop_interface_name2id},
    {"loadScalingFactorPrefs", ntop_load_scaling_factor_prefs},
    {"reloadGwMacs", ntop_reload_gw_macs},
    {"reloadDhcpRanges", ntop_reload_dhcp_ranges},
    {"reloadHostPrefs", ntop_reload_host_prefs},
    {"setHostOperatingSystem", ntop_set_host_operating_system},
    {"setHostResolvedName", ntop_set_host_resolved_name},
    {"getNumLocalHosts", ntop_get_num_local_hosts},
    {"getNumLocalRxOnlyHosts", ntop_get_num_local_rxonly_hosts},
    {"getNumHosts", ntop_get_num_hosts},
    {"getNumFlows", ntop_get_num_flows},
    {"periodicityMap", ntop_get_interface_periodicity_map},
    {"flushPeriodicityMap", ntop_flush_interface_periodicity_map},
    {"serviceMap", ntop_get_interface_service_map},
    {"periodicityMapFilterList",
     ntop_get_interface_periodicity_map_filter_list},
    {"isBehaviourAnalysisAvailable", ntop_is_behaviour_analysis_available},
    {"serviceMapFilterList", ntop_get_interface_service_map_filter_list},
    {"flushServiceMap", ntop_flush_interface_service_map},
    {"serviceMapLearningStatus", ntop_interface_service_map_learning_status},
    {"serviceMapSetStatus", ntop_interface_service_map_set_status},
    {"serviceMapSetMultipleStatus",
     ntop_interface_service_map_set_multiple_status},
    {"insertIPACL", ntop_interface_insert_ip_acl},
    {"removeIPACL", ntop_interface_remove_ip_acl},
    {"insertMacACL", ntop_interface_insert_mac_acl},
    {"removeMacACL", ntop_interface_remove_mac_acl},
    {"getACLInfo", ntop_interface_get_acl_info},
    {"getThroughput", ntop_interface_get_throughput},
    {"getProtocolFlowsStats", ntop_get_protocol_flows_stats},
    {"getVLANFlowsStats", ntop_get_vlan_flows_stats},
    {"getHostsPorts", ntop_get_hosts_ports},
    {"getHostsByPort", ntop_get_hosts_by_port},
    {"radiusAccountingStart", ntop_radius_accounting_start},
    {"radiusAccountingStop", ntop_radius_accounting_stop},
    {"radiusAccountingUpdate", ntop_radius_accounting_update},
    {"getHostsByService", ntop_get_hosts_by_service},

    /* Addresses */
    {"getAddressInfo", ntop_get_address_info},

    /* Addresses */
    {"getAddressInfo", ntop_get_address_info},

    /* Mac */
    {"getActiveMacs", ntop_get_interface_active_macs},
    {"getMacsInfo", ntop_get_interface_macs_info},
    {"getBatchedMacsInfo", ntop_get_batched_interface_macs_info},
    {"isMacActive", ntop_is_mac_active},
    {"getMacInfo", ntop_get_interface_mac_info},
    {"getMacHosts", ntop_get_interface_mac_hosts},
    {"getMacManufacturers", ntop_get_interface_macs_manufacturers},
    {"getMacDeviceTypes", ntop_get_mac_device_types},
    {"isMulticastMac", ntop_is_multicast_mac},
#ifdef HAVE_NEDGE
    {"appendMacEvent", ntop_append_mac_event},
#endif

    /* Anomalies */
    {"getAnomalies", ntop_get_interface_anomalies},

    /* Autonomous Systems */
    {"getASesInfo", ntop_get_interface_ases_info},
    {"getASInfo", ntop_get_interface_as_info},
    {"getASList", ntop_get_interface_as_list},

    /* Autonomous Systems */
    {"getObsPointsInfo", ntop_get_interface_obs_points_info},
    {"getObsPointInfo", ntop_get_interface_obs_point_info},
    {"prepareDeleteObsPoint", ntop_prepare_delete_interface_observation_point},
    {"deleteObsPoint", ntop_delete_interface_observation_point},

    /* Countries */
    {"getCountriesInfo", ntop_get_interface_countries_info},
    {"getCountryInfo", ntop_get_interface_country_info},
    {"convertCountryCode2U16", ntop_convert_country_code_to_u16},
    {"convertCountryU162Code", ntop_convert_country_u16_to_code},

    /* VLANs */
    {"getVLANsList", ntop_get_interface_vlans_list},
    {"getVLANsInfo", ntop_get_interface_vlans_info},
    {"getVLANInfo", ntop_get_interface_vlan_info},

    /* Host pools */
    {"findMemberPool", ntop_find_member_pool},
    {"findMacPool", ntop_find_mac_pool},
    {"getHostPoolsInfo", ntop_get_host_pools_info},

    /* InfluxDB */
    {"appendInfluxDB", ntop_append_influx_db},

    /* RRD queue */
    {"rrd_enqueue", ntop_rrd_queue_push},
    {"rrd_dequeue", ntop_rrd_queue_pop},
    {"rrd_queue_length", ntop_rrd_queue_length},

    {"getHostPoolsStats", ntop_get_host_pools_interface_stats},
    {"getHostPoolStats", ntop_get_host_pool_interface_stats},
#ifdef NTOPNG_PRO
#ifdef HAVE_NEDGE
    {"resetPoolsQuotas", ntop_reset_pools_quotas},
    {"flushPoolDynamicBlacklist", ntop_flush_pool_dynamic_blacklist},
    {"getPoolDynamicBlacklistStats", ntop_get_pool_dynamic_blacklist_stats},
    {"getPoolDynamicBlacklistMembers", ntop_get_pool_dynamic_blacklist_members},
    {"getHostUsedQuotasStats", ntop_get_host_used_quotas_stats},
#endif

    /* SNMP */
    {"getSNMPStats", ntop_interface_get_snmp_stats},

#ifdef NTOPNG_PRO
    /* Flow Devices */
    {"getFlowDevices", ntop_get_flow_devices},
    {"getFlowDeviceInfo", ntop_get_flow_device_info},
    {"getFlowDeviceInfoByIP", ntop_get_flow_device_info_by_ip},
#endif

#ifdef HAVE_NEDGE

    {"dropFlowTraffic", ntop_drop_flow_traffic},
    {"dropMultipleFlowsTraffic", ntop_drop_multiple_flows_traffic},
    {"dropHostTraffic", ntop_drop_host_traffic},

    /* L7 */
    {"reloadL7Rules", ntop_reload_l7_rules},
    {"reloadShapers", ntop_reload_shapers},
    {"addLanIPAddress", ntop_add_lan_ip_address},
    {"getPolicyChangeMarker", ntop_get_policy_change_marker},
    {"updateFlowsShapers", ntop_update_flows_shapers},
    {"getl7PolicyInfo", ntop_get_l7_policy_info},
#endif
#endif

    /* Network Discovery */
    {"discoverHosts", ntop_discover_iface_hosts},
    {"arpScanHosts", ntop_arpscan_iface_hosts},
    {"mdnsQueueNameToResolve", ntop_mdns_queue_name_to_resolve},
    {"mdnsQueueAnyQuery", ntop_mdns_batch_any_query},
    {"mdnsReadQueuedResponses", ntop_mdns_read_queued_responses},

    /* DB */
    {"execSQLQuery", ntop_interface_exec_sql_query},

    /* sFlow */
    {"getSFlowDevices", ntop_getsflowdevices},
    {"getSFlowDeviceInfo", ntop_getsflowdeviceinfo},

    /* Live Capture */
    {"liveCapture", ntop_interface_live_capture},
    {"stopLiveCapture", ntop_interface_stop_live_capture},
    {"dumpLiveCaptures", ntop_interface_dump_live_captures},

    /* Packet Capture */
    {"captureToPcap", ntop_capture_to_pcap},
    {"isCaptureRunning", ntop_is_capture_running},
    {"stopRunningCapture", ntop_stop_running_capture},

    /* Alerts */
    {"alert_store_query", ntop_interface_alert_store_query},
    {"alert_store_write", ntop_interface_alert_store_write},
    {"getCachedAlertValue", ntop_interface_get_cached_alert_value},
    {"setCachedAlertValue", ntop_interface_set_cached_alert_value},
    {"storeTriggeredAlert", ntop_interface_store_triggered_alert},
    {"releaseTriggeredAlert", ntop_interface_release_triggered_alert},
    {"triggerExternalAlert", ntop_interface_store_external_alert},
    {"releaseExternalAlert", ntop_interface_release_external_alert},
    {"checkContext", ntop_interface_check_context},
    {"getEngagedAlerts", ntop_interface_get_engaged_alerts},
    {"getAlerts", ntop_interface_get_alerts},
    {"releaseEngagedAlerts", ntop_interface_release_engaged_alerts},
    {"updateIPReassignment", ntop_interface_update_ip_reassignment},
    {"triggerTrafficAlert", ntop_interface_trigger_traffic_alert},
    {"getHostAttributes", ntop_interface_get_host_attributes},
    {"getHostTags", ntop_interface_get_host_tags},
    {"getUserDefinedHostTags", ntop_interface_get_user_defined_host_tags},
    {"setHostTags", ntop_interface_set_host_tags},

    {"addDataToLocalHostAssets", ntop_add_data_to_assets},
    {"removeDataFromLocalHostAssets", ntop_remove_data_from_assets},

    /* eBPF, Containers and Companion Interfaces */
    {"getPodsStats", ntop_interface_get_pods_stats},
    {"getContainersStats", ntop_interface_get_containers_stats},
    {"reloadCompanions", ntop_interface_reload_companions},

    /* Syslog */
    {"isSyslogInterface", ntop_interface_is_syslog_interface},
    {"incSyslogStats", ntop_interface_inc_syslog_stats},

    /* SubInterface (disaggregation) */
    {"isSubInterface", ntop_interface_is_sub_interface},
    {"getMasterInterfaceId", ntop_get_master_interface_id},

    /* ClickHouse */
    {"clickhouseExecCSVQuery", ntop_clickhouse_exec_csv_query},
    {"clickhouseArchiveData", ntop_clickhouse_archive_data},
    {"execSQLWrite", ntop_clickhouse_exec_sql_write},
    {"chTsEnqueue", ntop_interface_ch_ts_enqueue},
    {"chTsDequeue", ntop_interface_ch_ts_dequeue},
    {"chTsQueueLen", ntop_interface_ch_ts_queue_len},

    /* DNS Cache */
    {"swapHostnameIPCache", ntop_swap_hostname_ip_cache},

    /* Aggregated Flows */
    {"aggregateASNFlows", ntop_aggregate_asn_flows},
    {"execInMemoryQuery", ntop_exec_in_memory_sql_query},
#ifdef NTOPNG_PRO
    {"aggregateSiteFlows", ntop_aggregate_site_flows},

    /* Ranking */
    {"updateRanking", ntop_update_ranking},
#endif

    {NULL, NULL}};

luaL_Reg* ntop_interface_reg = _ntop_interface_reg;

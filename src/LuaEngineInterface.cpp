/*
 *
 * (C) 2013-25 - ntop.org
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

static NetworkInterface *handle_null_interface(lua_State *vm) {
  char allowed_ifname[MAX_INTERFACE_NAME_LEN];

  // this is normal, no need to generate a trace
  // ntop->getTrace()->traceEvent(TRACE_INFO, "NULL interface: did you restart
  // ntopng in the meantime?");

  if (ntop->getInterfaceAllowed(vm, allowed_ifname))
    return ntop->getNetworkInterface(allowed_ifname);

  return (ntop->getFirstInterface());
}

/* ****************************************** */

NetworkInterface *getCurrentInterface(lua_State *vm) {
  NetworkInterface *curr_iface;

  curr_iface = getLuaVMUserdata(vm, iface);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  return (curr_iface ? curr_iface : handle_null_interface(vm));
}

/* ****************************************** */

bool matches_allowed_ifname(char *allowed_ifname, char *iface) {
  return (
      ((allowed_ifname == NULL) ||
       (allowed_ifname[0] == '\0')) /* Periodic script / unrestricted user */
      || (!strncmp(allowed_ifname, iface, strlen(allowed_ifname))));
}

/* ****************************************** */

static int ntop_get_interface_names(lua_State *vm) {
  char *allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);
  bool exclude_viewed_interfaces = false;

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    exclude_viewed_interfaces = lua_toboolean(vm, 1) ? true : false;

  lua_newtable(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  for (int i = 0; i < ntop->get_num_interfaces(); i++) {
    NetworkInterface *iface;
    /*
      We should not call ntop->getInterfaceAtId() as it
      manipulates the vm that has been already modified with
      lua_newtable(vm) a few lines above.
    */

    if ((iface = ntop->getInterface(i)) != NULL) {
      char num[8], *ifname = iface->get_name();

      if (matches_allowed_ifname(allowed_ifname, ifname) &&
          (!exclude_viewed_interfaces || !iface->isViewed())) {
        ntop->getTrace()->traceEvent(TRACE_DEBUG, "Returning name [%d][%s]", i,
                                     ifname);
        snprintf(num, sizeof(num), "%d", iface->get_id());
        lua_push_str_table_entry(vm, num, ifname);
      }
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_first_interface_id(lua_State *vm) {
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  iface = ntop->getFirstInterface();

  if (iface) {
    lua_pushinteger(vm, iface->get_id());
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

static int ntop_select_interface(lua_State *vm) {
  char *ifname;
  bool already_set = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNIL)
    ifname = (char *)"any";
  else {
    if (lua_type(vm, 1) == LUA_TSTRING)
      ifname = (char *)lua_tostring(vm, 1);
    else if(lua_type(vm, 1) == LUA_TNUMBER) {
      int ifid = lua_tonumber(vm, 1);

      getLuaVMUservalue(vm, iface) = ntop->getNetworkInterface(vm, ifid);
      already_set = true;
    } else
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if(!already_set)
    getLuaVMUservalue(vm, iface) = ntop->getNetworkInterface(ifname, vm);

  // lua_pop(vm, 1); /* Cleanup the Lua stack */
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_mac(lua_State *vm) {
  NetworkInterface *iface;
  char buf[32];
  u_int8_t *ifMac;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((iface = getCurrentInterface(vm)) == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  ifMac = iface->getIfMac();

  lua_pushstring(vm, Utils::formatMac(ifMac, buf, sizeof(buf)));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_id(lua_State *vm) {
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((iface = getCurrentInterface(vm)) == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  lua_pushinteger(vm, iface->get_id());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_master_interface_id(lua_State *vm) {
  NetworkInterface *iface = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    const char *ifname = lua_tostring(vm, 1);
    iface = ntop->getNetworkInterface(ifname, vm);

  } else if (lua_type(vm, 1) == LUA_TNUMBER) {
    int ifid = lua_tointeger(vm, 1);
    iface = ntop->getNetworkInterface(vm, ifid);

  } else {
    iface = getCurrentInterface(vm);
  }

  if (iface == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (iface->isSubInterface())
    lua_pushinteger(vm, iface->getMasterInterface()->get_id());
  else
    lua_pushinteger(vm, iface->get_id());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_name(lua_State *vm) {
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((iface = getCurrentInterface(vm)) == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  lua_pushstring(vm, iface->get_name());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_is_valid_interface_id(lua_State *vm) {
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
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_max_if_speed(lua_State *vm) {
  char *ifname = NULL;
  int ifid;
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    ifname = (char *)lua_tostring(vm, 1);
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef NTOPNG_PRO
/**
 * @brief Get the SNMP statistics of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_interface_get_snmp_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  nDPIStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getFlowInterfacesStats()) {
    curr_iface->getFlowInterfacesStats()->lua(vm, curr_iface);
    
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    lua_pushnil(vm);
    
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
}
#endif

/* ****************************************** */

static int ntop_interface_has_vlans(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    lua_pushboolean(vm, curr_iface->hasSeenVLANTaggedPackets());
  else
    lua_pushboolean(vm, 0);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_has_ebpf(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    lua_pushboolean(vm, curr_iface->hasSeenEBPFEvents());
  else
    lua_pushboolean(vm, 0);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_has_external_alerts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    lua_pushboolean(vm, curr_iface->hasSeenExternalAlerts());
  else
    lua_pushboolean(vm, 0);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

// *** API ***
static int ntop_interface_is_packet_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  lua_pushboolean(vm, curr_iface->isPacketInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

// *** API ***
static int ntop_interface_is_discoverable_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  lua_pushboolean(vm, curr_iface->isDiscoverableInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_bridge_interface(lua_State *vm) {
  int ifid;
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((lua_type(vm, 1) == LUA_TNUMBER)) {
    ifid = lua_tointeger(vm, 1);

    if (ifid < 0 || !(iface = ntop->getInterfaceById(ifid)))
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  lua_pushboolean(vm, iface->is_bridge_interface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_pcap_dump_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getIfType() == interface_type_PCAP_DUMP)
    rv = true;

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_database_view_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getIfType() == interface_type_DB_VIEW)
    rv = true;

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_zmq_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getIfType() == interface_type_ZMQ)
    rv = true;

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_view(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isView();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_viewed_by(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface && curr_iface->isViewed())
    lua_pushinteger(vm, curr_iface->viewedBy()->get_id());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_viewed(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isViewed();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_loopback(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isLoopback();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_running(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->isRunning();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_is_idle(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) rv = curr_iface->idle();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_set_idle(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool state;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((!curr_iface) || (!ntop->isUserAdministrator(vm))) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  state = lua_toboolean(vm, 1) ? true : false;

  curr_iface->setIdleState(state);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_dump_live_captures(lua_State *vm) {
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  iface->dumpLiveCaptures(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

AddressTree *get_allowed_nets(lua_State *vm) {
  AddressTree *ptree;

  ptree = getLuaVMUserdata(vm, allowedNets);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return (ptree);
}

/* ****************************************** */

static int ntop_add_data_to_assets(lua_State *vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  char *host = NULL, *field = NULL, *value = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING) /* Host provided in IP@VLAN format */
    host = (char *)lua_tostring(vm, 1);

  if (host != NULL && strlen(host) > 0) {
    Host *h;
    char host_ip[64];
    char *key;
    u_int16_t vlan_id = 0;

    get_host_vlan_info(host, &key, &vlan_id, host_ip, sizeof(host_ip));

    if ((!iface) || 
        ((h = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
				  getLuaVMUservalue(vm, observationPointId))) == NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate host %s",
                                   host_ip);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    }

    if (h->isLocalHost()) {
      /* Available only for local hosts */
      if (lua_type(vm, 2) == LUA_TSTRING) /* Field provided */
        field = (char *)lua_tostring(vm, 2);
        
      if (lua_type(vm, 3) == LUA_TSTRING) /* Value provided */
        value = (char *)lua_tostring(vm, 3);

      if (!h->addDataToAssets(field, value)) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Error while updating [%s] Asset Map [field: %s][value :%s]",
                                  host ? host : "NULL",
                                  field ? field : "NULL", 
                                  value ? value : "NULL");
        return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
      }
    }
  }
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_remove_data_from_assets(lua_State *vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  char *host = NULL, *field = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING) /* Host provided in IP@VLAN format */
    host = (char *)lua_tostring(vm, 1);

  if (host != NULL && strlen(host) > 0) {
    Host *h;
    char host_ip[64];
    char *key;
    u_int16_t vlan_id = 0;

    get_host_vlan_info(host, &key, &vlan_id, host_ip, sizeof(host_ip));

    if ((!iface) || 
        ((h = iface->findHostByIP(get_allowed_nets(vm), host_ip,
				  vlan_id, getLuaVMUservalue(vm, observationPointId))) == NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate host %s",
                                   host_ip);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    }

    if (h->isLocalHost()) {
      /* Available only for local hosts */
      if (lua_type(vm, 2) == LUA_TSTRING) /* Field provided */
        field = (char *)lua_tostring(vm, 2);

      if (!h->removeDataFromAssets(field)) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Error while updating [%s] Asset Map [field: %s]",
                                  host ? host : "NULL",
                                  field ? field : "NULL");
        return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
      }
    }
  }
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_live_capture(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  NtopngLuaContext *c;
  int capture_id, duration;
  char *host = NULL;
  char *bpf = NULL;
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!ntop->isPcapDownloadAllowed(vm, curr_iface->get_name()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING) /* Host provided */
    host = (char *)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  duration = (u_int32_t)lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  bpf = (char *)lua_tostring(vm, 3);

  if (host != NULL && strlen(host) > 0) {
    Host *h;
    char host_ip[64];
    char *key;
    u_int16_t vlan_id = 0;

    get_host_vlan_info(host, &key, &vlan_id, host_ip, sizeof(host_ip));

    if ((!curr_iface) ||
        ((h = curr_iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
				       getLuaVMUservalue(vm, observationPointId))) == NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate host %s",
                                   host_ip);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
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
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Using capture filter '%s'",
  // bpf);

  if (bpf[0] != '\0') {
    pcap_t *pcap_handle = pcap_open_dead(iface->get_datalink(), 65535);
    if (pcap_handle) {
      if (pcap_compile(pcap_handle, &c->live_capture.fcode, bpf, 0, PCAP_NETMASK_UNKNOWN) == -1)
        ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Unable to set capture filter %s. Filter ignored.",
          bpf);
      else
        c->live_capture.bpfFilterSet = true;
      pcap_close(pcap_handle);
    }
  }

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
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_stop_live_capture(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  int capture_id;
  bool rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  capture_id = (int)lua_tointeger(vm, 1);

  rc = curr_iface->stopLiveCapture(capture_id);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Stopping live capture %d: %s",
                               capture_id, rc ? "stopped" : "error");

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_name2id(lua_State *vm) {
  char *if_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNIL)
    if_name = NULL;
  else {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    if_name = (char *)lua_tostring(vm, 1);
  }

  lua_pushinteger(vm, ntop->getInterfaceIdByName(vm, if_name));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_reset_counters(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool only_drops = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    only_drops = lua_toboolean(vm, 1) ? true : false;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->checkPointCounters(only_drops);
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_reset_host_stats(lua_State *vm, bool delete_data) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char buf[64], *host_ip;
  Host *host;
  u_int16_t vlan_id;
  bool reset_blacklisted = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if (lua_type(vm, 2) == LUA_TBOOLEAN) {
    reset_blacklisted = lua_toboolean(vm, 2) ? true : false;
  }

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  host =
      curr_iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
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
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static inline int ntop_interface_reset_host_stats(lua_State *vm) {
  return (ntop_interface_reset_host_stats(vm, false));
}

/* ****************************************** */

static int ntop_interface_delete_host_data(lua_State *vm) {
  return (ntop_interface_reset_host_stats(vm, true));
}

/* ****************************************** */

static int ntop_interface_reset_mac_stats(lua_State *vm, bool delete_data) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *mac;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  mac = (char *)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushboolean(vm, curr_iface->resetMacStats(vm, mac, delete_data));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static inline int ntop_interface_reset_mac_stats(lua_State *vm) {
  return (ntop_interface_reset_mac_stats(vm, false));
}

/* ****************************************** */

static int ntop_interface_delete_mac_data(lua_State *vm) {
  return (ntop_interface_reset_mac_stats(vm, true));
}

/* ****************************************** */

static int ntop_interface_exec_sql_query(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool limit_rows = true;  // honour the limit by default
  bool wait_for_db_created = true;
  char *sql;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((sql = (char *)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 2) == LUA_TBOOLEAN) {
    limit_rows = lua_toboolean(vm, 2) ? true : false;
  }

  if (lua_type(vm, 3) == LUA_TBOOLEAN) {
    wait_for_db_created = lua_toboolean(vm, 3) ? true : false;
  }

  /* In case the users login is disabled, the users have not the ability to run
   * queries, check if the users login is enabled or not
   */
  if (!ntop->hasCapability(vm, capability_historical_flows)
      && ntop->getPrefs()->is_users_login_enabled()) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "User is not allowed to run query: %s", sql);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  }

  if (curr_iface->exec_sql_query(vm, sql, limit_rows, wait_for_db_created) < 0)
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_get_pods_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->getPodsStats(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_get_containers_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *pod_filter = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING) pod_filter = (char *)lua_tostring(vm, 1);

  curr_iface->getContainersStats(vm, pod_filter);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
/* ****************************************** */

static int ntop_interface_reload_companions(lua_State *vm) {
  int ifid;
  NetworkInterface *iface;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return CONST_LUA_ERROR;
  ifid = lua_tonumber(vm, 1);

  if ((iface = ntop->getInterfaceById(ifid))) iface->reloadCompanions();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

int ntop_get_alerts(lua_State *vm, AlertableEntity *entity) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  u_int idx = 0;
  ScriptPeriodicity periodicity = no_periodicity;

  if (!entity)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TNUMBER)
    periodicity = (ScriptPeriodicity)lua_tointeger(vm, 1);

  lua_newtable(vm);
  entity->getAlerts(vm, periodicity, alert_none, alert_level_none,
                    alert_role_is_any, &idx);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_get_alerts(lua_State *vm) {
  NtopngLuaContext *c = getLuaVMContext(vm);

  return ntop_get_alerts(vm, c->iface);
}

/* ****************************************** */

static int ntop_interface_store_external_alert(lua_State *vm) {
  AlertEntity entity;
  const char *entity_value;
  NetworkInterface *iface = getCurrentInterface(vm);
  int idx = 1;

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  entity = (AlertEntity)lua_tointeger(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  entity_value = lua_tostring(vm, idx++);

  iface->processExternalAlertable(entity, entity_value, vm, idx,
                                  true /* store alert */);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_release_triggered_alert(lua_State *vm) {
  NtopngLuaContext *c = getLuaVMContext(vm);

  return (ntop_release_triggered_alert(vm, c->iface, 1));
}

/* ****************************************** */

static int ntop_interface_release_external_alert(lua_State *vm) {
  AlertEntity entity;
  const char *entity_value;
  NetworkInterface *iface = getCurrentInterface(vm);
  int idx = 1;

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  entity = (AlertEntity)lua_tointeger(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  entity_value = lua_tostring(vm, idx++);

  iface->processExternalAlertable(entity, entity_value, vm, idx,
                                  false /* release alert */);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_get_engaged_alerts(lua_State *vm) {
  AlertEntity entity_type = alert_entity_none;
  const char *entity_value = NULL;
  AlertType alert_type = alert_none;
  AlertLevel alert_severity = alert_level_none;
  AlertRole role_filter = alert_role_is_any;
  NetworkInterface *iface = getCurrentInterface(vm);
  AddressTree *allowed_nets = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TNUMBER)
    entity_type = (AlertEntity)lua_tointeger(vm, 1);
  if (lua_type(vm, 2) == LUA_TSTRING)
    entity_value = (char *)lua_tostring(vm, 2);
  if (lua_type(vm, 3) == LUA_TNUMBER)
    alert_type = (AlertType)lua_tointeger(vm, 3);
  if (lua_type(vm, 4) == LUA_TNUMBER)
    alert_severity = (AlertLevel)lua_tointeger(vm, 4);
  if (lua_type(vm, 5) == LUA_TNUMBER)
    role_filter = (AlertRole)lua_tointeger(vm, 5);

  iface->getEngagedAlerts(vm, entity_type, entity_value, alert_type,
                          alert_severity, role_filter, allowed_nets);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_inc_syslog_stats(lua_State *vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  u_int32_t num_received_events;
  u_int32_t num_malformed;
  u_int32_t num_unhandled;
  u_int32_t num_alerts;
  u_int32_t num_host_correlations;
  u_int32_t num_collected_flows;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_received_events = lua_tonumber(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_malformed = lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_unhandled = lua_tonumber(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_alerts = lua_tonumber(vm, 4);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_host_correlations = lua_tonumber(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_collected_flows = lua_tonumber(vm, 6);

  iface->incSyslogStats(0, num_malformed, num_received_events, num_unhandled,
                        num_alerts, num_host_correlations, num_collected_flows);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_alert_store_query(lua_State *vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  char *query = NULL;
  bool limit_rows = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Query */
  if (lua_type(vm, 1) == LUA_TSTRING) query = (char *)lua_tostring(vm, 1);

  /* Optional: interface id */
  if (lua_type(vm, 2) == LUA_TNUMBER) {
    int ifid = lua_tointeger(vm, 2);

    iface = ntop->getInterfaceById(ifid);
  }

  /* Optional: limit rows  */
  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    limit_rows = lua_toboolean(vm, 3) ? true : false;

  if (!iface || !query || !iface->alert_store_query(vm, query, limit_rows)) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifndef HAVE_NEDGE
static int ntop_process_flow(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) != LUA_TTABLE)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!dynamic_cast<ParserInterface *>(curr_iface))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TTABLE) {
    ParserInterface *ntop_parser_interface =
        dynamic_cast<ParserInterface *>(curr_iface);
    ParsedFlow flow;
    flow.fromLua(vm, 1);
    ntop_parser_interface->processFlow(&flow);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_update_syslog_producers(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  SyslogParserInterface *syslog_parser_interface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  syslog_parser_interface =
      dynamic_cast<SyslogParserInterface *>(curr_iface);
  if (!syslog_parser_interface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  syslog_parser_interface->updateProducersMapping();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_all_zmq_flow_field_descr(lua_State *vm) {
#ifdef HAVE_ZMQ
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  ZMQParserInterface *zmq_curr_iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface ||
      !(zmq_curr_iface =
            dynamic_cast<ZMQParserInterface *>(curr_iface)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  zmq_curr_iface->luaGetAllKeyDescription(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#else
  return (-1);
#endif
}

/* ****************************************** */

static int ntop_get_zmq_flow_field_descr(lua_State *vm) {
#ifdef HAVE_ZMQ
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  ZMQParserInterface *zmq_curr_iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface ||
      !(zmq_curr_iface =
            dynamic_cast<ZMQParserInterface *>(curr_iface)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  char *key = (char *)lua_tostring(vm, 1);
  u_int32_t pen = UNKNOWN_PEN, field = UNKNOWN_FLOW_ELEMENT;
  const char *descr;

  if (zmq_curr_iface->getKeyId((char *)key, strlen(key), &pen, &field) &&
      (descr = zmq_curr_iface->getKeyDescription(pen, field)))
    lua_pushstring(vm, descr);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#else
  return (-1);
#endif
}
#endif

/* ****************************************** */

static int ntop_get_host_pools_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (curr_iface && curr_iface->getHostPools()) {
    lua_newtable(vm);
    curr_iface->getHostPools()->lua(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/**
 * @brief Get the Host Pool statistics of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_pools_interface_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface && curr_iface->getHostPools()) {
    curr_iface->luaHostPoolsStats(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/**
 * @brief Get the Host Pool statistics for a pool of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_pool_interface_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  HostPools *hp;
  u_int64_t pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  pool_id = (u_int16_t)lua_tonumber(vm, 1);

  if (curr_iface && (hp = curr_iface->getHostPools())) {
    lua_newtable(vm);
    hp->luaStats(vm, pool_id);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

#ifdef NTOPNG_PRO

/**
 * @brief Get the Host statistics corresponding to the amount of host quotas
 * used
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_used_quotas_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  Host *h;
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[128];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((!curr_iface))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if ((h = curr_iface->getHost(host_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId),
                                   false /* Not an inline call */)))
    h->luaUsedQuotas(vm);
  else
    lua_newtable(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

#endif

/* ****************************************** */

static int ntop_get_ndpi_interface_flows_count(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) {
    lua_newtable(vm);
    curr_iface->getnDPIFlowsCount(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_interface_flows_status(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) {
    lua_newtable(vm);
    curr_iface->getFlowsStatus(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_protocol_name(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto = (u_int32_t)lua_tonumber(vm, 1);

  if (proto == HOST_FAMILY_ID)
    lua_pushstring(vm, "Host-to-Host Contact");
  else {
    if (curr_iface)
      lua_pushstring(vm, curr_iface->get_ndpi_proto_name(proto));
    else
      lua_pushnil(vm);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_full_protocol_name(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  ndpi_protocol proto;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto.proto.master_protocol = (u_int32_t)lua_tonumber(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto.proto.app_protocol = (u_int32_t)lua_tonumber(vm, 2);

  if (curr_iface)
    lua_pushstring(
        vm, curr_iface->get_ndpi_full_proto_name(proto, buf, sizeof(buf)));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_protocol_id(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  char *proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto = (char *)lua_tostring(vm, 1);

  if (curr_iface && proto)
    lua_pushinteger(vm, curr_iface->get_ndpi_proto_id(proto));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_category_id(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  char *category;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  category = (char *)lua_tostring(vm, 1);

  if (curr_iface && category)
    lua_pushinteger(vm, curr_iface->get_ndpi_category_id(category));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_category_name(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  ndpi_protocol_category_t category;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  category = (ndpi_protocol_category_t)((int)lua_tonumber(vm, 1));

  if (curr_iface)
    lua_pushstring(vm, curr_iface->get_ndpi_category_name(category));
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Same as ntop_get_ndpi_protocol_name() with the exception that the
 * protocol breed is returned
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if curr_iface is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_ndpi_protocol_breed(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  nDPIStats stats;
  int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto = (u_int32_t)lua_tonumber(vm, 1);

  if (proto == HOST_FAMILY_ID)
    lua_pushstring(vm, "Unrated-to-Host Contact");
  else {
    if (curr_iface)
      lua_pushstring(vm, curr_iface->get_ndpi_proto_breed_name(proto));
    else
      lua_pushnil(vm);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* This function is used by lua/rest/v2/charts/host/map.lua */

static int ntop_get_interface_hosts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
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
      (curr_iface->walkActiveHosts(vm, host_walk_mode, maxHits,
                                       networkIdFilter, localHostsOnly,
                                       treeMapMode) >= 0))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

static int ntop_get_batched_interface_hosts(lua_State *vm,
                                            LocationPolicy location,
                                            bool tsLua = false) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool show_details = true, filtered_hosts = false, blacklisted_hosts = false;
  char *sortColumn = (char *)"column_ip", *country = NULL, *mac_filter = NULL;
  OSType os_filter = os_any;
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

  if ((!curr_iface) ||
      curr_iface->getActiveHostsList(vm, &begin_slot, walk_all,
					 0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
					 get_allowed_nets(vm), show_details, location, country, mac_filter,
					 vlan_filter, os_filter, asn_filter, network_filter, pool_filter,
					 filtered_hosts, blacklisted_hosts, ipver_filter, proto_filter,
					 traffic_type_filter, 0 /* probe ip */,
					 tsLua /* host->tsLua | host->lua */, anomalousOnly, dhcpOnly,
					 NULL /* cidr filter */, sortColumn, maxHits, toSkip,
					 a2zSortOrder, false) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_hosts_criteria(lua_State *vm,
                                             LocationPolicy location) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool show_details = true, filtered_hosts = false, blacklisted_hosts = false;
  char *sortColumn = (char *)"column_ip", *country = NULL, *mac_filter = NULL;
  bool a2zSortOrder = true;
  OSType os_filter = os_any;
  u_int16_t vlan_filter = (u_int16_t)-1;
  u_int32_t asn_filter = (u_int32_t)-1;
  int32_t network_filter = -2;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t ipver_filter = 0;
  TrafficType traffic_type_filter = traffic_type_all;
  int proto_filter = -1;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int32_t device_ip = 0;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  bool anomalousOnly = false;
  bool dhcpOnly = false, cidr_filter_enabled = false;
  AddressTree cidr_filter;
  bool arrayFormat = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    show_details = lua_toboolean(vm, 1) ? true : false;
  if (lua_type(vm, 2) == LUA_TSTRING) sortColumn = (char *)lua_tostring(vm, 2);
  if (lua_type(vm, 3) == LUA_TNUMBER) maxHits = (u_int32_t)lua_tonumber(vm, 3);
  if (lua_type(vm, 4) == LUA_TNUMBER) toSkip = (u_int32_t)lua_tonumber(vm, 4);
  if (lua_type(vm, 5) == LUA_TBOOLEAN)
    a2zSortOrder = lua_toboolean(vm, 5) ? true : false;
  if (lua_type(vm, 6) == LUA_TSTRING) country = (char *)lua_tostring(vm, 6);
  if (lua_type(vm, 7) == LUA_TNUMBER) os_filter = (OSType)lua_tointeger(vm, 7);
  if (lua_type(vm, 8) == LUA_TNUMBER)
    vlan_filter = (u_int16_t)lua_tonumber(vm, 8);
  if (lua_type(vm, 9) == LUA_TNUMBER)
    asn_filter = (u_int32_t)lua_tonumber(vm, 9);
  if (lua_type(vm, 10) == LUA_TNUMBER)
    network_filter = (int32_t)lua_tonumber(vm, 10);
  if (lua_type(vm, 11) == LUA_TSTRING)
    mac_filter = (char *)lua_tostring(vm, 11);
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
  if (lua_type(vm, 21) == LUA_TSTRING)
    device_ip = ntohl(inet_addr(lua_tostring(vm, 21)));
  if (lua_type(vm, 22) == LUA_TBOOLEAN)
    arrayFormat = (lua_toboolean(vm, 22));

  if ((!curr_iface) ||
      curr_iface->getActiveHostsList(vm, &begin_slot, walk_all,
					 0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
					 get_allowed_nets(vm), show_details, location, country, mac_filter,
					 vlan_filter, os_filter, asn_filter, network_filter, pool_filter,
					 filtered_hosts, blacklisted_hosts, ipver_filter, proto_filter,
					 traffic_type_filter, device_ip, false /* host->lua */, anomalousOnly,
					 dhcpOnly, cidr_filter_enabled ? &cidr_filter : NULL, sortColumn,
					 maxHits, toSkip, a2zSortOrder, arrayFormat) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* Receives in input a Lua table, having mac address as keys and tables as
 * values. Every IP address found for a mac is inserted into the table as an
 * 'ip' field. */
static int ntop_add_macs_ip_addresses(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TTABLE) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((!curr_iface) || curr_iface->getMacsIpAddresses(vm, 1) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static u_int8_t str_2_location(const char *s) {
  if (!strcmp(s, "lan"))
    return located_on_lan_interface;
  else if (!strcmp(s, "wan"))
    return located_on_wan_interface;
  else if (!strcmp(s, "unknown"))
    return located_on_unknown_interface;
  return (u_int8_t)-1;
}

/* ****************************************** */

static int ntop_get_interface_active_macs(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if(!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    curr_iface->getActiveMacs(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_get_interface_macs_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *sortColumn = (char *)"column_mac";
  const char *manufacturer = NULL;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t devtype_filter = (u_int8_t)-1;
  bool a2zSortOrder = true, sourceMacsOnly = false;
  u_int8_t location_filter = (u_int8_t)-1;
  u_int32_t begin_slot = 0;
  time_t min_first_seen = 0;
  bool walk_all = true;

  if (lua_type(vm, 1) == LUA_TSTRING) sortColumn = (char *)lua_tostring(vm, 1);
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

  if (!curr_iface ||
      curr_iface->getActiveMacList(vm, &begin_slot, walk_all,
				       0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
				       sourceMacsOnly, manufacturer, sortColumn, maxHits, toSkip,
				       a2zSortOrder, pool_filter, devtype_filter, location_filter,
				       min_first_seen) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_batched_interface_macs_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *sortColumn = (char *)"column_mac";
  const char *manufacturer = NULL;
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
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_mac_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *mac = NULL;

  if (lua_type(vm, 1) == LUA_TSTRING) mac = (char *)lua_tostring(vm, 1);

  if ((!curr_iface) || (!mac) || (!curr_iface->getMacInfo(vm, mac)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_mac_hosts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *mac = NULL;

  if (lua_type(vm, 1) == LUA_TSTRING) mac = (char *)lua_tostring(vm, 1);

  lua_newtable(vm);

  if (curr_iface) curr_iface->getActiveMacHosts(vm, mac);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_set_host_operating_system(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip = NULL, buf[64];
  u_int16_t vlan_id = 0;
  OSType os = os_unknown;
  Host *host;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  os = (OSType)lua_tointeger(vm, 2);

  host =
      curr_iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId));

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[iface: %s][host_ip: %s][vlan_id: %u][host: %p][os: %u]",
			       curr_iface->get_name(), host_ip, vlan_id, host, os);
#endif

  if (curr_iface && host && os < os_max_os && os != os_unknown)
    host->setOS(os, os_learning_user_set_via_lua);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_set_host_resolved_name(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip = NULL, buf[64];
  u_int16_t vlan_id = 0;
  char *host_name = NULL;
  Host *host;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  host_name = (char *)lua_tostring(vm, 2);

  host = curr_iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
				  getLuaVMUservalue(vm, observationPointId));

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[iface: %s][host_ip: %s][vlan_id: %u][host: %p][os: %u]",
			       curr_iface->get_name(), host_ip, vlan_id, host, os);
#endif

  if (curr_iface && host && host_name) host->setResolvedName(host_name);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_num_local_hosts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushinteger(vm, curr_iface->getNumLocalHosts());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_num_hosts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushinteger(vm, curr_iface->getNumHosts());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_num_flows(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushinteger(vm, curr_iface->getNumFlows());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_mac_device_types(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int16_t maxHits = CONST_MAX_NUM_HITS;
  bool sourceMacsOnly = false;
  char *manufacturer = NULL;
  u_int8_t location_filter = (u_int8_t)-1;

  if (lua_type(vm, 1) == LUA_TNUMBER) maxHits = (u_int16_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    sourceMacsOnly = lua_toboolean(vm, 2) ? true : false;

  if (lua_type(vm, 3) == LUA_TSTRING)
    manufacturer = (char *)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    location_filter = str_2_location(lua_tostring(vm, 4));

  if ((!curr_iface) ||
      (curr_iface->getActiveDeviceTypes(
           vm, sourceMacsOnly, 0 /* bridge_iface_idx - TODO */, maxHits,
           manufacturer, location_filter) < 0))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_ases_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool diff = false;

  Paginator *p = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TTABLE) p->readOptions(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 2) ? true : false;

  if (curr_iface->getActiveASList(vm, p, diff) < 0) {
    if (p) delete (p);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (p) delete (p);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_obs_points_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  Paginator *p = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TTABLE) p->readOptions(vm, 1);

  if (curr_iface->getActiveObsPointsList(vm, p) < 0) {
    if (p) delete (p);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (p) delete (p);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_insert_ip_acl(lua_State *vm) {
  bool res = false;
#ifdef NTOPNG_PRO
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int8_t protocol = 0;
  u_int16_t l7_proto = 0;
  bool is_allowed = true;
  char *src, *dst, *port;
  
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));  
  protocol = (u_int8_t) lua_tointeger(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  src = (char *)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  dst = (char *)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    port = (char *)lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TNUMBER)
    l7_proto = (u_int16_t) lua_tointeger(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  is_allowed = (bool) lua_toboolean(vm, 6);

  if (curr_iface)
    res = curr_iface->insertIPACL(protocol, src, dst, port, l7_proto, is_allowed);
#endif
  lua_pushboolean(vm, res);
  
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_remove_ip_acl(lua_State *vm) {
  bool res = false;

#ifdef NTOPNG_PRO
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int8_t protocol = 0;
  u_int16_t l7_proto = 0;
  char *src, *dst, *port;
  
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  protocol = (u_int8_t) lua_tointeger(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  src = (char *)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  dst = (char *)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    port = (char *)lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TNUMBER)
    l7_proto = (u_int16_t) lua_tointeger(vm, 5);

  if (curr_iface)
    res = curr_iface->removeIPACL(protocol, src, dst, port, l7_proto);
#endif
  
  lua_pushboolean(vm, res);
  
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_insert_mac_acl(lua_State *vm) {
  bool res = false;
#ifdef NTOPNG_PRO
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *mac_string;
  u_int32_t _mac[6];
  bool is_allowed = true;
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac_string = (char *) lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    is_allowed = (bool) lua_toboolean(vm, 2);

  if (sscanf(mac_string, "%02X:%02X:%02X:%02X:%02X:%02X", &_mac[0], &_mac[1],
              &_mac[2], &_mac[3], &_mac[4], &_mac[5])) {
    u_int8_t mac[6];
    for (int i = 0; i < 6; i++) mac[i] = (u_int8_t)_mac[i];
    if (curr_iface) res = curr_iface->insertMacACL(mac, is_allowed);
  }
#endif
  lua_pushboolean(vm, res);
  
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_remove_mac_acl(lua_State *vm) {
  bool res = false;
#ifdef NTOPNG_PRO
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *mac_string;
  u_int32_t _mac[6];
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac_string = (char *) lua_tostring(vm, 1);

  if (sscanf(mac_string, "%02X:%02X:%02X:%02X:%02X:%02X", &_mac[0], &_mac[1],
              &_mac[2], &_mac[3], &_mac[4], &_mac[5])) {
    u_int8_t mac[6];
    for (int i = 0; i < 6; i++) mac[i] = (u_int8_t)_mac[i];
    if (curr_iface) res = curr_iface->removeMacACL(mac);
  }
#endif
  lua_pushboolean(vm, res);
  
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_get_acl_info(lua_State *vm) {
  lua_newtable(vm);
#ifdef NTOPNG_PRO
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  if (curr_iface) {
    curr_iface->getACLInfo(vm);
  }
#endif  
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_get_throughput(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_push_float_table_entry(vm, "throughput_bps",
                             curr_iface->getThroughputBps());
  lua_push_float_table_entry(vm, "throughput_pps",
                             curr_iface->getThroughputPps());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_protocol_flows_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->getFilteredLiveFlowsStats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_vlan_flows_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->getVLANFlowsStats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_hosts_ports(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->getHostsPorts(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_hosts_by_port(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->getHostsByPort(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* Function used to start the accounting of an Host */
static int ntop_radius_accounting_start(lua_State *vm) {
  bool res = false;

#ifdef HAVE_RADIUS
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  RadiusTraffic traffic_data;

  memset(&traffic_data, 0, sizeof(traffic_data));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING)
    traffic_data.username = (char *)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING)
    traffic_data.mac = (char *)lua_tostring(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING)
    traffic_data.session_id = (char *)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    traffic_data.last_ip = (char *)lua_tostring(vm, 4);

  if (lua_type(vm, 5) == LUA_TSTRING)
    traffic_data.time = (u_int32_t)lua_tonumber(vm, 5);

  traffic_data.nas_port_name = curr_iface->get_name();
  traffic_data.nas_port_id = curr_iface->get_id();

  res = ntop->radiusAccountingStart(&traffic_data);
#endif

  lua_pushboolean(vm, res);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_radius_accounting_stop(lua_State *vm) {
  bool res = false;

#ifdef HAVE_RADIUS
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  RadiusTraffic traffic_data;

  memset(&traffic_data, 0, sizeof(traffic_data));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING)
    traffic_data.username = (char *)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING)
    traffic_data.session_id = (char *)lua_tostring(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING)
    traffic_data.mac = (char *)lua_tostring(vm, 3);

  if (lua_type(vm, 4) == LUA_TSTRING)
    traffic_data.last_ip = (char *)lua_tostring(vm, 4);

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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_hosts_by_service(lua_State *vm) {
   NetworkInterface *curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->getHostsByService(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_radius_accounting_update(lua_State *vm) {
  bool res = false;
#ifdef HAVE_RADIUS
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  RadiusTraffic traffic_data;

  memset(&traffic_data, 0, sizeof(traffic_data));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING)
    traffic_data.mac = (char *)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING)
    traffic_data.session_id = (char *)lua_tostring(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING)
    traffic_data.username = (char *)lua_tostring(vm, 3);

  /* Unused
  if (lua_type(vm, 4) == LUA_TSTRING)
    password = (const char *)lua_tostring(vm, 4);
  */

  if (lua_type(vm, 5) == LUA_TSTRING)
    traffic_data.last_ip = (char *)lua_tostring(vm, 5);

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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_anomalies(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->luaAnomalies(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_interface_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool diff = false;

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 4) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 1) ? true : false;

  curr_iface->luaNdpiStats(vm, diff);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_score(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->luaScore(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_countries_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  Paginator *p = NULL;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TTABLE) p->readOptions(vm, 1);

  if (curr_iface->getActiveCountriesList(vm, p) < 0) {
    if (p) delete (p);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (p) delete (p);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_convert_country_code_to_u16(lua_State *vm) {
  const char *country_code;
  u_int16_t country_u16;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  country_code = lua_tostring(vm, 1);

  country_u16 = Utils::countryCode2U16(country_code);
  lua_pushinteger(vm, country_u16);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_convert_country_u16_to_code(lua_State *vm) {
  char country_code[3];
  u_int16_t country_u16;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  country_u16 = lua_tonumber(vm, 1);

  lua_pushstring(vm, Utils::countryU162Code(country_u16, country_code,
                                            sizeof(country_code)));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_country_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  const char *country;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  country = lua_tostring(vm, 1);

  if ((!curr_iface) || (!curr_iface->getCountryInfo(vm, country)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_vlans_list(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if ((!curr_iface) || curr_iface->getActiveVLANList(
                               vm, (char *)"column_vlan", CONST_MAX_NUM_HITS, 0,
                               true, details_normal /* Minimum details */) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_vlans_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *sortColumn = (char *)"column_vlan";
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  bool a2zSortOrder = true;
  DetailsLevel details_level = details_higher;

  if (lua_type(vm, 1) == LUA_TSTRING) {
    sortColumn = (char *)lua_tostring(vm, 1);

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
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_as_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int32_t asn;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  asn = (u_int32_t)lua_tonumber(vm, 1);

  if ((!curr_iface) || (!curr_iface->getASInfo(vm, asn)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_obs_point_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int16_t obs_point;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  obs_point = (u_int16_t)lua_tonumber(vm, 1);

  if ((!curr_iface) || (!curr_iface->getObsPointInfo(vm, obs_point)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_vlan_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int16_t vlan_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  vlan_id = (u_int16_t)lua_tonumber(vm, 1);

  if ((!curr_iface) || (!curr_iface->getVLANInfo(vm, vlan_id)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_macs_manufacturers(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
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
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_flows_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char buf[64];
  char *host_ip = NULL, *talking_with_ip = NULL, *server_ip = NULL,
       *client_ip = NULL;
  u_int16_t vlan_id = (u_int16_t)-1;
  Host *host = NULL, *talking_with_host = NULL, *client = NULL, *server = NULL;
  char *flow_info = NULL;
  Paginator *p = NULL;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                       sizeof(buf));
    host = curr_iface->getHost(host_ip, vlan_id,
                                   getLuaVMUservalue(vm, observationPointId),
                                   false /* Not an inline call */);
  }

  if (lua_type(vm, 2) == LUA_TTABLE) p->readOptions(vm, 2);

  if (lua_type(vm, 3) == LUA_TSTRING) {
    get_host_vlan_info((char *)lua_tostring(vm, 3), &talking_with_ip, &vlan_id,
                       buf, sizeof(buf));
    talking_with_host = curr_iface->getHost(
        talking_with_ip, vlan_id, getLuaVMUservalue(vm, observationPointId),
        false /* Not an inline call */);
  }

  if (lua_type(vm, 4) == LUA_TSTRING) {
    get_host_vlan_info((char *)lua_tostring(vm, 4), &client_ip, &vlan_id, buf,
                       sizeof(buf));
    client = curr_iface->getHost(client_ip, vlan_id,
                                     getLuaVMUservalue(vm, observationPointId),
                                     false /* Not an inline call */);
  }

  if (lua_type(vm, 5) == LUA_TSTRING) {
    get_host_vlan_info((char *)lua_tostring(vm, 5), &server_ip, &vlan_id, buf,
                       sizeof(buf));
    server = curr_iface->getHost(server_ip, vlan_id,
                                     getLuaVMUservalue(vm, observationPointId),
                                     false /* Not an inline call */);
  }

  if (lua_type(vm, 6) == LUA_TSTRING) {
    char *tmp = ((char *)lua_tostring(vm, 6));
    if (strlen(tmp) > 0) flow_info = tmp;
  }

  if ((curr_iface) && (!host_ip || host))
    curr_iface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm),
                             host, talking_with_host, client, server, flow_info,
                             p);
  else
    lua_pushnil(vm);

  if (p) delete p;
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_batched_interface_flows_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  Paginator *p = NULL;
  u_int32_t begin_slot = 0;
  bool walk_all = false;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNUMBER)
    begin_slot = (u_int32_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) == LUA_TTABLE) p->readOptions(vm, 2);

  if (curr_iface)
    curr_iface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm),
                             NULL, NULL, NULL, NULL, NULL, p);
  else
    lua_pushnil(vm);

  if (p) delete p;
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_get_grouped_flows(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  Paginator *p = NULL;
  const char *group_col;

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK ||
      (p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  group_col = lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TTABLE) p->readOptions(vm, 2);

  if (curr_iface)
    curr_iface->getFlowsGroup(vm, get_allowed_nets(vm), p, group_col);
  else
    lua_pushnil(vm);

  delete p;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_flows_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface) curr_iface->getFlowsStats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_networks_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool diff = false;

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 1) ? true : false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (curr_iface)
    curr_iface->getNetworksStats(vm, get_allowed_nets(vm), diff);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_local_server_ports(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    curr_iface->localHostsServerPorts(vm);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_network_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int32_t network_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  network_id = (u_int32_t)lua_tointeger(vm, 1);

  if (curr_iface) {
    lua_newtable(vm);
    curr_iface->getNetworkStats(vm, network_id, get_allowed_nets(vm));
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_host_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if ((!curr_iface) ||
      !curr_iface->getHostInfo(vm, get_allowed_nets(vm), host_ip, vlan_id))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_reset_interface_host_top_sites(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if ((!curr_iface) || !curr_iface->resetHostTopSites(
                               get_allowed_nets(vm), host_ip, vlan_id,
                               getLuaVMUservalue(vm, observationPointId)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_host_country(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  Host *h = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if ((!curr_iface) ||
      ((h = curr_iface->findHostByIP(
            get_allowed_nets(vm), host_ip, vlan_id,
            getLuaVMUservalue(vm, observationPointId))) == NULL))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    lua_pushstring(vm, h->get_country(buf, sizeof(buf)));
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_prepare_delete_interface_observation_point(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int16_t obs_point_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  obs_point_id = ((u_int16_t)lua_tonumber(vm, 1));

  if ((!curr_iface) ||
      !(curr_iface->prepareDeleteObsPoint(obs_point_id)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_delete_interface_observation_point(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int16_t obs_point_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  obs_point_id = ((u_int16_t)lua_tonumber(vm, 1));

  if ((!curr_iface) || !(curr_iface->deleteObsPoint(obs_point_id)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef NTOPNG_PRO
static int ntop_get_flow_devices(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);;
  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    curr_iface->getFlowDevices(vm);

  /* Return a table with key, the interface id and as value,
   * a table with the IPs of the interface
   */
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_get_flow_device_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int32_t device_id;
  bool showAllStats = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  device_id = (u_int32_t )lua_tonumber(vm, 1);
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    showAllStats = (bool)lua_toboolean(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    curr_iface->getFlowDeviceInfo(vm, device_id, showAllStats);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_get_flow_device_info_by_ip(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *device_ip;
  bool showAllStats = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  device_ip = (char *)lua_tostring(vm, 1);
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    showAllStats = (bool)lua_toboolean(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    in_addr_t addr = inet_addr(device_ip);

    curr_iface->getFlowDeviceInfoByIP(vm, ntohl(addr), showAllStats);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}
#endif

/* ****************************************** */

static int ntop_discover_iface_hosts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int timeout = 3; /* sec */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TNUMBER) timeout = (u_int)lua_tonumber(vm, 1);

  if (curr_iface->getNetworkDiscovery()) {
    /* TODO: do it periodically and not inline */

    try {
      curr_iface->getNetworkDiscovery()->discover(vm, timeout);
    } catch (...) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to perform network discovery");
    }

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

static int ntop_arpscan_iface_hosts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (curr_iface->getMDNS()) {
    /* This is a device we can use for network discovery */

    try {
      NetworkDiscovery *d;

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      if (Utils::gainWriteCapabilities() == -1)
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

      d = curr_iface->getNetworkDiscovery();

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && !defined(HAVE_NEDGE)
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

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
}

/* ****************************************** */

static int ntop_mdns_batch_any_query(lua_State *vm) {
  char *query, *target;
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((target = (char *)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((query = (char *)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->mdnsSendAnyQuery(target, query);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_mdns_queue_name_to_resolve(lua_State *vm) {
  char *numIP;
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((numIP = (char *)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->mdnsQueueResolveIPv4(inet_addr(numIP), true);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_mdns_read_queued_responses(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->mdnsFetchResolveResponses(vm, 2);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_getsflowdevices(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    curr_iface->getSFlowDevices(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_getsflowdeviceinfo(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *device_ip;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  device_ip = (char *)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    in_addr_t addr = inet_addr(device_ip);

    curr_iface->getSFlowDeviceInfo(vm, ntohl(addr));
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_get_interface_flow_key(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  Host *cli, *srv;
  char *cli_name = NULL;
  u_int16_t cli_port = 0;
  char *srv_name = NULL;
  u_int16_t srv_port = 0;
  u_int16_t cli_vlan = 0, srv_vlan = 0;
  u_int16_t protocol;
  char cli_buf[256], srv_buf[256];

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

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
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  get_host_vlan_info((char *)lua_tostring(vm, 1), &cli_name, &cli_vlan, cli_buf,
                     sizeof(cli_buf));
  cli_port = htons((u_int16_t)lua_tonumber(vm, 2));

  get_host_vlan_info((char *)lua_tostring(vm, 3), &srv_name, &srv_vlan, srv_buf,
                     sizeof(srv_buf));
  srv_port = htons((u_int16_t)lua_tonumber(vm, 4));

  protocol = (u_int16_t)lua_tonumber(vm, 5);

  if (cli_vlan != srv_vlan) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Client and Server vlans don't match.");
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_find_flow_by_key_and_hash_id(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int32_t key;
  u_int hash_id;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);
  bool set_context = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  /* Optional: set context */
  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    set_context = lua_toboolean(vm, 3) ? true : false;

  key = (u_int32_t)lua_tonumber(vm, 1);
  hash_id = (u_int)lua_tonumber(vm, 2);

  if (!curr_iface) return (false);

  f = curr_iface->findFlowByKeyAndHashId(key, hash_id, ptree);

  if (f == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    f->lua(vm, ptree, details_high, false);

    if (set_context) {
      NtopngLuaContext *c = getLuaVMContext(vm);

      c->flow = f, c->iface = f->getInterface();
    }

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_get_interface_find_flow_by_tuple(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  IpAddress src_ip_addr, dst_ip_addr;
  u_int16_t vlan_id, src_port, dst_port;
  u_int8_t l4_proto;
  u_int32_t private_flow_id = 0 /* FIX */;
  char *src_ip, *dst_ip;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) return (false);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  src_ip = (char *)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  dst_ip = (char *)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  vlan_id = (u_int16_t)lua_tonumber(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  src_port = (u_int16_t)lua_tonumber(vm, 4);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  dst_port = (u_int16_t)lua_tonumber(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  l4_proto = (u_int8_t)lua_tonumber(vm, 6);

  src_ip_addr.set(src_ip), dst_ip_addr.set(dst_ip);

  f = curr_iface->findFlowByTuple(
      vlan_id, getLuaVMUservalue(vm, observationPointId), private_flow_id, NULL,
      NULL, /* TODO MAC */
      &src_ip_addr, &dst_ip_addr, htons(src_port), htons(dst_port), l4_proto,
      ptree);

  if (f == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    f->lua(vm, ptree, details_high, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_drop_flow_traffic(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int32_t key;
  u_int hash_id;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  key = (u_int32_t)lua_tonumber(vm, 1);
  hash_id = (u_int)lua_tonumber(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  f = curr_iface->findFlowByKeyAndHashId(key, hash_id, ptree);

  if (f) {
    f->setDropVerdict();
    lua_pushboolean(vm, true);
  } else
    lua_pushboolean(vm, false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_drop_multiple_flows_traffic(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  Paginator *p = NULL;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TTABLE))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  p->readOptions(vm, 1);

  if (curr_iface->dropFlowsTraffic(ptree, p) < 0)
    lua_pushboolean(vm, false);
  else
    lua_pushboolean(vm, true);

  if (p) delete p;
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_find_pid_flows(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int32_t pid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  pid = (u_int32_t)lua_tonumber(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->findPidFlows(vm, pid);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_find_proc_name_flows(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *proc_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proc_name = (char *)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->findProcNameFlows(vm, proc_name);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_list_http_hosts(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) != LUA_TSTRING) /* Optional */
    key = NULL;
  else
    key = (char *)lua_tostring(vm, 1);

  curr_iface->listHTTPHosts(vm, key);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_find_host(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  key = (char *)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  curr_iface->findHostsByName(vm, get_allowed_nets(vm), key);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_find_host_by_mac(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *mac;
  u_int8_t _mac[6];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac = (char *)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  Utils::parseMac(_mac, mac);

  curr_iface->findHostsByMac(vm, _mac);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_is_multicast_mac(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *mac;
  u_int8_t _mac[6];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac = (char *)lua_tostring(vm, 1);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  Utils::parseMac(_mac, mac);

  lua_pushboolean(vm, Utils::isMulticastMac(_mac));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_update_traffic_mirrored(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateTrafficMirrored();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_smart_recording(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateSmartRecording();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_dynamic_interface_traffic_policy(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateDynIfaceTrafficPolicy();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_push_filters_settings(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updatePushFiltersSettings();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_lbd_identifier(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateLbdIdentifier();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_flows_only_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) curr_iface->updateFlowsOnlyInterface();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_host_traffic_policy(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (!curr_iface) return CONST_LUA_ERROR;

  lua_pushboolean(vm, curr_iface->updateHostTrafficPolicy(
                          get_allowed_nets(vm), host_ip, vlan_id));
  return CONST_LUA_OK;
}

/* ****************************************** */

// *** API ***
static int ntop_get_interface_endpoint(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int8_t id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) != LUA_TNUMBER) /* Optional */
    id = 0;
  else
    id = (u_int8_t)lua_tonumber(vm, 1);

  if (curr_iface) {
    char *endpoint = curr_iface->getEndpoint(id); /* CHECK */

    lua_pushfstring(vm, "%s", endpoint ? endpoint : "");
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_protocols(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  ndpi_protocol_category_t category_filter = NDPI_PROTOCOL_ANY_CATEGORY;
  bool skip_critical = false;

  if (curr_iface == NULL) curr_iface = getCurrentInterface(vm);

  if (curr_iface == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((lua_type(vm, 1) == LUA_TNUMBER)) {
    category_filter = (ndpi_protocol_category_t)lua_tointeger(vm, 1);

    if (category_filter >= NDPI_PROTOCOL_NUM_CATEGORIES) {
      lua_pushnil(vm);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
    }
  }
  if ((lua_type(vm, 2) == LUA_TBOOLEAN)) skip_critical = lua_toboolean(vm, 2);

  curr_iface->getnDPIProtocols(vm, category_filter, skip_critical);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_categories(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  lua_newtable(vm);

  for (int i = 0; i < NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
    char buf[8];
    const char *cat_name =
        curr_iface->get_ndpi_category_name((ndpi_protocol_category_t)i);

    if (cat_name && *cat_name) {
      snprintf(buf, sizeof(buf), "%d", i);
      lua_push_str_table_entry(vm, cat_name, buf);
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_load_scaling_factor_prefs(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  curr_iface->loadScalingFactorPrefs();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_reload_gw_macs(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  curr_iface->requestGwMacsReload();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_reload_dhcp_ranges(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  curr_iface->reloadDhcpRanges();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_reload_host_prefs(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char buf[64], *host_ip;
  Host *host;
  u_int16_t vlan_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if ((host = curr_iface->getHost(host_ip, vlan_id,
                                      getLuaVMUservalue(vm, observationPointId),
                                      false /* Not an inline call */)))
    host->reloadPrefs();

  lua_pushboolean(vm, (host != NULL));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static void *pcapDumpLoop(void *ptr) {
  NtopngLuaContext *c = (NtopngLuaContext *)ptr;
  Utils::setThreadName("ntopng-pcap");

  while (c->pkt_capture.captureInProgress) {
    u_char *pkt;
    struct pcap_pkthdr *h;
    int rc = pcap_next_ex(c->pkt_capture.pd, &h, (const u_char **)&pkt);

    if (rc > 0) {
      pcap_dump((u_char *)c->pkt_capture.dumper, (const struct pcap_pkthdr *)h,
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

static int ntop_capture_to_pcap(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int8_t capture_duration;
  char *bpfFilter = NULL, ftemplate[64];
  char errbuf[PCAP_ERRBUF_SIZE];
  struct bpf_program fcode;
  NtopngLuaContext *c;
  int rc;

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (c->pkt_capture.pd != NULL /* Another capture is in progress */)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  capture_duration = (u_int32_t)lua_tonumber(vm, 1);

  if (lua_type(vm, 2) != LUA_TSTRING) /* Optional */
    bpfFilter = (char *)lua_tostring(vm, 2);

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

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
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
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  /* Capture sessions can't be longer than 30 sec */
  if (capture_duration > 30) capture_duration = 30;

  c->pkt_capture.end_capture = time(NULL) + capture_duration;

  c->pkt_capture.captureInProgress = true;
  pthread_create(&c->pkt_capture.captureThreadLoop, NULL, pcapDumpLoop,
                 (void *)c);

  lua_pushstring(vm, ftemplate);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_is_capture_running(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  NtopngLuaContext *c;

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushboolean(
      vm, (c->pkt_capture.pd != NULL /* Another capture is in progress */)
              ? true
              : false);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_stop_running_capture(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  NtopngLuaContext *c;

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  c = getLuaVMContext(vm);

  if ((!curr_iface) || (!c))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  c->pkt_capture.end_capture = 0;

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_hosts_info(lua_State *vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_all));
}

static int ntop_get_interface_local_hosts_info(lua_State *vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_local_only));
}

static int ntop_get_interface_local_hosts_no_tx_info(lua_State *vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_local_only_no_tx));
}

static int ntop_get_interface_local_hosts_no_tcp_tx_info(lua_State *vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_local_only_no_tcp_tx));
}

static int ntop_get_interface_remote_hosts_info(lua_State *vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_remote_only));
}

static int ntop_get_interface_remote_hosts_no_tx_info(lua_State *vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_remote_only_no_tx));
}

static int ntop_get_interface_remote_hosts_no_tcp_tx_info(lua_State *vm) {
  return (
      ntop_get_interface_hosts_criteria(vm, location_remote_only_no_tcp_tx));
}

static int ntop_get_interface_broadcast_domain_hosts_info(lua_State *vm) {
  return (
      ntop_get_interface_hosts_criteria(vm, location_broadcast_domain_only));
}

static int ntop_get_interface_broadcast_multicast_hosts_info (lua_State *vm) {
  return (
      ntop_get_interface_hosts_criteria(vm, location_broadcat_multicast_only));
}

static int ntop_get_public_hosts_info(lua_State *vm) {
  return (ntop_get_interface_hosts_criteria(vm, location_public_only));
}

/* ****************************************** */

static int ntop_get_rxonly_hosts_list(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool local_host_rx_only = false, list_host_peers = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    local_host_rx_only = lua_toboolean(vm, 1) ? true : false;
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    list_host_peers = lua_toboolean(vm, 2) ? true : false;

  curr_iface->getRxOnlyHostsList(vm, local_host_rx_only, list_host_peers);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_batched_interface_hosts_info(lua_State *vm) {
  return (ntop_get_batched_interface_hosts(vm, location_all));
}

static int ntop_get_batched_interface_local_hosts_info(lua_State *vm) {
  return (ntop_get_batched_interface_hosts(vm, location_local_only));
}

static int ntop_get_batched_interface_remote_hosts_info(lua_State *vm) {
  return (ntop_get_batched_interface_hosts(vm, location_remote_only));
}

static int ntop_get_batched_interface_local_hosts_ts(lua_State *vm) {
  return (ntop_get_batched_interface_hosts(vm, location_local_only,
                                           true /* timeseries */));
}

/* ****************************************** */

static int ntop_interface_store_triggered_alert(lua_State *vm) {
  NtopngLuaContext *c = getLuaVMContext(vm);

  return (ntop_store_triggered_alert(vm, c->iface, 1 /* 1st argument of vm */));
}

/* ****************************************** */

static int ntop_get_interface_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool full_stats = true;
  
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    full_stats = lua_toboolean(vm, 1) ? true : false;

  curr_iface->lua(vm, full_stats);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_update_interface_direction_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->updateDirectionStats();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_update_interface_top_sites(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  curr_iface->updateSitesStats();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_stats_update_freq(lua_State *vm) {
  NetworkInterface *curr_iface = NULL;
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_secs_to_first_data(lua_State *vm) {
  NetworkInterface *curr_iface = NULL;
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_hash_tables_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (curr_iface)
    curr_iface->lua_hash_tables_stats(vm);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_periodic_activities_stats(lua_State *vm) {
  NetworkInterface *curr_iface = NULL;
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_queues_stats(lua_State *vm) {
  NetworkInterface *curr_iface = NULL;
  int ifid;

  if (lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    curr_iface = ntop->getInterfaceById(ifid);
  } else
    curr_iface = getCurrentInterface(vm);

  lua_newtable(vm);

  if (curr_iface) curr_iface->lua_queues_stats(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_set_interface_periodic_activity_progress(lua_State *vm) {
  int progress;
  NtopngLuaContext *ctx = getLuaVMContext(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  progress = (int)lua_tonumber(vm, 1);

  if (ctx && ctx->threaded_activity_stats)
    ctx->threaded_activity_stats->setCurrentProgress(progress);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_active_flows_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  nDPIStats ndpi_stats;
  FlowStats stats;
  char *host_ip = NULL, *talking_with_ip = NULL, *server_ip = NULL,
       *client_ip = NULL;
  u_int16_t vlan_id = 0;
  char buf[64];
  bool only_traffic_stats = false;
  Host *host = NULL, *talking_with_host = NULL, *client = NULL, *server = NULL;
  char *flow_info = NULL;
  Paginator *p = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((p = new (std::nothrow) Paginator()) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  /* Optional host */
  if (lua_type(vm, 1) == LUA_TSTRING) {
    char *tmp = (char *)lua_tostring(vm, 1);
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
    char *tmp = (char *)lua_tostring(vm, 4);
    if (strlen(tmp) > 0) {
      get_host_vlan_info(tmp, &talking_with_ip, &vlan_id, buf, sizeof(buf));
      talking_with_host = curr_iface->getHost(
          talking_with_ip, vlan_id, getLuaVMUservalue(vm, observationPointId),
          false /* Not an inline call */);
    }
  }

  if (lua_type(vm, 5) == LUA_TSTRING) {
    char *tmp = (char *)lua_tostring(vm, 5);
    if (strlen(tmp) > 0) {
      get_host_vlan_info(tmp, &client_ip, &vlan_id, buf, sizeof(buf));
      client = curr_iface->getHost(
          client_ip, vlan_id, getLuaVMUservalue(vm, observationPointId),
          false /* Not an inline call */);
    }
  }

  if (lua_type(vm, 6) == LUA_TSTRING) {
    char *tmp = (char *)lua_tostring(vm, 6);
    if (strlen(tmp) > 0) {
      get_host_vlan_info(tmp, &server_ip, &vlan_id, buf, sizeof(buf));
      server = curr_iface->getHost(
          server_ip, vlan_id, getLuaVMUservalue(vm, observationPointId),
          false /* Not an inline call */);
    }
  }

  if (lua_type(vm, 7) == LUA_TSTRING) {
    char *tmp = (char *)lua_tostring(vm, 7);
    if (strlen(tmp) > 0) {
      flow_info = tmp;
    }
  }

  if (curr_iface) {
    curr_iface->getActiveFlowsStats(
        &ndpi_stats, &stats, get_allowed_nets(vm), host, talking_with_host,
        client, server, flow_info, p, vm, only_traffic_stats);
  } else
    lua_pushnil(vm);

  if (p) delete p;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* curl -i -XPOST "http://localhost:8086/write?precision=s&db=ntopng"
 * --data-binary 'profile:traffic,ifid=0,profile=a profile bytes=2506351
 * 1559634840' */
static int ntop_append_influx_db(lua_State *vm) {
  bool rv = false;
  NetworkInterface *curr_iface;

  if ((curr_iface = getCurrentInterface(vm)) &&
      curr_iface->getInfluxDBTSExporter() &&
      curr_iface->getInfluxDBTSExporter()->enqueueData(vm))
    rv = true;

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_rrd_queue_push(lua_State *vm) {
  bool rv = false;
  NetworkInterface *curr_iface;
  TimeseriesExporter *ts_exporter;

  if ((curr_iface = getCurrentInterface(vm)) &&
      (ts_exporter = curr_iface->getRRDTSExporter())) {
    rv = ts_exporter->enqueueData(vm);
  }

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_rrd_queue_pop(lua_State *vm) {
  int ifid;
  NetworkInterface *iface;
  TimeseriesExporter *ts_exporter;
  char *ts_point;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ifid = lua_tointeger(vm, 1);

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(ts_exporter = iface->getRRDTSExporter()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ts_point = ts_exporter->dequeueData();

  if (ts_point) {
    lua_pushstring(vm, ts_point);
    free(ts_point);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_rrd_queue_length(lua_State *vm) {
  int ifid;
  NetworkInterface *iface;
  TimeseriesExporter *ts_exporter;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ifid = lua_tointeger(vm, 1);

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(ts_exporter = iface->getRRDTSExporter()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushinteger(vm, ts_exporter->queueLength());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_checkpoint_host_talker(lua_State *vm) {
  int ifid;
  NetworkInterface *iface = NULL;
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ifid = (int)lua_tointeger(vm, 1);
  iface = ntop->getInterfaceById(ifid);

  get_host_vlan_info((char *)lua_tostring(vm, 2), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  if (iface && !iface->isViewed())
    iface->checkPointHostTalker(vm, host_ip, vlan_id);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef NTOPNG_PRO

#ifdef HAVE_NEDGE
/* NOTE: do no call this directly - use host_pools_utils.resetPoolsQuotas
 * instead */
static int ntop_reset_pools_quotas(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int16_t pool_id_filter = (u_int16_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNUMBER)
    pool_id_filter = (u_int16_t)lua_tonumber(vm, 1);

  if (curr_iface) {
    curr_iface->resetPoolsStats(pool_id_filter);

    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}
#endif

#endif

/* ****************************************** */

static int ntop_find_member_pool(lua_State *vm) {
  NetworkInterface *curr_iface;
  char *address;
  u_int16_t vlan_id = 0;
  bool is_mac;
  ndpi_patricia_node_t *target_node = NULL;
  u_int16_t pool_id = 0;
  bool pool_found;
  char buf[64];

  /* Note: pools are global, selecting the current interface prvents
   * this from working on the system interface, thus we are selecting
   * the first interface */
  // curr_iface = getCurrentInterface(vm);
  curr_iface = ntop->getFirstInterface();

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((address = (char *)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  is_mac = lua_toboolean(vm, 3);

  if (curr_iface && curr_iface->getHostPools()) {
    if (is_mac) {
      u_int8_t mac_bytes[6];
      Utils::parseMac(mac_bytes, address);
      pool_found =
          curr_iface->getHostPools()->findMacPool(mac_bytes, &pool_id);
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
        ndpi_prefix_t *prefix = ndpi_patricia_get_node_prefix(target_node);
        lua_push_str_table_entry(
            vm, "matched_prefix",
            (char *)inet_ntop(prefix->family,
                              (prefix->family == AF_INET6)
                                  ? (void *)(&prefix->add.sin6)
                                  : (void *)(&prefix->add.sin),
                              buf, sizeof(buf)));
        lua_push_uint64_table_entry(vm, "matched_bitmask",
                                    ndpi_patricia_get_node_bits(target_node));
      }
    } else
      lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* *******************************************/

static int ntop_find_mac_pool(lua_State *vm) {
  const char *mac;
  u_int8_t mac_parsed[6];
  u_int16_t pool_id;

  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  mac = lua_tostring(vm, 1);

  Utils::parseMac(mac_parsed, mac);

  if (curr_iface && curr_iface->getHostPools()) {
    if (curr_iface->getHostPools()->findMacPool(mac_parsed, &pool_id))
      lua_pushinteger(vm, pool_id);
    else
      lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* *******************************************/

#ifdef HAVE_NEDGE

static int ntop_reload_l7_rules(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

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
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

static int ntop_reload_shapers(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface) {
#ifdef NTOPNG_PRO
    curr_iface->refreshShapers();
#endif
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

#endif

/* ****************************************** */

static int ntop_interface_get_cached_alert_value(lua_State *vm) {
  NtopngLuaContext *c = getLuaVMContext(vm);
  char *key;
  std::string val;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!c->iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char *)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 2)) >= MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  val = c->iface->getAlertCachedValue(std::string(key), periodicity);
  lua_pushstring(vm, val.c_str());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_set_cached_alert_value(lua_State *vm) {
  NtopngLuaContext *c = getLuaVMContext(vm);
  char *key, *value;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!c->iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char *)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((value = (char *)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 3)) >=
      MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if ((!key) || (!value))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  c->iface->setAlertCacheValue(std::string(key), std::string(value),
                               periodicity);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_check_context(lua_State *vm) {
  NtopngLuaContext *c = getLuaVMContext(vm);
  char *entity_val;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((entity_val = (char *)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if ((c->iface == NULL) ||
      (strcmp(c->iface->getEntityValue().c_str(), entity_val)) != 0) {
    /* NOTE: setting a context for a differnt interface is currently not
     * supported */
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Bad context - expected interface %s, found %s (%s) in context",
        entity_val,
        c->iface == NULL ? "NULL" : c->iface->getEntityValue().c_str(),
        c->iface == NULL ? "NULL" : c->iface->get_name());

    lua_pushboolean(vm, false);
  } else
    lua_pushboolean(vm, true);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_release_engaged_alerts(lua_State *vm) {
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  // iface->releaseAllEngagedAlerts();
  /* TODO: implement this function in lua for interface and for local networks
   */

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_inc_total_host_alerts(lua_State *vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  u_int16_t vlan_id = 0;
#ifdef UNUSED
  AlertType alert_type;
#endif
  char buf[64], *host_ip;
  Host *h;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

#ifdef UNUSED
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  alert_type = (AlertType)lua_tonumber(vm, 2);
#endif

  h = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                          getLuaVMUservalue(vm, observationPointId));

  if (h) h->incTotalAlerts();

  lua_pushboolean(vm, h ? true : false);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static void ntop_get_maps_filters(lua_State *vm, MapsFilters *filters) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

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
    const char *addr = lua_tostring(vm, 1);
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
						 (char *)lua_tostring(vm, 6));

  if (lua_type(vm, 7) == LUA_TNUMBER)
    filters->network_id = (int32_t)lua_tonumber(vm, 7);
  if (lua_type(vm, 8) == LUA_TNUMBER)
    filters->status = (ServiceAcceptance)lua_tonumber(vm, 8);
  if (lua_type(vm, 9) == LUA_TNUMBER) direction = (u_int8_t)lua_tonumber(vm, 9);
  if (lua_type(vm, 10) == LUA_TSTRING) {
    char *str = (char *)lua_tostring(vm, 10);

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

static int ntop_get_interface_map(lua_State *vm, bool periodicity) {
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_map_filter_list(lua_State *vm, bool periodicity) {
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_interface_periodicity_map_filter_list(lua_State *vm) {
  return ntop_get_interface_map_filter_list(vm, true /* periodicity */);
}

/* ****************************************** */

static int ntop_get_interface_service_map_filter_list(lua_State *vm) {
  return ntop_get_interface_map_filter_list(vm, false /* service */);
}

/* ****************************************** */

static int ntop_get_interface_periodicity_map(lua_State *vm) {
  return ntop_get_interface_map(vm, true /* periodicity */);
}

/* ****************************************** */

static int ntop_get_interface_service_map(lua_State *vm) {
  return ntop_get_interface_map(vm, false /* service */);
}

/* ****************************************** */

static int ntop_flush_interface_periodicity_map(lua_State *vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface *curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  curr_iface->flushPeriodicityMap();
#endif

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_flush_interface_service_map(lua_State *vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface *curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  curr_iface->flushServiceMap();
#endif

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_service_map_set_status(lua_State *vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  u_int64_t hash_id;
  ServiceAcceptance status;
  char *buff;
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  if (curr_iface) {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    if ((buff = (char *)lua_tostring(vm, 1)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    hash_id = strtoull(buff, NULL, 10);

    if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    status = (ServiceAcceptance)lua_tonumber(vm, 2);

    if (curr_iface->getServiceMap())
      curr_iface->getServiceMap()->setStatus(hash_id, status);
    else
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_service_map_set_multiple_status(lua_State *vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  ServiceAcceptance current_status = service_unknown,
                    new_status = service_unknown;
  u_int16_t proto_id = 0xFF;
  char *l7_proto = NULL;
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  if (curr_iface) {
    if (lua_type(vm, 1) == LUA_TSTRING) l7_proto = (char *)lua_tostring(vm, 1);
    if (lua_type(vm, 2) == LUA_TNUMBER)
      current_status = (ServiceAcceptance)lua_tonumber(vm, 2);
    if (lua_type(vm, 3) == LUA_TNUMBER)
      new_status = (ServiceAcceptance)lua_tonumber(vm, 3);

    if (l7_proto != NULL)
      proto_id = ndpi_get_proto_by_name(curr_iface->get_ndpi_struct(), l7_proto);

    curr_iface->getServiceMap()->setBatchStatus(proto_id, current_status,
                                                    new_status);
  }
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_service_map_learning_status(lua_State *vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface *curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO)
  if (curr_iface)
    curr_iface->luaServiceMapStatus(vm);
  else
    lua_pushnil(vm);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_is_behaviour_analysis_available(lua_State *vm) {
#if defined(NTOPNG_PRO)
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  lua_pushboolean(vm, curr_iface->isPeriodicityMapEnabled() ||
                          curr_iface->isServiceMapEnabled());
#else
  lua_pushboolean(vm, false);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_address_info(lua_State *vm) {
  char *addr;
  IpAddress ip;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  addr = (char *)lua_tostring(vm, 1);

  ip.set(addr);

  lua_newtable(vm);
  lua_push_bool_table_entry(vm, "is_blacklisted", ip.isBlacklistedAddress());
  lua_push_bool_table_entry(vm, "is_broadcast", ip.isBroadcastAddress());
  lua_push_bool_table_entry(vm, "is_multicast", ip.isMulticastAddress());
  lua_push_bool_table_entry(vm, "is_private", ip.isPrivateAddress());
  lua_push_bool_table_entry(vm, "is_local", ip.isLocalHost());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_ndpi_host_stats(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  else {
    if (!curr_iface->getHostMinInfo(vm, get_allowed_nets(vm), host_ip,
                                        vlan_id, true))
      ntop_get_address_info(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

static int ntop_get_interface_get_host_min_info(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char *)lua_tostring(vm, 1), &host_ip, &vlan_id, buf,
                     sizeof(buf));

  /* Optional VLAN id */
  if (lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if (!curr_iface) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  } else {
    if (!curr_iface->getHostMinInfo(vm, get_allowed_nets(vm), host_ip,
                                        vlan_id, false))
      lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

#ifdef HAVE_NEDGE

static int ntop_update_flows_shapers(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (curr_iface) curr_iface->updateFlowsL7Policy();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_policy_change_marker(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (curr_iface &&
      (curr_iface->getIfType() == interface_type_NETFILTER))
    lua_pushinteger(
        vm, ((NetfilterInterface *)curr_iface)->getPolicyChangeMarker());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_add_lan_ip_address(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  const char *ip = lua_tostring(vm, 1);

  if (curr_iface &&
      (curr_iface->getIfType() == interface_type_NETFILTER))
    ((NetfilterInterface *)curr_iface)->addLanIPAddress(inet_addr(ip));

  if (ntop->get_HTTPserver())
    ntop->get_HTTPserver()->addCaptiveRedirectAddress(ip);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_get_l7_policy_info(lua_State *vm) {
  u_int16_t pool_id;
  u_int8_t shaper_id;
  ndpi_protocol proto;
  DeviceType dev_type;
  bool as_client;
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  L7PolicySource_t policy_source;
  DeviceProtoStatus device_proto_status;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (!curr_iface || !curr_iface->getL7Policer())
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  pool_id = (u_int16_t)lua_tointeger(vm, 1);
  proto.proto.master_protocol = (u_int16_t)lua_tointeger(vm, 2);
  proto.proto.app_protocol = proto.proto.master_protocol;
  proto.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;  // important for
  // ndpi_get_proto_category below

  // set appropriate category based on the protocols
  proto.category =
      ndpi_get_proto_category(curr_iface->get_ndpi_struct(), proto);

  dev_type = (DeviceType)lua_tointeger(vm, 3);
  as_client = lua_toboolean(vm, 4);

  if (ntop->getPrefs()->are_device_protocol_policies_enabled() &&
      ((device_proto_status = ntop->getDeviceAllowedProtocolStatus(
            dev_type, proto, pool_id, as_client)) != device_proto_allowed)) {
    shaper_id = DROP_ALL_SHAPER_ID;
    policy_source = policy_source_device_protocol;
  } else {
    shaper_id = curr_iface->getL7Policer()->getShaperIdForPool(
        pool_id, proto, !as_client, &policy_source);
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "shaper_id", shaper_id);
  lua_push_str_table_entry(vm, "policy_source",
                           (char *)Utils::policySource2Str(policy_source));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

#endif

/* ****************************************** */

// *** API ***
static int ntop_interface_is_sub_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushboolean(vm, curr_iface->isSubInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

// *** API ***
static int ntop_interface_is_syslog_interface(lua_State *vm) {
  NetworkInterface *curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushboolean(vm, curr_iface->isSyslogInterface());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_clickhouse_exec_csv_query(lua_State *vm) {
#ifdef HAVE_CLICKHOUSE
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  const char *sql;
  bool use_json = false;
  struct mg_connection *conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((!curr_iface) || (!conn))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  sql = lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TBOOLEAN) /* optional */
    use_json = lua_toboolean(vm, 2) ? true : false;

  curr_iface->exec_csv_query(sql, use_json, conn);
#endif

  lua_pushnil(vm); /* Data is pushed via the HTTP server */

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_interface_update_ip_reassignment(lua_State *vm) {
  NetworkInterface *iface = NULL;
  int ifid = -1;
  bool ip_reassignment_enabled = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ifid = (int)lua_tointeger(vm, 1);
  iface = ntop->getInterfaceById(ifid);

  ip_reassignment_enabled = (bool)lua_toboolean(vm, 2);
  iface->enable_ip_reassignment_alerts(ip_reassignment_enabled);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_interface_trigger_traffic_alert(lua_State *vm) {
  u_int32_t frequency_sec;
  bool t_sign = true;
  char *metric, *ipaddress, ip_buf[64], *host_ip, *tmp, *value, *threshold;
  NetworkInterface *curr_iface = getCurrentInterface(vm);
  bool rc = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ipaddress = (char *)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  metric = (char *)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  frequency_sec = (u_int32_t)lua_tointeger(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  threshold = (char *)lua_tostring(vm, 4);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  value = (char *)lua_tostring(vm, 5);

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  t_sign = (u_int32_t)lua_toboolean(vm, 6);

  snprintf(ip_buf, sizeof(ip_buf), "%s", ipaddress);
  host_ip = strtok_r(ipaddress, "@", &tmp);

  if (host_ip) {
    char *vlan_str = strtok_r(NULL, "@", &tmp);
    u_int16_t vlan_id = 0;
    AddressTree ptree;
    Host *h;
    u_int16_t observation_point_id = 0;
    if (vlan_str) vlan_id = atoi(vlan_str);

    /* No host search restrictions */
    ptree.addAddresses("0.0.0.0/0,::/0");

    /* Find the host in memory */
    h = curr_iface->findHostByIP(&ptree, ipaddress, vlan_id,
                                     observation_point_id);

    if (h != NULL) {
      HostAlert *alert;
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

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
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
    {"getHostInfo", ntop_get_interface_host_info},
    {"getHostMinInfo", ntop_get_interface_get_host_min_info},
    {"getHostCountry", ntop_get_interface_host_country},
    {"addMacsIpAddresses", ntop_add_macs_ip_addresses},
    {"getNetworksStats", ntop_get_interface_networks_stats},
    {"getLocalServerPorts", ntop_get_local_server_ports},
    {"getNetworkStats", ntop_get_interface_network_stats},
    {"checkpointHostTalker", ntop_checkpoint_host_talker},
    {"getFlowsInfo", ntop_get_interface_flows_info},
    {"getGroupedFlows", ntop_get_interface_get_grouped_flows},
    {"getFlowsStats", ntop_get_interface_flows_stats},
    {"getFlowKey", ntop_get_interface_flow_key},
    {"getScore", ntop_get_interface_score},
    {"findFlowByKeyAndHashId", ntop_get_interface_find_flow_by_key_and_hash_id},
    {"findFlowByTuple", ntop_get_interface_find_flow_by_tuple},
    {"dropFlowTraffic", ntop_drop_flow_traffic},
    {"dropMultipleFlowsTraffic", ntop_drop_multiple_flows_traffic},
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
    {"updatePushFiltersSettings",
     ntop_update_push_filters_settings},
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
    { "radiusAccountingStart", ntop_radius_accounting_start },
    { "radiusAccountingStop", ntop_radius_accounting_stop },
    { "radiusAccountingUpdate", ntop_radius_accounting_update },
    { "getHostsByService", ntop_get_hosts_by_service },

    /* Addresses */
    {"getAddressInfo", ntop_get_address_info},

    /* Addresses */
    {"getAddressInfo", ntop_get_address_info},

    /* Mac */
    {"getActiveMacs", ntop_get_interface_active_macs},
    {"getMacsInfo", ntop_get_interface_macs_info},
    {"getBatchedMacsInfo", ntop_get_batched_interface_macs_info},
    {"getMacInfo", ntop_get_interface_mac_info},
    {"getMacHosts", ntop_get_interface_mac_hosts},
    {"getMacManufacturers", ntop_get_interface_macs_manufacturers},
    {"getMacDeviceTypes", ntop_get_mac_device_types},
    {"isMulticastMac", ntop_is_multicast_mac},

    /* Anomalies */
    {"getAnomalies", ntop_get_interface_anomalies},

    /* Autonomous Systems */
    {"getASesInfo", ntop_get_interface_ases_info},
    {"getASInfo", ntop_get_interface_as_info},

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
#endif
    {"getHostUsedQuotasStats", ntop_get_host_used_quotas_stats},

    /* SNMP */
    {"getSNMPStats", ntop_interface_get_snmp_stats},

#ifdef NTOPNG_PRO
    /* Flow Devices */
    {"getFlowDevices", ntop_get_flow_devices},
    {"getFlowDeviceInfo", ntop_get_flow_device_info},
    {"getFlowDeviceInfoByIP", ntop_get_flow_device_info_by_ip},
#endif

#ifdef HAVE_NEDGE
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
    {"incTotalHostAlerts", ntop_interface_inc_total_host_alerts},
    {"updateIPReassignment", ntop_interface_update_ip_reassignment},
    {"triggerTrafficAlert", ntop_interface_trigger_traffic_alert},

    {"addDataToLocalHostAssets", ntop_add_data_to_assets },
    {"removeDataFromLocalHostAssets", ntop_remove_data_from_assets },

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

    {NULL, NULL}};

luaL_Reg *ntop_interface_reg = _ntop_interface_reg;

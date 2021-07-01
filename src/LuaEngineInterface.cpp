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

static NetworkInterface* handle_null_interface(lua_State* vm) {
  char allowed_ifname[MAX_INTERFACE_NAME_LEN];

  // this is normal, no need to generate a trace
  //ntop->getTrace()->traceEvent(TRACE_INFO, "NULL interface: did you restart ntopng in the meantime?");

  if(ntop->getInterfaceAllowed(vm, allowed_ifname))
    return ntop->getNetworkInterface(allowed_ifname);

  return(ntop->getFirstInterface());
}

/* ****************************************** */

NetworkInterface* getCurrentInterface(lua_State* vm) {
  NetworkInterface *ntop_interface;

  ntop_interface = getLuaVMUserdata(vm, iface);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  return(ntop_interface ? ntop_interface : handle_null_interface(vm));
}

/* ****************************************** */

static int ntop_set_active_interface_id(lua_State* vm) {
  NetworkInterface *iface;
  int id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  id = lua_tonumber(vm, 1);

  iface = ntop->getNetworkInterface(vm, id);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Index: %d, Name: %s", id, iface ? iface->get_name() : "<unknown>");

  if(iface != NULL)
    lua_pushstring(vm, iface->get_name());
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

bool matches_allowed_ifname(char *allowed_ifname, char *iface) {
  return (((allowed_ifname == NULL) || (allowed_ifname[0] == '\0')) /* Periodic script / unrestricted user */
	  || (!strncmp(allowed_ifname, iface, strlen(allowed_ifname))));
}

/* ****************************************** */

static int ntop_get_interface_names(lua_State* vm) {
  char *allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);
  bool exclude_viewed_interfaces = false;

  if(lua_type(vm, 1) == LUA_TBOOLEAN)
    exclude_viewed_interfaces = lua_toboolean(vm, 1) ? true : false;

  lua_newtable(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  for(int i=0; i<ntop->get_num_interfaces(); i++) {
    NetworkInterface *iface;
    /*
      We should not call ntop->getInterfaceAtId() as it
      manipulates the vm that has been already modified with
      lua_newtable(vm) a few lines above.
    */

    if((iface = ntop->getInterface(i)) != NULL) {
      char num[8], *ifname = iface->get_name();

      if(matches_allowed_ifname(allowed_ifname, ifname)
	 && (!exclude_viewed_interfaces || !iface->isViewed()))	{
	ntop->getTrace()->traceEvent(TRACE_DEBUG, "Returning name [%d][%s]", i, ifname);
	snprintf(num, sizeof(num), "%d", iface->get_id());
	lua_push_str_table_entry(vm, num, ifname);
      }
    }
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_first_interface_id(lua_State* vm) {
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  iface = ntop->getFirstInterface();

  if(iface) {
    lua_pushinteger(vm, iface->get_id());
    return(CONST_LUA_OK);
  }

  return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_select_interface(lua_State* vm) {
  char *ifname;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNIL)
    ifname = (char*)"any";
  else {
    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
    ifname = (char*)lua_tostring(vm, 1);
  }

  getLuaVMUservalue(vm, iface) = ntop->getNetworkInterface(ifname, vm);

  // lua_pop(vm, 1); /* Cleanup the Lua stack */
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_id(lua_State* vm) {
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((iface = getCurrentInterface(vm)) == NULL)
    return(CONST_LUA_ERROR);

  lua_pushinteger(vm, iface->get_id());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_name(lua_State* vm) {
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((iface = getCurrentInterface(vm)) == NULL)
    return(CONST_LUA_ERROR);

  lua_pushstring(vm, iface->get_name());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_valid_interface_id(lua_State* vm) {
  int ifid;
  bool valid_int = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    errno = 0; /* Reset as possibly set by strtol. This is thread-safe. */
    ifid = strtol(lua_tostring(vm, 1), NULL, 0); /* Sets errno when the conversion fails, e.g., string is NaN once converted */
    if(!errno) valid_int = true;
  } else if(lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    valid_int = true;
  }

  lua_pushboolean(vm, valid_int ? ntop->getInterfaceById(ifid) != NULL : false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_max_if_speed(lua_State* vm) {
  char *ifname = NULL;
  int ifid;
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    ifname = (char*)lua_tostring(vm, 1);
    lua_pushinteger(vm, Utils::getMaxIfSpeed(ifname));
  } else if(lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);

    if((iface = ntop->getInterfaceById(ifid)) != NULL) {
      lua_pushinteger(vm, iface->getMaxSpeed());
    } else {
      lua_pushnil(vm);
    }
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_get_observation_points(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    ntop_interface->getObservationPoints(vm);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef NTOPNG_PRO
/**
 * @brief Get the SNMP statistics of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_interface_get_snmp_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface && ntop_interface->getFlowInterfacesStats()) {
    ntop_interface->getFlowInterfacesStats()->lua(vm, ntop_interface);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}
#endif

/* ****************************************** */

static int ntop_interface_has_vlans(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    lua_pushboolean(vm, ntop_interface->hasSeenVLANTaggedPackets());
  else
    lua_pushboolean(vm, 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_has_ebpf(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    lua_pushboolean(vm, ntop_interface->hasSeenEBPFEvents());
  else
    lua_pushboolean(vm, 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_has_external_alerts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    lua_pushboolean(vm, ntop_interface->hasSeenExternalAlerts());
  else
    lua_pushboolean(vm, 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// *** API ***
static int ntop_interface_is_packet_interface(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, ntop_interface->isPacketInterface());
  return(CONST_LUA_OK);
}

/* ****************************************** */

// *** API ***
static int ntop_interface_is_discoverable_interface(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  lua_pushboolean(vm, ntop_interface->isDiscoverableInterface());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_bridge_interface(lua_State* vm) {
  int ifid;
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((lua_type(vm, 1) == LUA_TNUMBER)) {
    ifid = lua_tointeger(vm, 1);

    if(ifid < 0 || !(iface = ntop->getInterfaceById(ifid)))
      return(CONST_LUA_ERROR);
  }

  lua_pushboolean(vm, iface->is_bridge_interface());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_pcap_dump_interface(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface && ntop_interface->getIfType() == interface_type_PCAP_DUMP)
    rv = true;

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_view(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isView();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_viewed_by(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface && ntop_interface->isViewed())
    lua_pushinteger(vm, ntop_interface->viewedBy()->get_id());
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_interface_is_viewed(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isViewed();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_loopback(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isLoopback();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_running(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isRunning();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_idle(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->idle();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_set_idle(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool state;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  state = lua_toboolean(vm, 1) ? true : false;

  ntop_interface->setIdleState(state);
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_dump_live_captures(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if(!iface)
    return(CONST_LUA_ERROR);

  iface->dumpLiveCaptures(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

AddressTree* get_allowed_nets(lua_State* vm) {
  AddressTree *ptree;

  ptree = getLuaVMUserdata(vm, allowedNets);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return(ptree);
}

/* ****************************************** */

static int ntop_interface_live_capture(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  struct ntopngLuaContext *c;
  int capture_id, duration;
  char *bpf = NULL;
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!iface) return(CONST_LUA_ERROR);

  c = getLuaVMContext(vm);

  if((!ntop_interface) || (!c))
    return(CONST_LUA_ERROR);

  if(!ntop->isPcapDownloadAllowed(vm, ntop_interface->get_name()))
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TSTRING) /* Host */ {
    Host *h;
    char host_ip[64];
    char *key;
    VLANid vlan_id = 0;

    get_host_vlan_info((char*)lua_tostring(vm, 1), &key, &vlan_id, host_ip, sizeof(host_ip));

    if((!ntop_interface) || ((h = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId))) == NULL))
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate host %s", host_ip);
    else
      c->live_capture.matching_host = h;
  }

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  duration = (u_int32_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  bpf = (char*)lua_tostring(vm, 3);

  c->live_capture.capture_until = time(NULL)+duration;
  c->live_capture.capture_max_pkts = CONST_MAX_NUM_PACKETS_PER_LIVE;
  c->live_capture.num_captured_packets = 0;
  c->live_capture.stopped = c->live_capture.pcaphdr_sent = false;
  c->live_capture.bpfFilterSet = false;

  bpf = ntop->preparePcapDownloadFilter(vm, bpf);

  if (bpf == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Failure building the capture filter");
    return(CONST_LUA_ERROR);
  }

  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Using capture filter '%s'", bpf);

  if(bpf[0] != '\0') {
    if(pcap_compile_nopcap(65535,   /* snaplen */
			   iface->get_datalink(), /* linktype */
			   &c->live_capture.fcode, /* program */
			   bpf,     /* const char *buf */
			   0,       /* optimize */
			   PCAP_NETMASK_UNKNOWN) == -1)
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Unable to set capture filter %s. Filter ignored.", bpf);
    else
      c->live_capture.bpfFilterSet = true;
  }

  if(ntop_interface->registerLiveCapture(c, &capture_id)) {
    ntop->getTrace()->traceEvent(TRACE_INFO,
				 "Starting live capture id %d",
				 capture_id);

    while(!c->live_capture.stopped) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "Capturing....");
      sleep(1);
    }

    ntop->getTrace()->traceEvent(TRACE_INFO, "Capture completed");
  }

  free(bpf);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_stop_live_capture(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  int capture_id;
  bool rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  capture_id = (int)lua_tointeger(vm, 1);

  rc = ntop_interface->stopLiveCapture(capture_id);

  ntop->getTrace()->traceEvent(TRACE_INFO,
			       "Stopping live capture %d: %s",
			       capture_id,
			       rc ? "stopped" : "error");

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_name2id(lua_State* vm) {
  char *if_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNIL)
    if_name = NULL;
  else {
    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
    if_name = (char*)lua_tostring(vm, 1);
  }

  lua_pushinteger(vm, ntop->getInterfaceIdByName(vm, if_name));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_reset_counters(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool only_drops = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TBOOLEAN)
    only_drops = lua_toboolean(vm, 1) ? true : false;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->checkPointCounters(only_drops);
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_reset_host_stats(lua_State* vm, bool delete_data) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char buf[64], *host_ip;
  Host *host;
  VLANid vlan_id;
  bool reset_blacklisted = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if(lua_type(vm, 2) == LUA_TBOOLEAN) {
    reset_blacklisted = lua_toboolean(vm, 2) ? true : false;
  }
    
  if(!ntop_interface) return(CONST_LUA_ERROR);

  host = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId));

  if(host) {
    if(reset_blacklisted == true) {
      host->blacklistedStatsResetRequested();
    } else {
      if(delete_data)
	host->requestDataReset();
      else
	host->requestStatsReset();
    }
  }

  lua_pushboolean(vm, (host != NULL));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static inline int ntop_interface_reset_host_stats(lua_State* vm) {
  return(ntop_interface_reset_host_stats(vm, false));
}

/* ****************************************** */

static int ntop_interface_delete_host_data(lua_State* vm) {
  return(ntop_interface_reset_host_stats(vm, true));
}

/* ****************************************** */

static int ntop_interface_reset_mac_stats(lua_State* vm, bool delete_data) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *mac;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  mac = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, ntop_interface->resetMacStats(vm, mac, delete_data));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static inline int ntop_interface_reset_mac_stats(lua_State* vm) {
  return(ntop_interface_reset_mac_stats(vm, false));
}

/* ****************************************** */

static int ntop_interface_delete_mac_data(lua_State* vm) {
  return(ntop_interface_reset_mac_stats(vm, true));
}

/* ****************************************** */

static int ntop_interface_exec_sql_query(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool limit_rows = true;  // honour the limit by default
  bool wait_for_db_created = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    char *sql;

    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
    if((sql = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    if(lua_type(vm, 2) == LUA_TBOOLEAN) {
      limit_rows = lua_toboolean(vm, 2) ? true : false;
    }

    if(lua_type(vm, 3) == LUA_TBOOLEAN) {
      wait_for_db_created = lua_toboolean(vm, 3) ? true : false;
    }

    if(ntop_interface->exec_sql_query(vm, sql, limit_rows, wait_for_db_created) < 0)
      lua_pushnil(vm);

    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_interface_get_pods_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->getPodsStats(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_get_containers_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *pod_filter = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TSTRING)
    pod_filter = (char*)lua_tostring(vm, 1);

  ntop_interface->getContainersStats(vm, pod_filter);
  return(CONST_LUA_OK);
}
/* ****************************************** */

static int ntop_interface_reload_companions(lua_State* vm) {
  int ifid;
  NetworkInterface *iface;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return CONST_LUA_ERROR;
  ifid = lua_tonumber(vm, 1);

  if((iface = ntop->getInterfaceById(ifid)))
    iface->reloadCompanions();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

int ntop_get_alerts(lua_State* vm, AlertableEntity *entity) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  u_int idx = 0;
  ScriptPeriodicity periodicity = no_periodicity;

  if(!entity) return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TNUMBER) periodicity = (ScriptPeriodicity)lua_tointeger(vm, 1);

  lua_newtable(vm);
  entity->getAlerts(vm, periodicity, alert_none, alert_level_none, alert_role_is_any, &idx);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_get_alerts(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return ntop_get_alerts(vm, c->iface);
}

/* ****************************************** */

static int ntop_interface_store_external_alert(lua_State* vm) {
  AlertEntity entity;
  const char *entity_value;
  AlertableEntity *alertable;
  NetworkInterface *iface = getCurrentInterface(vm);
  int idx = 1;

  if(!iface)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  entity = (AlertEntity)lua_tointeger(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  entity_value = lua_tostring(vm, idx++);

  alertable = iface->lockExternalAlertable(entity, entity_value, true /* Create if not exists */);

  if(!alertable)
    return(CONST_LUA_ERROR);

  ntop_store_triggered_alert(vm, alertable, idx);

  /* End of critical section */
  iface->unlockExternalAlertable(alertable);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_release_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return ntop_release_triggered_alert(vm, c->iface);
}

/* ****************************************** */

static int ntop_interface_release_external_alert(lua_State* vm) {
  AlertEntity entity;
  const char *entity_value;
  AlertableEntity *alertable;
  NetworkInterface *iface = getCurrentInterface(vm);
  int idx = 1;

  if(!iface)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  entity = (AlertEntity)lua_tointeger(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  entity_value = lua_tostring(vm, idx++);

  alertable = iface->lockExternalAlertable(entity, entity_value, false /* don't create if not exists */);

  if(!alertable) {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  }

  ntop_release_triggered_alert(vm, alertable, idx);

  /* End of critical section */
  iface->unlockExternalAlertable(alertable);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_get_engaged_alerts(lua_State* vm) {
  AlertEntity entity_type = alert_entity_none;
  const char *entity_value = NULL;
  AlertType alert_type = alert_none;
  AlertLevel alert_severity = alert_level_none;
  AlertRole role_filter = alert_role_is_any;
  NetworkInterface *iface = getCurrentInterface(vm);
  AddressTree *allowed_nets = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TNUMBER) entity_type = (AlertEntity)lua_tointeger(vm, 1);
  if(lua_type(vm, 2) == LUA_TSTRING) entity_value = (char*)lua_tostring(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER) alert_type = (AlertType)lua_tointeger(vm, 3);
  if(lua_type(vm, 4) == LUA_TNUMBER) alert_severity = (AlertLevel)lua_tointeger(vm, 4);
  if(lua_type(vm, 5) == LUA_TNUMBER) role_filter = (AlertRole)lua_tointeger(vm, 5);

  iface->getEngagedAlerts(vm, entity_type, entity_value, alert_type, alert_severity, role_filter, allowed_nets);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_inc_syslog_stats(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  u_int32_t num_received_events;
  u_int32_t num_malformed;
  u_int32_t num_unhandled;
  u_int32_t num_alerts;
  u_int32_t num_host_correlations;
  u_int32_t num_collected_flows;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_received_events = lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_malformed = lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_unhandled = lua_tonumber(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_alerts = lua_tonumber(vm, 4);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_host_correlations = lua_tonumber(vm, 5);

  if(ntop_lua_check(vm, __FUNCTION__, 6, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_collected_flows = lua_tonumber(vm, 6);

  iface->incSyslogStats(0,
    num_malformed,
    num_received_events,
    num_unhandled,
    num_alerts,
    num_host_correlations,
    num_collected_flows);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static char *getAllowedNetworksHostsSqlFilter(lua_State* vm) {
  /* Lazy initialization */
  if(!getLuaVMUservalue(vm, sqlite_filters_loaded))
    Utils::buildSqliteAllowedNetworksFilters(vm);

  return(getLuaVMUserdata(vm, sqlite_hosts_filter));
}

/* ****************************************** */

static char *getAllowedNetworksFlowsSqlFilter(lua_State* vm) {
  /* Lazy initialization */
  if(!getLuaVMUservalue(vm, sqlite_filters_loaded))
    Utils::buildSqliteAllowedNetworksFilters(vm);

  return(getLuaVMUserdata(vm, sqlite_flows_filter));
}

/* ****************************************** */

static int ntop_interface_alert_store_query(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  char *query;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!iface
     || lua_type(vm, 1) != LUA_TSTRING
     || !(query = (char*)lua_tostring(vm, 1))
     || !iface->alert_store_query(vm, query)) {
    lua_pushnil(vm);
    return(CONST_LUA_ERROR);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifndef HAVE_NEDGE
static int ntop_process_flow(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) != LUA_TTABLE)
    return(CONST_LUA_ERROR);

  if(!dynamic_cast<ParserInterface*>(ntop_interface))
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TTABLE) {
    ParserInterface *ntop_parser_interface = dynamic_cast<ParserInterface*>(ntop_interface);
    ParsedFlow flow;
    flow.fromLua(vm, 1);
    ntop_parser_interface->processFlow(&flow);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_update_syslog_producers(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  SyslogParserInterface *syslog_parser_interface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  syslog_parser_interface = dynamic_cast<SyslogParserInterface*>(ntop_interface);
  if(!syslog_parser_interface)
    return(CONST_LUA_ERROR);

  syslog_parser_interface->updateProducersMapping();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

static int ntop_get_host_pools_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface && ntop_interface->getHostPools()) {
    lua_newtable(vm);
    ntop_interface->getHostPools()->lua(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

/**
 * @brief Get the Host Pool statistics of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_pools_interface_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface && ntop_interface->getHostPools()) {
    ntop_interface->luaHostPoolsStats(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

/**
 * @brief Get the Host Pool statistics for a pool of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_pool_interface_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  HostPools *hp;
  u_int64_t pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  pool_id = (u_int16_t)lua_tonumber(vm, 1);

  if(ntop_interface && (hp = ntop_interface->getHostPools())) {
    lua_newtable(vm);
    hp->luaStats(vm, pool_id);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

#ifdef NTOPNG_PRO

/**
 * @brief Get the Host statistics corresponding to the amount of host quotas used
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_used_quotas_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  Host *h;
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[128];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((!ntop_interface))
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((h = ntop_interface->getHost(host_ip, vlan_id,
				  getLuaVMUservalue(vm, observationPointId),
				  false /* Not an inline call */)))
    h->luaUsedQuotas(vm);
  else
    lua_newtable(vm);

  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

static int ntop_get_ndpi_interface_flows_count(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {
    lua_newtable(vm);
    ntop_interface->getnDPIFlowsCount(vm);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_interface_flows_status(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {
    lua_newtable(vm);
    ntop_interface->getFlowsStatus(vm);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_protocol_name(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proto = (u_int32_t)lua_tonumber(vm, 1);

  if(proto == HOST_FAMILY_ID)
    lua_pushstring(vm, "Host-to-Host Contact");
  else {
    if(ntop_interface)
      lua_pushstring(vm, ntop_interface->get_ndpi_proto_name(proto));
    else
      lua_pushnil(vm);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_full_protocol_name(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  ndpi_protocol proto;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proto.master_protocol = (u_int32_t)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proto.app_protocol = (u_int32_t)lua_tonumber(vm, 2);

  if(ntop_interface)
    lua_pushstring(vm, ntop_interface->get_ndpi_full_proto_name(proto, buf, sizeof(buf)));
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_protocol_id(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  char *proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proto = (char*)lua_tostring(vm, 1);

  if(ntop_interface && proto)
    lua_pushinteger(vm, ntop_interface->get_ndpi_proto_id(proto));
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_category_id(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  char *category;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  category = (char*)lua_tostring(vm, 1);

  if(ntop_interface && category)
    lua_pushinteger(vm, ntop_interface->get_ndpi_category_id(category));
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_category_name(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  ndpi_protocol_category_t category;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  category = (ndpi_protocol_category_t)((int)lua_tonumber(vm, 1));

  if(ntop_interface)
    lua_pushstring(vm, ntop_interface->get_ndpi_category_name(category));
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Same as ntop_get_ndpi_protocol_name() with the exception that the protocol breed is returned
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_ndpi_protocol_breed(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proto = (u_int32_t)lua_tonumber(vm, 1);

  if(proto == HOST_FAMILY_ID)
    lua_pushstring(vm, "Unrated-to-Host Contact");
  else {
    if(ntop_interface)
      lua_pushstring(vm, ntop_interface->get_ndpi_proto_breed_name(proto));
    else
      lua_pushnil(vm);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_batched_interface_hosts(lua_State* vm, LocationPolicy location, bool tsLua=false) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool show_details = true, filtered_hosts = false, blacklisted_hosts = false, hide_top_hidden = false;
  char *sortColumn = (char*)"column_ip", *country = NULL, *mac_filter = NULL;
  OSType os_filter = os_any;
  bool a2zSortOrder = true;
  u_int16_t vlan_filter = (u_int16_t)-1;
  u_int32_t asn_filter = (u_int32_t)-1;
  int16_t network_filter = -2;
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

  if(lua_type(vm, 1) == LUA_TNUMBER)  begin_slot     = (u_int32_t)lua_tonumber(vm, 1);
  if(lua_type(vm, 2) == LUA_TBOOLEAN) show_details   = lua_toboolean(vm, 2) ? true : false;
  if(lua_type(vm, 3) == LUA_TNUMBER)  maxHits        = (u_int32_t)lua_tonumber(vm, 3);
  if(lua_type(vm, 4) == LUA_TBOOLEAN) anomalousOnly  = lua_toboolean(vm, 4);
  /* If parameter 5 is true, the caller wants to iterate all hosts, including those with unidirectional traffic.
     If parameter 5 is false, then the caller only wants host withs bidirectional traffic */
  if(lua_type(vm, 5) == LUA_TBOOLEAN) traffic_type_filter = lua_toboolean(vm, 5) ? traffic_type_all : traffic_type_bidirectional;

  if((!ntop_interface)
     || ntop_interface->getActiveHostsList(vm,
					   &begin_slot, walk_all,
					   0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
					   get_allowed_nets(vm),
					   show_details, location,
					   country, mac_filter,
					   vlan_filter, os_filter, asn_filter,
					   network_filter, pool_filter, filtered_hosts, blacklisted_hosts, hide_top_hidden,
					   ipver_filter, proto_filter,
					   traffic_type_filter, tsLua /* host->tsLua | host->lua */,
					   anomalousOnly, dhcpOnly,
					   NULL /* cidr filter */,
					   sortColumn, maxHits,
					   toSkip, a2zSortOrder) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_hosts(lua_State* vm, LocationPolicy location) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool show_details = true, filtered_hosts = false, blacklisted_hosts = false;
  char *sortColumn = (char*)"column_ip", *country = NULL, *mac_filter = NULL;
  bool a2zSortOrder = true;
  OSType os_filter = os_any;
  u_int16_t vlan_filter = (u_int16_t)-1;
  u_int32_t asn_filter = (u_int32_t)-1;
  int16_t network_filter = -2;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t ipver_filter = 0;
  TrafficType traffic_type_filter = traffic_type_all;
  int proto_filter = -1;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  bool hide_top_hidden = false;
  bool anomalousOnly = false;
  bool dhcpOnly = false, cidr_filter_enabled = false;
  AddressTree cidr_filter;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TBOOLEAN) show_details         = lua_toboolean(vm, 1) ? true : false;
  if(lua_type(vm, 2) == LUA_TSTRING)  sortColumn           = (char*)lua_tostring(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER)  maxHits              = (u_int16_t)lua_tonumber(vm, 3);
  if(lua_type(vm, 4) == LUA_TNUMBER)  toSkip               = (u_int16_t)lua_tonumber(vm, 4);
  if(lua_type(vm, 5) == LUA_TBOOLEAN) a2zSortOrder         = lua_toboolean(vm, 5) ? true : false;
  if(lua_type(vm, 6) == LUA_TSTRING)  country              = (char*)lua_tostring(vm, 6);
  if(lua_type(vm, 7) == LUA_TNUMBER)  os_filter            = (OSType)lua_tointeger(vm, 7);
  if(lua_type(vm, 8) == LUA_TNUMBER)  vlan_filter          = (u_int16_t)lua_tonumber(vm, 8);
  if(lua_type(vm, 9) == LUA_TNUMBER)  asn_filter           = (u_int32_t)lua_tonumber(vm, 9);
  if(lua_type(vm,10) == LUA_TNUMBER)  network_filter       = (int16_t)lua_tonumber(vm, 10);
  if(lua_type(vm,11) == LUA_TSTRING)  mac_filter           = (char*)lua_tostring(vm, 11);
  if(lua_type(vm,12) == LUA_TNUMBER)  pool_filter          = (u_int16_t)lua_tonumber(vm, 12);
  if(lua_type(vm,13) == LUA_TNUMBER)  ipver_filter         = (u_int8_t)lua_tonumber(vm, 13);
  if(lua_type(vm,14) == LUA_TNUMBER)  proto_filter         = (int)lua_tonumber(vm, 14);
  if(lua_type(vm,15) == LUA_TNUMBER)  traffic_type_filter  = (TrafficType)lua_tointeger(vm, 15);
  if(lua_type(vm,16) == LUA_TBOOLEAN) filtered_hosts       = lua_toboolean(vm, 16);
  if(lua_type(vm,17) == LUA_TBOOLEAN) blacklisted_hosts    = lua_toboolean(vm, 17);
  if(lua_type(vm,18) == LUA_TBOOLEAN) hide_top_hidden      = lua_toboolean(vm, 18);
  if(lua_type(vm,19) == LUA_TBOOLEAN) anomalousOnly        = lua_toboolean(vm, 19);
  if(lua_type(vm,20) == LUA_TBOOLEAN) dhcpOnly             = lua_toboolean(vm, 20);
  if(lua_type(vm,21) == LUA_TSTRING)  cidr_filter.addAddress(lua_tostring(vm, 21)), cidr_filter_enabled = true;

  if((!ntop_interface)
     || ntop_interface->getActiveHostsList(vm,
					   &begin_slot, walk_all,
					   0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
					   get_allowed_nets(vm),
					   show_details, location,
					   country, mac_filter,
					   vlan_filter, os_filter, asn_filter,
					   network_filter, pool_filter, filtered_hosts, blacklisted_hosts, hide_top_hidden,
					   ipver_filter, proto_filter,
					   traffic_type_filter, false /* host->lua */,
					   anomalousOnly, dhcpOnly,
					   cidr_filter_enabled ? &cidr_filter : NULL,
					   sortColumn, maxHits,
					   toSkip, a2zSortOrder) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/* Receives in input a Lua table, having mac address as keys and tables as values. Every IP address found for a mac is inserted into the table as an 'ip' field. */
static int ntop_add_macs_ip_addresses(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TTABLE) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  if((!ntop_interface) || ntop_interface->getMacsIpAddresses(vm, 1) < 0)
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static u_int8_t str_2_location(const char *s) {
  if(! strcmp(s, "lan")) return located_on_lan_interface;
  else if(! strcmp(s, "wan")) return located_on_wan_interface;
  else if(! strcmp(s, "unknown")) return located_on_unknown_interface;
  return (u_int8_t)-1;
}

/* ****************************************** */

static int ntop_get_interface_macs_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *sortColumn = (char*)"column_mac";
  const char* manufacturer = NULL;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t devtype_filter = (u_int8_t)-1;
  bool a2zSortOrder = true, sourceMacsOnly = false;
  u_int8_t location_filter = (u_int8_t)-1;
  u_int32_t begin_slot = 0;
  time_t min_first_seen = 0;
  bool walk_all = true;

  if(lua_type(vm,  1) == LUA_TSTRING)  sortColumn = (char*)lua_tostring(vm, 1);
  if(lua_type(vm,  2) == LUA_TNUMBER)  maxHits = (u_int16_t)lua_tonumber(vm, 2);
  if(lua_type(vm,  3) == LUA_TNUMBER)  toSkip = (u_int16_t)lua_tonumber(vm, 3);
  if(lua_type(vm,  4) == LUA_TBOOLEAN) a2zSortOrder = lua_toboolean(vm, 4);
  if(lua_type(vm,  5) == LUA_TBOOLEAN) sourceMacsOnly = lua_toboolean(vm, 5);
  if(lua_type(vm,  6) == LUA_TSTRING)  manufacturer = lua_tostring(vm, 6);
  if(lua_type(vm,  7) == LUA_TNUMBER)  pool_filter = (u_int16_t)lua_tonumber(vm, 7);
  if(lua_type(vm,  8) == LUA_TNUMBER)  devtype_filter = (u_int8_t)lua_tonumber(vm, 8);
  if(lua_type(vm,  9) == LUA_TSTRING)  location_filter = str_2_location(lua_tostring(vm, 9));
  if(lua_type(vm, 10) == LUA_TNUMBER)  min_first_seen = lua_tonumber(vm, 10);

  if(!ntop_interface ||
     ntop_interface->getActiveMacList(vm,
				      &begin_slot, walk_all,
				      0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
				      sourceMacsOnly, manufacturer,
				      sortColumn, maxHits,
				      toSkip, a2zSortOrder, pool_filter, devtype_filter, location_filter, min_first_seen) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_batched_interface_macs_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *sortColumn = (char*)"column_mac";
  const char* manufacturer = NULL;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t devtype_filter = (u_int8_t)-1;
  bool a2zSortOrder = true, sourceMacsOnly = false;
  u_int8_t location_filter = (u_int8_t)-1;
  time_t min_first_seen = 0;
  u_int32_t begin_slot = 0;
  bool walk_all = false;

  if(lua_type(vm, 1) == LUA_TNUMBER)  begin_slot     = (u_int16_t)lua_tonumber(vm, 1);

  if(!ntop_interface ||
     ntop_interface->getActiveMacList(vm,
				      &begin_slot, walk_all,
				      0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
				      sourceMacsOnly, manufacturer,
				      sortColumn, maxHits,
				      toSkip, a2zSortOrder, pool_filter, devtype_filter, location_filter, min_first_seen) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_mac_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *mac = NULL;

  if(lua_type(vm, 1) == LUA_TSTRING)
    mac = (char*)lua_tostring(vm, 1);

  if((!ntop_interface)
     || (!mac)
     || (!ntop_interface->getMacInfo(vm, mac)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_get_interface_mac_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *mac = NULL;

  if(lua_type(vm, 1) == LUA_TSTRING)
    mac = (char*)lua_tostring(vm, 1);

  lua_newtable(vm);

  if(ntop_interface)
    ntop_interface->getActiveMacHosts(vm, mac);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_host_operating_system(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip = NULL, buf[64];
  VLANid vlan_id = 0;
  OSType os = os_unknown;
  Host *host;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  os = (OSType)lua_tointeger(vm, 2);

  host = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId));

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[iface: %s][host_ip: %s][vlan_id: %u][host: %p][os: %u]", ntop_interface->get_name(), host_ip, vlan_id, host, os);
#endif

  if(ntop_interface && host && os < os_max_os && os != os_unknown)
    host->setOS(os);

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_num_local_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  lua_pushinteger(vm, ntop_interface->getNumLocalHosts());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_num_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  lua_pushinteger(vm, ntop_interface->getNumHosts());

  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_get_num_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  lua_pushinteger(vm, ntop_interface->getNumFlows());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_mac_device_types(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int16_t maxHits = CONST_MAX_NUM_HITS;
  bool sourceMacsOnly = false;
  char *manufacturer = NULL;
  u_int8_t location_filter = (u_int8_t)-1;

  if(lua_type(vm, 1) == LUA_TNUMBER)
    maxHits = (u_int16_t)lua_tonumber(vm, 1);

  if(lua_type(vm, 2) == LUA_TBOOLEAN)
    sourceMacsOnly = lua_toboolean(vm, 2) ? true : false;

  if(lua_type(vm, 3) == LUA_TSTRING)
    manufacturer = (char*)lua_tostring(vm, 3);

  if(lua_type(vm, 4) == LUA_TSTRING) location_filter = str_2_location(lua_tostring(vm, 4));

  if((!ntop_interface)
     || (ntop_interface->getActiveDeviceTypes(vm, sourceMacsOnly,
					      0 /* bridge_iface_idx - TODO */,
					      maxHits, manufacturer, location_filter) < 0))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_ases_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool diff = false;

  Paginator *p = NULL;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TTABLE)
    p->readOptions(vm, 1);

  if(lua_type(vm, 2) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 2) ? true : false;

  if(ntop_interface->getActiveASList(vm, p, diff) < 0) {
    if(p) delete(p);
    return(CONST_LUA_ERROR);
  }

  if(p) delete(p);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_get_throughput(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  lua_push_float_table_entry(vm, "throughput_bps", ntop_interface->getThroughputBps());
  lua_push_float_table_entry(vm, "throughput_pps", ntop_interface->getThroughputPps());

  
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_anomalies(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  lua_newtable(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->luaAnomalies(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_interface_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool diff = false;

  lua_newtable(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

	if(lua_type(vm, 4) == LUA_TBOOLEAN) 
	  diff = lua_toboolean(vm, 1) ? true : false;

  ntop_interface->luaNdpiStats(vm, diff);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_score(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  lua_newtable(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->luaScore(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_oses_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  Paginator *p = NULL;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TTABLE)
    p->readOptions(vm, 1);

  if(ntop_interface->getActiveOSList(vm, p) < 0) {
    if(p) delete(p);
    return(CONST_LUA_ERROR);
  }

  if(p) delete(p);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_countries_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  Paginator *p = NULL;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TTABLE)
    p->readOptions(vm, 1);

  if(ntop_interface->getActiveCountriesList(vm, p) < 0) {
    if(p) delete(p);
    return(CONST_LUA_ERROR);
  }

  if(p) delete(p);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_country_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  const char* country;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  country = lua_tostring(vm, 1);

  if((!ntop_interface)
     || (!ntop_interface->getCountryInfo(vm, country)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_vlans_list(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if((!ntop_interface)
     || ntop_interface->getActiveVLANList(vm,
					  (char*)"column_vlan", CONST_MAX_NUM_HITS,
					  0, true, details_normal /* Minimum details */) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_vlans_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *sortColumn = (char*)"column_vlan";
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  bool a2zSortOrder = true;
  DetailsLevel details_level = details_higher;

  if(lua_type(vm, 1) == LUA_TSTRING) {
    sortColumn = (char*)lua_tostring(vm, 1);

    if(lua_type(vm, 2) == LUA_TNUMBER) {
      maxHits = (u_int16_t)lua_tonumber(vm, 2);

      if(lua_type(vm, 3) == LUA_TNUMBER) {
	toSkip = (u_int16_t)lua_tonumber(vm, 3);

	if(lua_type(vm, 4) == LUA_TBOOLEAN) {
	  a2zSortOrder = lua_toboolean(vm, 4) ? true : false;

	  if(lua_type(vm, 5) == LUA_TBOOLEAN) {
	    details_level = lua_toboolean(vm, 4) ? details_higher : details_high;
	  }
	}
      }
    }
  }

  if(!ntop_interface ||
     ntop_interface->getActiveVLANList(vm,
				       sortColumn, maxHits,
				       toSkip, a2zSortOrder, details_level) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_as_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t asn;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  asn = (u_int32_t)lua_tonumber(vm, 1);

  if((!ntop_interface)
     || (!ntop_interface->getASInfo(vm, asn)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

static int ntop_get_interface_os_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  OSType os_type;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  os_type = (OSType)lua_tonumber(vm, 1);

  if((!ntop_interface)
     || (!ntop_interface->getOSInfo(vm, os_type)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_vlan_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  VLANid vlan_id;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  vlan_id = (u_int16_t)lua_tonumber(vm, 1);

  if((!ntop_interface)
     || (!ntop_interface->getVLANInfo(vm, vlan_id)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_macs_manufacturers(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t maxHits = CONST_MAX_NUM_HITS;
  u_int8_t devtype_filter = (u_int8_t)-1;
  bool sourceMacsOnly = false;
  u_int8_t location_filter = (u_int8_t)-1;

  if(lua_type(vm, 1) == LUA_TNUMBER)
    maxHits = (u_int16_t)lua_tonumber(vm, 1);

  if(lua_type(vm, 2) == LUA_TBOOLEAN)
    sourceMacsOnly = lua_toboolean(vm, 2) ? true : false;

  if(lua_type(vm, 3) == LUA_TNUMBER)
    devtype_filter = (u_int8_t)lua_tonumber(vm, 3);

  if(lua_type(vm, 4) == LUA_TSTRING) location_filter = str_2_location(lua_tostring(vm, 4));

  if(!ntop_interface ||
     ntop_interface->getActiveMacManufacturers(vm,
					       0, /* bridge_iface_idx - TODO */
					       sourceMacsOnly, maxHits,
					       devtype_filter, location_filter) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_check_networks_alerts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  std::vector<ScriptPeriodicity> periodicities;

  if(!ntop_interface) {
    lua_pushnil(vm);
    return(CONST_LUA_ERROR);
  }

  if(lua_type(vm, 1) == LUA_TBOOLEAN && lua_toboolean(vm, 1) == true) periodicities.push_back(minute_script);
  if(lua_type(vm, 2) == LUA_TBOOLEAN && lua_toboolean(vm, 2) == true) periodicities.push_back(five_minute_script);
  if(lua_type(vm, 3) == LUA_TBOOLEAN && lua_toboolean(vm, 3) == true) periodicities.push_back(hour_script);
  if(lua_type(vm, 4) == LUA_TBOOLEAN && lua_toboolean(vm, 4) == true) periodicities.push_back(day_script);

  ntop_interface->checkNetworksAlerts(&periodicities, vm);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_check_interface_alerts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  std::vector<ScriptPeriodicity> periodicities;

  if(!ntop_interface) {
    lua_pushnil(vm);
    return(CONST_LUA_ERROR);
  }

  if(lua_type(vm, 1) == LUA_TBOOLEAN && lua_toboolean(vm, 1) == true) periodicities.push_back(minute_script);
  if(lua_type(vm, 2) == LUA_TBOOLEAN && lua_toboolean(vm, 2) == true) periodicities.push_back(five_minute_script);
  if(lua_type(vm, 3) == LUA_TBOOLEAN && lua_toboolean(vm, 3) == true) periodicities.push_back(hour_script);
  if(lua_type(vm, 4) == LUA_TBOOLEAN && lua_toboolean(vm, 4) == true) periodicities.push_back(day_script);

  ntop_interface->checkInterfaceAlerts(&periodicities, vm);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_flows_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char buf[64];
  char *host_ip = NULL;
  VLANid vlan_id = 0;
  Host *host = NULL;
  Paginator *p = NULL;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));
    host = ntop_interface->getHost(host_ip, vlan_id,
				   getLuaVMUservalue(vm, observationPointId),
				   false /* Not an inline call */);
  }

  if(lua_type(vm, 2) == LUA_TTABLE)
    p->readOptions(vm, 2);
  
  if(ntop_interface
     && (!host_ip || host))
    ntop_interface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm), host, p);
  else
    lua_pushnil(vm);

  if(p) delete p;
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_batched_interface_flows_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  Paginator *p = NULL;
  u_int32_t begin_slot = 0;
  bool walk_all = false;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNUMBER)
    begin_slot = (u_int32_t)lua_tonumber(vm, 1);

  if(lua_type(vm, 2) == LUA_TTABLE)
    p->readOptions(vm, 2);

  if(ntop_interface)
    ntop_interface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm), NULL, p);
  else
    lua_pushnil(vm);

  if(p) delete p;
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_get_grouped_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  Paginator *p = NULL;
  const char *group_col;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK
     || (p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  group_col = lua_tostring(vm, 1);

  if(lua_type(vm, 2) == LUA_TTABLE)
    p->readOptions(vm, 2);

  if(ntop_interface)
    ntop_interface->getFlowsGroup(vm, get_allowed_nets(vm), p, group_col);
  else
    lua_pushnil(vm);

  delete p;

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_flows_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) ntop_interface->getFlowsStats(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_networks_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool diff = false;

  if(lua_type(vm, 1) == LUA_TBOOLEAN)
    diff = lua_toboolean(vm, 1) ? true : false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface)
    ntop_interface->getNetworksStats(vm, get_allowed_nets(vm), diff);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_network_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int8_t network_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  network_id = (u_int8_t)lua_tointeger(vm, 1);

  if(ntop_interface) {
    lua_newtable(vm);
    ntop_interface->getNetworkStats(vm, network_id, get_allowed_nets(vm));
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_host_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((!ntop_interface) || !ntop_interface->getHostInfo(vm, get_allowed_nets(vm), host_ip, vlan_id))
    return(CONST_LUA_ERROR);
  else
    return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_host_country(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];
  Host* h = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if((!ntop_interface) || ((h = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId))) == NULL))
    return(CONST_LUA_ERROR);
  else {
    lua_pushstring(vm, h->get_country(buf, sizeof(buf)));
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

#ifdef NTOPNG_PRO
static int ntop_get_flow_devices(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    ntop_interface->getFlowDevices(vm);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_get_flow_device_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *device_ip;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  device_ip = (char*)lua_tostring(vm, 1);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    in_addr_t addr = inet_addr(device_ip);

    ntop_interface->getFlowDeviceInfo(vm, ntohl(addr));
    return(CONST_LUA_OK);
  }
}
#endif

/* ****************************************** */

static int ntop_discover_iface_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int timeout = 3; /* sec */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TNUMBER) timeout = (u_int)lua_tonumber(vm, 1);

  if(ntop_interface->getNetworkDiscovery()) {
    /* TODO: do it periodically and not inline */

    try {
      ntop_interface->getNetworkDiscovery()->discover(vm, timeout);
    } catch(...) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to perform network discovery");
    }

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_arpscan_iface_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(ntop_interface->getMDNS()) {
    /* This is a device we can use for network discovery */

    try {
      NetworkDiscovery *d;

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      if(Utils::gainWriteCapabilities() == -1)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

      d = ntop_interface->getNetworkDiscovery();

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      Utils::dropWriteCapabilities();
#endif

      if(d)
	d->arpScan(vm);
    } catch(...) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to perform network scan");
#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      Utils::dropWriteCapabilities();
#endif
    }

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_mdns_resolve_name(lua_State* vm) {
  char *numIP, symIP[64];
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((numIP = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  lua_pushstring(vm, ntop_interface->mdnsResolveIPv4(inet_addr(numIP),
						     symIP, sizeof(symIP),
						     1 /* timeout */));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_mdns_batch_any_query(lua_State* vm) {
  char *query, *target;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((target = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((query = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->mdnsSendAnyQuery(target, query);
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_mdns_queue_name_to_resolve(lua_State* vm) {
  char *numIP;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((numIP = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->mdnsQueueResolveIPv4(inet_addr(numIP), true);
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_mdns_read_queued_responses(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->mdnsFetchResolveResponses(vm, 2);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_getsflowdevices(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    ntop_interface->getSFlowDevices(vm);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_getsflowdeviceinfo(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *device_ip;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  device_ip = (char*)lua_tostring(vm, 1);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    in_addr_t addr = inet_addr(device_ip);

    ntop_interface->getSFlowDeviceInfo(vm, ntohl(addr));
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_restore_interface_host(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  /* Ensure that the user has privileges for the given host */
  if(ptree && !ptree->match(host_ip))
    return(CONST_LUA_ERROR);

  lua_pushboolean(vm, ntop_interface->restoreHost(host_ip, vlan_id));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_flow_key(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  Host *cli, *srv;
  char *cli_name = NULL;
  u_int16_t cli_port = 0;
  char *srv_name = NULL;
  u_int16_t srv_port = 0;
  VLANid cli_vlan = 0, srv_vlan = 0;
  u_int16_t protocol;
  char cli_buf[256], srv_buf[256];

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)    /* cli_host@cli_vlan */
     || (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) /* cli port          */
     || (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) /* srv_host@srv_vlan */
     || (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK) /* srv port          */
     || (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK) /* protocol          */
     ) return(CONST_LUA_ERROR);

  get_host_vlan_info((char*)lua_tostring(vm, 1), &cli_name, &cli_vlan, cli_buf, sizeof(cli_buf));
  cli_port = htons((u_int16_t)lua_tonumber(vm, 2));

  get_host_vlan_info((char*)lua_tostring(vm, 3), &srv_name, &srv_vlan, srv_buf, sizeof(srv_buf));
  srv_port = htons((u_int16_t)lua_tonumber(vm, 4));

  protocol = (u_int16_t)lua_tonumber(vm, 5);

  if(cli_vlan != srv_vlan) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Client and Server vlans don't match.");
    return(CONST_LUA_ERROR);
  }

  if(cli_name == NULL || srv_name == NULL
     ||(cli = ntop_interface->getHost(cli_name, cli_vlan, getLuaVMUservalue(vm, observationPointId), false /* Not an inline call */)) == NULL
     ||(srv = ntop_interface->getHost(srv_name, srv_vlan, getLuaVMUservalue(vm, observationPointId), false /* Not an inline call */)) == NULL) {
    lua_pushnil(vm);
  } else
    lua_pushinteger(vm, Flow::key(cli, cli_port, srv, srv_port, cli_vlan, getLuaVMUservalue(vm, observationPointId), protocol));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_flow_by_key_and_hash_id(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t key;
  u_int hash_id;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);
  bool set_context = false;
  
  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  /* Optional: set context */
  if(lua_type(vm, 3) == LUA_TBOOLEAN) set_context = lua_toboolean(vm, 3) ? true : false;

  key = (u_int32_t)lua_tonumber(vm, 1);
  hash_id = (u_int)lua_tonumber(vm, 2);

  if(!ntop_interface) return(false);

  f = ntop_interface->findFlowByKeyAndHashId(key, hash_id, ptree);

  if(f == NULL)
    return(CONST_LUA_ERROR);
  else {
    f->lua(vm, ptree, details_high, false);

    if(set_context) {
      struct ntopngLuaContext *c = getLuaVMContext(vm);
      
      c->flow = f, c->iface = f->getInterface();
    }
    
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_get_interface_find_flow_by_tuple(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  IpAddress src_ip_addr, dst_ip_addr;
  VLANid vlan_id, src_port, dst_port;
  u_int8_t l4_proto;
  char *src_ip, *dst_ip;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(false);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  src_ip = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  dst_ip = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  vlan_id = (u_int16_t)lua_tonumber(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  src_port = (u_int16_t)lua_tonumber(vm, 4);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  dst_port = (u_int16_t)lua_tonumber(vm, 5);

  if(ntop_lua_check(vm, __FUNCTION__, 6, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  l4_proto = (u_int8_t)lua_tonumber(vm, 6);

  src_ip_addr.set(src_ip), dst_ip_addr.set(dst_ip);

  f = ntop_interface->findFlowByTuple(vlan_id, getLuaVMUservalue(vm, observationPointId),
				      &src_ip_addr, &dst_ip_addr, htons(src_port), htons(dst_port), l4_proto, ptree);

  if(f == NULL)
    return(CONST_LUA_ERROR);
  else {
    f->lua(vm, ptree, details_high, false);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_drop_flow_traffic(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t key;
  u_int hash_id;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  key = (u_int32_t)lua_tonumber(vm, 1);
  hash_id = (u_int)lua_tonumber(vm, 2);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  f = ntop_interface->findFlowByKeyAndHashId(key, hash_id, ptree);

  if(f) {
    f->setDropVerdict();
    lua_pushboolean(vm, true);
  } else
    lua_pushboolean(vm, false);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_drop_multiple_flows_traffic(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  Paginator *p = NULL;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface) return(CONST_LUA_ERROR);
  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TTABLE)) return(CONST_LUA_ERROR);
  if((p = new(std::nothrow) Paginator()) == NULL) return(CONST_LUA_ERROR);
  p->readOptions(vm, 1);

  if(ntop_interface->dropFlowsTraffic(ptree, p) < 0)
    lua_pushboolean(vm, false);
  else
    lua_pushboolean(vm, true);

  if(p) delete p;
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_dump_local_hosts_2_redis(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  ntop_interface->dumpLocalHosts2redis(true /* must disable purge as we are called from lua */);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_pid_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t pid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  pid = (u_int32_t)lua_tonumber(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  ntop_interface->findPidFlows(vm, pid);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_proc_name_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *proc_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proc_name = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  ntop_interface->findProcNameFlows(vm, proc_name);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_list_http_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) != LUA_TSTRING) /* Optional */
    key = NULL;
  else
    key = (char*)lua_tostring(vm, 1);

  ntop_interface->listHTTPHosts(vm, key);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_host(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  key = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->findHostsByName(vm, get_allowed_nets(vm), key);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_host_by_mac(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *mac;
  u_int8_t _mac[6];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  mac = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  Utils::parseMac(_mac, mac);

  ntop_interface->findHostsByMac(vm, _mac);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_update_ip_reassignment(lua_State* vm) {
  NetworkInterface *ntop_interface;
  int ifid;
  bool enabled = false;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return(CONST_LUA_ERROR);

  ifid = lua_tointeger(vm, 1);
  ntop_interface = ntop->getInterfaceById(ifid);
  enabled = lua_toboolean(vm, 2);

  if(ntop_interface)
    ntop_interface->updateIPReassignment(enabled);

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_traffic_mirrored(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    ntop_interface->updateTrafficMirrored();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_dynamic_interface_traffic_policy(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    ntop_interface->updateDynIfaceTrafficPolicy();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_lbd_identifier(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    ntop_interface->updateLbdIdentifier();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_discard_probing_traffic(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    ntop_interface->updateDiscardProbingTraffic();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_flows_only_interface(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    ntop_interface->updateFlowsOnlyInterface();

  lua_pushnil(vm);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_update_host_traffic_policy(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(!ntop_interface)
    return CONST_LUA_ERROR;

  lua_pushboolean(vm, ntop_interface->updateHostTrafficPolicy(get_allowed_nets(vm), host_ip, vlan_id));
  return CONST_LUA_OK;
}

/* ****************************************** */

// *** API ***
static int ntop_get_interface_endpoint(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int8_t id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) != LUA_TNUMBER) /* Optional */
    id = 0;
  else
    id = (u_int8_t)lua_tonumber(vm, 1);

  if(ntop_interface) {
    char *endpoint = ntop_interface->getEndpoint(id); /* CHECK */

    lua_pushfstring(vm, "%s", endpoint ? endpoint : "");
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_protocols(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  ndpi_protocol_category_t category_filter = NDPI_PROTOCOL_ANY_CATEGORY;
  bool skip_critical = false;

  if(ntop_interface == NULL)
    ntop_interface = getCurrentInterface(vm);

  if(ntop_interface == NULL)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((lua_type(vm, 1) == LUA_TNUMBER)) {
    category_filter = (ndpi_protocol_category_t)lua_tointeger(vm, 1);

    if(category_filter >= NDPI_PROTOCOL_NUM_CATEGORIES) {
      lua_pushnil(vm);
      return(CONST_LUA_OK);
    }
  }
  if((lua_type(vm, 2) == LUA_TBOOLEAN)) skip_critical = lua_toboolean(vm, 2);

  ntop_interface->getnDPIProtocols(vm, category_filter, skip_critical);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_categories(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  }

  lua_newtable(vm);

  for (int i=0; i < NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
    char buf[8];
    const char *cat_name = ntop_interface->get_ndpi_category_name((ndpi_protocol_category_t)i);

    if(cat_name && *cat_name) {
      snprintf(buf, sizeof(buf), "%d", i);
      lua_push_str_table_entry(vm, cat_name, buf);
    }
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_load_scaling_factor_prefs(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  ntop_interface->loadScalingFactorPrefs();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reload_hide_from_top(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->reloadHideFromTop();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reload_gw_macs(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->requestGwMacsReload();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reload_dhcp_ranges(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->reloadDhcpRanges();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reload_host_prefs(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char buf[64], *host_ip;
  Host *host;
  VLANid vlan_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if((host = ntop_interface->getHost(host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId), false /* Not an inline call */)))
    host->reloadPrefs();

  lua_pushboolean(vm, (host != NULL));
  return(CONST_LUA_OK);
}

/* ****************************************** */

#if defined(HAVE_NINDEX) && defined(NTOPNG_PRO)

static int ntop_nindex_select(lua_State* vm) {
  u_int8_t id = 1;
  char *select = NULL, *where = NULL;
  bool export_results = false;
  char *timestamp_begin, *timestamp_end;
  u_int32_t start_record, end_record, skip_initial_records;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  NIndexFlowDB *nindex;
  struct mg_connection *conn;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    nindex = ntop_interface->getNindex();
    if(!nindex) return(CONST_LUA_ERROR);
  }

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((timestamp_begin = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((timestamp_end = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((select = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  where = (char*)lua_tostring(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  start_record = (u_int32_t)lua_tonumber(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  end_record = (u_int32_t)lua_tonumber(vm, id++);

  /* ntop->getTrace()->traceEvent(TRACE_ERROR, "[start_record: %u][end_record: %u]", start_record, end_record); */
  
  skip_initial_records = (start_record <= 1) ? 0 : start_record-1;

  if(lua_type(vm, id) == LUA_TBOOLEAN)
    export_results = lua_toboolean(vm, id++) ? true : false;

  conn = getLuaVMUserdata(vm, conn);

  return(nindex->select(vm,
			timestamp_begin, timestamp_end, select,
			where, skip_initial_records, end_record,
			export_results ? conn : NULL));
}

/* ****************************************** */

static int ntop_nindex_topk(lua_State* vm) {
  u_int8_t id = 1;
  char *select_keys = NULL, *select_values = NULL,*where = NULL;
  char *timestamp_begin, *timestamp_end;
  u_int32_t skip_initial_records, max_num_hits;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  NIndexFlowDB *nindex;
  char *_topkOperator;
  TopKSelectOperator topkOperator = topk_select_operator_sum;
  bool topToBottomSort, useApproxQuery;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    nindex = ntop_interface->getNindex();
    if(!nindex) return(CONST_LUA_ERROR);
  }

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((timestamp_begin = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((timestamp_end = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((select_keys = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((select_values = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  where = (char*)lua_tostring(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  _topkOperator = (char*)lua_tostring(vm, id++);

  if(!strcasecmp(_topkOperator, "sum")) topkOperator = topk_select_operator_sum;
  else if(!strcasecmp(_topkOperator, "count")) topkOperator = topk_select_operator_count;
  else if(!strcasecmp(_topkOperator, "min")) topkOperator = topk_select_operator_min;
  else topkOperator = topk_select_operator_max;

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  skip_initial_records = (u_int32_t)lua_tonumber(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  max_num_hits = (u_int32_t)lua_tonumber(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  topToBottomSort = lua_toboolean(vm, id++) ? true : false;

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  useApproxQuery = lua_toboolean(vm, id++) ? true : false;

  return(nindex->topk(vm,
		      timestamp_begin, timestamp_end,
		      select_keys, select_values,
		      where, topkOperator,
		      useApproxQuery, skip_initial_records,
		      max_num_hits, topToBottomSort));
}

static int ntop_nindex_enabled(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  lua_pushboolean(vm, ntop_interface && ntop_interface->getNindex());

  return(CONST_LUA_OK);
}

#endif

#ifdef NTOPNG_PRO

/* ****************************************** */

static int ntop_interface_enable_traffic_map(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool enable = false;

  if(lua_type(vm, 1) == LUA_TBOOLEAN) enable = (bool)lua_toboolean(vm, 1);
  
  ntop_interface->enableTrafficMap(enable);
    
  return(CONST_LUA_OK);
}

/* ****************************************** */
 
static int ntop_interface_get_traffic_map_enabled(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    lua_pushboolean(vm, false);
  else
    lua_pushboolean(vm, ntop_interface->isTrafficMapEnabled());
    
  return(CONST_LUA_OK);
}

/* ****************************************** */
  
static int ntop_interface_get_traffic_map_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop_interface->luaTrafficMap(vm);
    
  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

static void* pcapDumpLoop(void* ptr) {
  struct ntopngLuaContext *c = (struct ntopngLuaContext*)ptr;
  Utils::setThreadName("pcapDumpLoop");

  while(c->pkt_capture.captureInProgress) {
    u_char *pkt;
    struct pcap_pkthdr *h;
    int rc = pcap_next_ex(c->pkt_capture.pd, &h, (const u_char **) &pkt);

    if(rc > 0) {
      pcap_dump((u_char*)c->pkt_capture.dumper, (const struct pcap_pkthdr*)h, pkt);

      if(h->ts.tv_sec > (time_t)c->pkt_capture.end_capture)
	break;
    } else if(rc < 0) {
      break;
    } else if(rc == 0) {
      if(time(NULL) > (time_t)c->pkt_capture.end_capture)
	break;
    }
  } /* while */

  if(c->pkt_capture.dumper) {
    pcap_dump_close(c->pkt_capture.dumper);
    c->pkt_capture.dumper = NULL;
  }

  if(c->pkt_capture.pd) {
    pcap_close(c->pkt_capture.pd);
    c->pkt_capture.pd = NULL;
  }

  c->pkt_capture.captureInProgress = false;

  return(NULL);
}

/* ****************************************** */

static int ntop_capture_to_pcap(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int8_t capture_duration;
  char *bpfFilter = NULL, ftemplate[64];
  char errbuf[PCAP_ERRBUF_SIZE];
  struct bpf_program fcode;
  struct ntopngLuaContext *c;

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  c = getLuaVMContext(vm);

  if((!ntop_interface) || (!c))
    return(CONST_LUA_ERROR);

  if(c->pkt_capture.pd != NULL /* Another capture is in progress */)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  capture_duration = (u_int32_t)lua_tonumber(vm, 1);

  if(lua_type(vm, 2) != LUA_TSTRING) /* Optional */
    bpfFilter = (char*)lua_tostring(vm, 2);

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
  if(Utils::gainWriteCapabilities() == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

  if((c->pkt_capture.pd = pcap_open_live(ntop_interface->get_name(),
					 1514, 0 /* promisc */, 500, errbuf)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to open %s for capture: %s",
				 ntop_interface->get_name(), errbuf);
#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
    Utils::dropWriteCapabilities();
#endif

    return(CONST_LUA_ERROR);
  }

  if(bpfFilter != NULL) {
    if(pcap_compile(c->pkt_capture.pd, &fcode, bpfFilter, 1, 0xFFFFFF00) < 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "pcap_compile error: '%s'", pcap_geterr(c->pkt_capture.pd));
    } else {
      if(pcap_setfilter(c->pkt_capture.pd, &fcode) < 0) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "pcap_setfilter error: '%s'", pcap_geterr(c->pkt_capture.pd));
      }
    }
  }

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
  Utils::dropWriteCapabilities();
#endif

  snprintf(ftemplate, sizeof(ftemplate), "/tmp/ntopng_%s_%u.pcap",
	   ntop_interface->get_name(), (unsigned int)time(NULL));
  c->pkt_capture.dumper = pcap_dump_open(pcap_open_dead(DLT_EN10MB, 1514 /* MTU */), ftemplate);

  if(c->pkt_capture.dumper == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create dump file %s\n", ftemplate);
    return(CONST_LUA_ERROR);
  }

  /* Capture sessions can't be longer than 30 sec */
  if(capture_duration > 30) capture_duration = 30;

  c->pkt_capture.end_capture = time(NULL) + capture_duration;

  c->pkt_capture.captureInProgress = true;
  pthread_create(&c->pkt_capture.captureThreadLoop, NULL, pcapDumpLoop, (void*)c);

  lua_pushstring(vm, ftemplate);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_capture_running(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  struct ntopngLuaContext *c;

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  c = getLuaVMContext(vm);

  if((!ntop_interface) || (!c))
    return(CONST_LUA_ERROR);

  lua_pushboolean(vm, (c->pkt_capture.pd != NULL /* Another capture is in progress */) ? true : false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_stop_running_capture(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  struct ntopngLuaContext *c;

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  c = getLuaVMContext(vm);

  if((!ntop_interface) || (!c))
    return(CONST_LUA_ERROR);

  c->pkt_capture.end_capture = 0;

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_all));
}

static int ntop_get_interface_local_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_local_only));
}

static int ntop_get_interface_remote_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_remote_only));
}

static int ntop_get_interface_broadcast_domain_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_broadcast_domain_only));
}

static int ntop_get_public_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_public_only));
}

/* ****************************************** */

static int ntop_get_batched_interface_hosts_info(lua_State* vm) {
  return(ntop_get_batched_interface_hosts(vm, location_all));
}

static int ntop_get_batched_interface_local_hosts_info(lua_State* vm) {
  return(ntop_get_batched_interface_hosts(vm, location_local_only));
}

static int ntop_get_batched_interface_remote_hosts_info(lua_State* vm) {
  return(ntop_get_batched_interface_hosts(vm, location_remote_only));
}

static int ntop_get_batched_interface_local_hosts_ts(lua_State* vm) {
  return(ntop_get_batched_interface_hosts(vm, location_local_only, true /* timeseries */));
}


/* ****************************************** */

static int ntop_interface_store_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_store_triggered_alert(vm, c->iface);
}

/* ****************************************** */

static int ntop_get_interface_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->lua(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_update_interface_direction_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->updateDirectionStats();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_update_interface_top_sites(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->updateSitesStats();

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_stats_update_freq(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface)
    lua_pushinteger(vm, ntop_interface->periodicStatsUpdateFrequency());
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_hash_tables_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface)
    ntop_interface->lua_hash_tables_stats(vm);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_periodic_activities_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = NULL;
  int ifid;

  if(lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    ntop_interface = ntop->getInterfaceById(ifid);
  } else
    ntop_interface = getCurrentInterface(vm);

  if(ntop_interface)
    ntop_interface->lua_periodic_activities_stats(vm);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_queues_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = NULL;
  int ifid;

  if(lua_type(vm, 1) == LUA_TNUMBER) {
    ifid = lua_tointeger(vm, 1);
    ntop_interface = ntop->getInterfaceById(ifid);
  } else
    ntop_interface = getCurrentInterface(vm);

  lua_newtable(vm);

  if(ntop_interface)
    ntop_interface->lua_queues_stats(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_interface_periodic_activity_progress(lua_State* vm) {
  int progress;
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_ERROR);

  progress = (int)lua_tonumber(vm, 1);

  if(ctx && ctx->threaded_activity_stats)
    ctx->threaded_activity_stats->setCurrentProgress(progress);

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_active_flows_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats ndpi_stats;
  FlowStats stats;
  char *host_ip = NULL;
  VLANid vlan_id = 0;
  char buf[64];
  bool only_traffic_stats = false;
  Host *host = NULL;
  Paginator *p = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  /* Optional host */
  if(lua_type(vm, 1) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));
    host = ntop_interface->getHost(host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId), false /* Not an inline call */);
  }

  if(lua_type(vm, 2) == LUA_TTABLE)
    p->readOptions(vm, 2);

  if(lua_type(vm, 3) == LUA_TBOOLEAN)
    only_traffic_stats = (bool)lua_toboolean(vm, 3);
  
  if(ntop_interface) {
    ntop_interface->getActiveFlowsStats(&ndpi_stats, &stats, get_allowed_nets(vm), host, p, vm, only_traffic_stats);
  } else
    lua_pushnil(vm);

  if(p) delete p;

  return(CONST_LUA_OK);
}

/* ****************************************** */

/* curl -i -XPOST "http://localhost:8086/write?precision=s&db=ntopng" --data-binary 'profile:traffic,ifid=0,profile=a profile bytes=2506351 1559634840' */
static int ntop_append_influx_db(lua_State* vm) {
  bool rv = false;
  NetworkInterface *ntop_interface;

  if((ntop_interface = getCurrentInterface(vm))
     && ntop_interface->getInfluxDBTSExporter()
     && ntop_interface->getInfluxDBTSExporter()->enqueueData(vm))
    rv = true;

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_rrd_queue_push(lua_State* vm) {
  bool rv = false;
  NetworkInterface *ntop_interface;
  TimeseriesExporter *ts_exporter;

    if((ntop_interface = getCurrentInterface(vm))
       && (ts_exporter = ntop_interface->getRRDTSExporter())) {
      rv = ts_exporter->enqueueData(vm);
    }

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_rrd_queue_pop(lua_State* vm) {
  int ifid;
  NetworkInterface* iface;
  TimeseriesExporter *ts_exporter;
  char *ts_point;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_ERROR);

  ifid = lua_tointeger(vm, 1);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(ts_exporter = iface->getRRDTSExporter()))
    return(CONST_LUA_ERROR);

  ts_point = ts_exporter->dequeueData();

  if(ts_point) {
    lua_pushstring(vm, ts_point);
    free(ts_point);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_rrd_queue_length(lua_State* vm) {
  int ifid;
  NetworkInterface* iface;
  TimeseriesExporter *ts_exporter;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_ERROR);

  ifid = lua_tointeger(vm, 1);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(ts_exporter = iface->getRRDTSExporter()))
    return(CONST_LUA_ERROR);

  lua_pushinteger(vm, ts_exporter->queueLength());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_checkpoint_host_talker(lua_State* vm) {
  int ifid;
  NetworkInterface *iface = NULL;
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  ifid = (int)lua_tointeger(vm, 1);
  iface = ntop->getInterfaceById(ifid);

  get_host_vlan_info((char*)lua_tostring(vm, 2), &host_ip, &vlan_id, buf, sizeof(buf));

  if(iface && !iface->isViewed())
    iface->checkPointHostTalker(vm, host_ip, vlan_id);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef NTOPNG_PRO

#ifdef HAVE_NEDGE
/* NOTE: do no call this directly - use host_pools_utils.resetPoolsQuotas instead */
static int ntop_reset_pools_quotas(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int16_t pool_id_filter = (u_int16_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNUMBER) pool_id_filter = (u_int16_t)lua_tonumber(vm, 1);

  if(ntop_interface) {
    ntop_interface->resetPoolsStats(pool_id_filter);

    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}
#endif

#endif

/* ****************************************** */

static int ntop_find_member_pool(lua_State *vm) {
  char *address;
  VLANid vlan_id = 0;
  bool is_mac;
  ndpi_patricia_node_t *target_node = NULL;
  u_int16_t pool_id;
  bool pool_found;
  char buf[64];

  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((address = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  is_mac = lua_toboolean(vm, 3);

  if(ntop_interface && ntop_interface->getHostPools()) {
    if(is_mac) {
      u_int8_t mac_bytes[6];
      Utils::parseMac(mac_bytes, address);
      pool_found = ntop_interface->getHostPools()->findMacPool(mac_bytes, &pool_id);
    } else {
      IpAddress ip;
      ip.set(address);

      pool_found = ntop_interface->getHostPools()->findIpPool(&ip, vlan_id, &pool_id, &target_node);
    }

    if(pool_found) {
      lua_newtable(vm);
      lua_push_uint64_table_entry(vm, "pool_id", pool_id);

      if(target_node != NULL) {
	ndpi_prefix_t *prefix = ndpi_patricia_get_node_prefix(target_node);
        lua_push_str_table_entry(vm, "matched_prefix", (char *)inet_ntop(prefix->family,
									 (prefix->family == AF_INET6) ?
									 (void*)(&prefix->add.sin6) :
									 (void*)(&prefix->add.sin),
									 buf, sizeof(buf)));
        lua_push_uint64_table_entry(vm, "matched_bitmask", ndpi_patricia_get_node_bits(target_node));
      }
    } else
      lua_pushnil(vm);

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* *******************************************/

static int ntop_find_mac_pool(lua_State *vm) {
  const char *mac;
  u_int8_t mac_parsed[6];
  u_int16_t pool_id;

  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  mac = lua_tostring(vm, 1);

  Utils::parseMac(mac_parsed, mac);

  if(ntop_interface && ntop_interface->getHostPools()) {
    if(ntop_interface->getHostPools()->findMacPool(mac_parsed, &pool_id))
      lua_pushinteger(vm, pool_id);
    else
      lua_pushnil(vm);

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* *******************************************/

#ifdef HAVE_NEDGE

static int ntop_reload_l7_rules(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);

  if(ntop_interface) {
    u_int16_t host_pool_id = (u_int16_t)lua_tonumber(vm, 1);

#ifdef SHAPER_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%i)", __FUNCTION__, host_pool_id);
#endif

    ntop_interface->refreshL7Rules();
    ntop_interface->updateHostsL7Policy(host_pool_id);
    ntop_interface->updateFlowsL7Policy();

    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_reload_shapers(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {
#ifdef NTOPNG_PRO
    ntop_interface->refreshShapers();
#endif
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

#endif

/* ****************************************** */

static int ntop_interface_get_cached_alert_value(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  char *key;
  std::string val;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!c->iface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 2)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  val = c->iface->getAlertCachedValue(std::string(key), periodicity);
  lua_pushstring(vm, val.c_str());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_set_cached_alert_value(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  char *key, *value;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!c->iface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 3)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  if((!key) || (!value))
    return(CONST_LUA_PARAM_ERROR);

  c->iface->setAlertCacheValue(std::string(key), std::string(value), periodicity);
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_check_context(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  char *entity_val;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((entity_val = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if((c->iface == NULL) || (strcmp(c->iface->getEntityValue().c_str(), entity_val)) != 0) {
    /* NOTE: settting a context for a differnt interface is currently not supported */
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Bad context for interface %s", entity_val);
    return(CONST_LUA_ERROR);
  }

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_release_engaged_alerts(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  iface->releaseAllEngagedAlerts();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_inc_total_host_alerts(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  VLANid vlan_id = 0;
#ifdef UNUSED
  AlertType alert_type;
#endif
  char buf[64], *host_ip;
  Host *h;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

#ifdef UNUSED
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_type = (AlertType)lua_tonumber(vm, 2);
#endif
  
  h = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId));

  if(h)
    h->incTotalAlerts();

  lua_pushboolean(vm, h ? true : false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_periodicity_map(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  IpAddress *ip = NULL;
  char * l7_proto = NULL;
  VLANid vlan_id = 0, host_pool_id = 0, filter_ndpi_proto = 0;
  u_int32_t first_seen = 0;
  bool unicast = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    ip = new (std::nothrow) IpAddress();
    if(ip) ip->set((char*)lua_tostring(vm, 1));    
  }
  if(lua_type(vm, 2) == LUA_TNUMBER)  vlan_id      = (u_int16_t)lua_tonumber(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER)  host_pool_id = (u_int16_t)lua_tonumber(vm, 3);
  if(lua_type(vm, 4) == LUA_TBOOLEAN) unicast      = (bool)lua_toboolean(vm, 4);
  if(lua_type(vm, 5) == LUA_TNUMBER)  first_seen   = (u_int32_t)lua_tonumber(vm, 5);
  if(lua_type(vm, 6) == LUA_TSTRING)  l7_proto     = (char *)lua_tostring(vm, 6);

  if(l7_proto)
    filter_ndpi_proto = ndpi_get_protocol_id(ntop_interface->get_ndpi_struct(), l7_proto);

  if(ntop_interface)
    ntop_interface->luaPeriodicityStats(vm, ip, vlan_id, host_pool_id, unicast, first_seen, filter_ndpi_proto);
  else
    lua_pushnil(vm);

  if(ip) delete ip;

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flush_interface_periodicity_map(lua_State* vm) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  ntop_interface->flushPeriodicityMap();
#endif

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_service_map(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  IpAddress *ip = NULL;
  char *l7_proto = NULL;
  VLANid vlan_id = 0, host_pool_id = 0, filter_ndpi_proto = 0;
  u_int32_t first_seen = 0;
  bool unicast = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    ip = new (std::nothrow) IpAddress();
    if(ip) ip->set((char*)lua_tostring(vm, 1));    
  }

  if(lua_type(vm, 2) == LUA_TNUMBER)  vlan_id           = (u_int16_t)lua_tonumber(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER)  host_pool_id      = (u_int16_t)lua_tonumber(vm, 3);
  if(lua_type(vm, 4) == LUA_TBOOLEAN) unicast           = (bool)lua_toboolean(vm, 4);
  if(lua_type(vm, 5) == LUA_TNUMBER)  first_seen        = (u_int32_t)lua_tonumber(vm, 5);
  if(lua_type(vm, 6) == LUA_TSTRING)  l7_proto          = (char *)lua_tostring(vm, 6);

  if(l7_proto)
    filter_ndpi_proto = ndpi_get_protocol_id(ntop_interface->get_ndpi_struct(), l7_proto);

  if(ntop_interface)
    ntop_interface->luaServiceMap(vm, ip, vlan_id, host_pool_id, unicast, first_seen, filter_ndpi_proto);
  else
    lua_pushnil(vm);

  if(ip) delete ip;

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_flush_interface_service_map(lua_State* vm) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  ntop_interface->flushServiceMap();
#endif

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_service_map_set_status(lua_State* vm) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int64_t hash_id;
  ServiceAcceptance acceptance;
  char* buff;
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  if(ntop_interface) {

    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
    if((buff = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);
    hash_id = strtoull(buff, NULL, 10);

    if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
    acceptance = (ServiceAcceptance)lua_tonumber(vm, 2);

    ntop_interface->getServiceMap()->setStatus(hash_id, acceptance);
  }
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_service_map_set_multiple_status(lua_State* vm) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  ServiceAcceptance current_status = service_unknown, new_status = service_unknown;
  u_int16_t proto_id = 0xFF;
  char* l7_proto = NULL;
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  if(ntop_interface) {

    if(lua_type(vm, 1) == LUA_TSTRING)  l7_proto       = (char*)lua_tostring(vm, 1);
    if(lua_type(vm, 2) == LUA_TNUMBER)  current_status = (ServiceAcceptance)lua_tonumber(vm, 2);
    if(lua_type(vm, 3) == LUA_TNUMBER)  new_status     = (ServiceAcceptance)lua_tonumber(vm, 3);

    if(l7_proto != NULL) proto_id = ndpi_get_protocol_id(ntop_interface->get_ndpi_struct(), l7_proto);

    ntop_interface->getServiceMap()->setBatchStatus(proto_id, current_status, new_status);
  }
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_service_map_learning_status(lua_State* vm) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  if(ntop_interface)
    ntop_interface->luaServiceMapStatus(vm);
  else
    lua_pushnil(vm);
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_periodicity_proto_filtering_menu(lua_State* vm) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  if(ntop_interface)
    ntop_interface->luaPeriodicityFilteringMenu(vm);
  else
    lua_pushnil(vm);
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_service_proto_filtering_menu(lua_State* vm) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  if(ntop_interface)
    ntop_interface->luaServiceFilteringMenu(vm);
  else
    lua_pushnil(vm);
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_address_info(lua_State* vm) {
  char *addr;
  IpAddress ip;
  int16_t network_id;
  
  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  addr = (char*)lua_tostring(vm, 1);

  ip.set(addr);

  lua_newtable(vm);
  lua_push_bool_table_entry(vm, "is_blacklisted", ip.isBlacklistedAddress());
  lua_push_bool_table_entry(vm, "is_broadcast",   ip.isBroadcastAddress());
  lua_push_bool_table_entry(vm, "is_multicast",   ip.isMulticastAddress());
  lua_push_bool_table_entry(vm, "is_private",     ip.isPrivateAddress());
  lua_push_bool_table_entry(vm, "is_local",       ip.isLocalHost(&network_id));

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef NTOPNG_PRO
static int ntop_interface_get_traffic_map_host_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else
    ntop_interface->luaTrafficMapHostStats(vm, get_allowed_nets(vm), host_ip, vlan_id);
      
  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

static int ntop_get_ndpi_host_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    if(!ntop_interface->getHostMinInfo(vm, get_allowed_nets(vm), host_ip, vlan_id, true))
      ntop_get_address_info(vm);

    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_get_interface_get_host_min_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  VLANid vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    if(!ntop_interface->getHostMinInfo(vm, get_allowed_nets(vm), host_ip, vlan_id, false))
      ntop_get_address_info(vm);

    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

#ifdef HAVE_NEDGE

static int ntop_update_flows_shapers(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface)
    ntop_interface->updateFlowsL7Policy();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_policy_change_marker(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface && (ntop_interface->getIfType() == interface_type_NETFILTER))
    lua_pushinteger(vm, ((NetfilterInterface *)ntop_interface)->getPolicyChangeMarker());
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_lan_ip_address(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);

  const char* ip = lua_tostring(vm, 1);

  if(ntop_interface && (ntop_interface->getIfType() == interface_type_NETFILTER))
    ((NetfilterInterface *)ntop_interface)->setLanIPAddress(inet_addr(ip));

  if(ntop->get_HTTPserver())
    ntop->get_HTTPserver()->setCaptiveRedirectAddress(ip);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_l7_policy_info(lua_State* vm) {
  u_int16_t pool_id;
  u_int8_t shaper_id;
  ndpi_protocol proto;
  DeviceType dev_type;
  bool as_client;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  L7PolicySource_t policy_source;
  DeviceProtoStatus device_proto_status;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface || !ntop_interface->getL7Policer()) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);

  pool_id = (u_int16_t)lua_tointeger(vm, 1);
  proto.master_protocol = (u_int16_t)lua_tointeger(vm, 2);
  proto.app_protocol = proto.master_protocol;
  proto.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED; // important for ndpi_get_proto_category below

  // set appropriate category based on the protocols
  proto.category = ndpi_get_proto_category(ntop_interface->get_ndpi_struct(), proto);

  dev_type = (DeviceType)lua_tointeger(vm, 3);
  as_client = lua_toboolean(vm, 4);

  if(ntop->getPrefs()->are_device_protocol_policies_enabled() &&
      ((device_proto_status = ntop->getDeviceAllowedProtocolStatus(dev_type, proto, pool_id, as_client)) != device_proto_allowed)) {
    shaper_id = DROP_ALL_SHAPER_ID;
    policy_source = policy_source_device_protocol;
  } else {
    shaper_id = ntop_interface->getL7Policer()->getShaperIdForPool(pool_id, proto, !as_client, &policy_source);
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "shaper_id", shaper_id);
  lua_push_str_table_entry(vm, "policy_source", (char*)Utils::policySource2Str(policy_source));

  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

// *** API ***
static int ntop_interface_is_syslog_interface(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, ntop_interface->isSyslogInterface());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static luaL_Reg _ntop_interface_reg[] = {
  { "setActiveInterfaceId",     ntop_set_active_interface_id },
  { "getIfNames",               ntop_get_interface_names },
  { "getFirstInterfaceId",      ntop_get_first_interface_id },
  { "select",                   ntop_select_interface },
  { "getId",                    ntop_get_interface_id },
  { "getName",                  ntop_get_interface_name },
  { "isValidIfId",              ntop_is_valid_interface_id },
  { "getObservationPoints",     ntop_interface_get_observation_points },
  { "getMaxIfSpeed",            ntop_get_max_if_speed },
  { "hasVLANs",                 ntop_interface_has_vlans },
  { "hasEBPF",                  ntop_interface_has_ebpf  },
  { "hasExternalAlerts",        ntop_interface_has_external_alerts  },
  { "getStats",                 ntop_get_interface_stats },
  { "getStatsUpdateFreq",       ntop_get_interface_stats_update_freq },
  { "updateDirectionStats",     ntop_update_interface_direction_stats },
  { "updateTopSites",           ntop_update_interface_top_sites},
  { "resetCounters",            ntop_interface_reset_counters },
  { "resetHostStats",           ntop_interface_reset_host_stats },
  { "deleteHostData",           ntop_interface_delete_host_data },
  { "resetMacStats",            ntop_interface_reset_mac_stats },
  { "deleteMacData",            ntop_interface_delete_mac_data },

  /* Functions related to the management of per-interface queues */
  { "getQueuesStats",           ntop_get_interface_queues_stats },

  /* Functions related to the management of the internal hash tables */
  { "getHashTablesStats",       ntop_get_interface_hash_tables_stats },

  /* Functions to get and reset the duration of periodic threaded activities */
  { "getPeriodicActivitiesStats",   ntop_get_interface_periodic_activities_stats   },
  { "setPeriodicActivityProgress",  ntop_set_interface_periodic_activity_progress  },

#ifndef HAVE_NEDGE
  { "processFlow",              ntop_process_flow },
  { "updateSyslogProducers",    ntop_update_syslog_producers },
#endif

  { "getActiveFlowsStats",      ntop_get_active_flows_stats },
  { "getnDPIProtoName",         ntop_get_ndpi_protocol_name },
  { "getnDPIFullProtoName",     ntop_get_ndpi_full_protocol_name },
  { "getnDPIProtoId",           ntop_get_ndpi_protocol_id },
  { "getnDPICategoryId",        ntop_get_ndpi_category_id },
  { "getnDPICategoryName",      ntop_get_ndpi_category_name },
  { "getnDPIFlowsCount",        ntop_get_ndpi_interface_flows_count },
  { "getnDPIStats",             ntop_get_ndpi_interface_stats },
  { "getnDPIHostStats",         ntop_get_ndpi_host_stats },
  { "getFlowsStatus",           ntop_get_ndpi_interface_flows_status },
  { "getnDPIProtoBreed",        ntop_get_ndpi_protocol_breed },
  { "getnDPIProtocols",         ntop_get_ndpi_protocols },
  { "getnDPICategories",        ntop_get_ndpi_categories },
  { "getHostsInfo",             ntop_get_interface_hosts_info },
  { "getLocalHostsInfo",        ntop_get_interface_local_hosts_info },
  { "getRemoteHostsInfo",       ntop_get_interface_remote_hosts_info },
  { "getBroadcastDomainHostsInfo", ntop_get_interface_broadcast_domain_hosts_info },
  { "getPublicHostsInfo",          ntop_get_public_hosts_info },
  { "getBatchedFlowsInfo",         ntop_get_batched_interface_flows_info },
  { "getBatchedHostsInfo",         ntop_get_batched_interface_hosts_info },
  { "getBatchedLocalHostsInfo",    ntop_get_batched_interface_local_hosts_info },
  { "getBatchedRemoteHostsInfo",   ntop_get_batched_interface_remote_hosts_info },
  { "getBatchedLocalHostsTs",   ntop_get_batched_interface_local_hosts_ts },
  { "getHostInfo",              ntop_get_interface_host_info },
  { "getHostMinInfo",           ntop_get_interface_get_host_min_info },
  { "getHostCountry",           ntop_get_interface_host_country },
  { "addMacsIpAddresses",       ntop_add_macs_ip_addresses },
  { "getNetworksStats",         ntop_get_interface_networks_stats       },
  { "getNetworkStats",          ntop_get_interface_network_stats        },
  { "restoreHost",              ntop_restore_interface_host             },
  { "checkpointHostTalker",     ntop_checkpoint_host_talker             },
  { "getFlowsInfo",             ntop_get_interface_flows_info           },
  { "getGroupedFlows",          ntop_get_interface_get_grouped_flows    },
  { "getFlowsStats",            ntop_get_interface_flows_stats          },
  { "getFlowKey",               ntop_get_interface_flow_key             },
  { "getScore",                 ntop_get_interface_score                },
  { "findFlowByKeyAndHashId",   ntop_get_interface_find_flow_by_key_and_hash_id  },
  { "findFlowByTuple",          ntop_get_interface_find_flow_by_tuple   },
  { "dropFlowTraffic",          ntop_drop_flow_traffic                  },
  { "dumpLocalHosts2redis",     ntop_dump_local_hosts_2_redis           },
  { "dropMultipleFlowsTraffic", ntop_drop_multiple_flows_traffic        },
  { "findPidFlows",             ntop_get_interface_find_pid_flows       },
  { "findNameFlows",            ntop_get_interface_find_proc_name_flows },
  { "listHTTPhosts",            ntop_list_http_hosts },
  { "findHost",                 ntop_get_interface_find_host },
  { "findHostByMac",            ntop_get_interface_find_host_by_mac },
  { "updateIPReassignment",             ntop_interface_update_ip_reassignment        },
  { "updateTrafficMirrored",            ntop_update_traffic_mirrored                 },
  { "updateDynIfaceTrafficPolicy",      ntop_update_dynamic_interface_traffic_policy },
  { "updateLbdIdentifier",              ntop_update_lbd_identifier                   },
  { "updateHostTrafficPolicy",          ntop_update_host_traffic_policy              },
  { "updateDiscardProbingTraffic",      ntop_update_discard_probing_traffic          },
  { "updateFlowsOnlyInterface",         ntop_update_flows_only_interface             },
  { "getEndpoint",                      ntop_get_interface_endpoint },
  { "isPacketInterface",                ntop_interface_is_packet_interface },
  { "isDiscoverableInterface",          ntop_interface_is_discoverable_interface },
  { "isBridgeInterface",                ntop_interface_is_bridge_interface },
  { "isPcapDumpInterface",              ntop_interface_is_pcap_dump_interface },
  { "isView",                           ntop_interface_is_view },
  { "isViewed",                         ntop_interface_is_viewed },
  { "viewedBy",                         ntop_interface_viewed_by },
  { "isLoopback",                       ntop_interface_is_loopback },
  { "isRunning",                        ntop_interface_is_running },
  { "isIdle",                           ntop_interface_is_idle },
  { "setInterfaceIdleState",            ntop_interface_set_idle },
  { "name2id",                          ntop_interface_name2id },
  { "loadScalingFactorPrefs",           ntop_load_scaling_factor_prefs },
  { "reloadHideFromTop",                ntop_reload_hide_from_top },
  { "reloadGwMacs",                     ntop_reload_gw_macs },
  { "reloadDhcpRanges",                 ntop_reload_dhcp_ranges },
  { "reloadHostPrefs",                  ntop_reload_host_prefs },
  { "setHostOperatingSystem",           ntop_set_host_operating_system },
  { "getNumLocalHosts",                 ntop_get_num_local_hosts },
  { "getNumHosts",                      ntop_get_num_hosts       },
  { "getNumFlows",                      ntop_get_num_flows       },
  { "periodicityMap",                   ntop_get_interface_periodicity_map },
  { "flushPeriodicityMap",              ntop_flush_interface_periodicity_map },
  { "serviceMap",                       ntop_get_interface_service_map },
  { "flushServiceMap",                  ntop_flush_interface_service_map },
  { "serviceMapLearningStatus",         ntop_interface_service_map_learning_status },
  { "serviceMapSetStatus",              ntop_interface_service_map_set_status },
  { "serviceMapSetMultipleStatus",      ntop_interface_service_map_set_multiple_status },
  { "periodicityFilteringMenu",         ntop_get_interface_periodicity_proto_filtering_menu },
  { "serviceFilteringMenu",             ntop_get_interface_service_proto_filtering_menu },
  { "getThroughput",                    ntop_interface_get_throughput },
  
  /* Addresses */
  { "getAddressInfo",                   ntop_get_address_info },

  /* Mac */
  { "getMacsInfo",                      ntop_get_interface_macs_info },
  { "getBatchedMacsInfo",               ntop_get_batched_interface_macs_info },
  { "getMacInfo",                       ntop_get_interface_mac_info  },
  { "getMacHosts",                      ntop_get_interface_mac_hosts },
  { "getMacManufacturers",              ntop_get_interface_macs_manufacturers },
  { "getMacDeviceTypes",                ntop_get_mac_device_types },

  /* Anomalies */
  { "getAnomalies",                     ntop_get_interface_anomalies },
  
  /* Autonomous Systems */
  { "getASesInfo",                      ntop_get_interface_ases_info },
  { "getASInfo",                        ntop_get_interface_as_info },

  /* Operating Systems */
  { "getOSesInfo",                      ntop_get_interface_oses_info },
  { "getOSInfo",                        ntop_get_interface_os_info },

  /* Countries */
  { "getCountriesInfo",                 ntop_get_interface_countries_info },
  { "getCountryInfo",                   ntop_get_interface_country_info },

  /* VLANs */
  { "getVLANsList",                     ntop_get_interface_vlans_list },
  { "getVLANsInfo",                     ntop_get_interface_vlans_info },
  { "getVLANInfo",                      ntop_get_interface_vlan_info } ,

  /* Host pools */
  { "findMemberPool",                   ntop_find_member_pool                 },
  { "findMacPool",                      ntop_find_mac_pool                    },
  { "getHostPoolsInfo",                 ntop_get_host_pools_info              },

  /* InfluxDB */
  { "appendInfluxDB",                   ntop_append_influx_db                 },

  /* RRD queue */
  { "rrd_enqueue",                      ntop_rrd_queue_push                   },
  { "rrd_dequeue",                      ntop_rrd_queue_pop                    },
  { "rrd_queue_length",                 ntop_rrd_queue_length                 },

  { "getHostPoolsStats",                ntop_get_host_pools_interface_stats   },
  { "getHostPoolStats",                 ntop_get_host_pool_interface_stats    },
#ifdef NTOPNG_PRO
#ifdef HAVE_NEDGE
  { "resetPoolsQuotas",                 ntop_reset_pools_quotas               },
#endif
  { "getHostUsedQuotasStats",           ntop_get_host_used_quotas_stats       },

  /* SNMP */
  { "getSNMPStats",                     ntop_interface_get_snmp_stats         },

  /* Flow Devices */
  { "getFlowDevices",                   ntop_get_flow_devices                  },
  { "getFlowDeviceInfo",                ntop_get_flow_device_info              },

#ifdef HAVE_NEDGE
  /* L7 */
  { "reloadL7Rules",                    ntop_reload_l7_rules                   },
  { "reloadShapers",                    ntop_reload_shapers                    },
  { "setLanIpAddress",                  ntop_set_lan_ip_address                },
  { "getPolicyChangeMarker",            ntop_get_policy_change_marker          },
  { "updateFlowsShapers",               ntop_update_flows_shapers              },
  { "getl7PolicyInfo",                  ntop_get_l7_policy_info                },
#endif
#endif

  /* Network Discovery */
  { "discoverHosts",                   ntop_discover_iface_hosts       },
  { "arpScanHosts",                    ntop_arpscan_iface_hosts        },
  { "mdnsResolveName",                 ntop_mdns_resolve_name          },
  { "mdnsQueueNameToResolve",          ntop_mdns_queue_name_to_resolve },
  { "mdnsQueueAnyQuery",               ntop_mdns_batch_any_query       },
  { "mdnsReadQueuedResponses",         ntop_mdns_read_queued_responses },

  /* DB */
  { "execSQLQuery",                    ntop_interface_exec_sql_query   },

  /* sFlow */
  { "getSFlowDevices",                 ntop_getsflowdevices            },
  { "getSFlowDeviceInfo",              ntop_getsflowdeviceinfo         },

#if defined(HAVE_NINDEX) && defined(NTOPNG_PRO)
  /* nIndex */
  { "nIndexEnabled",                   ntop_nindex_enabled             },
  { "nIndexSelect",                    ntop_nindex_select              },
  { "nIndexTopK",                      ntop_nindex_topk                },
#endif

  /* Live Capture */
  { "liveCapture",            ntop_interface_live_capture             },
  { "stopLiveCapture",        ntop_interface_stop_live_capture        },
  { "dumpLiveCaptures",       ntop_interface_dump_live_captures       },

  /* Packet Capture */
  { "captureToPcap",          ntop_capture_to_pcap                    },
  { "isCaptureRunning",       ntop_is_capture_running                 },
  { "stopRunningCapture",     ntop_stop_running_capture               },

  /* Alerts */
  { "alert_store_query",      ntop_interface_alert_store_query        },
  { "getCachedAlertValue",    ntop_interface_get_cached_alert_value   },
  { "setCachedAlertValue",    ntop_interface_set_cached_alert_value   },
  { "storeTriggeredAlert",    ntop_interface_store_triggered_alert    },
  { "releaseTriggeredAlert",  ntop_interface_release_triggered_alert  },
  { "triggerExternalAlert",   ntop_interface_store_external_alert     },
  { "releaseExternalAlert",   ntop_interface_release_external_alert   },
  { "checkContext",           ntop_interface_check_context            },
  { "getEngagedAlerts",       ntop_interface_get_engaged_alerts       },
  { "getAlerts",              ntop_interface_get_alerts               },
  { "releaseEngagedAlerts",   ntop_interface_release_engaged_alerts   },
  { "incTotalHostAlerts",     ntop_interface_inc_total_host_alerts    },

  /* Interface Alerts */
  { "checkInterfaceAlerts",   ntop_check_interface_alerts             },

  /* Network Alerts */
  { "checkNetworksAlerts",    ntop_check_networks_alerts              },

  /* eBPF, Containers and Companion Interfaces */
  { "getPodsStats",           ntop_interface_get_pods_stats           },
  { "getContainersStats",     ntop_interface_get_containers_stats     },
  { "reloadCompanions",       ntop_interface_reload_companions        },

#ifdef NTOPNG_PRO
  /* Traffic Map */
  { "getTrafficMap",          ntop_interface_get_traffic_map_stats    },
  { "trafficMapEnabled",      ntop_interface_get_traffic_map_enabled  },
  { "enableTrafficMap",       ntop_interface_enable_traffic_map       },
  { "getTrafficMapHostStats", ntop_interface_get_traffic_map_host_stats },
  
#endif
  
  /* Syslog */
  { "isSyslogInterface",      ntop_interface_is_syslog_interface      },
  { "incSyslogStats",         ntop_interface_inc_syslog_stats         },

  { NULL,                     NULL }
};


luaL_Reg *ntop_interface_reg = _ntop_interface_reg;

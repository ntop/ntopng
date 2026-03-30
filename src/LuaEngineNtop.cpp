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

extern "C" {
#include "rrd.h"
};

enum list_file_type {
  list_type_hosts = 0,
  list_type_ip_csv = 1,
  list_type_ip_occurrencies = 2,
  list_type_ip = 3,
  list_type_max
};

static int live_extraction_num = 0;
static Mutex live_extraction_num_lock;

/* ******************************* */

/**
 * @brief Check the expected type of lua function.
 * @details Find in the lua stack the function and check the function parameters
 * types.
 *
 * @param vm The lua state.
 * @param func The function name.
 * @param pos Index of lua stack.
 * @param expected_type Index of expected type.
 * @return @ref CONST_LUA_ERROR if the expected type is equal to function type,
 * @ref CONST_LUA_PARAM_ERROR otherwise.
 */
int ntop_lua_check(lua_State* vm, const char* func, int pos,
                   int expected_type) {
  if (lua_type(vm, pos) != expected_type) {
    lua_Debug ar;

    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "%s : expected %s[@pos %d], got %s", func,
                                 lua_typename(vm, expected_type), pos,
                                 lua_typename(vm, lua_type(vm, pos)));

    if (lua_getstack(vm, 1, &ar)) {
      // Fill 'ar' with Source (S) and current Line (l)
      lua_getinfo(vm, "Sl", &ar);

      const char* err_msg = lua_tostring(vm, -1);
      // Create a formatted string: "filename:line: error message"
      ntop->getTrace()->traceEvent(TRACE_ERROR, "%s:%d %s", ar.short_src,
                                   ar.currentline, err_msg ? err_msg : "");
    }

    return (CONST_LUA_PARAM_ERROR);
  }

  return (CONST_LUA_OK);
}

/* ****************************************** */

void get_host_vlan_info(char* lua_ip, char** host_ip, u_int16_t* vlan_id,
                        char* buf, u_int buf_len) {
  char *where, *vlan = NULL;

  snprintf(buf, buf_len, "%s", lua_ip);

  if (((*host_ip) = strtok_r(buf, "@", &where)) != NULL)
    vlan = strtok_r(NULL, "@", &where);

  if (*host_ip == NULL) *host_ip = lua_ip;

  if (vlan)
    (*vlan_id) = (u_int16_t)atoi(vlan);
  else
    (*vlan_id) = 0;
}

/* ****************************************** */

/* @brief Reads a text file and writes its content to the HTTP response, performing string substitutions.  Lua: ntop.dumpFile(path) → nil */
static int ntop_dump_file(lua_State* vm) {
  char* fname;
  FILE* fd;
  struct mg_connection* conn;

  conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((fname = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if ((fd = fopen(fname, "r")) != NULL) {
    char tmp[1024];

    ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] Serving file %s", fname);

    Utils::flushHTTPBuffer(vm);
    
    while ((fgets(tmp,
                  sizeof(tmp) - 256 /* To make sure we have room for replacements */,
                  fd)) != NULL) {
      for (int i = 0; string_to_replace[i].key != NULL; i++)
        Utils::replacestr(tmp, string_to_replace[i].key,
                          string_to_replace[i].val);

      mg_printf(conn, "%s", tmp);
    }

    fclose(fd);
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read file %s", fname);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
}

/* ****************************************** */

/* @brief Reads a binary file and writes it verbatim to the HTTP response.  Lua: ntop.dumpBinaryFile(path) → nil */
static int ntop_dump_binary_file(lua_State* vm) {
  char* fname;
  FILE* fd;
  struct mg_connection* conn;

  conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((fname = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->fixPath(fname);
  if ((fd = fopen(fname, "rb")) != NULL) {
    char tmp[1024];
    size_t n;

    Utils::flushHTTPBuffer(vm);
    while ((n = fread(tmp, 1, sizeof(tmp), fd)) > 0) {
      if (mg_write(conn, tmp, n) < (int)n) break;
    }

    fclose(fd);
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read file %s", fname);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
}

/* ****************************************** */

/* @brief Returns the vendor/manufacturer name for a MAC address OUI.  Lua: ntop.getMacManufacturer(mac) → string */
static int ntop_get_mac_manufacturer(lua_State* vm) {
  const char* mac = NULL;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac = (char*)lua_tostring(vm, 1);

  ntop->getMacManufacturer(mac, vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns combined host information table for an IP address.  Lua: ntop.getHostInformation(ip) → table */
static int ntop_get_host_information(lua_State* vm) {
  struct in_addr management_addr;
  management_addr.s_addr = Utils::getHostManagementIPv4Address();

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "ip", inet_ntoa(management_addr));
  lua_push_str_table_entry(vm, "instance_name",
                           ntop->getPrefs()->get_instance_name());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef HAVE_NEDGE
/* @brief Internal helper that sets HTTP or HTTPS bind address (called by set_http/https_bind_addr).  Lua: (internal helper) → nil */
static int ntop_set_bind_addr(lua_State* vm, bool http) {
  char *addr, *addr2 = (char*)CONST_LOOPBACK_ADDRESS;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  addr = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING) addr2 = (char*)lua_tostring(vm, 2);

  if (http)
    ntop->getPrefs()->bind_http_to_address(addr, addr2);
  else /* https */
    ntop->getPrefs()->bind_https_to_address(addr, addr2);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* @brief Sets the HTTP bind address (nEdge only).  Lua: ntop.setHTTPBindAddr(addr) → nil */
static int ntop_set_http_bind_addr(lua_State* vm) {
  return ntop_set_bind_addr(vm, true /* http */);
}

/* @brief Sets the HTTPS bind address (nEdge only).  Lua: ntop.setHTTPSBindAddr(addr) → nil */
static int ntop_set_https_bind_addr(lua_State* vm) {
  return ntop_set_bind_addr(vm, false /* https */);
}

#endif

/* ****************************************** */

/* @brief Initiates ntopng shutdown (nEdge/Appliance only).  Lua: ntop.shutdown() → nil */
static int ntop_shutdown(lua_State* vm) {
  char* action;
  extern AfterShutdownAction afterShutdownAction;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 1) == LUA_TSTRING) {
    action = (char*)lua_tostring(vm, 1);

    if (!strcmp(action, "poweroff"))
      afterShutdownAction = after_shutdown_poweroff;
    else if (!strcmp(action, "reboot"))
      afterShutdownAction = after_shutdown_reboot;
    else if (!strcmp(action, "restart_self"))
      afterShutdownAction = after_shutdown_restart_self;
  }

  ntop->getGlobals()->requestShutdown();
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is currently in shutdown sequence.  Lua: ntop.isShuttingDown() → boolean */
static int ntop_is_shuttingdown(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->getGlobals()->isShutdownRequested());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table of all available network interfaces.  Lua: ntop.listInterfaces() → table */
static int ntop_list_interfaces(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);
  Utils::listInterfaces(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Compares two IP address strings; returns -1, 0, or 1.  Lua: ntop.ipCmp(ip1, ip2) → integer */
static int ntop_ip_cmp(lua_State* vm) {
  IpAddress a, b;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  a.set((char*)lua_tostring(vm, 1));
  b.set((char*)lua_tostring(vm, 2));

  lua_pushinteger(vm, a.compare(&b));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Applies a traffic mask to a domain name for nDPI classification.  Lua: ntop.setDomainMask(domain, mask) → integer */
static int ntop_setDomainMask(lua_State* vm) {
  const char* domain;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  domain = lua_tostring(vm, 1);

  rc = ntop->nDPISetDomainMask(domain, 0 /* mask all */);

  return (ntop_lua_return_value(vm, __FUNCTION__, rc));
}

/* ****************************************** */

/* @brief Adds a trusted TLS certificate issuer Distinguished Name.  Lua: ntop.addTrustedIssuerDN(dn) → integer */
static int ntop_addTrustedIssuerDN(lua_State* vm) {
  const char* dn;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  dn = lua_tostring(vm, 1);

  rc = ntop->getSystemInterface()->addTrustedIssuerDN(dn);

  return (ntop_lua_return_value(vm, __FUNCTION__, rc));
}

/* ****************************************** */

/* @brief Sets the device type classification for a MAC address.  Lua: ntop.setMacDeviceType(mac, type) → nil */
static int ntop_set_mac_device_type(lua_State* vm) {
  char* mac = NULL;
  DeviceType dtype = device_unknown;
  bool overwriteType;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  dtype = (DeviceType)lua_tonumber(vm, 2);
  if (dtype >= device_max_type) dtype = device_unknown;

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  overwriteType = (bool)lua_toboolean(vm, 3);

  for (int i = 0; i < ntop->get_num_interfaces(); i++) {
    NetworkInterface* curr_iface = ntop->getInterface(i);

    if (curr_iface && mac)
      curr_iface->setMacDeviceType(mac, dtype, overwriteType);
  }

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Triggers a reload of host pool configuration from Redis.  Lua: ntop.reloadHostPools() → nil */
static int ntop_reload_host_pools(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->reloadHostPools();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef HAVE_NEDGE
/* @brief Enables or disables routing mode (nEdge only).  Lua: ntop.setRoutingMode(enabled) → nil */
static int ntop_set_routing_mode(lua_State* vm) {
  bool routing_enabled;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  routing_enabled = lua_toboolean(vm, 1);
  ntop->getPrefs()->set_routing_mode(routing_enabled);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

#ifdef HAVE_NEDGE
/* @brief Returns true if nEdge is in routing mode (nEdge only).  Lua: ntop.isRoutingMode() → boolean */
static int ntop_is_routing_mode(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->getPrefs()->is_routing_mode());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

/* @brief Returns true if the given path is an existing directory.  Lua: ntop.isdir(path) → boolean */
static int ntop_is_dir(lua_State* vm) {
  char* path;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  path = (char*)lua_tostring(vm, 1);

  lua_pushboolean(vm, Utils::dir_exists(path));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the given path is a non-empty file.  Lua: ntop.notEmptyFile(path) → boolean */
static int ntop_is_not_empty_file(lua_State* vm) {
  char* path;
  struct stat buf;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  path = (char*)lua_tostring(vm, 1);

  rc = (stat(path, &buf) != 0) ? 0 : 1;
  if (rc && (buf.st_size == 0)) rc = 0;
  lua_pushboolean(vm, rc);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Executes a query on the alert database and streams JSON results to the HTTP response.  Lua: ntop.alert_store_query(query[,ifid,limit]) → nil */
static int ntop_alert_store_query(lua_State* vm) {
  NetworkInterface* iface = NULL;
  char* query;
  bool limit_rows = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) != LUA_TSTRING || !(query = (char*)lua_tostring(vm, 1))) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (lua_type(vm, 2) == LUA_TSTRING) {
    const char* ifname = lua_tostring(vm, 1);
    iface = ntop->getNetworkInterface(ifname, vm);

  } else if (lua_type(vm, 2) == LUA_TNUMBER) {
    int ifid = lua_tointeger(vm, 2);
    iface = ntop->getNetworkInterface(vm, ifid);

  } else {
    iface = getCurrentInterface(vm);
  }

  /* Optional: limit rows  */
  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    limit_rows = lua_toboolean(vm, 3) ? true : false;

  if (iface == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (ntop->getPrefs()->are_alerts_disabled()) {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  if (!iface->alert_store_query(vm, query, limit_rows)) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

int ntop_release_triggered_alert(lua_State* vm, OtherAlertableEntity* alertable,
                                 u_int idx) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  char* key;
  ScriptPeriodicity periodicity;
  time_t when;

  if (!c->iface || !alertable)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, idx++)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, idx++)) >=
      MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  when = (time_t)lua_tonumber(vm, idx++);

  /* The released alert will be pushed to LUA */
  alertable->releaseAlert(vm, std::string(key), periodicity, when);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

int ntop_store_triggered_alert(lua_State* vm, OtherAlertableEntity* alertable,
                               u_int idx) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  char *key, *alert_subtype, *alert_json, *ip = NULL, *name = NULL;
  u_int16_t port = 0;
  ScriptPeriodicity periodicity;
  u_int32_t score;
  AlertType alert_type;
  // Host *host;
  /* bool triggered; */

  if (!alertable || !c->iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, idx++)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, idx++)) >=
      MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  score = lua_tointeger(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  alert_type = (AlertType)lua_tonumber(vm, idx++);

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((alert_subtype = (char*)lua_tostring(vm, idx++)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((alert_json = (char*)lua_tostring(vm, idx++)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ip = (char*)lua_tostring(vm, idx++);
  name = (char*)lua_tostring(vm, idx++);
  port = (u_int16_t)lua_tonumber(vm, idx++);

  /* triggered = */ alertable->triggerAlert(
      vm, std::string(key), periodicity, time(NULL), score, alert_type,
      alert_subtype, alert_json, ip, name, port);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the given file or directory exists.  Lua: ntop.exists(path) → boolean */
static int ntop_get_file_dir_exists(lua_State* vm) {
  char* path;
  struct stat buf;
  int rc;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  path = (char*)lua_tostring(vm, 1);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s(%s) called", __FUNCTION__,
                               path ? path : "???");
  rc = (stat(path, &buf) != 0) ? 0 : 1;
  //   ntop->getTrace()->traceEvent(TRACE_ERROR, "%s: %d", path, rc);
  lua_pushboolean(vm, rc);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the last modification time of a file as a Unix epoch.  Lua: ntop.fileLastChange(path) → integer */
static int ntop_get_file_last_change(lua_State* vm) {
  char* path;
  struct stat buf;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  path = (char*)lua_tostring(vm, 1);

  if (stat(path, &buf) == 0)
    lua_pushinteger(vm, (lua_Integer)buf.st_mtime);
  else
    lua_pushinteger(vm, -1); /* not found */

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if MaxMind GeoIP databases are loaded.  Lua: ntop.hasGeoIP() → boolean */
static int ntop_has_geoip(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(
      vm,
      ntop->getGeolocation() && ntop->getGeolocation()->isAvailable() ? 1 : 0);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns Elasticsearch connection details or nil if not configured.  Lua: ntop.elasticsearchConnection() → table|nil */
static int ntop_elasticsearch_connection(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop->getPrefs()->do_dump_flows_on_es()) {
    lua_newtable(vm);

    lua_push_str_table_entry(vm, "user", ntop->getPrefs()->get_es_user());
    lua_push_str_table_entry(vm, "password", ntop->getPrefs()->get_es_pwd());
    lua_push_str_table_entry(vm, "url", ntop->getPrefs()->get_es_url());
    lua_push_str_table_entry(vm, "host", ntop->getPrefs()->get_es_host());
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the configured ntopng instance name.  Lua: ntop.getInstanceName() → string */
static int ntop_get_instance_name(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, ntop->getPrefs()->get_instance_name());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is running on Windows.  Lua: ntop.isWindows() → boolean */
static int ntop_is_windows(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm,
#ifdef WIN32
                  1
#else
                  0
#endif
  );

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is running on FreeBSD.  Lua: ntop.isFreeBSD() → boolean */
static int ntop_is_freebsd(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm,
#ifdef __FreeBSD__
                  1
#else
                  0
#endif
  );

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is running on Linux.  Lua: ntop.isLinux() → boolean */
static int ntop_is_linux(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm,
#ifdef __linux__
                  1
#else
                  0
#endif
  );

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Begins a hot-reload of nDPI custom categories (call before loading categories).  Lua: ntop.initnDPIReload() → boolean */
static int ntop_initnDPIReload(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop->isnDPIReloadInProgress() || (!ntop->initnDPIReload())) {
    /* initnDPIReload abort */
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  lua_pushboolean(vm, true /* can now start reloading */);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Associates an IP or CIDR range with a custom nDPI category.  Lua: ntop.loadCustomCategoryIp(cat_id, ip_or_cidr) → boolean */
static int ntop_loadCustomCategoryIp(lua_State* vm) {
  char *net, *listname;
  ndpi_protocol_category_t catid;
  bool success;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  net = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  catid = (ndpi_protocol_category_t)lua_tointeger(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  listname = (char*)lua_tostring(vm, 3);

  success = ntop->nDPILoadIPCategory(net, catid, listname);

  lua_pushboolean(vm, success);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Associates a hostname pattern with a custom nDPI category.  Lua: ntop.loadCustomCategoryHost(cat_id, hostname) → boolean */
static int ntop_loadCustomCategoryHost(lua_State* vm) {
  char *host, *listname;
  ndpi_protocol_category_t catid;
  bool success;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  host = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  catid = (ndpi_protocol_category_t)lua_tointeger(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  listname = (char*)lua_tostring(vm, 3);

  success = ntop->nDPILoadHostnameCategory(host, catid, listname);

  lua_pushboolean(vm, success);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static bool is_valid_host(char* _host, enum list_file_type t,
                          bool ignorePrivateIPs) {
  char host[256], *div, *slash = strchr(_host, '/');
  ;
  int cidr = 128;

  if (slash) slash[0] = '\0';

  snprintf(host, sizeof(host), "%s", _host);

  if ((div = strchr(host, '\t')) != NULL) div[0] = '\0';
  if ((div = strchr(host, ' ')) != NULL) div[0] = '\0';
  if ((slash = strchr(host, '/')) != NULL) {
    slash[0] = '\0';
    cidr = atoi(&slash[1]);
  }

  if (cidr < 12) {
    /* ntop->getTrace()->traceEvent(TRACE_WARNING, "CIDR too small %s [%d]",
     * host, t); */
    return (false);
  }

  if (t == list_type_hosts) {
    if (strcmp(host, "localhost")) return (true);
  } else {
    if (ignorePrivateIPs) {
      IpAddress ip;

      if ((strcmp(host, "127.0.0.1") == 0) ||
          (strcmp(host, "255.255.255.255") == 0) ||
          (strncmp(host, "0.0.0.0", 7) == 0) ||
          (strchr(host, ':') != NULL) /* Ignore IPv6 */
      ) {
        /* ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarding IP address
         * %s", host); */
        return (false);
      }

      ip.set((const char*)host);

      if (ip.isPrivateAddress()) {
        /* ntop->getTrace()->traceEvent(TRACE_INFO, "WARNING: xsIgnoring private
         * IP address %s", host); */
        return (false);
      }
    }
  }

  return (true);
}

/* ****************************************** */

/* @brief Loads IP/hostname entries from a file into a custom nDPI category.  Lua: ntop.loadCustomCategoryFile(cat_id, path) → integer */
static int ntop_loadCustomCategoryFile(lua_State* vm) {
  char *path, *listname;
  const char* format;
  enum list_file_type list_type;
  ndpi_protocol_category_t catid;
  FILE* fd;
  u_int32_t num_lines_loaded = 0;
  u_int32_t num_bad_lines = 0;
  bool ignorePrivateIPs = false;
  bool warn_once = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushinteger(vm, (int)num_lines_loaded);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  path = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) {
    lua_pushinteger(vm, (int)num_lines_loaded);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  list_type = (enum list_file_type)lua_tointeger(vm, 2);

  if (list_type >= list_type_max) {
    lua_pushinteger(vm, (int)num_lines_loaded);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) {
    lua_pushinteger(vm, (int)num_lines_loaded);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  catid = (ndpi_protocol_category_t)lua_tointeger(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushinteger(vm, (int)num_lines_loaded);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  listname = (char*)lua_tostring(vm, 4);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TBOOLEAN) == CONST_LUA_OK)
    ignorePrivateIPs = (bool)lua_toboolean(vm, 5);

  if ((fd = fopen(path, "r")) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Unable to open category list in %s", path);
    lua_pushinteger(vm, (int)num_lines_loaded);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  switch (list_type) {
    case list_type_hosts:
      format = "%s\t%s";
      break;

    case list_type_ip_csv:
      format = "%[^,],%lf";
      break;

    case list_type_ip_occurrencies:
      format = "%s\t%d";
      break;

    case list_type_ip:
      format = "%s";
      break;

    default:
      format = NULL;
      break;
  }

  while (1) {
    char buffer[256];
    char* line = fgets(buffer, sizeof(buffer), fd);
    int len;

    if (line == NULL || format == NULL) break;

    len = strlen(line);

    if ((len <= 1) || (line[0] == '#')) continue;

    if ((line[len - 1] == '\n') || (line[len - 1] == '\r'))
      line[len - 1] = '\0';

    switch (list_type) {
      case list_type_hosts:
      case list_type_ip_csv:
      case list_type_ip: {
        /*o
          Format
          127.0.0.1       domainname
          127.0.0.1,domainname
        */
        char host[256], ignore[64];
        bool loaded = false, success;
        double f;

        if (list_type == list_type_ip)
          success = (sscanf(line, format, host) == 1) ? true : false;
        else if (list_type == list_type_hosts)
          success = (sscanf(line, format, ignore, host) == 2) ? true : false;
        else
          success = (sscanf(line, format, host, &f) == 2) ? true : false;

        if (success) {
          if (is_valid_host(host, list_type, ignorePrivateIPs)) {
            if (list_type == list_type_hosts)
              success = ntop->nDPILoadHostnameCategory(host, catid, listname);
            else
              success = ntop->nDPILoadIPCategory(host, catid, listname);

            if (success) num_lines_loaded++, loaded = true;
          }
        }

        if (!loaded
            /* Silence Stratosphere Lab.txt (it has 2 possible formatting) */
            && (strcmp(line, "ip,score") &&
                strcmp(line, "Number,IP address,Rating"))) {
          num_bad_lines++;
          if (warn_once) {
            ntop->getTrace()->traceEvent(
                TRACE_NORMAL, "Invalid line format %s%s [%s]",
                ignorePrivateIPs ? "or private IP " : "", line, path);
            warn_once = false;
          }
        }
      } break;

      case list_type_ip_occurrencies: {
        /*
          Format
          127.0.0.1       occurrencies
        */
        char host[64];
        int occurrencies;
        bool loaded = false;

        if (sscanf(line, format, host, &occurrencies) == 2) {
          if (is_valid_host(host, list_type, ignorePrivateIPs)) {
            if (occurrencies >= 2) {
              if (ntop->nDPILoadIPCategory(host, catid, listname))
                num_lines_loaded++, loaded = true;
            } else
              continue;
          }
        }

        if (!loaded) {
          num_bad_lines++;
          if (warn_once) {
            ntop->getTrace()->traceEvent(
                TRACE_ERROR, "Invalid line format %s [%s]", line, path);
            warn_once = false;
          }
        }
      } break;

      default:
        /* Not reached */
        break;
    }
  } /* while */

  fclose(fd);

  if (num_bad_lines > 1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%u invalid lines [%s]",
                                 num_bad_lines - 1, path);
  }

  lua_pushinteger(vm, (int)num_lines_loaded);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* NOTE: ntop.initnDPIReload() must be called before this */
/* @brief Commits the nDPI category hot-reload started by initnDPIReload.  Lua: ntop.finalizenDPIReload() → boolean */
static int ntop_finalizenDPIReload(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Starting category lists reload");
  ntop->finalizenDPIReload();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Category lists reload done");
  ntop->setLastInterfacenDPIReload(time(NULL));
  ntop->setnDPICleanupNeeded(true);

  lua_pushboolean(vm, true /* reload performed */);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the custom category id that matches a hostname, or nil.  Lua: ntop.matchCustomCategory(hostname) → integer|nil */
static int ntop_match_custom_category(lua_State* vm) {
  char* host_to_match;
  NetworkInterface* iface;
  ndpi_protocol_category_t match;
  ndpi_protocol_breed_t breed;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  iface = ntop->getFirstInterface();

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  host_to_match = (char*)lua_tostring(vm, 1);

  if ((!iface) || (ndpi_get_custom_category_match(
                       iface->get_ndpi_struct(), host_to_match,
                       strlen(host_to_match), &match, &breed) != 0))
    lua_pushnil(vm);
  else {
    /* Remember to unshift `match` (see Ntop::nDPILoadHostnameCategory) */
    lua_pushinteger(vm, ((int)match) & 0xFF);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the human-readable TLS version string for a numeric id.  Lua: ntop.getTLSVersionName(id) → string */
static int ntop_get_tls_version_name(lua_State* vm) {
  u_int16_t tls_version;
  u_int8_t unknown_version = 0;
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  tls_version = (u_int16_t)lua_tonumber(vm, 1);

  lua_pushstring(vm, ndpi_ssl_version2str(buf, sizeof(buf), tls_version,
                                          &unknown_version));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Expands a 48-bit MAC address string to 64-bit EUI-64 format.  Lua: ntop.getMac64(mac) → number */
static int ntop_get_mac_64(lua_State* vm) {
  char* mac_str;
  u_int8_t mac[6];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac_str = (char*)lua_tostring(vm, 1);

  Utils::parseMac(mac, mac_str);

  lua_pushnumber(vm, Utils::encodeMacTo64(mac));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Decodes a 64-bit EUI-64 address back to 48-bit MAC format.  Lua: ntop.decodeMac64(mac64) → string */
static int ntop_decode_mac_64(lua_State* vm) {
  u_int64_t mac64;
  u_int8_t mac[6];
  char buf[20];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  mac64 = lua_tonumber(vm, 1);

  Utils::decode64ToMac(mac64, mac);
  lua_pushstring(vm, Utils::formatMacAddress(mac, buf, sizeof(buf)));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the given address string is an IPv6 address.  Lua: ntop.isIPv6(ip) → boolean */
static int ntop_is_ipv6(lua_State* vm) {
  char* ip;
  struct in6_addr addr6;
  bool rv;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ip = (char*)lua_tostring(vm, 1);

  if (!ip || (inet_pton(AF_INET6, ip, &addr6) != 1))
    rv = false;
  else
    rv = true;

  lua_pushboolean(vm, rv);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns execution statistics for all flow check scripts.  Lua: ntop.getFlowChecksStats() → table|nil */
static int ntop_get_flow_checks_stats(lua_State* vm) {
  FlowChecksLoader* fcl = ntop->getFlowChecksLoader();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (fcl)
    fcl->lua(vm);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Triggers a hot-reload of flow check scripts.  Lua: ntop.reloadFlowChecks() → nil */
static int ntop_reload_flow_checks(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->reloadFlowChecks();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Triggers a hot-reload of host check scripts.  Lua: ntop.reloadHostChecks() → nil */
static int ntop_reload_host_checks(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->reloadHostChecks();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the default risk score for a flow alert type id.  Lua: ntop.getFlowAlertScore(alert_id) → integer */
static int ntop_get_flow_alert_score(lua_State* vm) {
  FlowAlertTypeEnum alert_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  alert_id = (FlowAlertTypeEnum)lua_tonumber(vm, 1);

  lua_pushinteger(vm, ntop->getFlowAlertScore(alert_id));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table of all known flow risk ids and their names.  Lua: ntop.getRiskList() → table */
static int ntop_get_risk_list(lua_State* vm) {
  lua_newtable(vm);

  for (int i = 0; i < NDPI_MAX_RISK; i++) {
    lua_pushstring(vm, ntop->getRiskStr((ndpi_risk_enum)i));
    lua_rawseti(vm, -2, i + 1);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#define MAX_RSP_LEN 512

bool check_network_entry(char* ip_addr, char* rsp, void* user_data) {
  AddressTree* at = (AddressTree*)user_data;
  char a[64], *slash;
  u_int8_t network_mask_bits;

  snprintf(a, sizeof(a), "%s", ip_addr);
  slash = strchr(a, '/');

  if (slash != NULL) slash[0] = '\0'; /* Remove slash if present */

  if (at->find(a, &network_mask_bits) != -1) {
    /* Overlapping address */
    bool ok = false;

    if (slash != NULL) {
      if (atoi(&slash[1]) > network_mask_bits) {
        /* This is smaller subnet, so we accept it */
        ok = true;
      }
    }

    if (!ok) {
      snprintf(rsp, MAX_RSP_LEN, "Overlapping address error %s", ip_addr);
      return (false);
    }
  }

  at->addAddress(ip_addr);

  return true;
}

/*
  This function is called whenever a new network configuration is is
  modified/defined.
 */
/* @brief Evaluates and returns the network policy applicable to an IP address.  Lua: ntop.checkNetworkPolicy(ip) → table */
static int ntop_check_network_policy(lua_State* vm) {
  char *local_devices, *corporate_devices, *whitelisted_networks;
  char* rsp = NULL;
  AddressTree at;

  lua_newtable(vm);

  if ((rsp = (char*)malloc(MAX_RSP_LEN)) == NULL) {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((local_devices = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((corporate_devices = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((whitelisted_networks = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  /*
    We need to check if the networks are well defined and if there are no
    overlaps in networks
   */
  if (!Utils::checkNetworkList(local_devices, rsp, check_network_entry,
                               (void*)&at)) {
    lua_push_bool_table_entry(vm, "error", true);
    lua_push_str_table_entry(vm, "error_msg", rsp);
    goto free;
  }

  if (!Utils::checkNetworkList(corporate_devices, rsp, check_network_entry,
                               (void*)&at)) {
    lua_push_bool_table_entry(vm, "error", true);
    lua_push_str_table_entry(vm, "error_msg", rsp);
    goto free;
  }

  if (!Utils::checkNetworkList(whitelisted_networks, rsp, check_network_entry,
                               (void*)&at)) {
    lua_push_bool_table_entry(vm, "error", true);
    lua_push_str_table_entry(vm, "error_msg", rsp);
    goto free;
  }

  lua_push_bool_table_entry(vm, "error", false);
  lua_push_str_table_entry(vm, "error_msg", "");

free:
  if (rsp) free(rsp);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the human-readable name string for a flow risk id.  Lua: ntop.getRiskStr(risk_id) → string */
static int ntop_get_risk_str(lua_State* vm) {
  ndpi_risk_enum risk_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  risk_id = (ndpi_risk_enum)lua_tonumber(vm, 1);

  lua_pushstring(vm, ntop->getRiskStr(risk_id));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the nDPI risk id associated with a flow alert type.  Lua: ntop.getFlowAlertRisk(alert_id) → integer */
static int ntop_get_flow_alert_risk(lua_State* vm) {
  FlowAlertTypeEnum alert_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  alert_id = (FlowAlertTypeEnum)lua_tonumber(vm, 1);

  lua_pushinteger(vm, ntop->getFlowAlertRisk(alert_id));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table mapping nDPI risk ids to corresponding flow alert types.  Lua: ntop.getFlowRiskAlerts() → table */
static int ntop_get_flow_risk_alerts(lua_State* vm) {
  FlowRiskAlerts::lua(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns metadata table for a specific flow check.  Lua: ntop.getFlowCheckInfo(check_id) → table|nil */
static int ntop_get_flow_check_info(lua_State* vm) {
  const char* check_name;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  check_name = lua_tostring(vm, 1);

  if (!ntop->luaFlowCheckInfo(vm, check_name)) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns metadata table for a specific host check.  Lua: ntop.getHostCheckInfo(check_id) → table|nil */
static int ntop_get_host_check_info(lua_State* vm) {
  const char* check_name;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  check_name = lua_tostring(vm, 1);

  if (!ntop->luaHostCheckInfo(vm, check_name)) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Triggers a reload of alert exclusion rules from configuration.  Lua: ntop.reloadAlertExclusions() → nil */
static int ntop_reload_alert_exclusions(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->reloadAlertExclusions();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if DNS resolution should be attempted for this host.  Lua: ntop.shouldResolveHost(ip) → boolean */
static int ntop_should_resolve_host(lua_State* vm) {
  char* ip;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((ip = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, Utils::shouldResolveHost(ip));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sets the whitelist of allowed IEC 104 SCADA type identifiers.  Lua: ntop.setIEC104AllowedTypeIDs(ids_table) → boolean */
static int ntop_set_iec104_allowed_typeids(lua_State* vm) {
  char* typeids;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((typeids = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->getPrefs()->setIEC104AllowedTypeIDs(typeids);
  lua_pushboolean(vm, true);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if flow deduplication is active.  Lua: ntop.isFlowDedupEnabled() → boolean */
static int ntop_is_flow_deduplication_enabled(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->isFlowDedupEnabled());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef NTOPNG_PRO
/* @brief Sets the whitelist of allowed Modbus function codes (Pro only).  Lua: ntop.setModbusAllowedFunctionCodes(codes_table) → boolean */
static int ntop_set_modbus_allowed_function_codes(lua_State* vm) {
  char* function_codes;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((function_codes = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->getPrefs()->setModbusAllowedFunctionCodes(function_codes);
  lua_pushboolean(vm, true);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

/* @brief Temporarily re-acquires elevated write capabilities on Unix.  Lua: ntop.gainWriteCapabilities() → boolean */
static int ntop_gainWriteCapabilities(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, Utils::gainWriteCapabilities() == 0);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Drops back to low-privilege mode after gainWriteCapabilities.  Lua: ntop.dropWriteCapabilities() → boolean */
static int ntop_dropWriteCapabilities(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, Utils::dropWriteCapabilities() == 0);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the well-known service name for a port/protocol pair.  Lua: ntop.getservbyport(port, proto) → string|nil */
static int ntop_getservbyport(lua_State* vm) {
  int port;
  char* proto;
  struct servent* s = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  port = (int)lua_tonumber(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto = (char*)lua_tostring(vm, 2);

  if ((port > 0) && (proto != NULL)) s = getservbyport(htons(port), proto);

  if (s && s->s_name)
    lua_pushstring(vm, s->s_name);
  else {
    char buf[32];

    snprintf(buf, sizeof(buf), "%d", port);
    lua_pushstring(vm, buf);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sleeps for the given number of milliseconds.  Lua: ntop.msleep(ms) → nil */
static int ntop_msleep(lua_State* vm) {
  u_int ms_duration, max_duration = 60000 /* 1 min */;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ms_duration = (u_int)lua_tonumber(vm, 1);

  if (ms_duration > max_duration) ms_duration = max_duration;

  _usleep(ms_duration * 1000);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* https://www.linuxquestions.org/questions/programming-9/connect-timeout-change-145433/
 */
static int non_blocking_connect(int sock, struct sockaddr_in* sa, int timeout) {
  int flags = 0, error = 0, ret = 0;
  fd_set rset, wset;
  socklen_t len = sizeof(error);

  // clear out descriptor sets for select
  // add socket to the descriptor sets
  FD_ZERO(&rset);
  FD_SET(sock, &rset);
  wset = rset;  // structure assignment ok

#ifdef WIN32
  // Windows sockets are created in blocking mode by default
  // currently on windows, there is no easy way to obtain the socket's current
  // blocking mode since WSAIsBlocking was deprecated
  u_long f = 1;
  if (ioctlsocket(sock, FIONBIO, &f) != NO_ERROR) return -1;
#else
  // set socket nonblocking flag
  if ((flags = fcntl(sock, F_GETFL, 0)) < 0) return -1;

  if (fcntl(sock, F_SETFL, flags | O_NONBLOCK) < 0) return -1;
#endif

  // initiate non-blocking connect
  if ((ret = connect(sock, (struct sockaddr*)sa, sizeof(struct sockaddr_in))) <
      0)
    if (errno != EINPROGRESS) return -1;

  if (ret == 0)  // then connect succeeded right away
    goto done;

  // we are waiting for connect to complete now
  if ((ret = Utils::pollSocket(sock,
                               timeout ? (timeout * 1000) : -1 /* wait */)) < 0)
    return -1;

  if (ret == 0) {
    // we had a timeout
    errno = ETIMEDOUT;
    return -1;
  }

  // we had a positivite return so a descriptor is ready
  if (FD_ISSET(sock, &rset) || FD_ISSET(sock, &wset)) {
    if (getsockopt(sock, SOL_SOCKET, SO_ERROR,
#ifdef WIN32
                   (char*)
#endif
                   &error,
                   &len) < 0) {
      return -1;
    }
  } else {
    return -1;
  }

  if (error) {  // check if we had a socket error
    errno = error;
    return -1;
  }

done:
#ifdef WIN32
  f = 0;

  if (ioctlsocket(sock, FIONBIO, &f) != NO_ERROR) return -1;
#else
  // put socket back in blocking mode
  if (fcntl(sock, F_SETFL, flags) < 0) return -1;
#endif

  return 0;
}

/* ****************************************** */

/* Millisecond sleep */
/* @brief Tests TCP reachability; returns true if connection succeeds.  Lua: ntop.tcpProbe(host, port[, timeout]) → string|nil */
static int ntop_tcp_probe(lua_State* vm) {
  char* server_ip;
  u_int server_port, timeout = 3;
  int sockfd;
  struct sockaddr_in serv_addr;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  server_ip = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  server_port = (u_int)lua_tonumber(vm, 2);

  if (lua_type(vm, 3) == LUA_TNUMBER) timeout = (u_int16_t)lua_tonumber(vm, 3);

  if ((sockfd = Utils::openSocket(AF_INET, SOCK_STREAM, 0, "Lua TCP Probe")) <
      0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  memset(&serv_addr, '0', sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_port = htons(server_port);
  serv_addr.sin_addr.s_addr = inet_addr(server_ip);

  if (non_blocking_connect(sockfd, &serv_addr, timeout) < 0)
    lua_pushnil(vm);
  else {
    u_int timeout = 1, offset = 0;
    char buf[512];

    while (true) {
      int rc;

      rc = Utils::pollSocket(sockfd, timeout * 1000);
      timeout = 0;

      if (rc <= 0)
        break;
      else {
        int l = read(sockfd, &buf[offset], sizeof(buf) - offset - 1);

        if (l <= 0)
          break;
        else
          offset += l;
      }
    }

    buf[offset] = 0;
    lua_pushstring(vm, buf);
  }

  Utils::closeSocket(sockfd);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table listing filenames in the given directory.  Lua: ntop.readdir(path) → table */
static int ntop_list_dir_files(lua_State* vm) {
  char* path;
  DIR* dirp;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  path = (char*)lua_tostring(vm, 1);
  ntop->fixPath(path);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Listing directory %s", path);
  lua_newtable(vm);

  if ((dirp = opendir(path)) != NULL) {
    struct dirent* dp;

    while ((dp = readdir(dirp)) != NULL)
      if ((dp->d_name[0] != '\0') && (dp->d_name[0] != '.')) {
        lua_push_str_table_entry(vm, dp->d_name, dp->d_name);
      }
    (void)closedir(dirp);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Recursively removes a directory and all its contents.  Lua: ntop.rmdir(path) → boolean */
static int ntop_remove_dir_recursively(lua_State* vm) {
  char* path = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) path = (char*)lua_tostring(vm, 1);

  if (path) ntop->fixPath(path);

  lua_pushboolean(vm, path && !Utils::remove_recursively(path)
                          ? true /* OK */
                          : false /* Errors */);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Deletes a single file.  Lua: ntop.unlink(path) → boolean */
static int ntop_unlink_file(lua_State* vm) {
  char* path = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) path = (char*)lua_tostring(vm, 1);

  if (path) ntop->fixPath(path);

  lua_pushboolean(
      vm, path && (unlink(path) == 0) ? true /* OK */ : false /* Errors */);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Registers a runtime PCAP or DB interface from Lua.  Lua: ntop.registerRuntimeInterface(params) → integer */
static int ntop_register_runtime_interface(lua_State* vm) {
  char *source = NULL, *name = NULL;
  int if_id = -1, new_if_id = -99;
  bool create_new_interface;
  NetworkInterface* iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) source = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TSTRING) name = (char*)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  create_new_interface = (bool)lua_toboolean(vm, 3);

  if (lua_type(vm, 4) == LUA_TNUMBER) {
    if_id = (u_int32_t)lua_tonumber(vm, 4);
    create_new_interface = false;
  }

  if (create_new_interface) {
    if ((!ntop->isUserAdministrator(vm)) || (source == NULL) ||
        (ntop->get_num_interfaces() >= MAX_NUM_DEFINED_INTERFACES)) {
      ; /* No way */
    } else {
      if_id = -1; /* -1 = allocate new interface */
      bool rc = ntop->createRuntimeInterface(name, source, &if_id);

      if (rc) new_if_id = if_id;
    }
  } else {
    /* Upload pcap on this interface */

    if (if_id == -1) if_id = iface->get_id();

    bool rc = ntop->createRuntimeInterface(name, source, &if_id);

    if (rc) new_if_id = if_id;
  }

  lua_pushinteger(vm, new_if_id);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#if defined(NTOPNG_PRO) && defined(HAVE_KAFKA)
/* @brief Publishes a message to a Kafka topic (Pro + Kafka build).  Lua: ntop.sendKafkaMessage(topic, msg) → boolean */
static int ntop_send_kafka_message(lua_State* vm) {
  char *kafka_broker_info, *message;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* <brokers>;<topic>;<options> */
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  kafka_broker_info = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  message = (char*)lua_tostring(vm, 2);

  if (kafka_broker_info && message)
    lua_pushboolean(vm, ntop->sendKafkaMessage(kafka_broker_info, message,
                                               strlen(message)));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

/* @brief Returns the current time as a floating-point millisecond timestamp.  Lua: ntop.gettimemsec() → number */
static int ntop_gettimemsec(lua_State* vm) {
  struct timeval tp;
  double ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  gettimeofday(&tp, NULL);

  ret = (((double)tp.tv_usec) / (double)1000000) + tp.tv_sec;

  lua_pushnumber(vm, ret);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the current CPU tick counter value.  Lua: ntop.getticks() → number */
static int ntop_getticks(lua_State* vm) {
  lua_pushnumber(vm, Utils::getticks());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the number of CPU ticks per second.  Lua: ntop.gettickspersec() → number */
static int ntop_gettickspersec(lua_State* vm) {
  lua_pushnumber(vm, Utils::gettickspersec());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Refreshes the timezone after a change
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */

/* @brief Refreshes the process timezone from the TZ environment variable.  Lua: ntop.tzset() → nil */
static int ntop_tzset(lua_State* vm) {
#ifndef WIN32
  tzset();
#endif
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Rounds a Unix epoch down to the nearest multiple of secs.  Lua: ntop.roundTime(epoch, secs[, tz]) → integer */
static int ntop_round_time(lua_State* vm) {
  time_t now;
  u_int32_t rounder;
  bool align_to_localtime;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  now = lua_tonumber(vm, 1);
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  rounder = lua_tonumber(vm, 2);
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  align_to_localtime = lua_toboolean(vm, 3);

  lua_pushinteger(
      vm, Utils::roundTime(now, rounder,
                           align_to_localtime ? ntop->get_time_offset() : 0));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Converts a 32-bit integer to an IPv4 dotted-decimal string.  Lua: ntop.inet_ntoa(n) → string */
static int ntop_inet_ntoa(lua_State* vm) {
  u_int32_t ip;
  struct in_addr in;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING)
    ip = atol((char*)lua_tostring(vm, 1));
  else if (lua_type(vm, 1) == LUA_TNUMBER)
    ip = (u_int32_t)lua_tonumber(vm, 1);
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  in.s_addr = htonl(ip);
  lua_pushstring(vm, inet_ntoa(in));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Converts an IPv4 dotted-decimal string to a 32-bit integer.  Lua: ntop.ipToNumber(ip) → integer */
static int ntop_ip_to_number(lua_State* vm) {
  char* device_ip = NULL;
  struct in_addr addr;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  device_ip = (char*)lua_tostring(vm, 1);

  if (inet_pton(AF_INET, device_ip, &addr) != 1)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushinteger(vm, ntohl(addr.s_addr));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifndef HAVE_NEDGE

/* @brief Broadcasts a string message to the IPS subsystem (non-nEdge only).  Lua: ntop.broadcastIPSMessage(msg) → nil */
static int ntop_brodcast_ips_message(lua_State* vm) {
  char* msg;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  msg = (char*)lua_tostring(vm, 1);

  ntop->broadcastIPSMessage(msg);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* @brief Returns true if IPS rules are due for a periodic refresh.  Lua: ntop.timeToRefreshIPSRules() → boolean */
static int ntop_time_to_refresh_ips_rules(lua_State* vm) {
  /* Read and reset the variable */
  lua_pushboolean(vm, ntop->timeToRefreshIPSRules());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* @brief Signals the IPS subsystem to refresh its rules.  Lua: ntop.askToRefreshIPSRules() → boolean */
static int ntop_ask_to_refresh_ips_rules(lua_State* vm) {
  ntop->askToRefreshIPSRules();

  lua_pushboolean(vm, true);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Connects to a ZMQ publisher endpoint (non-nEdge builds with ZMQ support).  Lua: ntop.zmq_connect(endpoint, topic) → nil */
static int ntop_zmq_connect(lua_State* vm) {
  char *endpoint, *topic;
  void *context, *subscriber;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef HAVE_ZMQ
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((endpoint = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((topic = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  context = zmq_ctx_new(), subscriber = zmq_socket(context, ZMQ_SUB);

  if (zmq_connect(subscriber, endpoint) != 0) {
    zmq_close(subscriber);
    zmq_ctx_destroy(context);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  }

  if (zmq_setsockopt(subscriber, ZMQ_SUBSCRIBE, topic, strlen(topic)) != 0) {
    zmq_close(subscriber);
    zmq_ctx_destroy(context);
    return -1;
  }

  getLuaVMUservalue(vm, zmq_context) = context;
  getLuaVMUservalue(vm, zmq_subscriber) = subscriber;
#endif

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

/* @brief Returns Redis memory usage and command execution statistics.  Lua: ntop.getCacheStats() → table */
static int ntop_get_redis_stats(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getRedis()->lua(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Deletes a key (or pattern of keys) from Redis.  Lua: ntop.delCache(key) → nil */
static int ntop_delete_redis_key(lua_State* vm) {
  char* key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  ntop->getRedis()->del(key);
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Atomically renames a Redis key.  Lua: ntop.renameCache(old_key, new_key) → nil */
static int ntop_rename_redis_key(lua_State* vm) {
  char *key, *new_key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((new_key = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->getRedis()->rename(key, new_key);
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Flushes ALL Redis data — destructive operation, admin only.  Lua: ntop.flushCache() → boolean */
static int ntop_flush_redis(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushboolean(vm, (ntop->getRedis()->flushDb() == 0) ? true : false);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Adds a member to a Redis set.  Lua: ntop.setMembersCache(key, member) → nil */
static int ntop_add_set_member_redis(lua_State* vm) {
  char *key, *value;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((value = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop->getRedis()->sadd(key, value) == 0) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Removes a member from a Redis set.  Lua: ntop.delMembersCache(key, member) → nil */
static int ntop_del_set_member_redis(lua_State* vm) {
  char *key, *value;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((value = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop->getRedis()->srem(key, value) == 0) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Returns all members of a Redis set as a Lua table.  Lua: ntop.getMembersCache(key) → table */
static int ntop_get_set_members_redis(lua_State* vm) {
  char* key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  ntop->getRedis()->smembers(vm, key);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef HAVE_ZMQ
#ifndef HAVE_NEDGE

/* @brief Disconnects from the previously connected ZMQ publisher endpoint.  Lua: ntop.zmq_disconnect() → nil */
static int ntop_zmq_disconnect(lua_State* vm) {
  void* context;
  void* subscriber;

  context = getLuaVMUserdata(vm, zmq_context);
  subscriber = getLuaVMUserdata(vm, zmq_subscriber);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  zmq_close(subscriber);
  zmq_ctx_destroy(context);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

#endif

/* ****************************************** */

#ifndef HAVE_NEDGE
/* @brief Receives and returns the next message from the active ZMQ subscription.  Lua: ntop.zmq_receive() → string */
static int ntop_zmq_receive(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  void* subscriber;
  int size;
  struct zmq_msg_hdr_v1 h;
  char* payload;
  int payload_len;
  zmq_pollitem_t item;
  int rc;

  subscriber = getLuaVMUserdata(vm, zmq_subscriber);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  item.socket = subscriber;
  item.events = ZMQ_POLLIN;
  do {
    rc = zmq_poll(&item, 1, 1000);
    if (rc < 0 || !curr_iface->isRunning()) /* CHECK */
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  } while (rc == 0);

  size = zmq_recv(subscriber, &h, sizeof(h), 0);

  if (size != sizeof(h) || h.version != ZMQ_MSG_VERSION) {
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "Unsupported publisher version [%d]", h.version);
    return -1;
  }

  payload_len = h.size + 1;
  if ((payload = (char*)malloc(payload_len)) != NULL) {
    size = zmq_recv(subscriber, payload, payload_len, 0);
    payload[h.size] = '\0';

    if (size > 0) {
      enum json_tokener_error jerr = json_tokener_success;
      json_object* o = json_tokener_parse_verbose(payload, &jerr);

      if (o != NULL) {
        struct json_object_iterator it = json_object_iter_begin(o);
        struct json_object_iterator itEnd = json_object_iter_end(o);

        while (!json_object_iter_equal(&it, &itEnd)) {
          char* key = (char*)json_object_iter_peek_name(&it);
          const char* value =
              json_object_get_string(json_object_iter_peek_value(&it));

          ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s]=[%s]", key, value);

          json_object_iter_next(&it);
        }

        json_object_put(o);
      } else
        ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s]: %s",
                                     json_tokener_error_desc(jerr), payload);

      lua_pushfstring(vm, "%s", payload);
      ntop->getTrace()->traceEvent(TRACE_INFO, "[%u] %s", h.size, payload);
      free(payload);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
    } else {
      free(payload);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    }
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
}
#endif
#endif

/* ****************************************** */

/* @brief Reloads all system preferences from Redis into process memory.  Lua: ntop.reloadPreferences([set_defaults]) → nil */
static int ntop_reload_preferences(lua_State* vm) {
  bool set_redis_defaults = false;

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    set_redis_defaults = lua_toboolean(vm, 1) ? true : false;

  if (set_redis_defaults) ntop->getRedis()->setDefaults();

  ntop->getPrefs()->reloadPrefsFromRedis();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Applies default ntopng file permissions (0640) to a path (Unix only).  Lua: ntop.setDefaultFilePermissions(path) → nil */
static int ntop_set_default_file_permissions(lua_State* vm) {
  char* fpath;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  fpath = (char*)lua_tostring(vm, 1);

  if (!fpath) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

#ifndef WIN32
  chmod(fpath, CONST_DEFAULT_FILE_MODE);
#endif

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Logs a message only when verbose tracing mode is enabled.  Lua: ntop.verboseTrace(msg) → nil */
static int ntop_verbose_trace(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, (ntop->getTrace()->get_trace_level() == MAX_TRACE_LEVEL)
                          ? true
                          : false);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sends a UDP datagram to the specified host and port.  Lua: ntop.send_udp_data(host, port, data) → nil */
static int ntop_send_udp_data(lua_State* vm) {
  int port;
  char *host, *data;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  host = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  port = (u_int16_t)lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  data = (char*)lua_tostring(vm, 3);

  if (Utils::sendUDPData(host, port, data)) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
}

/* ****************************************** */

/* @brief Sends data over TCP to the specified host and port.  Lua: ntop.send_tcp_data(host, port, data) → nil */
static int ntop_send_tcp_data(lua_State* vm) {
  bool rv = true;
  char *host, *data;
  int port;
  int timeout = 0;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((host = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  port = (int32_t)lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((data = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  /* Optional timeout */
  if (lua_type(vm, 4) == LUA_TNUMBER) timeout = lua_tonumber(vm, 4);

  rv = Utils::sendTCPData(host, port, data, timeout);

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the current periodic script is nearing its execution deadline.  Lua: ntop.isDeadlineApproaching() → boolean */
static int ntop_script_is_deadline_approaching(lua_State* vm) {
  NtopngLuaContext* ctx = getLuaVMContext(vm);

  if (ctx && ctx->deadline && ctx->threaded_activity) {
    ThreadedActivity* ta = (ThreadedActivity*)ctx->threaded_activity;

    lua_pushboolean(vm, ta->isDeadlineApproaching(ctx->deadline));
  } else
    lua_pushboolean(vm, false);

  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns the Unix epoch deadline for the current periodic script execution.  Lua: ntop.getDeadline() → integer */
static int ntop_script_get_deadline(lua_State* vm) {
  NtopngLuaContext* ctx = getLuaVMContext(vm);

  lua_pushinteger(vm, ctx && ctx->deadline ? ctx->deadline : 0);

  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns true if network speedtest functionality is compiled in.  Lua: ntop.hasSpeedtestSupport() → boolean */
static int ntop_has_speedtest_support(lua_State* vm) {
#ifdef HAVE_EXPAT
  lua_pushboolean(vm, true);
#else
  lua_pushboolean(vm, false);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Runs a network speedtest and returns download/upload/latency results (Pro).  Lua: ntop.speedtest() → table */
static int ntop_speedtest(lua_State* vm) {
  ntop->speedtest(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns IP blacklist hit counts and per-list statistics.  Lua: ntop.getBlacklistStats() → table */
static int ntop_get_bl_stats(lua_State* vm) {
  ntop->getBlacklistStats()->lua(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Resets all IP blacklist statistics counters to zero.  Lua: ntop.resetBlacklistStats() → nil */
static int ntop_reset_bl_stats(lua_State* vm) {
  ntop->resetBlacklistStats();
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the ClickHouse historical flows backend is active.  Lua: ntop.isClickHouseEnabled() → boolean */
static int ntop_clickhouse_enabled(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  bool enabled = ntop->getPrefs()->do_dump_flows_on_clickhouse();

  /* Make sure database is enabled - e.g. not enabled on 'database'
   * runtime interfaces */
  if (curr_iface->getDB() == NULL) enabled = false;

  lua_pushboolean(vm, enabled);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

// *** API ***
/* @brief Issues an HTTP 302 redirect to the given URL (for page-level Lua scripts).  Lua: ntop.httpRedirect(url) → nil */
static int ntop_http_redirect(lua_State* vm) {
  char *url, str[512];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((url = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  build_redirect(url, NULL, str, sizeof(str));
  lua_pushstring(vm, str);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

// *** API ***
/* @brief Performs an outbound HTTP GET request and optionally returns the response body.  Lua: ntop.httpGet(url[,user,pass,timeout,return_content,...]) → string */
static int ntop_http_get(lua_State* vm) {
  char *url, *username = NULL, *pwd = NULL, *bearer = NULL;
  int connection_timeout = 30, lifetime_timeout = 0;
  bool return_content = true, use_cookie_authentication = false;
  bool follow_redirects = true;
  int ip_version = 0;
  HTTPTranferStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if ((url = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 2) == LUA_TSTRING) {
    username = (char*)lua_tostring(vm, 2);

    if (lua_type(vm, 3) == LUA_TSTRING) {
      pwd = (char*)lua_tostring(vm, 3);
    }
  }

  if (lua_type(vm, 4) == LUA_TNUMBER) {
    connection_timeout = lua_tointeger(vm, 4);
    if (connection_timeout < 1) connection_timeout = 1;
  }

  /*
    This optional parameter specifies if the result of HTTP GET has to be
    returned to LUA or not. Usually the content has to be returned, but in some
    causes it just matters to time (for instance when use for testing HTTP
    services)
  */
  if (lua_type(vm, 5) == LUA_TBOOLEAN) {
    return_content = lua_toboolean(vm, 5) ? true : false;
  }

  if (lua_type(vm, 6) == LUA_TBOOLEAN) {
    use_cookie_authentication = lua_toboolean(vm, 6) ? true : false;
  }

  if (lua_type(vm, 7) == LUA_TBOOLEAN) {
    follow_redirects = lua_toboolean(vm, 7) ? true : false;
  }

  if (lua_type(vm, 8) == LUA_TNUMBER) ip_version = lua_tointeger(vm, 8);

  if (lua_type(vm, 9) == LUA_TSTRING)
    bearer = (char*)lua_tostring(vm, 9);

  Utils::httpGetPostPutPatch(vm, url, username, pwd, bearer,
			     NULL /* user_header_token */, connection_timeout,
			     lifetime_timeout, return_content, use_cookie_authentication, &stats, NULL,
			     NULL, follow_redirects, ip_version, method_get);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

// *** API ***
/* @brief Performs an HTTP GET with a Bearer authorization token header.  Lua: ntop.httpGetAuthToken(url, token[,timeout,return_content,no_verify]) → string */
static int ntop_http_get_auth_token(lua_State* vm) {
  char *url, *auth_token = NULL;
  int connection_timeout = 30, lifetime_timeout = 0;
  bool return_content = true, use_cookie_authentication = false;
  bool follow_redirects = true;
  int ip_version = 0;
  HTTPTranferStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((url = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((auth_token = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 3) == LUA_TNUMBER) {
    connection_timeout = lua_tointeger(vm, 3);
    if (connection_timeout < 1) connection_timeout = 1;
  }

  /*
    This optional parameter specifies if the result of HTTP GET has to be
    returned to LUA or not. Usually the content has to be returned, but in some
    causes it just matters to time (for instance when use for testing HTTP
    services)
  */
  if (lua_type(vm, 4) == LUA_TBOOLEAN)
    return_content = lua_toboolean(vm, 4) ? true : false;

  if (lua_type(vm, 5) == LUA_TBOOLEAN)
    use_cookie_authentication = lua_toboolean(vm, 5) ? true : false;

  if (lua_type(vm, 6) == LUA_TBOOLEAN)
    follow_redirects = lua_toboolean(vm, 6) ? true : false;

  if (lua_type(vm, 7) == LUA_TNUMBER) ip_version = lua_tointeger(vm, 7);

  Utils::httpGetPostPutPatch(vm, url, NULL /* username */, NULL /* pwd */,
			     NULL, /* bearer */
                             auth_token, connection_timeout, lifetime_timeout,
                             return_content, use_cookie_authentication, &stats,
                             NULL, NULL, follow_redirects, ip_version,
                             method_get);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the HTTP path prefix configured for this ntopng instance.  Lua: ntop.getHttpPrefix() → string */
static int ntop_http_get_prefix(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, ntop->getPrefs()->get_http_prefix());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the Unix epoch when ntopng was last started.  Lua: ntop.getStartupEpoch() → integer */
static int ntop_http_get_startup_epoch(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushinteger(vm, ntop->getLastModifiedStaticFileEpoch());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns an epoch value used for HTTP static-file cache busting.  Lua: ntop.getStaticFileEpoch() → integer */
static int ntop_http_get_static_file_epoch(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushinteger(vm, ntop->getLastModifiedStaticFileEpoch());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sanitizes a string to prevent XSS by removing dangerous characters.  Lua: ntop.httpPurifyParam(str) → string */
static int ntop_http_purify_param(lua_State* vm) {
  char *str, *buf;
  bool strict = false, allowURL = true, allowDots = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  }

  if ((str = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (lua_type(vm, 2) == LUA_TBOOLEAN)
    strict = lua_toboolean(vm, 2) ? true : false;
  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    allowURL = lua_toboolean(vm, 3) ? true : false;
  if (lua_type(vm, 4) == LUA_TBOOLEAN)
    allowDots = lua_toboolean(vm, 4) ? true : false;

  buf = strdup(str);

  if (buf == NULL) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  }

  Utils::purifyHTTPparam(buf, strict, allowURL, allowDots);
  lua_pushstring(vm, buf);
  free(buf);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns all current system preferences as a flat Lua table.  Lua: ntop.getPrefs() → table */
static int ntop_get_prefs(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getPrefs()->lua(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if raw ICMP ping is available on this system.  Lua: ntop.isPingAvailable() → boolean */
static int ntop_is_ping_available(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->canSendICMP());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ICMP ping is available on the given network interface.  Lua: ntop.isPingIfaceAvailable(ifname) → boolean */
static int ntop_is_ping_iface_available(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->canSelectNetworkIfaceICMP());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sends an ICMP ping to a host; use collectPingResults to retrieve RTT.  Lua: ntop.pingHost(host, is_v6, iface) → nil */
static int ntop_ping_host(lua_State* vm) {
#ifdef WIN32
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#else
  char *host, *ifname = NULL;
  bool is_v6;
  bool continuous = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((host = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  is_v6 = (bool)lua_toboolean(vm, 2);

  if (lua_type(vm, 3) == LUA_TBOOLEAN)
    continuous = lua_toboolean(vm, 3) ? true : false;

  if (lua_type(vm, 4) == LUA_TSTRING) ifname = (char*)lua_tostring(vm, 4);

  if (!continuous) {
    /* Ping one shot */
    Ping* ping = ntop->getPing(ifname);

    if (ping == NULL) {
      lua_pushnil(vm);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
    } else
      ping->ping(host, is_v6);
  } else {
    /* This is a continuous ping instead */
    ContinuousPing* c = ntop->getContinuousPing();

    if (c) {
      c->start(); /* In case not started it will now start */
      c->ping(host, is_v6, ifname);
    } else {
      lua_pushnil(vm);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#endif
}

/* ****************************************** */

/* @brief Collects and returns RTT results from recently sent pings.  Lua: ntop.collectPingResults() → table */
static int ntop_collect_ping_results(lua_State* vm) {
#ifdef WIN32
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#else
  bool continuous = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  continuous = lua_toboolean(vm, 1) ? true : false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!continuous) {
    /* Ping one shot */
    ntop->collectResponses(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    ntop->collectContinuousResponses(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

#endif
}

/* ****************************************** */

/* @brief Returns a table of interface names usable for ICMP ping.  Lua: ntop.getPingIfNames() → table */
static int ntop_get_ping_interface_names(lua_State* vm) {
#ifndef WIN32
  ContinuousPing* cping = ntop->getContinuousPing();
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

#ifndef WIN32
  if (cping) cping->getAllInterfaces(vm);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the special no-login username constant used for unauthenticated access.  Lua: ntop.getNologinUser() → string */
static int ntop_get_nologin_username(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, NTOP_NOLOGIN_USER);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table of all configured users with their attributes.  Lua: ntop.getUsers() → table */
static int ntop_get_users(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getUsers(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the network CIDRs visible to the current user.  Lua: ntop.getAllowedNetworks() → table */
static int ntop_get_allowed_networks(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getAllowedNetworks(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the current user has permission to download PCAP files.  Lua: ntop.isPcapDownloadAllowed() → boolean */
static int ntop_is_pcap_download_allowed(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->isPcapDownloadAllowed(vm, curr_iface->get_name()));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the current request is authenticated as an administrator.  Lua: ntop.isAdministrator() → boolean */
static int ntop_is_administrator(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->isUserAdministrator(vm));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static bool allowLocalUserManagement(lua_State* vm) {
  if (!ntop->isLocalUser(vm) && !ntop->isLocalAuthEnabled()) return (false);

  if (!ntop->isUserAdministrator(vm)) return (false);

  return (true);
}

/* Returns true if the caller is admin OR is managing their own account */
static bool allowWebAuthnManagement(lua_State* vm, const char* target_username) {
  if (!ntop->isLocalUser(vm) && !ntop->isLocalAuthEnabled()) return (false);
  if (ntop->isUserAdministrator(vm)) return (true);
  char* session_user = getLuaVMUserdata(vm, user);
  return (session_user && target_username &&
          strcmp(session_user, target_username) == 0);
}

/* ****************************************** */

/* @brief Changes a user password (requires old password or admin privileges).  Lua: ntop.resetUserPassword(who, username, old_pw, new_pw) → boolean */
static int ntop_reset_user_password(lua_State* vm) {
  char *who, *username, *old_password, *new_password;
  bool is_admin = ntop->isUserAdministrator(vm), ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Username who requested the password change */
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((who = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((old_password = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((new_password = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  /* non-local users cannot change their local password */
  if ((strcmp(who, username) == 0) && !ntop->isLocalUser(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  /* only the administrator can change other users passwords */
  if ((strcmp(who, username) != 0) && !allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  /* only the administrator can use and empty old password */
  if ((old_password[0] == '\0') && !is_admin)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ret = ntop->resetUserPassword(username, old_password, new_password);

  lua_pushboolean(vm, ret);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Changes a user role: administrator, unprivileged, or captivePortal.  Lua: ntop.changeUserRole(username, role) → boolean */
static int ntop_change_user_role(lua_State* vm) {
  char *username, *user_role;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((user_role = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->changeUserRole(username, user_role));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Updates the comma-separated allowed network CIDRs for a user.  Lua: ntop.changeAllowedNets(username, nets_csv) → boolean */
static int ntop_change_allowed_nets(lua_State* vm) {
  char *username, *allowed_nets;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((allowed_nets = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->changeAllowedNets(username, allowed_nets));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Updates the allowed interface restriction for a user.  Lua: ntop.changeAllowedIfname(username, ifname) → boolean */
static int ntop_change_allowed_ifname(lua_State* vm) {
  char *username, *allowed_ifname;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((allowed_ifname = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->changeAllowedIfname(username, allowed_ifname));
  return CONST_LUA_OK;
}

/* ****************************************** */

/*
 * Set the host pool for a captive portal user on authentication
 * (this is a 1-1 user-pool binding used for policy enforcement)
 */
/* @brief Sets the captive portal host pool for a user.  Lua: ntop.changeUserHostPool(username, pool_id) → boolean */
static int ntop_change_user_host_pool(lua_State* vm) {
  char *username, *host_pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((host_pool_id = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->changeUserHostPool(username, host_pool_id));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* Set which pools an unprivileged user is allowed to view */
/* @brief Sets the host pools viewable by an unprivileged user.  Lua: ntop.changeAllowedHostPools(username, pools) → boolean */
static int ntop_change_user_allowed_host_pools(lua_State* vm) {
  char *username, *allowed_host_pools;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((allowed_host_pools = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm,
                  ntop->changeAllowedHostPools(username, allowed_host_pools));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns the host pools the current user is allowed to see.  Lua: ntop.getAllowedHostPools() → table */
static int ntop_get_allowed_host_pools(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getAllowedHostPools(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Updates the display name for a user.  Lua: ntop.changeUserFullName(username, full_name) → boolean */
static int ntop_change_user_full_name(lua_State* vm) {
  char *username, *full_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((full_name = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->changeUserFullName(username, full_name));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Updates the UI language preference for a user.  Lua: ntop.changeUserLanguage(username, lang) → boolean */
static int ntop_change_user_language(lua_State* vm) {
  char *username, *language;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((language = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->changeUserLanguage(username, language));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Grants or revokes historical flow data access for a user.  Lua: ntop.changeHistoricalFlowPermission(username, allow) → boolean */
static int ntop_change_user_historical_flow_permission(lua_State* vm) {
  char* username;
  bool allow_historical_flows = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  allow_historical_flows = lua_toboolean(vm, 2) ? true : false;

  lua_pushboolean(vm, ntop->changeUserHistoricalFlowPermission(
                          username, allow_historical_flows));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Grants or revokes alerts viewing permission for a user.  Lua: ntop.changeAlertsPermission(username, allow) → boolean */
static int ntop_change_user_alerts_permission(lua_State* vm) {
  char* username;
  bool allow_alerts = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  allow_alerts = lua_toboolean(vm, 2) ? true : false;

  lua_pushboolean(vm, ntop->changeUserAlertsPermission(username, allow_alerts));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Grants or revokes PCAP download permission for a user.  Lua: ntop.changePcapDownloadPermission(username, allow) → boolean */
static int ntop_change_user_pcap_download_permission(lua_State* vm) {
  char* username;
  bool allow_pcap_download = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  allow_pcap_download = lua_toboolean(vm, 2) ? true : false;

  lua_pushboolean(vm, ntop->changeUserPcapDownloadPermission(
                          username, allow_pcap_download));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Posts a JSON string body to a URL via HTTP POST.  Lua: ntop.postHTTPJsonData(url, json_body) → boolean */
static int ntop_post_http_json_data(lua_State* vm) {
  char *username, *password, *url, *json, *bearer_token = NULL;
  HTTPTranferStats stats;
  int connection_timeout = 0, lifetime_timeout = 0;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((password = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((url = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((json = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  /* Optional connection timeout */
  if (lua_type(vm, 5) == LUA_TNUMBER) connection_timeout = lua_tonumber(vm, 5);

  /* Optional Bearer Token */
  if (lua_type(vm, 6) == LUA_TSTRING) bearer_token = (char*)lua_tostring(vm, 6);

  bool rv =
      Utils::postHTTPJsonData(bearer_token, username, password, url, json,
                              connection_timeout, lifetime_timeout, &stats);

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Performs an outbound HTTP POST request.  Lua: ntop.httpPost(url, body[,user,pass,timeout,return_content,content_type]) → string */
static int ntop_http_post(lua_State* vm) {
  char *username = (char*)"", *password = (char*)"", *url, *form_data;
  char *bearer = NULL;
  char *x_api_key = NULL;
  char *extra_header = NULL;
  int connection_timeout = 30, lifetime_timeout = 0;
  bool return_content = false;
  bool use_cookie_authentication = false;
  HTTPTranferStats stats;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((url = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((form_data = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 3) == LUA_TSTRING) /* Optional */
    if ((username = (char*)lua_tostring(vm, 3)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 4) == LUA_TSTRING) /* Optional */
    if ((password = (char*)lua_tostring(vm, 4)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 5) == LUA_TNUMBER) /* Optional */
    connection_timeout = lua_tonumber(vm, 5);

  if (lua_type(vm, 6) == LUA_TBOOLEAN) /* Optional */
    return_content = lua_toboolean(vm, 6) ? true : false;

  if (lua_type(vm, 7) == LUA_TBOOLEAN) /* Optional */
    use_cookie_authentication = lua_toboolean(vm, 7) ? true : false;

  if (lua_type(vm, 8) == LUA_TSTRING) /* Optional: Authorization: Bearer <token> */
    bearer = (char*)lua_tostring(vm, 8);

  if (lua_type(vm, 9) == LUA_TSTRING) /* Optional: x-api-key header */
    x_api_key = (char*)lua_tostring(vm, 9);

  if (lua_type(vm, 10) == LUA_TSTRING) /* Optional: raw extra header (e.g. "anthropic-version: 2023-06-01") */
    extra_header = (char*)lua_tostring(vm, 10);

  Utils::httpGetPostPutPatch(vm, url, username, password, bearer,
			     NULL /* user_header_token */,
      connection_timeout, lifetime_timeout, return_content,
      use_cookie_authentication, &stats, form_data, NULL, true, 0, method_post,
      x_api_key, extra_header);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Internal helper for HTTP requests requiring multiple auth token types.  Lua: (internal multi-auth helper) → string */
static int ntop_http_multi_auth_token(lua_State* vm, HttpMethod method) {
  char *url, *auth_token = NULL, *form_data;
  int connection_timeout = 30, lifetime_timeout = 0;
  bool return_content = false;
  bool use_cookie_authentication = false;
  HTTPTranferStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((url = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((auth_token = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((form_data = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 4) == LUA_TNUMBER) /* Optional */
    connection_timeout = lua_tonumber(vm, 4);

  if (lua_type(vm, 5) == LUA_TBOOLEAN) /* Optional */
    return_content = lua_toboolean(vm, 5) ? true : false;

  if (lua_type(vm, 6) == LUA_TBOOLEAN) /* Optional */
    use_cookie_authentication = lua_toboolean(vm, 6) ? true : false;

  Utils::httpGetPostPutPatch(vm, url, NULL /* username */, NULL /* pwd */,
			     NULL, /* bearer */
                             auth_token, connection_timeout, lifetime_timeout,
                             return_content, use_cookie_authentication, &stats,
                             form_data, NULL, true, 0, method);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Performs an HTTP POST request with a Bearer authorization token.  Lua: ntop.httpPostAuthToken(url, token, body[,timeout,content_type]) → string */
static int ntop_http_post_auth_token(lua_State* vm) {
  return (ntop_http_multi_auth_token(vm, method_post));
}
/* @brief Performs an HTTP PUT request with a Bearer authorization token.  Lua: ntop.httpPutAuthToken(url, token, body[,timeout]) → string */
static int ntop_http_put_auth_token(lua_State* vm) {
  return (ntop_http_multi_auth_token(vm, method_put));
}
/* @brief Performs an HTTP PATCH request with a Bearer authorization token.  Lua: ntop.httpPatchAuthToken(url, token, body[,timeout]) → string */
static int ntop_http_patch_auth_token(lua_State* vm) {
  return (ntop_http_multi_auth_token(vm, method_patch));
}

/* ****************************************** */

/* @brief Full-featured HTTP fetch accepting all options in a single parameter table.  Lua: ntop.httpFetch(params_table) → table */
static int ntop_http_fetch(lua_State* vm) {
  char *url, *f, fname[PATH_MAX];
  HTTPTranferStats stats;
  int connection_timeout = 30, lifetime_timeout = 0;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((url = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((f = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 3) == LUA_TNUMBER) /* Optional */
    connection_timeout = lua_tonumber(vm, 3);

  snprintf(fname, sizeof(fname), "%s", f);
  ntop->fixPath(fname);

  Utils::httpGetPostPutPatch(vm, url, NULL, NULL, NULL, /* bearer */
			     NULL /* user_header_token */,
                             connection_timeout, lifetime_timeout, false, false,
                             &stats, NULL, fname, true, 0, method_post);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Posts the contents of a text file to a URL via HTTP POST.  Lua: ntop.postHTTPTextFile(url, file_path) → boolean */
static int ntop_post_http_text_file(lua_State* vm) {
  char *username, *password, *url, *path;
  bool delete_file_after_post = false;
  int connection_timeout = 30, lifetime_timeout = 0;
  HTTPTranferStats stats;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((password = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((url = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((path = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 5) == LUA_TBOOLEAN) /* Optional */
    delete_file_after_post = lua_toboolean(vm, 5) ? true : false;

  if (lua_type(vm, 6) == LUA_TNUMBER) {
    /* Optional */
    connection_timeout = lua_tonumber(vm, 6);
    if (connection_timeout < 1) connection_timeout = 1;
  }

  if (Utils::postHTTPTextFile(vm, username, password, url, path,
                              connection_timeout, lifetime_timeout, &stats)) {
    if (delete_file_after_post) {
      if (unlink(path) != 0)
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to delete file %s",
                                     path);
      else
        ntop->getTrace()->traceEvent(TRACE_INFO, "Deleted file %s", path);
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef HAVE_CURL_SMTP
/* @brief Sends an email via SMTP (requires HAVE_CURL_SMTP build option).  Lua: ntop.sendMail(params_table) → boolean */
static int ntop_send_mail(lua_State* vm) {
  char *from, *to, *cc, *msg, *smtp_server, *username = NULL, *password = NULL;
  bool verbose = false, use_proxy = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((from = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((to = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((cc = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((msg = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((smtp_server = (char*)lua_tostring(vm, 5)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 6) == LUA_TSTRING) /* Optional */
    username = (char*)lua_tostring(vm, 6);

  if (lua_type(vm, 7) == LUA_TSTRING) /* Optional */
    password = (char*)lua_tostring(vm, 7);

  if (lua_type(vm, 8) == LUA_TBOOLEAN) /* Optional */
    use_proxy = lua_toboolean(vm, 8);

  if (lua_type(vm, 9) == LUA_TBOOLEAN) /* Optional */
    verbose = lua_toboolean(vm, 9);

  Utils::sendMail(vm, from, to, cc, msg, smtp_server, username, password,
                  use_proxy, verbose);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

/* @brief Creates a new user account with specified permissions and restrictions.  Lua: ntop.addUser(username, full_name, password, role, nets, iface, ...) → boolean */
static int ntop_add_user(lua_State* vm) {
  char *username, *full_name, *password, *host_role, *allowed_networks,
      *allowed_interface;
  char *host_pool_id = NULL, *language = NULL, *allowed_host_pools = NULL;
  bool allow_pcap_download = false;
  bool allow_historical_flows = false;
  bool allow_alerts = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((full_name = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((password = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((host_role = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((allowed_networks = (char*)lua_tostring(vm, 5)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((allowed_interface = (char*)lua_tostring(vm, 6)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 7) == LUA_TSTRING)
    if ((host_pool_id = (char*)lua_tostring(vm, 7)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 8) == LUA_TSTRING)
    if ((language = (char*)lua_tostring(vm, 8)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 9) == LUA_TBOOLEAN)
    allow_pcap_download = lua_toboolean(vm, 9);

  if (lua_type(vm, 10) == LUA_TBOOLEAN)
    allow_historical_flows = lua_toboolean(vm, 10);

  if (lua_type(vm, 11) == LUA_TBOOLEAN) allow_alerts = lua_toboolean(vm, 11);

  if (lua_type(vm, 12) == LUA_TSTRING)
    allowed_host_pools = (char*)lua_tostring(vm, 12);

  lua_pushboolean(
      vm, ntop->addUser(username, full_name, password, host_role,
                        allowed_networks, allowed_interface, host_pool_id,
                        language, allow_pcap_download, allow_historical_flows,
                        allow_alerts, allowed_host_pools));

  return CONST_LUA_OK;
}

/* ******************************************* */

/* @brief Creates a login session for a user and returns the session id.  Lua: ntop.createUserSession(username[, duration]) → string */
static int ntop_create_user_session(lua_State* vm) {
  char* username;
  char session_id[NTOP_SESSION_ID_LENGTH];
  u_int session_duration = 0;

  session_id[0] = '\0';

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (strlen(username) == 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 2) == LUA_TNUMBER) /* Optional */
    session_duration = lua_tonumber(vm, 2);

  /* Admin or the same user is allowed to get a session */
  if (!ntop->isUserAdministrator(vm)) {
    char* curr_user = getLuaVMUserdata(vm, user);

    if (strcmp(curr_user, username) != 0)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }

  ntop->get_HTTPserver()->authorize_noconn(
      username, session_id, sizeof(session_id), session_duration);

  lua_pushstring(vm, session_id);
  return CONST_LUA_OK;
}

/* ******************************************* */

/* @brief Generates and stores a new API token for a user.  Lua: ntop.createUserAPIToken(username) → string */
static int ntop_create_user_api_token(lua_State* vm) {
  char* username = NULL;
  char api_token[NTOP_SESSION_ID_LENGTH];
  api_token[0] = '\0';

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop->get_HTTPserver()->create_api_token(username, api_token,
                                               sizeof(api_token)))
    lua_pushstring(vm, api_token);
  else
    lua_pushnil(vm);

  return CONST_LUA_OK;
}

/* ******************************************* */

/* @brief Returns the existing API token for a user, or nil if none exists.  Lua: ntop.getUserAPIToken(username) → string */
static int ntop_get_user_api_token(lua_State* vm) {
  char* username = NULL;
  char api_token[NTOP_SESSION_ID_LENGTH];
  api_token[0] = '\0';

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  // get the username param from the Lua vm
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  char* curr_user = getLuaVMUserdata(vm, user);
  if (ntop->isUserAdministrator(vm) ||
      strncmp(curr_user, username, strlen(username)) == 0) {
    if (ntop->getUserAPIToken(username, api_token, NTOP_SESSION_ID_LENGTH)) {
      lua_pushstring(vm, api_token);
    } else {
      lua_pushnil(vm);
    }

    return CONST_LUA_OK;
  }
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Permanently deletes a user account and all associated settings.  Lua: ntop.deleteUser(username) → boolean */
static int ntop_delete_user(lua_State* vm) {
  char* username;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->deleteUser(username));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* MFA/TOTP Lua bindings */

/* @brief Generates a new base32 TOTP secret for two-factor authentication setup.  Lua: ntop.generateTOTPSecret() → string */
static int ntop_generate_totp_secret(lua_State* vm) {
  char secret[64];
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->generateTOTPSecret(secret, sizeof(secret)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushstring(vm, secret);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Stores a TOTP secret for a user.  Lua: ntop.setUserTOTPSecret(username, secret) → boolean */
static int ntop_set_user_totp_secret(lua_State* vm) {
  char *username, *secret;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((secret = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->setUserTOTPSecret(username, secret));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns the TOTP secret for a user (admin only).  Lua: ntop.getUserTOTPSecret(username) → string */
static int ntop_get_user_totp_secret(lua_State* vm) {
  char *username, secret[64];
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Only admins or the user themselves can retrieve the TOTP secret */
  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop->getUserTOTPSecret(username, secret, sizeof(secret)))
    lua_pushstring(vm, secret);
  else
    lua_pushnil(vm);

  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns true if TOTP two-factor authentication is enabled for a user.  Lua: ntop.isTOTPEnabled(username) → boolean */
static int ntop_is_totp_enabled(lua_State* vm) {
  char* username;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->isTOTPEnabled(username));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Enables or disables TOTP two-factor authentication for a user.  Lua: ntop.setUserTOTPEnabled(username, enabled) → boolean */
static int ntop_set_user_totp_enabled(lua_State* vm) {
  char* username;
  bool enabled;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!allowLocalUserManagement(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  enabled = lua_toboolean(vm, 2);

  lua_pushboolean(vm, ntop->setUserTOTPEnabled(username, enabled));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Validates a 6-digit TOTP code against the user's stored secret.  Lua: ntop.validateTOTP(username, code) → boolean */
static int ntop_validate_totp(lua_State* vm) {
  char *username, *code;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((code = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushboolean(vm, ntop->validateTOTPCode(username, code));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns the otpauth:// URI for scanning with an authenticator app.  Lua: ntop.getTOTPProvisioningUri(username) → string */
static int ntop_get_totp_provisioning_uri(lua_State* vm) {
  char *username, uri[256];
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->getTOTPProvisioningUri(username, uri, sizeof(uri));
  if (uri[0] != '\0')
    lua_pushstring(vm, uri);
  else
    lua_pushnil(vm);

  return CONST_LUA_OK;
}

/* ****************************************** */

/* WebAuthn/Passkey Lua bindings */

/* @brief Generate a WebAuthn registration challenge. Lua: ntop.generateWebAuthnRegistrationOptions(username) -> table or nil */
static int ntop_generate_webauthn_registration_options(lua_State* vm) {
  char *username;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (!allowWebAuthnManagement(vm, username))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  char challenge[64];
  if (!ntop->generateWebAuthnChallenge(challenge, sizeof(challenge)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  /* Store registration challenge in Redis with TTL */
  char key[256], val[256];
  snprintf(key, sizeof(key), "%s.%s", WEBAUTHN_REG_CHALLENGE_PREFIX, challenge);
  snprintf(val, sizeof(val), "%s", username);
  ntop->getRedis()->set(key, val, WEBAUTHN_REG_CHALLENGE_TTL);

  lua_newtable(vm);
  lua_pushstring(vm, challenge);  lua_setfield(vm, -2, "challenge");
  lua_pushstring(vm, username);   lua_setfield(vm, -2, "username");
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Complete WebAuthn registration. Lua: ntop.completeWebAuthnRegistration(username, cred_name, cred_id, cdj_b64, att_obj_b64, challenge, origin, rp_id) -> boolean */
static int ntop_complete_webauthn_registration(lua_State* vm) {
  char *username, *cred_name, *cred_id, *cdj_b64, *att_obj_b64, *challenge, *origin, *rp_id;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (!allowWebAuthnManagement(vm, username))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((cred_name = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((cred_id = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((cdj_b64 = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((att_obj_b64 = (char*)lua_tostring(vm, 5)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((challenge = (char*)lua_tostring(vm, 6)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 7, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((origin = (char*)lua_tostring(vm, 7)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 8, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((rp_id = (char*)lua_tostring(vm, 8)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  /* Verify the registration challenge is valid */
  char key[256], stored_user[64];
  snprintf(key, sizeof(key), "%s.%s", WEBAUTHN_REG_CHALLENGE_PREFIX, challenge);
  if (ntop->getRedis()->get(key, stored_user, sizeof(stored_user)) < 0 ||
      strcmp(stored_user, username) != 0) {
    lua_pushboolean(vm, false);
    return CONST_LUA_OK;
  }
  ntop->getRedis()->del(key); /* Consume challenge */

  bool ok = ntop->verifyAndStoreWebAuthnRegistration(
      username, cred_name, cred_id, cdj_b64, att_obj_b64, challenge, origin, rp_id);
  lua_pushboolean(vm, ok);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Get WebAuthn credentials as JSON. Lua: ntop.getWebAuthnCredentials(username) -> string JSON */
static int ntop_get_webauthn_credentials(lua_State* vm) {
  char* username;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  char json[4096];
  ntop->getWebAuthnCredentialsJSON(username, json, sizeof(json));
  lua_pushstring(vm, json);
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Delete a WebAuthn credential. Lua: ntop.deleteWebAuthnCredential(username, cred_id) -> boolean */
static int ntop_delete_webauthn_credential(lua_State* vm) {
  char *username, *cred_id;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (!allowWebAuthnManagement(vm, username))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((cred_id = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  lua_pushboolean(vm, ntop->deleteWebAuthnCredential(username, cred_id));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Check if user has WebAuthn enabled. Lua: ntop.isWebAuthnEnabled(username) -> boolean */
static int ntop_is_webauthn_enabled(lua_State* vm) {
  char* username;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((username = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  lua_pushboolean(vm, ntop->isWebAuthnEnabled(username));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Get pending WebAuthn token info. Lua: ntop.getWebAuthnPendingToken(token) -> table or nil */
static int ntop_get_webauthn_pending_token(lua_State* vm) {
  char* token;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((token = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  char username[64], referer[512], challenge[128];
  if (!ntop->getWebAuthnPendingToken(token, username, sizeof(username),
                                     referer, sizeof(referer),
                                     challenge, sizeof(challenge))) {
    lua_pushnil(vm);
    return CONST_LUA_OK;
  }
  lua_newtable(vm);
  lua_pushstring(vm, username);  lua_setfield(vm, -2, "username");
  lua_pushstring(vm, referer);   lua_setfield(vm, -2, "referer");
  lua_pushstring(vm, challenge); lua_setfield(vm, -2, "challenge");
  return CONST_LUA_OK;
}

/* ****************************************** */

/* Similar to ntop_get_resolved_address but actually perfoms the address
 * resolution now */
/* @brief Triggers asynchronous DNS reverse lookup for an IP (prefer resolveAddress() from lua_utils).  Lua: ntop.resolveName(ip) → nil */
static int ntop_resolve_address(lua_State* vm) {
  char *numIP, symIP[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((numIP = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->resolveHostName(numIP, symIP, sizeof(symIP));
  lua_pushstring(vm, symIP);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

void lua_push_str_table_entry(lua_State* L, const char* key,
                              const char* value) {
  if (L) {
    lua_pushstring(L, key);
    lua_pushstring(L, value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_str_len_table_entry(lua_State* L, const char* key,
                                  const char* value, const unsigned int len) {
  if (L) {
    char* v = (char*)malloc(len + 1);
    ;

    if (v != NULL) {
      memcpy(v, value, len);
      v[len] = 0;
    }

    lua_pushstring(L, key);
    if (v != NULL) {
      lua_pushstring(L, v);
      free(v);
    } else
      lua_pushstring(L, value);

    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_nil_table_entry(lua_State* L, const char* key) {
  if (L) {
    lua_pushstring(L, key);
    lua_pushnil(L);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_bool_table_entry(lua_State* L, const char* key, bool value) {
  if (L) {
    lua_pushstring(L, key);
    lua_pushboolean(L, value ? 1 : 0);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_uint64_table_entry(lua_State* L, const char* key,
                                 u_int64_t value) {
  if (L) {
    lua_pushstring(L, key);
    /* NOTE since LUA 5.3 integers are 64 bits */
    lua_pushinteger(L, (lua_Integer)value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_int64_table_entry(lua_State* L, const char* key, int64_t value) {
  if (L) {
    lua_pushstring(L, key);
    /* NOTE since LUA 5.3 integers are 64 bits */
    lua_pushinteger(L, (lua_Integer)value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_uint32_table_entry(lua_State* L, const char* key,
                                 u_int32_t value) {
  if (L) {
    lua_pushstring(L, key);
    lua_pushinteger(L, (lua_Integer)value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_int32_table_entry(lua_State* L, const char* key, int32_t value) {
  if (L) {
    lua_pushstring(L, key);

#if defined(LUA_MAXINTEGER) && defined(LUA_MININTEGER)
    if ((lua_Integer)value > LUA_MAXINTEGER ||
        (lua_Integer)value < LUA_MININTEGER)
      lua_pushnumber(L, (lua_Number)value);
    else
#endif
      lua_pushinteger(L, (lua_Integer)value);

    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_float_table_entry(lua_State* L, const char* key, float value) {
  if (L) {
    lua_pushstring(L, key);
    lua_pushnumber(L, value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

/* @brief Returns true if ntopng is installed from a distribution package.  Lua: ntop.isPackage() → boolean */
static int ntop_is_package(lua_State* vm) {
  bool is_package = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef NTOPNG_PRO
#ifndef WIN32
  is_package = (getppid() == 1 /* parent is systemd */);
#else
  is_package = true;
#endif
#endif

  lua_pushboolean(vm, is_package);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is forced to run in Community mode.  Lua: ntop.isForcedCommunity() → boolean */
static int ntop_is_forced_community(lua_State* vm) {
  bool is_forced_community = true;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
#ifdef NTOPNG_PRO
  is_forced_community = ntop->getPro()->forced_community_edition();
#endif
  lua_pushboolean(vm, is_forced_community);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running Pro edition or higher.  Lua: ntop.isPro() → boolean */
static int ntop_is_pro(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_pro_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running Enterprise M edition or higher.  Lua: ntop.isEnterpriseM() / ntop.isEnterprise() → boolean */
static int ntop_is_enterprise_m(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_enterprise_m_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running Enterprise L edition or higher.  Lua: ntop.isEnterpriseL() → boolean */
static int ntop_is_enterprise_l(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_enterprise_l_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running Enterprise XL edition or higher.  Lua: ntop.isEnterpriseXL() → boolean */
static int ntop_is_enterprise_xl(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_enterprise_xl_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running Enterprise XXL edition or higher.  Lua: ntop.isEnterpriseXXL() → boolean */
static int ntop_is_enterprise_xxl(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_enterprise_xxl_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running Enterprise XXXL edition or higher.  Lua: ntop.isEnterpriseXXXL() → boolean */
static int ntop_is_enterprise_xxxl(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_enterprise_xxxl_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running nEdge Pro edition.  Lua: ntop.isnEdge() → boolean */
static int ntop_is_nedge(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_nedge_pro_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running nEdge Enterprise edition.  Lua: ntop.isnEdgeEnterprise() → boolean */
static int ntop_is_nedge_enterprise(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_nedge_enterprise_edition());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if running on a dedicated ntopng hardware appliance.  Lua: ntop.isAppliance() → boolean */
static int ntop_is_appliance(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
#ifndef HAVE_NEDGE
  lua_pushboolean(vm, ntop->getPrefs()->is_appliance());
#else
  lua_pushboolean(vm, false);
#endif
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is configured in IoT Bridge mode.  Lua: ntop.isIoTBridge() → boolean */
static int ntop_is_iot_bridge(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
#ifndef HAVE_NEDGE
  bool is_supported = false;
#ifdef HAVE_EMBEDDED_SUPPORT
  is_supported = true; /* TODO Restrict this check to supported devices */
#endif
  lua_pushboolean(vm, ntop->getPrefs()->is_appliance() && is_supported);
#else
  lua_pushboolean(vm, false);
#endif
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Starts a PCAP extraction job from recorded traffic (admin only).  Lua: ntop.runExtraction(id, ifid, from, to, filter[,max_bytes,timeline]) → nil */
static int ntop_run_extraction(lua_State* vm) {
  int id, ifid;
  time_t time_from, time_to;
  char* filter;
  u_int64_t max_bytes;
  char* timeline_path = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (lua_type(vm, 6) == LUA_TNUMBER)
    max_bytes = lua_tonumber(vm, 6);
  else
    max_bytes = 0; /* optional */
  if (lua_tostring(vm, 7)) timeline_path = (char*)lua_tostring(vm, 7);

  id = lua_tointeger(vm, 1);
  ifid = lua_tointeger(vm, 2);
  time_from = lua_tointeger(vm, 3);
  time_to = lua_tointeger(vm, 4);
  if ((filter = (char*)lua_tostring(vm, 5)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  max_bytes = lua_tonumber(vm, 6);

  ntop->getTimelineExtract()->runExtractionJob(id, ntop->getInterfaceById(ifid),
                                               time_from, time_to, filter,
                                               max_bytes, timeline_path);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Stops a running PCAP extraction job by id.  Lua: ntop.stopExtraction(job_id) → nil */
static int ntop_stop_extraction(lua_State* vm) {
  int id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  id = lua_tointeger(vm, 1);

  ntop->getTimelineExtract()->stopExtractionJob(id);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if any PCAP extraction job is currently running.  Lua: ntop.isExtractionRunning() → boolean */
static int ntop_is_extraction_running(lua_State* vm) {
  bool rv;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  rv = ntop->getTimelineExtract()->isRunning();

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Reserved; returns extraction job status information.  Lua: ntop.getExtractionStatus() → nil */
static int ntop_get_extraction_status(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ntop->getTimelineExtract()->getStatus(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Starts a live PCAP stream extraction for the given time window and BPF filter.  Lua: ntop.runLiveExtraction(ifid, from, to, bpf[, timeline]) → boolean */
static int ntop_run_live_extraction(lua_State* vm) {
  NtopngLuaContext* c = NULL;
  NetworkInterface* iface = NULL;
  TimelineExtract timeline;
  int ifid = 0;
  time_t time_from = 0, time_to = 0;
  char* bpf = NULL;
  bool allow = false, success = false;
  char* timeline_path = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  c = getLuaVMContext(vm);

  if (!c) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ifid = lua_tointeger(vm, 1);
  time_from = lua_tointeger(vm, 2);
  time_to = lua_tointeger(vm, 3);
  if ((bpf = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  /* Optional: by default use <id>/timeline as path */
  if (lua_tostring(vm, 5)) timeline_path = (char*)lua_tostring(vm, 5);

  iface = ntop->getInterfaceById(ifid);
  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!ntop->isPcapDownloadAllowed(vm, iface->get_name()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  live_extraction_num_lock.lock(__FILE__, __LINE__);
  if (live_extraction_num < CONST_MAX_NUM_LIVE_EXTRACTIONS) {
    allow = true;
    live_extraction_num++;
  }
  live_extraction_num_lock.unlock(__FILE__, __LINE__);

  if (allow) {
    bpf = ntop->preparePcapDownloadFilter(vm, bpf);

    if (bpf) {
      success = timeline.extractLive(c->conn, iface, time_from, time_to, bpf,
                                     timeline_path);

      live_extraction_num_lock.lock(__FILE__, __LINE__);
      live_extraction_num--;
      live_extraction_num_lock.unlock(__FILE__, __LINE__);

      free(bpf);
    }
  }

  lua_pushboolean(vm, success);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the specified bit is set in the bitmap integer.  Lua: ntop.bitmapIsSet(bitmap, bit_value) → boolean */
static int ntop_bitmap_is_set(lua_State* vm) {
  u_int64_t bitmap;
  u_int64_t val;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  bitmap = lua_tointeger(vm, 1);
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  val = lua_tointeger(vm, 2);

  lua_pushboolean(vm, Utils::bitmapIsSet(bitmap, val));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sets the specified bit in the bitmap and returns the new bitmap value.  Lua: ntop.bitmapSet(bitmap, bit_value) → integer */
static int ntop_bitmap_set(lua_State* vm) {
  u_int64_t bitmap;
  u_int64_t val;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  bitmap = lua_tointeger(vm, 1);
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  val = lua_tointeger(vm, 2);

  lua_pushinteger(vm, Utils::bitmapSet(bitmap, val));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Clears the specified bit in the bitmap and returns the new bitmap value.  Lua: ntop.bitmapClear(bitmap, bit_value) → integer */
static int ntop_bitmap_clear(lua_State* vm) {
  u_int64_t bitmap;
  u_int64_t val;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  bitmap = lua_tointeger(vm, 1);
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  val = lua_tointeger(vm, 2);

  lua_pushinteger(vm, Utils::bitmapClear(bitmap, val));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Converts a numeric alert score to an alert severity enum value.  Lua: ntop.mapScoreToSeverity(score) → integer */
static int ntop_map_score_to_severity(lua_State* vm) {
  u_int64_t score;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  score = lua_tointeger(vm, 1);

  lua_pushinteger(vm, (u_int32_t)Utils::mapScoreToSeverity(score));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Converts an alert severity enum value to a numeric score.  Lua: ntop.mapSeverityToScore(severity) → integer */
static int ntop_map_severity_to_score(lua_State* vm) {
  AlertLevel alert_level;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  alert_level = (AlertLevel)lua_tointeger(vm, 1);

  lua_pushinteger(vm, Utils::mapSeverityToScore(alert_level));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Resets all per-interface traffic statistics counters.  Lua: ntop.resetStats() → nil */
static int ntop_reset_stats(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->resetStats();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the absolute path of the currently executing scripts directory.  Lua: ntop.getCurrentScriptsDir() → string */
static int ntop_get_current_scripts_dir(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, ntop->get_scripts_dir());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table of all key directory paths: installdir, scriptdir, httpdocsdir, workingdir, etc..  Lua: ntop.getDirs() → table */
static int ntop_get_dirs(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "bindir", ntop->get_bin_dir());
  lua_push_str_table_entry(vm, "installdir", ntop->get_install_dir());
  lua_push_str_table_entry(vm, "workingdir", ntop->get_working_dir());
  lua_push_str_table_entry(vm, "scriptdir",
                           ntop->getPrefs()->get_scripts_dir());
  lua_push_str_table_entry(vm, "httpdocsdir", ntop->getPrefs()->get_docs_dir());
  lua_push_str_table_entry(vm, "callbacksdir",
                           ntop->getPrefs()->get_callbacks_dir());
  lua_push_str_table_entry(vm, "pcapdir", ntop->getPrefs()->get_pcap_dir());
  lua_push_str_table_entry(vm, "dbarchivedir",
                           ntop->getPrefs()->get_clickhouse_archive_dir());
  lua_push_str_table_entry(vm, "etcdir", CONST_ETC_DIR);
  lua_push_str_table_entry(vm, "sharedir", CONST_SHARE_DIR);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Enables the asset discovery logging feature.  Lua: ntop.enableAssetsLog() → nil */
static int ntop_enable_assets_log(lua_State* vm) {
  bool enable_assets_log = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  }
  enable_assets_log = (bool)lua_tonumber(vm, 1);
  ntop->getPrefs()->do_enable_assets_log(enable_assets_log);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the assets discovery and logging feature is enabled.  Lua: ntop.assetsEnabled() → boolean */
static int ntop_assets_enabled(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef NTOPNG_PRO
  lua_pushboolean(vm, ntop->getPrefs()->isAssetInventoryEnabled());
#else
  lua_pushboolean(vm, false);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Recursively finds all files matching a pattern under base_path.  Lua: ntop.getAllPaths(base_path, filename_pattern) → table */
static int ntop_get_all_paths(lua_State* vm) {
  const char *path, *filename;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((path = (const char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((filename = (const char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_newtable(vm);
  Utils::lua_getpaths_recursively(vm, path, filename);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the ntopng uptime in seconds since last restart.  Lua: ntop.getUptime() → integer */
static int ntop_get_uptime(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushinteger(vm, ntop->getGlobals()->getUptime());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns system statistics including CPU load, memory usage, and alert queue info.  Lua: ntop.systemHostStat() → table */
static int ntop_system_host_stat(lua_State* vm) {
  float cpu_load;
  u_int64_t dropped_alerts = 0, written_alerts = 0, alerts_queries = 0;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  if (ntop->getCPULoad(&cpu_load))
    lua_push_float_table_entry(vm, "cpu_load", cpu_load);

  Utils::luaMeminfo(vm);

  for (int i = -1; i < ntop->get_num_interfaces(); i++) {
    NetworkInterface* iface =
        (i == -1) ? ntop->getSystemInterface() : ntop->getInterface(i);

    if (iface) {
      dropped_alerts += iface->getNumDroppedAlerts();
      written_alerts += iface->getNumWrittenAlerts();
      alerts_queries += iface->getNumAlertsQueries();
    }
  }

  lua_push_uint64_table_entry(vm, "dropped_alerts", dropped_alerts);
  lua_push_uint64_table_entry(vm, "written_alerts", written_alerts);
  lua_push_uint64_table_entry(vm, "alerts_queries", alerts_queries);

  /* ntopng alert queues stats */
  lua_newtable(vm);

  ntop->lua_alert_queues_stats(vm);

  lua_pushstring(vm, "alerts_stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns information about all running ntopng threads and their status.  Lua: ntop.threadsInfo() → table */
static int ntop_threads_info(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  ntop->lua_threadsInfo(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns system-level alert queue statistics (drops and writes).  Lua: ntop.getSystemAlertsStats() → table */
static int ntop_get_system_alerts_stats(lua_State* vm) {
  NetworkInterface* iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  iface = ntop->getSystemInterface();

  if (!iface) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_newtable(vm);

  iface->luaNumEngagedAlerts(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Refreshes and returns the current CPU load percentage.  Lua: ntop.refreshCPULoad() → number */
static int ntop_refresh_cpu_load(lua_State* vm) {
  float cpu_load;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->refreshCPULoad();

  if (ntop->getCPULoad(&cpu_load))
    lua_pushnumber(vm, cpu_load);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Triggers a license validation check and returns 1.  Lua: ntop.checkLicense() → integer */
static int ntop_check_license(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef NTOPNG_PRO
  ntop->getPro()->check_license();
#endif

  lua_pushinteger(vm, 1);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns comprehensive product info: version, OS, license, uptime, listening ports.  Lua: ntop.getInfo([verbose]) → table */
static int ntop_get_info(lua_State* vm) {
  char rsp[256];
#ifdef NTOPNG_PRO
  char buf[128];
#endif
#ifndef HAVE_NEDGE
  int major, minor, patch;
#endif
  bool verbose = true;
  char* zoneinfo = ntop->getZoneInfo();
  FILE* fd = fopen("/proc/device-tree/model", "r");

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TBOOLEAN)
    verbose = lua_toboolean(vm, 1) ? true : false;

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "product",
#ifdef NTOPNG_PRO
                           ntop->getPro()->get_product_name()
#else
                           (char*)"ntopng"
#endif
  );
  lua_push_bool_table_entry(vm, "oem",
#ifdef NTOPNG_PRO
                            ntop->getPro()->is_oem()
#else
                            false
#endif
  );
  lua_push_str_table_entry(
      vm, "copyright",
#ifdef NTOPNG_PRO
      ntop->getPro()->is_oem() ? (char*)"" :
#endif
                               (char*)"&copy; 1998-26 - ntop");
  lua_push_str_table_entry(vm, "authors", (char*)"The ntop team");
  lua_push_str_table_entry(vm, "license", (char*)"GNU GPLv3");
  lua_push_str_table_entry(vm, "platform", (char*)PACKAGE_MACHINE);
  lua_push_str_table_entry(vm, "version", (char*)PACKAGE_VERSION);
  lua_push_str_table_entry(vm, "revision", (char*)PACKAGE_REVISION);
  lua_push_str_table_entry(vm, "git", (char*)NTOPNG_GIT_RELEASE);
#ifndef WIN32
  lua_push_uint64_table_entry(vm, "pid", getpid());
#endif
#ifdef HAVE_JEMALLOC
  lua_push_bool_table_entry(vm, "jemalloc", true);
#endif

  snprintf(rsp, sizeof(rsp), "%s [%s]", PACKAGE_OS, PACKAGE_MACHINE);
  lua_push_str_table_entry(vm, "platform", rsp);
  lua_push_str_table_entry(vm, "OS",
#ifdef WIN32
                           (char*)"Windows"
#else
                           (char*)PACKAGE_OS
#endif
  );

  if (fd != NULL) {
    char* rc = fgets(rsp, sizeof(rsp), fd);

    if (rc != NULL) lua_push_str_table_entry(vm, "hw_model", rsp);

    fclose(fd);
  }

  lua_push_uint64_table_entry(vm, "bits", (sizeof(void*) == 4) ? 32 : 64);
  lua_push_uint64_table_entry(vm, "uptime", ntop->getGlobals()->getUptime());
  lua_push_str_table_entry(vm, "command_line",
                           ntop->getPrefs()->get_command_line());
  lua_push_uint32_table_entry(vm, "http_port",
                              ntop->getPrefs()->get_http_port());
  lua_push_uint32_table_entry(vm, "https_port",
                              ntop->getPrefs()->get_https_port());

  lua_push_str_table_entry(vm, "tzname", ntop->getTZname()); /* Timezone name */

  if (zoneinfo) lua_push_str_table_entry(vm, "zoneinfo", zoneinfo);

#ifdef __linux__
  lua_push_int32_table_entry(vm, "timezone",
                             timezone); /* Seconds west of UTC */
#endif

  if (verbose) {
    lua_push_str_table_entry(vm, "version.rrd", rrd_strversion());
    lua_push_str_table_entry(vm, "version.redis",
                             ntop->getRedis()->getVersion());
    lua_push_str_table_entry(vm, "version.httpd", (char*)mg_version());
    lua_push_str_table_entry(vm, "version.git", (char*)NTOPNG_GIT_RELEASE);
    lua_push_str_table_entry(vm, "version.curl", (char*)LIBCURL_VERSION);
    lua_push_str_table_entry(vm, "version.lua", (char*)LUA_RELEASE);
#ifdef HAVE_MAXMINDDB
    lua_push_str_table_entry(vm, "version.geoip", (char*)MMDB_lib_version());
#endif
    lua_push_str_table_entry(vm, "version.ndpi", ndpi_revision());

    lua_push_bool_table_entry(vm, "pro.release",
                              ntop->getPrefs()->is_pro_edition());
    lua_push_bool_table_entry(vm, "version.enterprise_edition",
                              ntop->getPrefs()->is_enterprise_m_edition());
    lua_push_bool_table_entry(vm, "version.enterprise_m_edition",
                              ntop->getPrefs()->is_enterprise_m_edition());
    lua_push_bool_table_entry(vm, "version.enterprise_l_edition",
                              ntop->getPrefs()->is_enterprise_l_edition());
    lua_push_bool_table_entry(vm, "version.enterprise_xl_edition",
                              ntop->getPrefs()->is_enterprise_xl_edition());
    lua_push_bool_table_entry(vm, "version.enterprise_xxl_edition",
                              ntop->getPrefs()->is_enterprise_xxl_edition());
    lua_push_bool_table_entry(vm, "version.enterprise_xxxl_edition",
                              ntop->getPrefs()->is_enterprise_xxxl_edition());

    lua_push_bool_table_entry(vm, "version.nedge_edition",
                              ntop->getPrefs()->is_nedge_pro_edition());
    lua_push_bool_table_entry(vm, "version.nedge_enterprise_edition",
                              ntop->getPrefs()->is_nedge_enterprise_edition());

    lua_push_bool_table_entry(vm, "version.embedded_edition",
                              ntop->getPrefs()->is_embedded_edition());

    lua_push_uint64_table_entry(vm, "pro.demo_ends_at",
                                ntop->getPrefs()->pro_edition_demo_ends_at());
#ifdef NTOPNG_PRO
#ifndef FORCE_VALID_LICENSE
    time_t until_then;
    int days_left;

    if (ntop->getPro()->get_maintenance_expiration_time(&until_then,
                                                        &days_left)) {
      lua_push_uint64_table_entry(vm, "pro.license_ends_at",
                                  (u_int64_t)until_then);
      lua_push_int64_table_entry(vm, "pro.license_days_left", days_left);
    }
#endif
    lua_push_str_table_entry(vm, "pro.license", ntop->getPro()->get_license());
    lua_push_str_table_entry(vm, "pro.license_encoded",
                             ntop->getPro()->get_encoded_license());
    lua_push_bool_table_entry(vm, "pro.has_valid_license",
                              ntop->getPro()->has_valid_license());
    lua_push_str_table_entry(
        vm, "pro.license_type",
        ntop->getPro()->get_license_type(buf, sizeof(buf)));
    lua_push_bool_table_entry(vm, "pro.forced_community",
                              ntop->getPro()->is_forced_community());
    lua_push_bool_table_entry(vm, "pro.out_of_maintenance",
                              ntop->getPro()->is_out_of_maintenance());
    lua_push_bool_table_entry(vm, "pro.use_redis_license",
                              ntop->getPro()->use_redis_license());
    lua_push_str_table_entry(vm, "pro.systemid",
                             ntop->getPro()->get_system_id());
#endif
    lua_push_uint64_table_entry(vm, "constants.max_num_host_pools",
                                MAX_NUM_HOST_POOLS);
    lua_push_uint64_table_entry(vm, "constants.max_num_pool_members",
                                MAX_NUM_POOL_MEMBERS);
    lua_push_uint64_table_entry(vm, "constants.max_num_profiles",
                                MAX_NUM_PROFILES);

#ifdef HAVE_ZMQ
#ifndef HAVE_NEDGE
    zmq_version(&major, &minor, &patch);
    snprintf(rsp, sizeof(rsp), "%d.%d.%d", major, minor, patch);
    lua_push_str_table_entry(vm, "version.zmq", rsp);
#endif
#endif
  }

#ifdef NTOPNG_PRO
  ntop->getPro()->lua(vm);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the HTTP cookie security attributes string (e.g. SameSite=Strict; Secure).  Lua: ntop.getCookieAttributes() → string */
static int ntop_get_cookie_attributes(lua_State* vm) {
  struct mg_request_info* request_info;
  struct mg_connection* conn;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!(conn = getLuaVMUserdata(vm, conn)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!(request_info = mg_get_request_info(conn)))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushstring(vm, (char*)get_secure_cookie_attributes(request_info));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the current user is allowed to access the given interface.  Lua: ntop.isAllowedInterface(ifname) → boolean */
static int ntop_is_allowed_interface(lua_State* vm) {
  int id;
  NetworkInterface* iface;
  bool rv = false;
  char* allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  id = lua_tointeger(vm, 1);

  if ((allowed_ifname == NULL) || (allowed_ifname[0] == '\0'))
    rv = true;
  else if (((iface = ntop->getNetworkInterface(vm, id)) != NULL) &&
           (iface->get_id() == id) &&
           matches_allowed_ifname(allowed_ifname, iface->get_name()))
    rv = true;

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the current user is allowed to see the given network.  Lua: ntop.isAllowedNetwork(network) → boolean */
static int ntop_is_allowed_network(lua_State* vm) {
  bool rv = false;
  u_int16_t vlan_id = 0;
  char *host, buf[64];
  AddressTree* allowed_nets = get_allowed_nets(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host, &vlan_id, buf,
                     sizeof(buf));

  if (!allowed_nets /* e.g., when the user is 'nologin' there's no allowed
                       network to enforce */
      || allowed_nets->match(host))
    rv = true;

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the IP belongs to one of this machine's network interfaces.  Lua: ntop.isLocalInterfaceAddress(ip) → boolean */
static int ntop_is_local_interface_address(lua_State* vm) {
  char* host;
  IpAddress ipa;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  host = (char*)lua_tostring(vm, 1);
  ipa.set(host);

  /* Check if this IP address is local to this machine */
  lua_pushboolean(vm, ipa.isLocalInterfaceAddress());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the IP is in one of the configured local networks.  Lua: ntop.isLocalAddress(ip) → boolean */
static int ntop_is_local_address(lua_State* vm) {
  char *host, *slash;
  IpAddress ipa;
  char shadow[64];

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  host = (char*)lua_tostring(vm, 1);
  snprintf(shadow, sizeof(shadow), "%s", host);

  if ((slash = strchr(shadow, '/')) != NULL) {
    /* network/CIDR */
    char *ip, *mask;
    u_int8_t nmask_bits;
    int32_t local_network_id;

    shadow[0] = '\0';
    ip = shadow, mask = &shadow[1];
    nmask_bits = (u_int8_t)atoi(mask);

    if (strchr(ip, ':') != NULL) {
      /* IPv6 */
      struct ndpi_in6_addr ipv6;

      if (inet_pton(AF_INET6, ip, &ipv6) <= 0)
        lua_pushboolean(vm, false);
      else
        lua_pushboolean(
            vm, ntop->isLocalAddress(AF_INET6, (void*)&ipv6, &local_network_id,
                                     &nmask_bits));
    } else {
      /* IPv4 */
      u_int32_t addr = inet_addr(ip);

      lua_pushboolean(vm, ntop->isLocalAddress(AF_INET, &addr,
                                               &local_network_id, &nmask_bits));
    }
  } else {
    ipa.set(shadow);

    /* Check if this IP address is local (-m) */
    lua_pushboolean(vm, ipa.isLocalHost());
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the local network info table for the network containing the given IP.  Lua: ntop.getAddressNetwork(ip) → table */
static int ntop_get_address_network(lua_State* vm) {
  char* ip;
  IpAddress ipa;
  int32_t local_network_id = -1;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ip = (char*)lua_tostring(vm, 1);

  ipa.set(ip);
  ipa.isLocalHost(&local_network_id);

  lua_pushinteger(vm, (u_int32_t)local_network_id);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Retrieves a cached DNS reverse lookup result (prefer getResolvedAddress() from lua_utils).  Lua: ntop.getResolvedName(ip) → string */
static int ntop_get_resolved_address(lua_State* vm) {
  char *key, *tmp, rsp[256], value[280];
  Redis* redis = ntop->getRedis();
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  get_host_vlan_info((char*)lua_tostring(vm, 1), &key, &vlan_id, buf,
                     sizeof(buf));

  if (key == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((redis->getAddress(key, rsp, sizeof(rsp), true) == 0) && (rsp[0] != '\0'))
    tmp = rsp;
  else
    tmp = key;

  if (vlan_id != 0)
    snprintf(value, sizeof(value), "%s@%u", tmp, vlan_id);
  else
    snprintf(value, sizeof(value), "%s", tmp);

  lua_pushfstring(vm, "%s", value);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Synchronously resolves a hostname to its IP address.  Lua: ntop.resolveHost(hostname) → string */
static int ntop_resolve_host(lua_State* vm) {
  char buf[64];
  char* host;
  bool ipv4 = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((host = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  ipv4 = lua_toboolean(vm, 2);

  if (ntop->resolveHost(host, buf, sizeof(buf), ipv4))
    lua_pushstring(vm, buf);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Enables or disables full (fat) MIB polling mode for SNMP.  Lua: ntop.snmpSetFatMibPollingMode(enabled) → nil */
static int ntop_snmp_set_fat_mib_polling_mode(lua_State* vm) {
  NtopngLuaContext* ctx = getLuaVMContext(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ctx && ctx->threaded_activity_stats)
    ctx->threaded_activity_stats->setFatMIBMode((bool)lua_toboolean(vm, 1));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if the corresponding SNMP capability is compiled in.  Lua: ntop.snmpv3available()/snmpsetavailable()/snmpgetbulkavailable() → boolean */
static int ntop_is_libsnmp_available(lua_State* vm) {
  lua_pushboolean(vm,
#ifdef HAVE_LIBSNMP
                  true
#else
                  false
#endif
  );

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the maximum number of concurrent SNMP engines supported.  Lua: ntop.snmpMaxNumEngines() → integer */
static int ntop_snmp_max_num_engines(lua_State* vm) {
  u_int16_t num = 0;

#ifdef NTOPNG_PRO
  if (ntop->getPro()->has_valid_enterprise_xxxl_license())
    num = NTOPNG_MAX_NUM_SNMP_DEVICES_ENT_XXXL;
  else if (ntop->getPro()->has_valid_enterprise_xxl_license())
    num = NTOPNG_MAX_NUM_SNMP_DEVICES_ENT_XXL;
  else if (ntop->getPro()->has_valid_enterprise_xl_license())
    num = NTOPNG_MAX_NUM_SNMP_DEVICES_ENT_XL;
  else if (ntop->getPro()->has_valid_enterprise_l_license())
    num = NTOPNG_MAX_NUM_SNMP_DEVICES_ENT_L;
  else if (ntop->getPro()->has_valid_enterprise_m_license())
    num = NTOPNG_MAX_NUM_SNMP_DEVICES_ENT_M;
#endif
#ifdef HAVE_NEDGE
  if (ntop->getPro()->has_valid_nedge_enterprise_license())
    num = NTOPNG_MAX_NUM_SNMP_DEVICES_NEDGE;
#endif

  lua_pushinteger(vm, num);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sets the maximum number of variable repetitions for SNMP GETBULK requests.  Lua: ntop.snmpSetBulkMaxNumRepetitions(n) → nil */
static int ntop_snmp_set_bulk_max_repetitions(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  c->getbulkMaxNumRepetitions = (u_int8_t)lua_tointeger(vm, 1);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* Synchronous calls */
/* @brief Performs a blocking SNMP GET and returns the OID response table.  Lua: ntop.snmpget(host, community, oid, version) → table */
static int ntop_snmpget(lua_State* vm) {
  SNMP s;

  return (s.get(vm, false));
}

/* ****************************************** */

/* @brief Performs a blocking SNMP GETNEXT and returns the next OID response.  Lua: ntop.snmpgetnext(host, community, oid, version) → table */
static int ntop_snmpgetnext(lua_State* vm) {
  SNMP s;

  return (s.getnext(vm, false));
}

/* ****************************************** */

/* @brief Performs a blocking SNMP GETBULK and returns all OID responses.  Lua: ntop.snmpgetnextbulk(host, community, oid, version) → table */
static int ntop_snmpgetnextbulk(lua_State* vm) {
  SNMP s;

  return (s.getnextbulk(vm, false));
}

/* ****************************************** */

/* @brief Performs a blocking SNMP SET operation on a remote OID.  Lua: ntop.snmpset(host, community, oid, type, value, version) → boolean */
static int ntop_snmpset(lua_State* vm) {
  SNMP s;

  return (s.set(vm, false));
}

/* ****************************************** */

/* Asynchronous calls */
/* @brief Allocates an async SNMP engine and returns its integer handle.  Lua: ntop.snmpallocasnyncengine() → integer */
static int ntop_allocasnyncengine(lua_State* vm) {
  SNMP** snmpAsyncEngine = getLuaVMUserdata(vm, snmpAsyncEngine);
  u_int16_t slot_id;
  bool found_empty_slot = false;

  for (slot_id = 0; slot_id < MAX_NUM_ASYNC_SNMP_ENGINES; slot_id++) {
    if (snmpAsyncEngine[slot_id] == NULL) {
      found_empty_slot = true;
      break;
    }
  } /* for */

  if (found_empty_slot) {
    if ((snmpAsyncEngine[slot_id] = new SNMP()) != NULL) {
      lua_pushinteger(vm, slot_id);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
    }
  }

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Frees an async SNMP engine previously allocated with snmpallocasnyncengine.  Lua: ntop.snmpfreeasnycengine(handle) → nil */
static int ntop_freeasnyncengine(lua_State* vm) {
  SNMP** snmpAsyncEngine = getLuaVMUserdata(vm, snmpAsyncEngine);
  u_int16_t slot_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  slot_id = (u_int16_t)lua_tonumber(vm, 1);

  if ((slot_id >= MAX_NUM_ASYNC_SNMP_ENGINES) ||
      (snmpAsyncEngine[slot_id] == NULL))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  delete snmpAsyncEngine[slot_id];
  snmpAsyncEngine[slot_id] = NULL;

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Queues an asynchronous SNMP GET request on the given engine handle.  Lua: ntop.snmpgetasync(handle, host, community, oid, version) → nil */
static int ntop_snmpgetasync(lua_State* vm) {
  SNMP** snmpAsyncEngine = getLuaVMUserdata(vm, snmpAsyncEngine);
  u_int16_t slot_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  slot_id = (u_int16_t)lua_tonumber(vm, 1);

  if ((slot_id >= MAX_NUM_ASYNC_SNMP_ENGINES) ||
      (snmpAsyncEngine[slot_id] == NULL))
    return (ntop_lua_return_value(vm, __FUNCTION__,
                                  CONST_LUA_ERROR)); /* Invalid slot selected */

  return (snmpAsyncEngine[slot_id]->get(vm, true /* Skip first param */));
}

/* ****************************************** */

/* @brief Queues an asynchronous SNMP GETNEXT request on the given engine handle.  Lua: ntop.snmpgetnextasync(handle, host, community, oid, version) → nil */
static int ntop_snmpgetnextasync(lua_State* vm) {
  SNMP** snmpAsyncEngine = getLuaVMUserdata(vm, snmpAsyncEngine);
  u_int16_t slot_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  slot_id = (u_int16_t)lua_tonumber(vm, 1);

  if ((slot_id >= MAX_NUM_ASYNC_SNMP_ENGINES) ||
      (snmpAsyncEngine[slot_id] == NULL))
    return (ntop_lua_return_value(vm, __FUNCTION__,
                                  CONST_LUA_ERROR)); /* Invalid slot selected */

  return (snmpAsyncEngine[slot_id]->getnext(vm, true /* Skip first param */));
}

/* ****************************************** */

/* @brief Queues an asynchronous SNMP GETBULK request on the given engine handle.  Lua: ntop.snmpgetnextbulkasync(handle, ...) → nil */
static int ntop_snmpgetnextbulkasync(lua_State* vm) {
  SNMP** snmpAsyncEngine = getLuaVMUserdata(vm, snmpAsyncEngine);
  u_int16_t slot_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  slot_id = (u_int16_t)lua_tonumber(vm, 1);

  if ((slot_id >= MAX_NUM_ASYNC_SNMP_ENGINES) ||
      (snmpAsyncEngine[slot_id] == NULL))
    return (ntop_lua_return_value(vm, __FUNCTION__,
                                  CONST_LUA_ERROR)); /* Invalid slot selected */

  return (
      snmpAsyncEngine[slot_id]->getnextbulk(vm, true /* Skip first param */));
}

/* ****************************************** */

/* @brief Reads and returns all pending async SNMP responses from an engine handle.  Lua: ntop.snmpreadasyncrsp(handle) → table */
static int ntop_snmpreadasyncrsp(lua_State* vm) {
  SNMP** snmpAsyncEngine = getLuaVMUserdata(vm, snmpAsyncEngine);
  u_int16_t slot_id;
  u_int timeout = 0; /* Don't wait */

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  slot_id = (u_int16_t)lua_tonumber(vm, 1);

  if ((slot_id >= MAX_NUM_ASYNC_SNMP_ENGINES) ||
      (snmpAsyncEngine[slot_id] == NULL))
    return (ntop_lua_return_value(vm, __FUNCTION__,
                                  CONST_LUA_ERROR)); /* Invalid slot selected */

  if (lua_type(vm, 2) == LUA_TNUMBER) timeout = (u_int8_t)lua_tonumber(vm, 2);

  snmpAsyncEngine[slot_id]->snmp_fetch_responses(vm, timeout);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Internal helper that handles the SNMPv3-specific portion of batch GET operations.  Lua: (internal SNMPv3 helper) → nil */
static int ntop_snmpv3_batch_get(lua_State* vm) {
#ifdef HAVE_LIBSNMP
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* oid[SNMP_MAX_NUM_OIDS] = {NULL};
  char value_types[SNMP_MAX_NUM_OIDS];
  SNMP* snmp;
  bool ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 6, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 7, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 8, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 9, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  oid[0] = (char*)lua_tostring(vm, 9);

  snmp = getLuaVMUserdata(vm, snmpBatch);

  if (snmp == NULL) {
    snmp = new SNMP();

    if (!snmp)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    getLuaVMUservalue(vm, snmpBatch) = snmp;
  }

  ret = snmp->send_snmpv3_request(
      (char*)lua_tostring(vm, 1), /* agent_host */
      (char*)lua_tostring(vm, 2), /* level */
      (char*)lua_tostring(vm, 3), /* username */
      (char*)lua_tostring(vm, 4), /* auth_protocol */
      (char*)lua_tostring(vm, 5), /* auth_passphrase */
      (char*)lua_tostring(vm, 6), /* privacy_protocol */
      (char*)lua_tostring(vm, 7), /* privacy_passphrase */
      (char*)lua_tostring(vm, 8), /* context_name */
      snmp_get_pdu, oid,          /* oid */
      value_types, NULL, true /* batch */);

  if (ret) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
#else
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
#endif
}

/* ****************************************** */

/* @brief Submits a batch of SNMP GET requests (v1/v2c/v3) for async collection.  Lua: ntop.snmpGetBatch(params_table) → nil */
static int ntop_snmp_batch_get(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  char* oid[SNMP_MAX_NUM_OIDS] = {NULL};
  SNMP* snmp;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 4) != LUA_TNUMBER) return (ntop_snmpv3_batch_get(vm));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  oid[0] = (char*)lua_tostring(vm, 3);

  snmp = getLuaVMUserdata(vm, snmpBatch);

  if (snmp == NULL) {
    snmp = new SNMP();

    if (!snmp)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    getLuaVMUservalue(vm, snmpBatch) = snmp;
  }

  snmp->send_snmpv1v2c_request((char*)lua_tostring(vm, 1), /* agent_host */
                               (char*)lua_tostring(vm, 2), /* community */
                               snmp_get_pdu,
                               (u_int)lua_tonumber(vm, 4), /* version */
                               oid, true /* batch */);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Collects and returns all pending batch SNMP GET responses.  Lua: ntop.snmpReadResponses() → table */
static int ntop_snmp_read_responses(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  SNMP* snmp = getLuaVMUserdata(vm, snmpBatch);
  int timeout = 0;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((!curr_iface) || (!snmp))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  /* Optional timeout */
  if (lua_type(vm, 1) == LUA_TNUMBER) timeout = lua_tonumber(vm, 1);

  snmp->snmp_fetch_responses(vm, timeout);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#if defined(NTOPNG_PRO)

/* @brief Enables the SNMP interface roles set by ntop.snmpSetInterfaceRole,. Lua: ntop.activateSnmpInterfaceRoles() → nil */
static int ntop_activate_snmp_interface_roles(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->activateSnmpInterfaceRoles();
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));  
}

/* ****************************************** */

/* @brief Sets the LAN/WAN role for an SNMP-managed interface (Pro only).  Lua: ntop.snmpSetInterfaceRole(host, ifidx, role) → nil */
static int ntop_snmp_set_interface_role(lua_State* vm) {
  u_int32_t exporter_ip_v4;
  u_int32_t interface_id;
  SNMPInterfaceRole interface_role;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) ||
      (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) ||
      (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  exporter_ip_v4 = ntohl((u_int32_t)inet_addr((char*)lua_tostring(vm, 1)));
  interface_id = (u_int32_t)lua_tonumber(vm, 2);
  interface_role = (SNMPInterfaceRole)lua_tonumber(vm, 3);

  if (interface_role < role_max_value) {
    /* Set data */

    ntop->snmpSetInterfaceRole(exporter_ip_v4, interface_id, interface_role);

    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
}
#endif

/* ****************************************** */

/* @brief Enables or disables SNMP trap collection.  Lua: ntop.snmpToggleTrapCollection(enabled) → nil */
static int ntop_snmp_toggle_trap_collection(lua_State* vm) {
#ifdef HAVE_SNMP_TRAP
  bool enable = false;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  enable = (bool)lua_toboolean(vm, 1);

  ntop->toggleSNMPTrapCollector(enable);
#endif

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifndef WIN32
/* @brief Writes a message to the system syslog at the given severity level (Unix only).  Lua: ntop.syslog(level, msg) → nil */
static int ntop_syslog(lua_State* vm) {
  char* msg;
  int syslog_severity = LOG_INFO;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  msg = (char*)lua_tostring(vm, 1);
  if (lua_type(vm, 2) == LUA_TNUMBER)
    syslog_severity = (int)lua_tonumber(vm, 2);

  syslog(syslog_severity, "%s", msg);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

/**
 * @brief Get the random value associated to the user session to prevent CSRF
 * attacks
 * @details See https://owasp.org/www-community/attacks/csrf . ntopng uses
 * per-session tokens as explained in
 * https://www.sjoerdlangkemper.nl/2019/12/18/different-csrf-token-for-each-form
 */
/* @brief Returns the current CSRF token for use in forms and AJAX requests.  Lua: ntop.getRandomCSRFValue() → string */
static int ntop_get_csrf_value(lua_State* vm) {
  const char* csrf = getLuaVMUservalue(vm, csrf);

  if (!csrf) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, csrf);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the MD5 hex digest of the given string.  Lua: ntop.md5(data) → string */
static int ntop_md5(lua_State* vm) {
  char result[33];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  mg_md5(result, lua_tostring(vm, 1), NULL);

  lua_pushstring(vm, result);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if RADIUS authentication support is compiled in.  Lua: ntop.hasRadiusSupport() → boolean */
static int ntop_has_radius_support(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef HAVE_RADIUS
  lua_pushboolean(vm, true);
#else
  lua_pushboolean(vm, false);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Logs a RADIUS authentication event with user and result details.  Lua: ntop.logRadius(info_table) → nil */
static int ntop_log_radius(lua_State* vm) {
  bool logged = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef HAVE_RADIUS
  Radius* radius = ntop->getRadius();
  char *event_type, *message;

  if (radius) {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    event_type = (char*)lua_tostring(vm, 1);

    if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    message = (char*)lua_tostring(vm, 2);

    radius->logRadius(event_type, "%s", message);

    logged = true;
  }
#endif

  lua_pushboolean(vm, logged);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if LDAP authentication support is compiled in.  Lua: ntop.hasLdapSupport() → boolean */
static int ntop_has_ldap_support(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && defined(HAVE_LDAP) && !defined(HAVE_NEDGE)
  lua_pushboolean(vm, true);
#else
  lua_pushboolean(vm, false);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef UNUSED_CODE

struct ntopng_sqlite_state {
  lua_State* vm;
  u_int num_rows;
};

static int sqlite_callback(void* data, int argc, char** argv,
                           char** azColName) {
  struct ntopng_sqlite_state* s = (struct ntopng_sqlite_state*)data;

  lua_newtable(s->vm);

  for (int i = 0; i < argc; i++)
    lua_push_str_table_entry(s->vm, (const char*)azColName[i],
                             (char*)(argv[i] ? argv[i] : "NULL"));

  lua_pushinteger(s->vm, ++s->num_rows);
  lua_insert(s->vm, -2);
  lua_settable(s->vm, -3);

  return (0);
}

#endif

/* ****************************************** */

/**
 * @brief Insert a new minute sampling in the historical database
 * @details Given a certain sampling point, store statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Inserts a minute-granularity statistics sample for an interface into the historical DB.  Lua: ntop.insertMinuteSampling(ifid, json_data) → nil */
static int ntop_stats_insert_minute_sampling(lua_State* vm) {
  char* sampling;
  time_t rawtime;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((sampling = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  time(&rawtime);

  if (sm->insertMinuteSampling(rawtime, sampling))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Insert a new hour sampling in the historical database
 * @details Given a certain sampling point, store statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Inserts an hour-granularity statistics sample for an interface into the historical DB.  Lua: ntop.insertHourSampling(ifid, json_data) → nil */
static int ntop_stats_insert_hour_sampling(lua_State* vm) {
  char* sampling;
  time_t rawtime;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((sampling = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  time(&rawtime);
  rawtime -= (rawtime % 60);

  if (sm->insertHourSampling(rawtime, sampling))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Insert a new day sampling in the historical database
 * @details Given a certain sampling point, store statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Inserts a day-granularity statistics sample for an interface into the historical DB.  Lua: ntop.insertDaySampling(ifid, json_data) → nil */
static int ntop_stats_insert_day_sampling(lua_State* vm) {
  char* sampling;
  time_t rawtime;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((sampling = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  time(&rawtime);
  rawtime -= (rawtime % 60);

  if (sm->insertDaySampling(rawtime, sampling))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Get a minute sampling from the historical database
 * @details Given a certain sampling point, get statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Retrieves the minute statistics sample for an interface at a given epoch.  Lua: ntop.getMinuteSampling(ifid, epoch) → string */
static int ntop_stats_get_minute_sampling(lua_State* vm) {
  time_t epoch;
  string sampling;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch = (time_t)lua_tointeger(vm, 2);

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->getMinuteSampling(epoch, &sampling))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushstring(vm, sampling.c_str());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Delete minute stats older than a certain number of days.
 * @details Given a number of days, delete stats for the current interface that
 *          are older than a certain number of days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Purges minute-granularity statistics records older than the given number of days.  Lua: ntop.deleteMinuteStatsOlderThan(ifid, num_days) → nil */
static int ntop_stats_delete_minute_older_than(lua_State* vm) {
  int num_days;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_days = lua_tointeger(vm, 2);
  if (num_days < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->deleteMinuteStatsOlderThan(num_days))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Delete hour stats older than a certain number of days.
 * @details Given a number of days, delete stats for the current interface that
 *          are older than a certain number of days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Purges hour-granularity statistics records older than the given number of days.  Lua: ntop.deleteHourStatsOlderThan(ifid, num_days) → nil */
static int ntop_stats_delete_hour_older_than(lua_State* vm) {
  int num_days;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_days = lua_tointeger(vm, 2);
  if (num_days < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->deleteHourStatsOlderThan(num_days))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Delete day stats older than a certain number of days.
 * @details Given a number of days, delete stats for the current interface that
 *          are older than a certain number of days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Purges day-granularity statistics records older than the given number of days.  Lua: ntop.deleteDayStatsOlderThan(ifid, num_days) → nil */
static int ntop_stats_delete_day_older_than(lua_State* vm) {
  int num_days;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  num_days = lua_tointeger(vm, 2);
  if (num_days < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->deleteDayStatsOlderThan(num_days))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Get an interval of minute stats samplings from the historical database
 * @details Given a certain interval of sampling points, get statistics for said
 *          sampling points.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Returns minute statistics samples in the given epoch range.  Lua: ntop.getMinuteSamplingsInterval(ifid, from_epoch, to_epoch) → table */
static int ntop_stats_get_minute_samplings_interval(lua_State* vm) {
  time_t epoch_start, epoch_end;
  int ifid;
  NetworkInterface* iface;
  StatsManager* sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  ifid = lua_tointeger(vm, 1);
  if (ifid < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_start = lua_tointeger(vm, 2);
  if (epoch_start < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_end = lua_tointeger(vm, 3);
  if (epoch_end < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (!(iface = ntop->getInterfaceById(ifid)) ||
      !(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->retrieveMinuteStatsInterval(epoch_start, epoch_end, &retvals))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_newtable(vm);

  for (unsigned i = 0; i < retvals.rows.size(); i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Given an epoch, get minute stats for the latest n minutes
 * @details Given a certain sampling point, get statistics for that point and
 *          for all timepoints spanning an interval of a given number of
 *          minutes.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Returns all minute-granularity statistics samples starting from a given epoch.  Lua: ntop.getMinuteSamplingsFromEpoch(ifid, epoch) → table */
static int ntop_stats_get_samplings_of_minutes_from_epoch(lua_State* vm) {
  time_t epoch_start, epoch_end;
  NetworkInterface* iface = getCurrentInterface(vm);
  StatsManager* sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_end = lua_tointeger(vm, 1);
  /* Round at the closest hour */
  epoch_end -= (epoch_end % 60);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_start = lua_tointeger(vm, 2);
  /* Round at the closest hour */
  epoch_start -= (epoch_start % 60);

  if (!(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->retrieveMinuteStatsInterval(epoch_start, epoch_end, &retvals))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_newtable(vm);

  for (unsigned i = 0; i < retvals.rows.size(); i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Given an epoch, get hour stats for the latest n hours
 * @details Given a certain sampling point, get statistics for that point and
 *          for all timepoints spanning an interval of a given number of
 *          hours.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Returns all hour-granularity statistics samples starting from a given epoch.  Lua: ntop.getHourSamplingsFromEpoch(ifid, epoch) → table */
static int ntop_stats_get_samplings_of_hours_from_epoch(lua_State* vm) {
  time_t epoch_start, epoch_end;
  NetworkInterface* iface = getCurrentInterface(vm);
  StatsManager* sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_end = lua_tointeger(vm, 1);
  /* Round at the closest hour */
  epoch_end -= (epoch_end % 60);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_start = lua_tointeger(vm, 2);
  /* Round at the closest hour */
  epoch_start -= (epoch_start % 60);

  if (!(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->retrieveHourStatsInterval(epoch_start, epoch_end, &retvals))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_newtable(vm);

  for (unsigned i = 0; i < retvals.rows.size(); i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/**
 * @brief Given an epoch, get hour stats for the latest n days
 * @details Given a certain sampling point, get statistics for that point and
 *          for all timepoints spanning an interval of a given number of
 *          days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK
 * otherwise.
 */
/* @brief Returns all day-granularity statistics samples starting from a given epoch.  Lua: ntop.getDaySamplingsFromEpoch(ifid, epoch) → table */
static int ntop_stats_get_samplings_of_days_from_epoch(lua_State* vm) {
  time_t epoch_start, epoch_end;
  NetworkInterface* iface = getCurrentInterface(vm);
  StatsManager* sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_end = lua_tointeger(vm, 1);
  /* Round at the closest hour */
  epoch_end -= (epoch_end % 60);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  epoch_start = lua_tointeger(vm, 2);
  /* Round at the closest hour */
  epoch_start -= (epoch_start % 60);

  if (!(sm = iface->getStatsManager()))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (sm->retrieveDayStatsInterval(epoch_start, epoch_end, &retvals))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_newtable(vm);

  for (unsigned i = 0; i < retvals.rows.size(); i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/*
  Code partially taken from third-party/rrdtool-1.4.7/bindings/lua/rrdlua.c
  and made reentrant
*/

static void reset_rrd_state(void) {
  optind = 0;
  opterr = 0;
  rrd_clear_error();
}

/* ****************************************** */

static int ntop_rrd_get_lastupdate(const char* filename, time_t* last_update,
                                   unsigned long* ds_count) {
  char** ds_names;
  char** last_ds;
  unsigned long i;
  int status;

  reset_rrd_state();
  status =
      rrd_lastupdate_r(filename, last_update, ds_count, &ds_names, &last_ds);

  if (status != 0) {
    return (-1);
  } else {
    for (i = 0; i < *ds_count; i++) free(last_ds[i]), free(ds_names[i]);

    free(last_ds), free(ds_names);
    return (0);
  }
}

/* ****************************************** */

static bool ntop_delete_old_rrd_files_recursive(const char* dir_name,
                                                time_t now,
                                                int older_than_seconds) {
  struct dirent* result;
  int path_length;
  char path[MAX_PATH];
  DIR* d;
  time_t last_update;
  unsigned long ds_count;

  if (!dir_name || strlen(dir_name) > MAX_PATH) return false;

  d = opendir(dir_name);
  if (!d) return false;

  while ((result = readdir(d)) != NULL) {
    if (result->d_type & DT_REG) {
      if ((path_length = snprintf(path, MAX_PATH, "%s/%s", dir_name,
                                  result->d_name)) <= MAX_PATH) {
        ntop->fixPath(path);

        if (ntop_rrd_get_lastupdate(path, &last_update, &ds_count) == 0) {
          if ((now >= last_update) &&
              ((now - last_update) > older_than_seconds)) {
            // printf("DELETE %s\n", path);
            unlink(path);
          }
        }
      }
    } else if (result->d_type & DT_DIR) {
      if (strncmp(result->d_name, "..", 2) && strncmp(result->d_name, ".", 1)) {
        if ((path_length = snprintf(path, MAX_PATH, "%s/%s", dir_name,
                                    result->d_name)) <= MAX_PATH) {
          ntop->fixPath(path);

          ntop_delete_old_rrd_files_recursive(path, now, older_than_seconds);
        }
      }
    }
  }

  rmdir(dir_name); /* Remove the directory, if empty */
  closedir(d);

  return true;
}

/* ****************************************** */

/* @brief Removes stale/unused RRD files from the data directory.  Lua: ntop.deleteOldRRDs() → nil */
static int ntop_delete_old_rrd_files(lua_State* vm) {
  char path[PATH_MAX + 8];
  int older_than_seconds;
  time_t now = time(NULL);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  strncpy(path, lua_tostring(vm, 1), sizeof(path) - 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((older_than_seconds = lua_tointeger(vm, 2)) < 0)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ntop->fixPath(path);

  if (ntop_delete_old_rrd_files_recursive(path, now, older_than_seconds))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Creates a directory tree recursively, equivalent to 'mkdir -p'.  Lua: ntop.mkdir(path) → nil */
static int ntop_mkdir_tree(lua_State* vm) {
  char* dir;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushnil(vm);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((dir = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (dir[0] == '\0') {
    lua_pushboolean(vm, true);
    return (ntop_lua_return_value(vm, __FUNCTION__,
                                  CONST_LUA_OK)); /* Nothing to do */
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Trying to created directory %s",
                               dir);

  lua_pushboolean(vm, Utils::mkdir_tree(dir));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table listing available report files.  Lua: ntop.listReports() → table */
static int ntop_list_reports(lua_State* vm) {
  DIR* dir;
  char fullpath[MAX_PATH + 64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  snprintf(fullpath, sizeof(fullpath) - 1, "%s/%s", ntop->get_working_dir(),
           "reports");
  ntop->fixPath(fullpath);
  if ((dir = opendir(fullpath)) != NULL) {
    struct dirent* ent;

    while ((ent = readdir(dir)) != NULL) {
      char filepath[MAX_PATH + MAX_PATH + 64 + 1];
      struct stat buf;

      snprintf(filepath, sizeof(filepath), "%s/%s", fullpath, ent->d_name);
      ntop->fixPath(filepath);

      if (!stat(filepath, &buf) && !S_ISDIR(buf.st_mode))
        lua_push_str_table_entry(vm, ent->d_name, (char*)"");
    }
    closedir(dir);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns Redis connection status and server information.  Lua: ntop.getCacheStatus() → table */
static int ntop_info_redis(lua_State* vm) {
  char* rsp;
  u_int rsp_len = CONST_MAX_LEN_REDIS_VALUE;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  if ((rsp = (char*)malloc(rsp_len)) != NULL) {
    lua_push_str_table_entry(
        vm, "info", (redis->info(rsp, rsp_len) == 0) ? rsp : (char*)"");
    lua_push_uint64_table_entry(vm, "dbsize", redis->dbsize());
    free(rsp);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Retrieves a string value from Redis by key; returns nil if not found.  Lua: ntop.getCache(key) / ntop.getPref(key) → string */
static int ntop_get_redis(lua_State* vm) {
  char *key, *rsp = NULL;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  rsp = redis->getWithAlloc(key);

  if (rsp) {
    lua_pushfstring(vm, "%s", rsp);
    free(rsp);
  } else
    lua_pushfstring(vm, "");

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Atomically increments a Redis integer counter (default increment: 1).  Lua: ntop.incrCache(key[, increment]) → integer */
static int ntop_incr_redis(lua_State* vm) {
  char* key;
  u_int rsp;
  int amount = 1;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 2) == LUA_TNUMBER) amount = lua_tonumber(vm, 2);

  rsp = redis->incr(key, amount);

  lua_pushinteger(vm, rsp);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Retrieves a single field value from a Redis hash.  Lua: ntop.getHashCache(key, field) → string */
static int ntop_get_hash_redis(lua_State* vm) {
  char *key, *member, *rsp;
  Redis* redis = ntop->getRedis();
  u_int json_len;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((member = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  json_len = ntop->getRedis()->hstrlen(key, member);
  if (json_len == 0) {
#ifdef WIN32
    json_len = CONST_MAX_LEN_REDIS_VALUE;
#else
    /*
      We assume that redis is recent enough to return 0 when string is missing
      and not because it is an outdated value
    */
    lua_pushstring(vm, "");
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#endif
  } else
    json_len += 8; /* Little overhead */

  if ((rsp = (char*)malloc(json_len)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushfstring(
      vm, "%s",
      (redis->hashGet(key, member, rsp, json_len - 1) == 0) ? rsp : (char*)"");
  free(rsp);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sets a field value in a Redis hash.  Lua: ntop.setHashCache(key, field, value) → nil */
static int ntop_set_hash_redis(lua_State* vm) {
  char *key, *member, *value;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((member = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((value = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  redis->hashSet(key, member, value);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static void ntop_reset_host_name(lua_State* vm, char* address) {
  NetworkInterface* iface;
  char buf[64], *host_ip;
  Host* host;
  u_int16_t vlan_id;

  get_host_vlan_info(address, &host_ip, &vlan_id, buf, sizeof(buf));

  for (int i = 0; i < ntop->get_num_interfaces(); i++) {
    if ((iface = ntop->getInterface(i)) != NULL) {
      host = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id,
                                 getLuaVMUservalue(vm, observationPointId));
      if (host) host->requestNameReset();
    }
  }
}

/* ****************************************** */

/* @brief Caches a DNS reverse mapping for an IP address in Redis.  Lua: ntop.setResolvedAddress(ip, hostname) → nil */
static int ntop_set_resolved_address(lua_State* vm) {
  char *ip, *name;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((ip = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((name = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  redis->setResolvedAddress(ip, name);

  ntop_reset_host_name(vm, ip);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Deletes a field from a Redis hash.  Lua: ntop.delHashCache(key, field) → nil */
static int ntop_delete_hash_redis_key(lua_State* vm) {
  char *key, *member;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((member = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->getRedis()->hashDel(key, member);
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns all field names present in a Redis hash.  Lua: ntop.getHashKeysCache(key) → table */
static int ntop_get_hash_keys_redis(lua_State* vm) {
  char *key, **vals;
  Redis* redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  rc = redis->hashKeys(key, &vals);

  if (rc > 0) {
    lua_newtable(vm);

    for (int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, vals[i] ? vals[i] : "", (char*)"");
      if (vals[i]) free(vals[i]);
    }
    free(vals);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns all field-value pairs from a Redis hash as a Lua table.  Lua: ntop.getHashAllCache(key) → table */
static int ntop_get_hash_all_redis(lua_State* vm) {
  char *key, **keys, **values;
  Redis* redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  rc = redis->hashGetAll(key, &keys, &values);

  if (rc > 0) {
    lua_newtable(vm);

    for (int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, keys[i] ? keys[i] : (char*)"",
                               values[i] ? values[i] : (char*)"");
      if (values[i]) free(values[i]);
      if (keys[i]) free(keys[i]);
    }

    free(keys);
    free(values);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns all Redis keys matching the given glob pattern.  Lua: ntop.getKeysCache(pattern) → table */
static int ntop_get_keys_redis(lua_State* vm) {
  char *pattern, **keys = NULL;
  Redis* redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((pattern = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  rc = redis->keys(pattern, &keys);

  if (rc > 0) {
    lua_newtable(vm);

    for (int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, keys[i] ? keys[i] : "", (char*)"");
      if (keys[i]) free(keys[i]);
    }
  } else
    lua_pushnil(vm);

  if (keys) free(keys);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a range of elements from a Redis list (0-based indices).  Lua: ntop.lrangeCache(key, start, stop) → table */
static int ntop_lrange_redis(lua_State* vm) {
  char *l_name, **l_elements = NULL;
  Redis* redis = ntop->getRedis();
  int start_offset = 0, end_offset = -1;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((l_name = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 2) == LUA_TNUMBER) {
    start_offset = lua_tointeger(vm, 2);
  }
  if (lua_type(vm, 3) == LUA_TNUMBER) {
    end_offset = lua_tointeger(vm, 3);
  }

  rc = redis->lrange(l_name, &l_elements, start_offset, end_offset);

  if (rc > 0) {
    lua_newtable(vm);

    for (int i = 0; i < rc; i++) {
      lua_pushstring(vm, l_elements[i] ? l_elements[i] : "");
      lua_rawseti(vm, -2, i + 1);
      if (l_elements[i]) free(l_elements[i]);
    }
  } else
    lua_pushnil(vm);

  if (l_elements) free(l_elements);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the current length of a Redis list.  Lua: ntop.llenCache(key) → integer */
static int ntop_llen_redis(lua_State* vm) {
  char* l_name;
  Redis* redis = ntop->getRedis();
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!redis) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((l_name = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  lua_pushinteger(vm, redis->llen(l_name));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if a binary RDB dump is available for a Redis key.  Lua: ntop.hasDumpCache(key) → boolean */
static int ntop_redis_has_dump(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->getRedis()->hasRedisDump());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a binary serialization (RDB dump) of a Redis key's value.  Lua: ntop.dumpCache(key) → string */
static int ntop_redis_dump(lua_State* vm) {
  char *key, *dump;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!redis->hasRedisDump()) {
    lua_pushnil(vm); /* This is old redis */
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    if ((key = (char*)lua_tostring(vm, 1)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

    dump = redis->dump(key);

    if (dump) {
      lua_pushfstring(vm, "%s", dump);
      free(dump);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
    } else
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
}

/* ****************************************** */

/* @brief Restores a Redis key from a previously obtained binary RDB dump.  Lua: ntop.restoreCache(key, dump_data) → boolean */
static int ntop_redis_restore(lua_State* vm) {
  char *key, *dump;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!redis->hasRedisDump()) {
    lua_pushnil(vm); /* This is old redis */
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    if ((key = (char*)lua_tostring(vm, 1)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

    if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    if ((dump = (char*)lua_tostring(vm, 2)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

    lua_pushboolean(vm, (redis->restore(key, dump) != 0));
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }
}

/* ****************************************** */

/* @brief Returns the element at the given 0-based index in a Redis list.  Lua: ntop.listIndexCache(key, index) → string */
static int ntop_list_index_redis(lua_State* vm) {
  char *index_name, *rsp;
  Redis* redis = ntop->getRedis();
  int idx;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((index_name = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  idx = lua_tointeger(vm, 2);

  if ((rsp = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (redis->lindex(index_name, idx, rsp, CONST_MAX_LEN_REDIS_VALUE) != 0) {
    free(rsp);
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  lua_pushfstring(vm, "%s", rsp);
  free(rsp);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Internal helper implementing lpop/rpop; called by ntop_lpop_redis and ntop_rpop_redis.  Lua: (internal helper) → string */
static int ntop_lrpop_redis(lua_State* vm, bool lpop) {
  char msg[1024], *list_name;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((list_name = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if ((lpop ? redis->lpop(list_name, msg, sizeof(msg))
            : redis->rpop(list_name, msg, sizeof(msg))) == 0) {
    lua_pushfstring(vm, "%s", msg);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Pops and returns the leftmost (head) element from a Redis list.  Lua: ntop.lpopCache(key) → string */
static int ntop_lpop_redis(lua_State* vm) {
  return ntop_lrpop_redis(vm, true /* LPOP */);
}

/* ****************************************** */

/* @brief Pops and returns the rightmost (tail) element from a Redis list.  Lua: ntop.rpopCache(key) → string */
static int ntop_rpop_redis(lua_State* vm) {
  return ntop_lrpop_redis(vm, false /* RPOP */);
}

/* ****************************************** */

/* @brief Removes up to count matching elements from a Redis list.  Lua: ntop.lremCache(key, count, value) → nil */
static int ntop_lrem_redis(lua_State* vm) {
  char *list_name, *rem_value;
  int ret;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if ((list_name = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((rem_value = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ret = redis->lrem(list_name, rem_value);

  if (ret == 0)
    lua_pushboolean(vm, true);
  else
    lua_pushboolean(vm, false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Trims a Redis list to only the elements in the specified index range.  Lua: ntop.ltrimCache(key, start, stop) → nil */
static int ntop_ltrim_redis(lua_State* vm) {
  char* list_name;
  int start_idx, end_idx;
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((list_name = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  start_idx = lua_tonumber(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  end_idx = lua_tonumber(vm, 3);

  if (redis && redis->ltrim(list_name, start_idx, end_idx) == 0) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Internal helper implementing lpush/rpush used by ntop_lpush_redis and ntop_rpush_redis.  Lua: (internal helper) → nil */
static int ntop_push_redis(lua_State* vm, bool use_lpush) {
  char *list_name, *value;
  u_int list_trim_size = 0;  // default 0 = no trim
  Redis* redis = ntop->getRedis();
  int rv;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((list_name = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((value = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  /* Optional trim list up to the specified number of elements */
  if (lua_type(vm, 3) == LUA_TNUMBER)
    list_trim_size = (u_int)lua_tonumber(vm, 3);

  if (use_lpush)
    rv = redis->lpush(list_name, value, list_trim_size);
  else
    rv = redis->rpush(list_name, value, list_trim_size);

  if (rv == 0) {
    lua_pushnil(vm);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Pushes a value onto the left (head) of a Redis list.  Lua: ntop.lpushCache(key, value) → nil */
static int ntop_lpush_redis(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return ntop_push_redis(vm, true);
}

/* ****************************************** */

/* @brief Pushes a value onto the right (tail) of a Redis list.  Lua: ntop.rpushCache(key, value) → nil */
static int ntop_rpush_redis(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return ntop_push_redis(vm, false);
}

/* ****************************************** */

/* @brief Adds a CIDR network to the runtime list of local networks.  Lua: ntop.addLocalNetwork(cidr) → nil */
static int ntop_add_local_network(lua_State* vm) {
  char* local_network;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((local_network = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->addLocalNetworkList(local_network);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the configured alias for a local network CIDR, or nil.  Lua: ntop.getLocalNetworkAlias(cidr) → string */
static int ntop_check_local_network_alias(lua_State* vm) {
  u_int32_t network_id = (u_int32_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TSTRING) {
    char* local_network;

    if ((local_network = (char*)lua_tostring(vm, 1)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

    network_id = ntop->getLocalNetworkId(local_network);

  } else if (lua_type(vm, 1) == LUA_TNUMBER) {
    network_id = (u_int32_t)lua_tonumber(vm, 1);
  }

  if (network_id != (u_int32_t)-1) {
    if (!ntop->getLocalNetworkAlias(vm, network_id)) {
      lua_pushnil(vm);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the internal numeric id for a local network CIDR.  Lua: ntop.getLocalNetworkID(cidr) → integer */
static int ntop_get_local_network_id(lua_State* vm) {
  char* local_network;
  u_int32_t network_id = (u_int32_t)-1;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((local_network = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  network_id = ntop->getLocalNetworkId(local_network);

  lua_pushinteger(vm, network_id);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifndef HAVE_NEDGE
#ifdef NTOPNG_PRO
/* @brief Validates sub-interface configuration syntax (Pro, non-nEdge).  Lua: ntop.checkSubInterfaceSyntax(str) → boolean */
static int ntop_check_sub_interface_syntax(lua_State* vm) {
#ifdef HAVE_NBPF
  char* filter;
  NetworkInterface* curr_iface = getCurrentInterface(vm);
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

#ifdef HAVE_NBPF
  filter = (char*)lua_tostring(vm, 1);
#endif

  lua_pushboolean(vm,
#ifdef HAVE_NBPF
                  curr_iface ? curr_iface->checkSubInterfaceSyntax(filter) :
#endif
                             false);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif
#endif

/* ****************************************** */

#ifdef NTOPNG_PRO
/* @brief Validates a BPF-like filter expression syntax (Pro).  Lua: ntop.checkFilterSyntax(str) → boolean */
static int ntop_check_filter_syntax(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef HAVE_NEDGE
  lua_pushboolean(vm, true); /* TODO need to implement the logic */
#else

#ifdef HAVE_NBPF
  char* filter;
  NetworkInterface* curr_iface = getCurrentInterface(vm);
#endif

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

#ifdef HAVE_NBPF
  filter = (char*)lua_tostring(vm, 1);
#endif

  lua_pushboolean(vm,
#ifdef HAVE_NBPF
                  curr_iface ? curr_iface->checkFilterSyntax(filter) :
#endif
                             false);
#endif

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif

/* ****************************************** */

#ifndef HAVE_NEDGE
#ifdef NTOPNG_PRO
/* @brief Reloads traffic profiles from Redis configuration (Pro, non-nEdge).  Lua: ntop.reloadProfiles() → nil */
static int ntop_reload_traffic_profiles(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (curr_iface)
    curr_iface->updateFlowProfiles(); /* Reload profiles in memory */

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}
#endif
#endif

/* ****************************************** */

static int _ntop_set_redis(bool do_setnx, lua_State* vm) {
  char *key, *value, buf[21];
  u_int expire_secs = 0;  // default 0 = no expiration
  Redis* redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 2) == LUA_TSTRING) {
    if ((value = (char*)lua_tostring(vm, 2)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  } else if (lua_type(vm, 2) == LUA_TNUMBER) {
    u_int64_t v = (u_int64_t)lua_tonumber(vm, 2);

    snprintf(buf, sizeof(buf), "%llu", (unsigned long long)v);
    value = buf;
  } else if (lua_type(vm, 2) == LUA_TBOOLEAN) {
    bool v = (bool)lua_toboolean(vm, 2);

    snprintf(buf, sizeof(buf), "%s", v ? "true" : "false");
    value = buf;
  } else {
    lua_pushboolean(vm, false);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  /* Optional key expiration in SECONDS */
  if (lua_type(vm, 3) == LUA_TNUMBER) expire_secs = (u_int)lua_tonumber(vm, 3);

  if (do_setnx)
    lua_pushboolean(vm, (redis->setnx(key, value, expire_secs) ==
                         1 /* value added (not existing) */)
                            ? true
                            : false);
  else
    lua_pushboolean(vm, (redis->set(key, value, expire_secs) == 0));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sets a string value in Redis with optional TTL expiration.  Lua: ntop.setCache(key, value[, ttl_secs]) → nil */
static int ntop_set_redis(lua_State* vm) {
  return (_ntop_set_redis(false, vm));
}
/* @brief Sets a Redis key only if it does not already exist (atomic set-if-not-exists).  Lua: ntop.setnxCache(key, value) → boolean */
static int ntop_setnx_redis(lua_State* vm) {
  return (_ntop_set_redis(true, vm));
}

/* ****************************************** */

/* @brief Sets a system preference in Redis (alias for setCache with ntopng.prefs. prefix).  Lua: ntop.setPref(key, value) → nil */
static int ntop_set_preference(lua_State* vm) { return (ntop_set_redis(vm)); }

/* ****************************************** */

/* @brief Returns true if login authentication is globally disabled.  Lua: ntop.isLoginDisabled() → boolean */
static int ntop_is_login_disabled(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  bool ret = ntop->getPrefs()->is_localhost_users_login_disabled() ||
             !ntop->getPrefs()->is_users_login_enabled();

  lua_pushboolean(vm, ret);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if a username is temporarily blocked due to brute-force attempts.  Lua: ntop.isLoginBlacklisted(username) → boolean */
static int ntop_is_login_blacklisted(lua_State* vm) {
  struct mg_connection* conn;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if ((conn = getLuaVMUserdata(vm, conn)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushboolean(vm, ntop->isBlacklistedLogin(conn));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if GUI access is restricted to specific source IP addresses.  Lua: ntop.isGuiAccessRestricted() → boolean */
static int ntop_is_gui_access_restricted(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->get_HTTPserver()->is_gui_access_restricted());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Requests a ntopng service restart by writing a restart flag.  Lua: ntop.serviceRestart() → nil */
static int ntop_service_restart(lua_State* vm) {
#if defined(__linux__) && defined(NTOPNG_PRO)
  extern AfterShutdownAction afterShutdownAction;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if (!ntop->isUserAdministrator(vm))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (getppid() == 1 /* parent is systemd */) {
    /* See also ntop_shutdown (used by nEdge) */
    afterShutdownAction = after_shutdown_restart_self;
    ntop->getGlobals()->requestShutdown();
    lua_pushboolean(vm, true);
  }

  lua_pushboolean(vm, false);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#else
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
#endif
}

/* ****************************************** */

/* @brief Returns the observation point id assigned to a user.  Lua: ntop.getUserObservationPointId(username) → integer */
static int ntop_get_user_observation_point_id(lua_State* vm) {
  char* username;

  if ((username = getLuaVMUserdata(vm, user)) == NULL) {
    lua_pushboolean(vm, false);
  } else {
    char key[64], val[16];
    NetworkInterface* iface = getCurrentInterface(vm);
    bool rc = false;

    snprintf(key, sizeof(key), NTOPNG_PREFS_PREFIX ".%s.observationPointId",
             username);

    if (ntop->getRedis()->get(key, val, sizeof(val)) != -1) {
      u_int16_t observationPointId = (u_int16_t)atoi(val);

      if (iface->haveObservationPointsDefined()) {
        if (!iface->hasObservationPointId(observationPointId)) {
          observationPointId = iface->getFirstObservationPointId();
          snprintf(val, sizeof(val), "%u", observationPointId);
          ntop->getRedis()->set(key, val);
        }

        getLuaVMUservalue(vm, observationPointId) = observationPointId;
        rc = true;
        lua_pushinteger(vm, observationPointId);
      }
    }

    if (!rc) lua_pushinteger(vm, 0 /* No observation point */);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Sets the global log verbosity level (debug/normal/warning/error/quiet).  Lua: ntop.setLoggingLevel(level_str) → nil */
static int ntop_set_logging_level(lua_State* vm) {
  char* lvlStr;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if (ntop->getPrefs()->hasCmdlTraceLevel())
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lvlStr = (char*)lua_tostring(vm, 1);

  if (!strcmp(lvlStr, "trace"))
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_TRACE);
  else if (!strcmp(lvlStr, "debug"))
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_DEBUG);
  else if (!strcmp(lvlStr, "info"))
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_INFO);
  else if (!strcmp(lvlStr, "normal"))
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_NORMAL);
  else if (!strcmp(lvlStr, "warning"))
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_WARNING);
  else if (!strcmp(lvlStr, "error"))
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_ERROR);
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* NOTE: use lua traceError function */
/* @brief Logs a message at the specified trace level to the ntopng trace log.  Lua: ntop.traceEvent(level, msg) → nil */
static int ntop_trace_event(lua_State* vm) {
  char *msg, *fname;
  int level, line;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  level = lua_tointeger(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((fname = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  line = lua_tointeger(vm, 3);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  if ((msg = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->getTrace()->traceEvent(level, fname, line, "%s", msg);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Computes the network address (e.g. 192.168.1.0) from an IP and prefix length.  Lua: ntop.networkPrefix(ip, prefix_bits) → string */
static int ntop_network_prefix(lua_State* vm) {
  char* address;
  char buf[64];
  u_int8_t mask;
  IpAddress ip;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((address = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  mask = (int)lua_tonumber(vm, 2);

  ip.set(address);
  lua_pushstring(vm, ip.print(buf, sizeof(buf), mask));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static const char** make_argv(lua_State* vm, int* argc_out, u_int offset,
                              int extra_args) {
  const char** argv;
  int i;
  int argc = lua_gettop(vm) + 1 - offset + extra_args;

  if (!(argv = (const char**)calloc(argc, sizeof(char*))))
    /* raise an error and never return */
    luaL_error(vm, "Can't allocate memory for arguments array");

  /* fprintf(stderr, "%s\n", argv[0]); */
  for (i = 0; i < argc; i++) {
    if (i < extra_args) {
      argv[i] = ""; /* put an empty extra argument */
    } else {
      int idx = (i - extra_args) + offset;

      /* accepts string or number */
      if (lua_isstring(vm, idx) || lua_isnumber(vm, idx)) {
        if (!(argv[i] = (char*)lua_tostring(vm, idx))) {
          /* raise an error and never return */
          luaL_error(vm, "Error duplicating string area for arg #%d", i);
        }
        // printf("@%u: %s\n", i, argv[i]);
      } else {
        /* raise an error and never return */
        luaL_error(vm, "Invalid arg #%d: args must be strings or numbers", i);
      }
    }

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%d] %s", i, argv[i]);
  }

  *argc_out = argc;
  return (argv);
}

/* ****************************************** */

/* @brief Creates a new RRD file with specified data sources and round-robin archives.  Lua: ntop.rrd_create(path, step, start, ...) → nil */
static int ntop_rrd_create(lua_State* vm) {
  const char* filename;
  unsigned long pdp_step;
  const char** argv;
  int argc, status, offset = 3;
  time_t start_time = time(NULL) - 86400 /* 1 day */;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((filename = (const char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  pdp_step = (unsigned long)lua_tonumber(vm, 2);

  if (lua_type(vm, 3) == LUA_TNUMBER) {
    start_time = (time_t)lua_tonumber(vm, 3);
    offset++;
  }

  if (Utils::file_exists(filename))
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "Overwriting already existing RRD [%s]", filename);

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  argv = make_argv(vm, &argc, offset, 0);

  reset_rrd_state();
  status = rrd_create_r(filename, pdp_step, start_time, argc, argv);
  free(argv);

  if (status != 0) {
    char* err = rrd_get_error();

    if (err != NULL) {
      char error_buf[256];
      snprintf(error_buf, sizeof(error_buf), "Unable to create %s [%s]",
               filename, err);

      lua_pushstring(vm, error_buf);
    } else
      lua_pushstring(vm, "Unknown RRD error");
  } else {
    lua_pushnil(vm);
    chmod(filename, CONST_DEFAULT_FILE_MODE);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Appends a new timestamped data point to an existing RRD file.  Lua: ntop.rrd_update(path, timestamp, ...) → nil */
static int ntop_rrd_update(lua_State* vm) {
  NtopngLuaContext* ctx = getLuaVMContext(vm);
  const char *filename, *when = NULL, *v1 = NULL, *v2 = NULL, *v3 = NULL,
                        *v4 = NULL, *v5 = NULL, *v6 = NULL;
  int status;
  ticks ticks_duration;
  struct stat s;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((filename = (const char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (stat(filename, &s) != 0) {
    char error_buf[256];

    snprintf(error_buf, sizeof(error_buf), "File %s does not exist", filename);
    lua_pushstring(vm, error_buf);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  // Delete empty rrd files which cause an mmap error
  if (s.st_size == 0) {
    char error_buf[256];

    snprintf(error_buf, sizeof(error_buf), "Empty RRD: %s, deleting it\n",
             filename);
    lua_pushstring(vm, error_buf);

    unlink(filename);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  if (lua_type(vm, 2) == LUA_TSTRING) {
    if ((when = (const char*)lua_tostring(vm, 2)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  } else if (lua_type(vm, 2) != LUA_TNIL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (lua_type(vm, 3) == LUA_TSTRING) v1 = (const char*)lua_tostring(vm, 3);
  if (lua_type(vm, 4) == LUA_TSTRING) v2 = (const char*)lua_tostring(vm, 4);
  if (lua_type(vm, 5) == LUA_TSTRING) v3 = (const char*)lua_tostring(vm, 5);
  if (lua_type(vm, 6) == LUA_TSTRING) v4 = (const char*)lua_tostring(vm, 6);
  if (lua_type(vm, 6) == LUA_TSTRING) v5 = (const char*)lua_tostring(vm, 7);
  if (lua_type(vm, 6) == LUA_TSTRING) v6 = (const char*)lua_tostring(vm, 8);

  /* Apparently RRD does not like static buffers, so we need to malloc */
  u_int buf_len = 64;
  char* buf = (char*)malloc(buf_len);

  if (buf) {
    snprintf(buf, buf_len, "%s:%s%s%s%s%s%s%s%s%s%s%s", when ? when : "N", v1,
             v2 ? ":" : "", v2 ? v2 : "", v3 ? ":" : "", v3 ? v3 : "",
             v4 ? ":" : "", v4 ? v4 : "", v5 ? ":" : "", v5 ? v5 : "",
             v6 ? ":" : "", v6 ? v6 : "");

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%s) %s", __FUNCTION__,
    // filename, buf);

    ticks_duration = Utils::getticks();
    reset_rrd_state();
    status = rrd_update_r(filename, NULL, 1, (const char**)&buf);
    ticks_duration = Utils::getticks() - ticks_duration;

    if (ctx && ctx->threaded_activity_stats)
      ctx->threaded_activity_stats->updateTimeseriesWriteStats(ticks_duration);

    if (status != 0) {
      char* err = rrd_get_error();

      if (err != NULL) {
        char error_buf[256];

        snprintf(error_buf, sizeof(error_buf),
                 "rrd_update_r() [%s][%s] failed [%s]", filename, buf, err);
        lua_pushstring(vm, error_buf);
      } else
        lua_pushstring(vm, "Unknown RRD error");
    } else
      lua_pushnil(vm);

    free(buf);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Returns the Unix timestamp of the last update recorded in an RRD file.  Lua: ntop.rrd_lastupdate(path) → integer */
static int ntop_rrd_lastupdate(lua_State* vm) {
  const char* filename;
  time_t last_update;
  unsigned long ds_count;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((filename = (const char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  reset_rrd_state();

  if (ntop_rrd_get_lastupdate(filename, &last_update, &ds_count) == -1) {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  } else {
    lua_pushinteger(vm, last_update);
    lua_pushinteger(vm, ds_count);
    return (2 /* 2 values returned */);
  }
}

/* ****************************************** */

/* @brief Modifies parameters (heartbeat, min/max values) of an existing RRD file.  Lua: ntop.rrd_tune(path, ...) → nil */
static int ntop_rrd_tune(lua_State* vm) {
  const char* filename;
  const char** argv;
  int argc, status, offset = 1;
  int extra_args = 1; /* Program name arg */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  argv = make_argv(vm, &argc, offset, extra_args);

  if (argc < 2) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "ntop_rrd_tune: invalid number of arguments");
    free(argv);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
  filename = argv[1];

  reset_rrd_state();
  status = rrd_tune(
      argc, (std::conditional<
                std::is_same<decltype(rrd_tune), int(int, const char**)>::value,
                const char**, char**>::type)argv);

  if (status != 0) {
    char* err = rrd_get_error();

    if (err != NULL) {
      char error_buf[256];

      snprintf(error_buf, sizeof(error_buf),
               "Unable to run rrd_tune on %s [%s]", filename, err);

      lua_pushstring(vm, error_buf);
    } else
      lua_pushstring(vm, "Unknown RRD error");
  } else
    lua_pushnil(vm);

  free(argv);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Increments the packet drop counter in an interface RRD file.  Lua: ntop.rrd_inc_num_drops(path) → nil */
static int ntop_rrd_inc_num_drops(lua_State* vm) {
  NtopngLuaContext* ctx = getLuaVMContext(vm);
  u_long num_drops = 1;

  if (lua_type(vm, 1) == LUA_TNUMBER) num_drops = lua_tonumber(vm, 1);

  if (ctx && ctx->threaded_activity_stats)
    ctx->threaded_activity_stats->incTimeseriesWriteDrops(num_drops);

  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns statistics about the packet drop pool (packets dropped vs configured limit).  Lua: ntop.getDropPoolInfo() → table */
static int ntop_get_drop_pool_info(lua_State* vm) {
  lua_newtable(vm);

  lua_push_str_table_entry(vm, "pool_name", DROP_HOST_POOL_NAME);
  lua_push_str_table_entry(vm, "list_key", DROP_HOST_POOL_LIST);
  lua_push_uint64_table_entry(vm, "expiration_time",
                              DROP_HOST_POOL_EXPIRATION_TIME);

  return CONST_LUA_OK;
}

/* ****************************************** */

/* @brief Returns true if ntopng was forced offline via command-line flag.  Lua: ntop.isForcedOffline() → boolean */
static int ntop_is_forced_offline(lua_State* vm) {
  lua_pushboolean(vm, ntop->isForcedOffline());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is currently in offline mode.  Lua: ntop.isOffline() → boolean */
static int ntop_is_offline(lua_State* vm) {
  lua_pushboolean(vm, ntop->isOffline());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Puts ntopng into offline mode (disables outbound connectivity features).  Lua: ntop.setOffline() → nil */
static int ntop_set_offline(lua_State* vm) {
  ntop->toggleOffline(true);
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Updates stored RADIUS login state and session information for a user.  Lua: ntop.updateRadiusLoginInfo(info_table) → nil */
static int ntop_update_radius_login_info(lua_State* vm) {
#ifdef HAVE_RADIUS
  ntop->updateRadiusLoginInfo();

  lua_pushnil(vm);

  ntop->getTrace()->traceEvent(TRACE_INFO,
                               "Radius: updated radius login informations");
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
#else
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
#endif
}

/* ****************************************** */

/* @brief Takes ntopng out of offline mode, re-enabling outbound connectivity.  Lua: ntop.setOnline() → nil */
static int ntop_set_online(lua_State* vm) {
  ntop->toggleOffline(false);
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns true if ntopng is in the process of shutting down.  Lua: ntop.isShuttingDown() → boolean */
static int ntop_is_shutting_down(lua_State* vm) {
  lua_pushboolean(vm, ntop->getGlobals()->isShutdown());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Voluntarily throttles CPU usage of the current Lua thread to avoid overloading.  Lua: ntop.limitResourcesUsage() → nil */
static int ntop_limit_resources_usage(lua_State* vm) {
  lua_pushboolean(vm, ntop->getPrefs()->limitResourcesUsage());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* positional 1:4 parameters for ntop_rrd_fetch */
/* @brief Internal helper that parses and validates RRD argument lists from the Lua stack.  Lua: (internal RRD helper) → nil */
static int __ntop_rrd_args(lua_State* vm, char** filename, char** cf,
                           time_t* start, time_t* end) {
  char *start_s, *end_s, *err;
  rrd_time_value_t start_tv, end_tv;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((*filename = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((*cf = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if ((lua_type(vm, 3) == LUA_TNUMBER) && (lua_type(vm, 4) == LUA_TNUMBER))
    *start = (time_t)lua_tonumber(vm, 3), *end = (time_t)lua_tonumber(vm, 4);
  else {
    if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    if ((start_s = (char*)lua_tostring(vm, 3)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

    if ((err = rrd_parsetime(start_s, &start_tv)) != NULL) {
      lua_pushstring(vm, err);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    }

    if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    if ((end_s = (char*)lua_tostring(vm, 4)) == NULL)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

    if ((err = rrd_parsetime(end_s, &end_tv)) != NULL) {
      lua_pushstring(vm, err);
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
    }

    if (rrd_proc_start_end(&start_tv, &end_tv, start, end) == -1)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Internal helper that checks RRD operation status and pushes error/ok to Lua.  Lua: (internal RRD helper) → nil */
static int __ntop_rrd_status(lua_State* vm, int status, char* filename,
                             char* cf) {
  char* err;

  if (status != 0) {
    err = rrd_get_error();

    if (err != NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Error '%s' while calling rrd_fetch_r(%s, "
                                   "%s): is the RRD corrupted perhaps?",
                                   err, filename, cf);

      if (strstr(err, "fetching cdp from rra") != NULL)
        unlink(filename); /* 99,99999% this is a corrupted file */

      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    }
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* Fetches data from RRD by rows */
/* @brief Fetches consolidated data from an RRD file for the given time range.  Lua: ntop.rrd_fetch(path, cf, start, stop[, step]) → table */
static int ntop_rrd_fetch(lua_State* vm) {
  unsigned long i, j, step = 0, ds_cnt = 0;
  rrd_value_t *data, *p;
  char** names;
  char *filename, *cf;
  time_t t, start, end;
#if 0
  time_t last_update;
  unsigned long ds_count;
#endif
  int status;

  reset_rrd_state();

  if ((status = __ntop_rrd_args(vm, &filename, &cf, &start, &end)) !=
      CONST_LUA_OK) {
    return status;
  }

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  if ((status = __ntop_rrd_status(vm,
                                  rrd_fetch_r(filename, cf, &start, &end, &step,
                                              &ds_cnt, &names, &data),
                                  filename, cf)) != CONST_LUA_OK)
    return status;

  lua_pushinteger(vm, (lua_Integer)start);
  lua_pushinteger(vm, (lua_Integer)step);
  /* fprintf(stderr, "%lu, %lu, %lu, %lu\n", start, end, step, num_points); */

  /* create the ds names array */
  lua_newtable(vm);
  for (i = 0; i < ds_cnt; i++) {
    lua_pushstring(vm, names[i]);
    lua_rawseti(vm, -2, i + 1);
    rrd_freemem(names[i]);
  }
  rrd_freemem(names);

  /* create the data points array */
  lua_newtable(vm);
  p = data;
  for (t = start + 1, i = 0; t < end; t += step, i++) {
#if 0
    bool add_point;

    /* Check for avoid going after the last point set */
    if(t > last_update) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "Skipping %u / %u", t, last_update);
      break;
    }

    if((t == last_update) && (i > 3)) {
      /* Add the point only if not zero an dwith at least 3 points or more */

      add_point = false;

      for(j=0; j<ds_cnt; j++) {
	rrd_value_t value = *p++;

	if(value != DNAN /* Skip NaN */) {
	  if(value > 0) {
	    add_point = true;
	    break;
	  }
	}
      }

      add_point = true;
    } else
      add_point = true;

    if(add_point) {
#endif
    lua_newtable(vm);

    for (j = 0; j < ds_cnt; j++) {
      rrd_value_t value = *p++;

      if (value != DNAN /* Skip NaN */) {
        lua_pushnumber(vm, (lua_Number)value);
        lua_rawseti(vm, -2, j + 1);
        // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u / %.f", t, value);
      }
    }

    lua_rawseti(vm, -2, i + 1);
#if 0
    } else
      break;
#endif
  }

  rrd_freemem(data);

  /* return the end as the last value */
  lua_pushinteger(vm, (lua_Integer)end);

  /* number of return values: start, step, names, data, end */
  return (5);
}

/* ****************************************** */

/*
 * Similar to ntop_rrd_fetch, but data series oriented  (reads RRD by columns)
 *
 * Positional parameters:
 *    filename: RRD file path
 *    cf: RRD cf
 *    start: the start time you wish to query
 *    end: the end time you wish to query
 *
 * Positional return values:
 *    start: the time of the first data in the series
 *     step: the fetched data step
 *     data: a table, where each key is an RRD name, and the value is its series
 * data end: the time of the last data in each series npoints: the number of
 * points in each series
 */
/* @brief Fetches RRD data in column-oriented format (one array per data source).  Lua: ntop.rrd_fetch_columns(path, cf, start, stop[, step]) → table */
static int ntop_rrd_fetch_columns(lua_State* vm) {
  char *filename, *cf;
  time_t start, end;
  int status;
  unsigned int npoints = 0, i, j;
  char** names;
  unsigned long step = 0, ds_cnt = 0;
  rrd_value_t *data, *p;

  reset_rrd_state();

  if ((status = __ntop_rrd_args(vm, &filename, &cf, &start, &end)) !=
      CONST_LUA_OK) {
    return status;
  }

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  if ((status = __ntop_rrd_status(vm,
                                  rrd_fetch_r(filename, cf, &start, &end, &step,
                                              &ds_cnt, &names, &data),
                                  filename, cf)) != CONST_LUA_OK) {
    return status;
  }

  npoints = (end - start) / step;

  lua_pushinteger(vm, (lua_Integer)start);
  lua_pushinteger(vm, (lua_Integer)step);

  /* create the data series table */
  lua_createtable(vm, 0, ds_cnt);

  for (i = 0; i < ds_cnt; i++) {
    /* a single series table, preallocated */
    lua_createtable(vm, npoints, 0);
    p = data + i;

    for (j = 0; j < npoints; j++) {
      rrd_value_t value = *p;
      /* we are accessing data table by columns */
      p = p + ds_cnt;
      lua_pushnumber(vm, (lua_Number)value);
      lua_rawseti(vm, -2, j + 1);
    }

    /* add the single series to the series table */
    lua_setfield(vm, -2, names[i]);
  } /* for */

  /* end and npoints as last values */
  lua_pushinteger(vm, (lua_Integer)end);
  lua_pushinteger(vm, (lua_Integer)npoints);

  lua_createtable(vm, 0, ds_cnt);
  for (i = 0; i < ds_cnt; i++) {
    lua_pushstring(vm, names[i]);
    lua_rawseti(vm, -2, i + 1);
    rrd_freemem(names[i]);
  }

  rrd_freemem(names);
  rrd_freemem(data);

  /* number of return values */
  return (6);
}

/* ****************************************** */

/* @brief Returns the network CIDR or alias for the given local network id.  Lua: ntop.getNetworkNameById(id) → string */
static int ntop_network_name_by_id(lua_State* vm) {
  int id;
  const char* name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  id = (u_int32_t)lua_tonumber(vm, 1);

  name = ntop->getLocalNetworkName(id);

  lua_pushstring(vm, name ? name : "");

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the internal numeric id for a local network given its CIDR or alias.  Lua: ntop.getNetworkIdByName(name) → integer */
static int ntop_network_id_by_name(lua_State* vm) {
  u_int32_t num_local_networks = ntop->getNumLocalNetworks();
  int found_id = -1;
  char* name;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  name = (char*)lua_tostring(vm, 1);

  for (u_int32_t network_id = 0; network_id < num_local_networks;
       network_id++) {
    if (!strcmp(ntop->getLocalNetworkName(network_id), name)) {
      found_id = network_id;
      break;
    }
  }

  lua_pushinteger(vm, found_id);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns a table of all configured local networks with their ids and CIDRs.  Lua: ntop.getNetworks() → table */
static int ntop_get_networks(lua_State* vm) {
  u_int32_t num_local_networks = ntop->getNumLocalNetworks();

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  for (u_int32_t network_id = 0; network_id < num_local_networks; network_id++)
    lua_push_uint64_table_entry(vm, ntop->getLocalNetworkName(network_id),
                                network_id);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Dequeues and returns pending internal alert events from the engine.  Lua: ntop.popInternalAlerts() → table */
static int ntop_pop_internal_alerts(lua_State* vm) {
  ndpi_serializer* alert = ntop->getInternalAlertsQueue()->dequeue();

  if (alert) {
    lua_newtable(vm);
    Utils::tlv2lua(vm, alert);

    ndpi_term_serializer(alert);
    free(alert);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Enqueues a JSON notification string to the specified recipient channel.  Lua: ntop.recipient_enqueue(recipient_id, notification_json) → nil */
static int ntop_recipient_enqueue(lua_State* vm) {
  NtopngLuaContext* ctx = getLuaVMContext(vm);
  u_int16_t recipient_id;
  const char* alert;
  bool rv = false;
  AlertFifoItem* notification;
  u_int16_t alert_id = 0;
  u_int32_t score = 0;
  AlertCategory alert_category = alert_category_other;
  AlertEntity alert_entity = alert_entity_other;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  recipient_id = lua_tointeger(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  alert = lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  score = lua_tonumber(vm, 3);

  if (lua_type(vm, 4) == LUA_TNUMBER) alert_id = lua_tonumber(vm, 4);

  if (lua_type(vm, 5) == LUA_TNUMBER)
    alert_entity = (AlertEntity)lua_tonumber(vm, 5);

  if (lua_type(vm, 6) == LUA_TNUMBER)
    alert_category = (AlertCategory)lua_tonumber(vm, 6);

  notification = new AlertFifoItem();

  if (notification) {
    notification->alert = alert;
    notification->score = score;
    notification->alert_severity = Utils::mapScoreToSeverity(score);
    notification->alert_id = alert_id;
    notification->alert_entity = alert_entity;
    notification->alert_category = alert_category;
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enqueing alert: %s", alert);
    rv = ntop->recipient_enqueue(recipient_id, notification);
  }

  if (!rv) {
    NetworkInterface* iface = getCurrentInterface(vm);

    if (iface) {
      iface->incNumDroppedAlerts(alert_entity_other);

      if (ctx->threaded_activity_stats)
        ctx->threaded_activity_stats->setAlertsDrops();
    }

    delete notification;
  }

  lua_pushboolean(vm, rv);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Dequeues and returns the next pending notification from a recipient channel.  Lua: ntop.recipient_dequeue(recipient_id) → string */
static int ntop_recipient_dequeue(lua_State* vm) {
  u_int16_t recipient_id;
  AlertFifoItem* notification;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  recipient_id = lua_tointeger(vm, 1);

  notification = ntop->recipient_dequeue(recipient_id);

  if (notification) {
    lua_newtable(vm);

    lua_push_str_table_entry(vm, "alert", notification->alert.c_str());
    lua_push_uint64_table_entry(vm, "score", notification->score);
    lua_push_uint64_table_entry(vm, "alert_severity",
                                notification->alert_severity);

    delete notification;
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns queue length and throughput statistics for all recipient channels.  Lua: ntop.recipient_stats() → table */
static int ntop_recipient_stats(lua_State* vm) {
  u_int16_t recipient_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  recipient_id = lua_tointeger(vm, 1);

  ntop->recipient_stats(recipient_id, vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Increments a named performance counter for a recipient channel.  Lua: ntop.recipient_inc_stats(recipient_id, stat_name) → nil */
static int ntop_recipient_inc_stats(lua_State* vm) {
  u_int16_t recipient_id;
  u_int64_t delivered = 0;
  u_int64_t filtered_out = 0;
  u_int64_t delivery_failures = 0;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  recipient_id = lua_tointeger(vm, 1);

  if (lua_type(vm, 2) == LUA_TNUMBER) delivered = lua_tonumber(vm, 2);

  if (lua_type(vm, 3) == LUA_TNUMBER) filtered_out = lua_tonumber(vm, 3);

  if (lua_type(vm, 4) == LUA_TNUMBER) delivery_failures = lua_tonumber(vm, 4);

  ntop->inc_recipient_stats(recipient_id, delivered, filtered_out,
                            delivery_failures);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the Unix epoch when the recipient queue was last dequeued.  Lua: ntop.recipient_last_use(recipient_id) → integer */
static int ntop_recipient_last_use(lua_State* vm) {
  u_int16_t recipient_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  recipient_id = lua_tointeger(vm, 1);

  lua_pushinteger(vm, ntop->recipient_last_use(recipient_id));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Unregisters and removes a recipient notification channel.  Lua: ntop.recipient_delete(recipient_id) → nil */
static int ntop_recipient_delete(lua_State* vm) {
  u_int16_t recipient_id;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  recipient_id = lua_tointeger(vm, 1);

  ntop->recipient_delete(recipient_id);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Registers a new recipient channel for alert notification delivery.  Lua: ntop.recipient_register(recipient_id) → nil */
static int ntop_recipient_register(lua_State* vm) {
  u_int16_t recipient_id;
  AlertLevel minimum_severity = alert_level_none;
  char *str_categories, *str_host_pools, *str_entities, *str_flow_alert_types,
      *str_host_alert_types, *str_other_alert_types;
  bool match_alert_id = false, skip_alerts = false;
  Bitmap128 enabled_categories, enabled_entities, enabled_flow_alert_types,
      enabled_host_alert_types, enabled_other_alert_types;
  Bitmap4096 enabled_host_pools;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  recipient_id = lua_tointeger(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  minimum_severity = (AlertLevel)lua_tointeger(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((str_categories = (char*)lua_tostring(vm, 3)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  enabled_categories.setBits(str_categories);

  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((str_host_pools = (char*)lua_tostring(vm, 4)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  enabled_host_pools.setBits(str_host_pools);

  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((str_entities = (char*)lua_tostring(vm, 5)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  enabled_entities.setBits(str_entities);

  if ((lua_type(vm, 6) == LUA_TSTRING) &&
      ((str_flow_alert_types = (char*)lua_tostring(vm, 6)) != NULL)) {
    enabled_flow_alert_types.reset();
    enabled_flow_alert_types.setBits(str_flow_alert_types);
    match_alert_id = true; /* Match by ID (ignore severity, category, etc) */
  }

  if ((lua_type(vm, 7) == LUA_TSTRING) &&
      ((str_host_alert_types = (char*)lua_tostring(vm, 7)) != NULL)) {
    enabled_host_alert_types.reset();
    enabled_host_alert_types.setBits(str_host_alert_types);
    match_alert_id = true; /* Match by ID (ignore severity, category, etc) */
  }

  if ((lua_type(vm, 8) == LUA_TSTRING) &&
      ((str_other_alert_types = (char*)lua_tostring(vm, 8)) != NULL)) {
    enabled_other_alert_types.reset();
    enabled_other_alert_types.setBits(str_other_alert_types);
    match_alert_id = true; /* Match by ID (ignore severity, category, etc) */
  }

  if (lua_type(vm, 9) == LUA_TBOOLEAN) skip_alerts = (bool)lua_toboolean(vm, 9);

  /*
  char bitmap_buf[64];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Skip alerts: %s", skip_alerts ?
  "true" : "false"); ntop->getTrace()->traceEvent(TRACE_NORMAL, "Recipient ID =
  %u", recipient_id); ntop->getTrace()->traceEvent(TRACE_NORMAL, "Categories
  bitmap: %s", enabled_categories.toHexString(bitmap_buf, sizeof(bitmap_buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Hosts bitmap: %s",
  enabled_host_pools.toHexString(bitmap_buf, sizeof(bitmap_buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Entities bitmap: %s",
  enabled_entities.toHexString(bitmap_buf, sizeof(bitmap_buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow alert types bitmap: %s",
  enabled_flow_alert_types.toHexString(bitmap_buf, sizeof(bitmap_buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Host alert types bitmap: %s",
  enabled_host_alert_types.toHexString(bitmap_buf, sizeof(bitmap_buf)));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Other alert types bitmap: %s",
  enabled_other_alert_types.toHexString(bitmap_buf, sizeof(bitmap_buf)));
  */

  ntop->recipient_register(
      recipient_id, minimum_severity, enabled_categories, enabled_host_pools,
      enabled_entities, enabled_flow_alert_types, enabled_host_alert_types,
      enabled_other_alert_types, match_alert_id, skip_alerts);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Returns true if the given nDPI protocol id is a user-defined custom application.  Lua: ntop.isCustomApplication(proto_id) → boolean */
static int ndpi_is_custom_application(lua_State* vm) {
  u_int16_t app_id;
  NetworkInterface* iface = getCurrentInterface(vm);

  if ((iface == NULL) ||
      (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  app_id = (u_int16_t)lua_tonumber(vm, 1);

  lua_pushboolean(vm, iface->isCustomDPIProtocol(app_id));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Executes a shell command synchronously and returns its stdout output.  Lua: ntop.execCmd(cmd) → string */
static int ntop_exec_cmd(lua_State* vm) {
  char* cmd;
  std::string out;
  bool rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((cmd = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  rc = Utils::execCmd(cmd, &out);

  if (rc) lua_pushstring(vm, out.c_str());

  return (ntop_lua_return_value(vm, __FUNCTION__,
                                rc ? CONST_LUA_OK : CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Starts a shell command asynchronously and returns a result handle.  Lua: ntop.execCmdAsync(cmd) → integer */
static int ntop_exec_cmd_async(lua_State* vm) {
  char* cmd;
  u_int32_t id;
  bool rc;
  JobQueue* jq = ntop->getJobsQueue();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  if ((cmd = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  rc = jq->queueJob(cmd, &id);

  if (rc)
    lua_pushnumber(vm, (lua_Number)id);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__,
                                rc ? CONST_LUA_OK : CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Reads and returns available stdout from an async command handle.  Lua: ntop.readResultCmdAsync(handle) → string */
static int ntop_read_result_cmd_async(lua_State* vm) {
  u_int32_t id;
  bool rc;
  JobQueue* jq = ntop->getJobsQueue();
  std::string out;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  else
    id = (u_int32_t)lua_tonumber(vm, 1);

  rc = jq->getJobResult(id, &out);

  if (rc)
    lua_pushstring(vm, out.c_str());
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__,
                                rc ? CONST_LUA_OK : CONST_LUA_ERROR));
}

/* ****************************************** */

/* @brief Reloads device-to-protocol policy rules from Redis configuration.  Lua: ntop.reloadDeviceProtocols() → nil */
static int ntop_reload_device_protocols(lua_State* vm) {
  DeviceType device_type = device_unknown;
  char* dir; /* client or server */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TTABLE) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  device_type = (DeviceType)lua_tointeger(vm, 1);
  if ((dir = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ntop->refreshAllowedProtocolPresets(device_type, !!strcmp(dir, "server"), vm,
                                      3);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the ASN organization name for a given IP address via GeoIP.  Lua: ntop.getASName(ip) → string */
static int ntop_get_asn_name(lua_State* vm) {
  IpAddress a;
  char* as_name;
  u_int32_t asn = 0;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  a.set((char*)lua_tostring(vm, 1));

  ntop->getGeolocation()->getAS(&a, &asn, &as_name);

  if (as_name != NULL) {
    lua_pushstring(vm, as_name);
    free(as_name);
  }

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the organization name for a given autonomous system number.  Lua: ntop.getASNameFromASN(asn_number) → string */
static int ntop_get_as_name_from_asn(lua_State* vm) {
  u_int32_t asn;
  char as_name[128];

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  else
    asn = (u_int32_t)lua_tonumber(vm, 1);

  if (ntop->getGeolocation()->getASName(asn, as_name, sizeof(as_name)))
    lua_pushstring(vm, as_name);
  else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns geolocation data (country, city, lat, lon) for an IP via GeoIP.  Lua: ntop.getHostGeolocation(ip) → table */
static int ntop_get_host_geolocation(lua_State* vm) {
  IpAddress ip;
  char *continent = NULL, *country_name = NULL, *city = NULL;
  float latitude = 0, longitude = 0;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));

  ip.set((char*)lua_tostring(vm, 1));

  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city,
                                  &latitude, &longitude);

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "continent", continent ? continent : (char*)"");
  lua_push_str_table_entry(vm, "country",
                           country_name ? country_name : (char*)"");
  lua_push_float_table_entry(vm, "latitude", latitude);
  lua_push_float_table_entry(vm, "longitude", longitude);
  lua_push_str_table_entry(vm, "city", city ? city : (char*)"");

  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Returns the nDPI category id assigned to a protocol id.  Lua: ntop.getnDPIProtoCategory(proto_id) → integer */
static int ntop_get_ndpi_protocol_category(lua_State* vm) {
  NetworkInterface* curr_iface = getCurrentInterface(vm);
  u_int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!curr_iface)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto = (u_int)lua_tonumber(vm, 1);

  ndpi_protocol_category_t category = ntop->get_ndpi_proto_category(proto);

  lua_newtable(vm);
  lua_push_int32_table_entry(vm, "id", category);
  lua_push_str_table_entry(vm, "name",
                           (char*)curr_iface->get_ndpi_category_name(category));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Overrides the nDPI category assignment for a protocol id.  Lua: ntop.setnDPIProtoCategory(proto_id, category_id) → nil */
static int ntop_set_ndpi_protocol_category(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  u_int16_t proto;
  ndpi_protocol_category_t category;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  proto = (u_int16_t)lua_tonumber(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  category = (ndpi_protocol_category_t)lua_tointeger(vm, 2);

  ntop->setnDPIProtocolCategory(proto, category);

  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* Replace the interfaces configured with -i with the provided one */
/* @brief Overrides the current network interface context (Appliance builds only).  Lua: ntop.overrideInterface(ifname) → nil */
static int ntop_override_interface(lua_State* vm) {
  char* ifname;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  ifname = (char*)lua_tostring(vm, 1);

  ntop->getPrefs()->resetDeferredInterfacesToRegister();
  ntop->getPrefs()->addDeferredInterfaceToRegister(ifname);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

#ifdef HAVE_NEDGE

/* @brief Registers an interface as a LAN interface (nEdge only).  Lua: ntop.addLanInterface(ifname) → nil */
static int ntop_add_lan_interface(lua_State* vm) {
  char* lan_ifname;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  lan_ifname = (char*)lua_tostring(vm, 1);

  ntop->getPrefs()->add_lan_interface(lan_ifname);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Registers an interface as a WAN interface (nEdge only).  Lua: ntop.addWanInterface(ifname) → nil */
static int ntop_add_wan_interface(lua_State* vm) {
  char* lan_ifname;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  lan_ifname = (char*)lua_tostring(vm, 1);

  ntop->getPrefs()->add_wan_interface(lan_ifname);

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

/* @brief Refreshes device-protocol policy configuration from preferences (nEdge only).  Lua: ntop.refreshDeviceProtocolsPoliciesConf() → nil */
static int ntop_refresh_device_protocols_policies_pref(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getPrefs()->refreshDeviceProtocolsPolicyPref();

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

#endif

/* **************************************************************** */

/* @brief Adds a weighted data point to a named bin for similarity analysis.  Lua: ntop.addBin(name, value, weight) → nil */
static int ntop_add_bin(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NtopngLuaContext* ctx = getLuaVMContext(vm);

  if (ctx) {
    if (ctx->bin == NULL) ctx->bin = new (std::nothrow) BinAnalysis();

    if (ctx->bin) return (ctx->bin->addBin(vm));
  }
#endif

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Finds and returns bins similar to the named bin by Euclidean distance.  Lua: ntop.findSimilarities(name) → table */
static int ntop_find_bin_similarities(lua_State* vm) {
#if defined(NTOPNG_PRO)
  NtopngLuaContext* ctx = getLuaVMContext(vm);

  if (ctx && ctx->bin) {
    return (ctx->bin->findSimilarities(vm));
  }
#endif

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Returns true if nProbe IPS is configured and active.  Lua: ntop.isNProbeIPSConfigured() → boolean */
static int ntop_check_nprobe_ips_configured(lua_State* vm) {
  lua_pushboolean(vm,
                  (ntop->getPrefs()->getZMQPublishEventsURL() ? true : false));

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Acquires the global pools write lock (must be paired with poolsUnlock).  Lua: ntop.poolsLock() → nil */
static int ntop_pools_lock(lua_State* vm) {
  u_int max_lock_duration;
  struct timespec wait;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  max_lock_duration = lua_tonumber(vm, 1);

  if (max_lock_duration > 10) max_lock_duration = 10;

  wait.tv_sec = max_lock_duration, wait.tv_nsec = 0;
  lua_pushboolean(
      vm, ntop->get_pools_lock()->lockTimeout(__FILE__, __LINE__, &wait));
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Releases the global pools write lock acquired by poolsLock.  Lua: ntop.poolsUnlock() → nil */
static int ntop_pools_unlock(lua_State* vm) {
  ntop->get_pools_lock()->unlock(__FILE__, __LINE__);
  lua_pushboolean(vm, true);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Enables or disables debug tracing of C++ new/delete memory allocation calls.  Lua: ntop.toggleNewDeleteTrace(enabled) → nil */
static int ntop_toggle_new_delete_trace(lua_State* vm) {
  trace_new_delete = !trace_new_delete;
  lua_pushboolean(vm, trace_new_delete);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Returns the internal InfluxDB database name used by ntopng.  Lua: ntop.getInfluxDBInternalDBName() → string */
static int ntop_get_influxdb_internal_db_name(lua_State* vm) {
  lua_pushstring(vm, ntop->getPrefs()->get_influx_internal_db_name());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Sets the internal InfluxDB database name used by ntopng.  Lua: ntop.setInfluxDBInternalDBName(name) → nil */
static int ntop_set_influxdb_internal_db_name(lua_State* vm) {
  char* influx_internal_db;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  influx_internal_db = (char*)lua_tostring(vm, 1);

  if (influx_internal_db && influx_internal_db[0] != '\0') {
    ntop->getPrefs()->set_influx_internal_db_name(influx_internal_db);
  }
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Returns true if the internal InfluxDB instance is ready and available.  Lua: ntop.isInfluxDBInternalAvailable() → boolean */
static int ntop_get_influxdb_internal_available(lua_State* vm) {
  lua_pushboolean(vm, ntop->getPrefs()->get_influx_internal_available());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Sets the availability flag for the internal InfluxDB instance.  Lua: ntop.setInfluxDBInternalAvailable(available) → nil */
static int ntop_set_influxdb_internal_available(lua_State* vm) {
  bool influx_internal_db_available;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  influx_internal_db_available = (bool)lua_toboolean(vm, 1);

  ntop->getPrefs()->set_influx_internal_available(influx_internal_db_available);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Returns the capacity limits imposed by the current license (max hosts, flows, etc.).  Lua: ntop.getLicenseLimits() → table */
static int ntop_get_license_limits(lua_State* vm) {
  u_int32_t num_hosts = 0, num_local_hosts = 0, num_flows = 0;

  for (int i = 0; i < ntop->get_num_interfaces(); i++) {
    NetworkInterface* curr_iface = ntop->getInterface(i);

    if (curr_iface) {
      u_int32_t hosts = curr_iface->getNumHosts();
      u_int32_t local_hosts = curr_iface->getNumLocalHosts();
      u_int32_t rxonly_local_hosts = curr_iface->getNumLocalRxOnlyHosts();
      if (local_hosts >= rxonly_local_hosts)  // Safety check
        local_hosts -=
            rxonly_local_hosts;  // Do not consider non-existing hosts

      if (!curr_iface->isView()) num_flows += curr_iface->getNumFlows();

      num_hosts += hosts;
      num_local_hosts += local_hosts;
    }
  }

  lua_newtable(vm);

  lua_newtable(vm);
  lua_push_uint32_table_entry(vm, "num_flow_exporters",
                              ntop->getNumFlowExporters());
  lua_push_uint32_table_entry(vm, "num_flow_exporter_interfaces",
                              ntop->getNumFlowExportersInterfaces());
  lua_push_uint32_table_entry(vm, "num_host_pools", ntop->getNumberHostPools());
  lua_push_uint32_table_entry(vm, "num_pool_members",
                              ntop->getNumberHostPoolsMembers());
  lua_push_uint32_table_entry(vm, "num_profiles", ntop->getNumberProfiles());
  lua_push_uint32_table_entry(vm, "num_hosts", num_hosts);
  lua_push_uint32_table_entry(vm, "num_local_hosts", num_local_hosts);
  lua_push_uint32_table_entry(vm, "num_flows", num_flows);
  lua_pushstring(vm, "current");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
#ifdef NTOPNG_PRO
  lua_push_uint32_table_entry(vm, "num_flow_exporters",
                              get_max_num_flow_exporters());
  lua_push_uint32_table_entry(vm, "num_flow_exporter_interfaces",
                              get_max_num_flow_exporters_interfaces());
  lua_push_uint32_table_entry(vm, "num_profiles", MAX_NUM_PROFILES);
#endif
  lua_push_uint32_table_entry(vm, "num_host_pools", MAX_NUM_HOST_POOLS);
  lua_push_uint32_table_entry(vm, "num_pool_members", MAX_NUM_POOL_MEMBERS);
  lua_push_uint32_table_entry(vm, "num_hosts", 0 /* no limit */);
  lua_push_uint32_table_entry(vm, "num_local_hosts", MAX_NUM_ACTIVE_HOSTS);
  lua_push_uint32_table_entry(vm, "num_flows", MAX_NUM_ACTIVE_FLOWS);
  lua_pushstring(vm, "max");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

#if defined(NTOPNG_PRO)

/* **************************************************************** */

/* @brief Publishes a message to the internal message broker topic (Pro only).  Lua: ntop.publish(topic, message) → nil */
static int m_broker_publish(lua_State* vm) {
  char *topic, *message;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  topic = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  message = (char*)lua_tostring(vm, 2);

  MessageBroker* message_broker = ntop->getMessageBroker();
  if (!message_broker)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (message_broker->publish(topic, message))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}

/* **************************************************************** */

/* @brief Performs a synchronous RPC call via the internal message broker (Pro only).  Lua: ntop.rpcCall(topic, request) → string */
static int m_broker_rpc_call(lua_State* vm) {
  char *topic, *message, rsp[BROKER_RPC_CALL_MAX_RSP_LEN];
  u_int64_t timeout_ms;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  topic = (char*)lua_tostring(vm, 1);

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  message = (char*)lua_tostring(vm, 2);

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    timeout_ms = BROKER_RPC_CALL_DEFAULT_TIMEOUT_MS;
  else
    timeout_ms = (u_int64_t)lua_tonumber(vm, 3);

  MessageBroker* message_broker = ntop->getMessageBroker();

  if (!message_broker)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (message_broker->rpcCall(topic, message, timeout_ms, (char*)rsp,
                              BROKER_RPC_CALL_MAX_RSP_LEN)) {
    lua_newtable(vm);
    lua_push_str_table_entry(vm, "broker_rsp", rsp);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  } else {
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  }
}

#endif /* defined(NTOPNG_PRO) */

/* **************************************************************** */

/* @brief Queries a Modbus/TCP device for its identification information.  Lua: ntop.readModbusDeviceInfo(host, port) → table */
static int read_modbus_device_info(lua_State* vm) {
  char* device_ip;
  int timeout = 5;
  bool rc;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  else
    device_ip = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TNUMBER) timeout = (u_int16_t)lua_tonumber(vm, 2);

  rc = Utils::readModbusDeviceInfo(device_ip, timeout, vm);

  if (rc == false) {
    lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Queries an EtherNet/IP device for its identification information.  Lua: ntop.readEthernetIPDeviceInfo(host, port) → table */
static int read_ether_ip_device_info(lua_State* vm) {
  char* device_ip;
  int timeout = 5;
  bool rc;

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_PARAM_ERROR));
  else
    device_ip = (char*)lua_tostring(vm, 1);

  if (lua_type(vm, 2) == LUA_TNUMBER) timeout = (u_int16_t)lua_tonumber(vm, 2);

  rc = Utils::readEthernetIPDeviceInfo(device_ip, timeout, vm);

  if (rc == false) {
    lua_pushnil(vm);

    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
  } else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Reloads server configuration from Redis (DNS, NTP, DHCP server settings).  Lua: ntop.reloadServersConfiguration() → nil */
static int reload_servers_configuration(lua_State* vm) {
  ntop->getPrefs()->reloadServersConfiguration();
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Reloads custom ASN-to-name mappings from Redis configuration.  Lua: ntop.reloadASNConfiguration() → nil */
static int reload_asn_configuration(lua_State* vm) {
  ntop->reloadASNConfiguration();
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

#ifdef NTOPNG_PRO

/* @brief Reloads networks policy configuration from Redis (Pro only).  Lua: ntop.reloadNetworksPolicyConfiguration() → nil */
static int reload_networks_policy_configuration(lua_State* vm) {
  if (ntop->getPrefs()->reloadNetworksPolicyConfiguration()) {
    lua_pushboolean(vm, 1);
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
  }

  lua_pushboolean(vm, 0);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
}
#endif

/* **************************************************************** */

/* @brief Retrieves a value from the in-process Lua cache shared across all VMs.  Lua: ntop.getLuaCache(key) → any */
static int ntop_get_lua_cache(lua_State* vm) {
  std::string ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  ret = ntop->getLuaCache(std::string((char*)lua_tostring(vm, 1)));

  lua_pushstring(vm, ret.c_str());
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Stores a value in the in-process Lua cache with optional TTL seconds.  Lua: ntop.setLuaCache(key, value[, ttl_secs]) → nil */
static int ntop_set_lua_cache(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  if (lua_type(vm, 2) == LUA_TSTRING)
    ntop->setLuaCache(std::string((char*)lua_tostring(vm, 1)),
                      std::string((char*)lua_tostring(vm, 2)));
  else if (lua_type(vm, 2) == LUA_TNUMBER)
    ntop->setLuaCache(std::string((char*)lua_tostring(vm, 1)),
                      std::to_string(lua_tonumber(vm, 2)));
  else
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

/* @brief Returns all entries in the in-process Lua cache (debug/inspection).  Lua: ntop.dumpLuaCache() → table */
static int ntop_dump_lua_cache(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  ntop->dumpLuaCache(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static luaL_Reg _ntop_reg[] = {
    {"getDirs", ntop_get_dirs},
    {"getInfo", ntop_get_info},
    {"getUptime", ntop_get_uptime},
    {"dumpFile", ntop_dump_file},
    {"dumpBinaryFile", ntop_dump_binary_file},
    {"checkLicense", ntop_check_license},
    {"systemHostStat", ntop_system_host_stat},
    {"threadsInfo", ntop_threads_info},
    {"getSystemAlertsStats", ntop_get_system_alerts_stats},
    {"refreshCPULoad", ntop_refresh_cpu_load},
    {"getCookieAttributes", ntop_get_cookie_attributes},
    {"isAllowedInterface", ntop_is_allowed_interface},
    {"isAllowedNetwork", ntop_is_allowed_network},
    {"isLocalInterfaceAddress", ntop_is_local_interface_address},
    {"isLocalAddress", ntop_is_local_address},
    {"md5", ntop_md5},
    {"hasRadiusSupport", ntop_has_radius_support},
    {"logRadius", ntop_log_radius},
    {"hasLdapSupport", ntop_has_ldap_support},
    {"resetStats", ntop_reset_stats},
    {"getCurrentScriptsDir", ntop_get_current_scripts_dir},
    {"getDropPoolInfo", ntop_get_drop_pool_info},
    {"isOffline", ntop_is_offline},
    {"isForcedOffline", ntop_is_forced_offline},
    {"setOffline", ntop_set_offline},
    {"setOnline", ntop_set_online},
    {"isShuttingDown", ntop_is_shutting_down},
    {"limitResourcesUsage", ntop_limit_resources_usage},
    {"getAllPaths", ntop_get_all_paths},

    /* Assets Inventory */
    {"enableAssetsLog", ntop_enable_assets_log},
    {"assetsEnabled", ntop_assets_enabled},

    /* Execute commands */
    {"execCmd", ntop_exec_cmd},
    {"execCmdAsync", ntop_exec_cmd_async},
    {"readResultCmdAsync", ntop_read_result_cmd_async},

    /* Redis */
    {"getCacheStatus", ntop_info_redis},
    {"getCache", ntop_get_redis},
    {"setCache", ntop_set_redis},
    {"setnxCache", ntop_setnx_redis},
    {"incrCache", ntop_incr_redis},
    {"getCacheStats", ntop_get_redis_stats},
    {"delCache", ntop_delete_redis_key},
    {"renameCache", ntop_rename_redis_key},
    {"flushCache", ntop_flush_redis},
    {"listIndexCache", ntop_list_index_redis},
    {"lpushCache", ntop_lpush_redis},
    {"rpushCache", ntop_rpush_redis},
    {"lpopCache", ntop_lpop_redis},
    {"rpopCache", ntop_rpop_redis},
    {"lremCache", ntop_lrem_redis},
    {"ltrimCache", ntop_ltrim_redis},
    {"lrangeCache", ntop_lrange_redis},
    {"llenCache", ntop_llen_redis},
    {"setMembersCache", ntop_add_set_member_redis},
    {"delMembersCache", ntop_del_set_member_redis},
    {"getMembersCache", ntop_get_set_members_redis},
    {"getHashCache", ntop_get_hash_redis},
    {"setHashCache", ntop_set_hash_redis},
    {"delHashCache", ntop_delete_hash_redis_key},
    {"getHashKeysCache", ntop_get_hash_keys_redis},
    {"getHashAllCache", ntop_get_hash_all_redis},
    {"getKeysCache", ntop_get_keys_redis},
    {"hasDumpCache", ntop_redis_has_dump},
    {"dumpCache", ntop_redis_dump},
    {"restoreCache", ntop_redis_restore},
    {"addLocalNetwork", ntop_add_local_network},
    {"setResolvedAddress", ntop_set_resolved_address},

    /* Redis Preferences */
    {"setPref", ntop_set_preference},
    {"getPref", ntop_get_redis},

    {"isdir", ntop_is_dir},
    {"mkdir", ntop_mkdir_tree},
    {"notEmptyFile", ntop_is_not_empty_file},
    {"exists", ntop_get_file_dir_exists},
    {"listReports", ntop_list_reports},
    {"fileLastChange", ntop_get_file_last_change},
    {"readdir", ntop_list_dir_files},
    {"rmdir", ntop_remove_dir_recursively},
    {"unlink", ntop_unlink_file},

    {"isNProbeIPSConfigured", ntop_check_nprobe_ips_configured},

#ifndef HAVE_NEDGE
#ifdef HAVE_ZMQ
    {"zmq_connect", ntop_zmq_connect},
    {"zmq_disconnect", ntop_zmq_disconnect},
    {"zmq_receive", ntop_zmq_receive},
#endif

    /* IPS */
    {"broadcastIPSMessage", ntop_brodcast_ips_message},
    {"timeToRefreshIPSRules", ntop_time_to_refresh_ips_rules},
    {"askToRefreshIPSRules", ntop_ask_to_refresh_ips_rules},
#endif

    {"reloadPreferences", ntop_reload_preferences},
    {"setDefaultFilePermissions", ntop_set_default_file_permissions},

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    {"checkSubInterfaceSyntax", ntop_check_sub_interface_syntax},
    {"reloadProfiles", ntop_reload_traffic_profiles},
#endif
    {"checkFilterSyntax", ntop_check_filter_syntax},
#endif

    {"isForcedCommunity", ntop_is_forced_community},
    {"isPro", ntop_is_pro},
    {"isEnterprise", ntop_is_enterprise_m},
    {"isEnterpriseM", ntop_is_enterprise_m},
    {"isEnterpriseL", ntop_is_enterprise_l},
    {"isEnterpriseXL", ntop_is_enterprise_xl},
    {"isEnterpriseXXL", ntop_is_enterprise_xxl},
    {"isnEdge", ntop_is_nedge},
    {"isnEdgeEnterprise", ntop_is_nedge_enterprise},
    {"isPackage", ntop_is_package},
    {"isAppliance", ntop_is_appliance},
    {"isIoTBridge", ntop_is_iot_bridge},

    /* Historical database */
    {"insertMinuteSampling", ntop_stats_insert_minute_sampling},
    {"insertHourSampling", ntop_stats_insert_hour_sampling},
    {"insertDaySampling", ntop_stats_insert_day_sampling},
    {"getMinuteSampling", ntop_stats_get_minute_sampling},
    {"deleteMinuteStatsOlderThan", ntop_stats_delete_minute_older_than},
    {"deleteHourStatsOlderThan", ntop_stats_delete_hour_older_than},
    {"deleteDayStatsOlderThan", ntop_stats_delete_day_older_than},
    {"getMinuteSamplingsFromEpoch",
     ntop_stats_get_samplings_of_minutes_from_epoch},
    {"getHourSamplingsFromEpoch", ntop_stats_get_samplings_of_hours_from_epoch},
    {"getDaySamplingsFromEpoch", ntop_stats_get_samplings_of_days_from_epoch},
    {"getMinuteSamplingsInterval", ntop_stats_get_minute_samplings_interval},

    {"deleteOldRRDs", ntop_delete_old_rrd_files},

    /* Time */
    {"gettimemsec", ntop_gettimemsec},
    {"tzset", ntop_tzset},
    {"roundTime", ntop_round_time},

    /* Ticks */
    {"getticks", ntop_getticks},
    {"gettickspersec", ntop_gettickspersec},

    /* UDP */
    {"send_udp_data", ntop_send_udp_data},

    /* TCP */
    {"send_tcp_data", ntop_send_tcp_data},

    /* IP */
    {"ipToNumber", ntop_ip_to_number},
    {"inet_ntoa", ntop_inet_ntoa},
    {"networkPrefix", ntop_network_prefix},

    /* RRD */
    {"rrd_create", ntop_rrd_create},
    {"rrd_update", ntop_rrd_update},
    {"rrd_fetch", ntop_rrd_fetch},
    {"rrd_fetch_columns", ntop_rrd_fetch_columns},
    {"rrd_lastupdate", ntop_rrd_lastupdate},
    {"rrd_tune", ntop_rrd_tune},
    {"rrd_inc_num_drops", ntop_rrd_inc_num_drops},

    /* Prefs */
    {"getPrefs", ntop_get_prefs},

    /* Ping */
    {"isPingAvailable", ntop_is_ping_available},
    {"isPingIfaceAvailable", ntop_is_ping_iface_available},
    {"pingHost", ntop_ping_host},
    {"collectPingResults", ntop_collect_ping_results},
    {"getPingIfNames", ntop_get_ping_interface_names},

    /* HTTP utils */
    {"httpRedirect", ntop_http_redirect},
    {"getHttpPrefix", ntop_http_get_prefix},
    {"getStartupEpoch", ntop_http_get_startup_epoch},
    {"getStaticFileEpoch", ntop_http_get_static_file_epoch},
    {"httpPurifyParam", ntop_http_purify_param},

    /* Admin */
    {"getNologinUser", ntop_get_nologin_username},
    {"getUsers", ntop_get_users},
    {"isAdministrator", ntop_is_administrator},
    {"isPcapDownloadAllowed", ntop_is_pcap_download_allowed},
    {"getAllowedNetworks", ntop_get_allowed_networks},
    {"resetUserPassword", ntop_reset_user_password},
    {"changeUserRole", ntop_change_user_role},
    {"changeAllowedNets", ntop_change_allowed_nets},
    {"changeAllowedIfname", ntop_change_allowed_ifname},
    {"changeUserHostPool", ntop_change_user_host_pool},
    {"changeAllowedHostPools", ntop_change_user_allowed_host_pools},
    {"getAllowedHostPools", ntop_get_allowed_host_pools},
    {"changeUserFullName", ntop_change_user_full_name},
    {"changeUserLanguage", ntop_change_user_language},
    {"changePcapDownloadPermission", ntop_change_user_pcap_download_permission},
    {"changeHistoricalFlowPermission",
     ntop_change_user_historical_flow_permission},
    {"changeAlertsPermission", ntop_change_user_alerts_permission},
    {"addUser", ntop_add_user},
    {"deleteUser", ntop_delete_user},
    {"createUserSession", ntop_create_user_session},
    {"createUserAPIToken", ntop_create_user_api_token},
    {"getUserAPIToken", ntop_get_user_api_token},
    {"isLoginDisabled", ntop_is_login_disabled},
    {"isLoginBlacklisted", ntop_is_login_blacklisted},

    /* MFA/TOTP */
    {"generateTOTPSecret", ntop_generate_totp_secret},
    {"setUserTOTPSecret", ntop_set_user_totp_secret},
    {"getUserTOTPSecret", ntop_get_user_totp_secret},
    {"isTOTPEnabled", ntop_is_totp_enabled},
    {"setUserTOTPEnabled", ntop_set_user_totp_enabled},
    {"validateTOTP", ntop_validate_totp},
    {"getTOTPProvisioningUri", ntop_get_totp_provisioning_uri},

    /* WebAuthn/Passkey */
    {"generateWebAuthnRegistrationOptions", ntop_generate_webauthn_registration_options},
    {"completeWebAuthnRegistration", ntop_complete_webauthn_registration},
    {"getWebAuthnCredentials", ntop_get_webauthn_credentials},
    {"deleteWebAuthnCredential", ntop_delete_webauthn_credential},
    {"isWebAuthnEnabled", ntop_is_webauthn_enabled},
    {"getWebAuthnPendingToken", ntop_get_webauthn_pending_token},

    {"getNetworkNameById", ntop_network_name_by_id},
    {"getNetworkIdByName", ntop_network_id_by_name},
    {"getNetworks", ntop_get_networks},
    {"getAddressNetwork", ntop_get_address_network},
    {"isGuiAccessRestricted", ntop_is_gui_access_restricted},
    {"serviceRestart", ntop_service_restart},
    {"getUserObservationPointId", ntop_get_user_observation_point_id},
    {"updateRadiusLoginInfo", ntop_update_radius_login_info},

    /* Security */
    {"getRandomCSRFValue", ntop_get_csrf_value},

    /* HTTP */
    {"httpGet", ntop_http_get},
    {"httpGetAuthToken", ntop_http_get_auth_token},
    {"httpPost", ntop_http_post},
    {"httpPostAuthToken", ntop_http_post_auth_token},
    {"httpPutAuthToken", ntop_http_put_auth_token},
    {"httpPatchAuthToken", ntop_http_patch_auth_token},
    {"httpFetch", ntop_http_fetch},
    {"postHTTPJsonData", ntop_post_http_json_data},
    {"postHTTPTextFile", ntop_post_http_text_file},

#ifdef HAVE_CURL_SMTP
    /* SMTP */
    {"sendMail", ntop_send_mail},
#endif

    /* Address Resolution */
    {"resolveName",
     ntop_resolve_address}, /* Note: you should use resolveAddress() to call
                              from Lua */
    {"getResolvedName",
     ntop_get_resolved_address}, /* Note: you should use getResolvedAddress() to
                                   call from Lua */
    {"resolveHost", ntop_resolve_host},

/* Logging */
#ifndef WIN32
    {"syslog", ntop_syslog},
#endif
    {"setLoggingLevel", ntop_set_logging_level},
    {"traceEvent", ntop_trace_event},
    {"verboseTrace", ntop_verbose_trace},

    /* SNMP */
    {"snmpSetFatMibPollingMode", ntop_snmp_set_fat_mib_polling_mode},
    {"snmpv3available", ntop_is_libsnmp_available},
    {"snmpsetavailable", ntop_is_libsnmp_available},
    {"snmpgetbulkavailable", ntop_is_libsnmp_available},
    {"snmpMaxNumEngines", ntop_snmp_max_num_engines},
    {"snmpSetBulkMaxNumRepetitions", ntop_snmp_set_bulk_max_repetitions},
    {"snmpToggleTrapCollection", ntop_snmp_toggle_trap_collection},

    /* Synchronous */
    {"snmpget", ntop_snmpget},
    {"snmpgetnext", ntop_snmpgetnext},
    {"snmpgetnextbulk", ntop_snmpgetnextbulk},
    {"snmpset", ntop_snmpset},

    /* Asynchronous */
    {"snmpallocasnyncengine", ntop_allocasnyncengine},
    {"snmpfreeasnycengine", ntop_freeasnyncengine},
    {"snmpgetasync", ntop_snmpgetasync},
    {"snmpgetnextasync", ntop_snmpgetnextasync},
    {"snmpgetnextbulkasync", ntop_snmpgetnextbulkasync},
    {"snmpreadasyncrsp", ntop_snmpreadasyncrsp},

    /* Batch */
    {"snmpGetBatch", ntop_snmp_batch_get}, /* v1/v2c/v3 */
    {"snmpReadResponses", ntop_snmp_read_responses},

#if defined(NTOPNG_PRO)
    /* SNMP Interfaces */
    {"snmpSetInterfaceRole", ntop_snmp_set_interface_role},
    {"activateSnmpInterfaceRoles", ntop_activate_snmp_interface_roles},
#endif

    /* Runtime */
    {"hasGeoIP", ntop_has_geoip},
    {"isWindows", ntop_is_windows},
    {"isFreeBSD", ntop_is_freebsd},
    {"isLinux", ntop_is_linux},
    {"elasticsearchConnection", ntop_elasticsearch_connection},
    {"getInstanceName", ntop_get_instance_name},

    /* Custom Categories, Malicious fingerprints
     * Note: only inteded to be called from housekeeping.lua */
    {"initnDPIReload", ntop_initnDPIReload},
    {"finalizenDPIReload", ntop_finalizenDPIReload},
    {"loadCustomCategoryIp", ntop_loadCustomCategoryIp},
    {"loadCustomCategoryHost", ntop_loadCustomCategoryHost},
    {"loadCustomCategoryFile", ntop_loadCustomCategoryFile},
    {"setDomainMask", ntop_setDomainMask},
    {"addTrustedIssuerDN", ntop_addTrustedIssuerDN},

    /* Privileges */
    {"gainWriteCapabilities", ntop_gainWriteCapabilities},
    {"dropWriteCapabilities", ntop_dropWriteCapabilities},

    /* Misc */
    {"getservbyport", ntop_getservbyport},
    {"msleep", ntop_msleep},
    {"tcpProbe", ntop_tcp_probe},
    {"getMacManufacturer", ntop_get_mac_manufacturer},
    {"getHostInformation", ntop_get_host_information},
    {"isShuttingDown", ntop_is_shuttingdown},
    {"listInterfaces", ntop_list_interfaces},
    {"ipCmp", ntop_ip_cmp},
    {"matchCustomCategory", ntop_match_custom_category},
    {"getTLSVersionName", ntop_get_tls_version_name},
    {"isIPv6", ntop_is_ipv6},
    {"getMac64", ntop_get_mac_64},
    {"decodeMac64", ntop_decode_mac_64},
    {"reloadFlowChecks", ntop_reload_flow_checks},
    {"reloadHostChecks", ntop_reload_host_checks},
    {"reloadAlertExclusions", ntop_reload_alert_exclusions},
    {"getFlowChecksStats", ntop_get_flow_checks_stats},
    {"getFlowAlertScore", ntop_get_flow_alert_score},
    {"getFlowAlertRisk", ntop_get_flow_alert_risk},
    {"getFlowRiskAlerts", ntop_get_flow_risk_alerts},
    {"getFlowCheckInfo", ntop_get_flow_check_info},
    {"getHostCheckInfo", ntop_get_host_check_info},
    {"shouldResolveHost", ntop_should_resolve_host},
    {"setIEC104AllowedTypeIDs", ntop_set_iec104_allowed_typeids},
    {"isFlowDedupEnabled", ntop_is_flow_deduplication_enabled},
#ifdef NTOPNG_PRO
    {"setModbusAllowedFunctionCodes", ntop_set_modbus_allowed_function_codes},
#endif
    {"getLocalNetworkAlias", ntop_check_local_network_alias},
    {"getLocalNetworkID", ntop_get_local_network_id},
    {"getRiskStr", ntop_get_risk_str},
    {"getRiskList", ntop_get_risk_list},

    {"checkNetworkPolicy", ntop_check_network_policy},

    /* ASN */
    {"getASName", ntop_get_asn_name},
    {"getASNameFromASN", ntop_get_as_name_from_asn},
    {"getHostGeolocation", ntop_get_host_geolocation},

    /* Mac */
    {"setMacDeviceType", ntop_set_mac_device_type},

    /* Host pools */
    {"reloadHostPools", ntop_reload_host_pools},

    /* Device Protocols */
    {"reloadDeviceProtocols", ntop_reload_device_protocols},

    /* Traffic Recording/Extraction */
    {"runExtraction", ntop_run_extraction},
    {"stopExtraction", ntop_stop_extraction},
    {"isExtractionRunning", ntop_is_extraction_running},
    {"getExtractionStatus", ntop_get_extraction_status},
    {"runLiveExtraction", ntop_run_live_extraction},

    /* Bitmap functions */
    {"bitmapIsSet", ntop_bitmap_is_set},
    {"bitmapSet", ntop_bitmap_set},
    {"bitmapClear", ntop_bitmap_clear},

    /* Score */
    {"mapScoreToSeverity", ntop_map_score_to_severity},
    {"mapSeverityToScore", ntop_map_severity_to_score},

    /* Alerts */
    {"alert_store_query", ntop_alert_store_query},

    /* Alerts queues */
    {"popInternalAlerts", ntop_pop_internal_alerts},

    /* Recipient queues */
    {"recipient_enqueue", ntop_recipient_enqueue},
    {"recipient_dequeue", ntop_recipient_dequeue},
    {"recipient_stats", ntop_recipient_stats},
    {"recipient_inc_stats", ntop_recipient_inc_stats},
    {"recipient_last_use", ntop_recipient_last_use},
    {"recipient_delete", ntop_recipient_delete},
    {"recipient_register", ntop_recipient_register},

    /* nDPI */
    {"getnDPIProtoCategory", ntop_get_ndpi_protocol_category},
    {"setnDPIProtoCategory", ntop_set_ndpi_protocol_category},
    {"isCustomApplication", ndpi_is_custom_application},

/* nEdge */
#ifdef HAVE_NEDGE
    {"setHTTPBindAddr", ntop_set_http_bind_addr},
    {"setHTTPSBindAddr", ntop_set_https_bind_addr},
    {"setRoutingMode", ntop_set_routing_mode},
    {"isRoutingMode", ntop_is_routing_mode},
    {"addLanInterface", ntop_add_lan_interface},
    {"addWanInterface", ntop_add_wan_interface},
    {"refreshDeviceProtocolsPoliciesConf",
     ntop_refresh_device_protocols_policies_pref},
#endif

    /* Appliance */
    {"overrideInterface", ntop_override_interface},

    /* nEdge and Appliance */
    {"shutdown", ntop_shutdown},

    /* Periodic scripts (ThreadedActivity.cpp) */
    {"isDeadlineApproaching", ntop_script_is_deadline_approaching},
    {"getDeadline", ntop_script_get_deadline},

    /* Speedtest */
    {"hasSpeedtestSupport", ntop_has_speedtest_support},
    {"speedtest", ntop_speedtest},

    /* Blacklists */
    {"getBlacklistStats", ntop_get_bl_stats},
    {"resetBlacklistStats", ntop_reset_bl_stats},

    /* ClickHouse */
    {"isClickHouseEnabled", ntop_clickhouse_enabled},

    /* Data Binning */
    {"addBin", ntop_add_bin},
    {"findSimilarities", ntop_find_bin_similarities},

    /* Pools Lock/Unlock */
    {"poolsLock", ntop_pools_lock},
    {"poolsUnlock", ntop_pools_unlock},

    /* Register Runtime Interface (PCAP or DB) */
    {"registerRuntimeInterface", ntop_register_runtime_interface},

#if defined(NTOPNG_PRO) && defined(HAVE_KAFKA)
    /* Kafka */
    {"sendKafkaMessage", ntop_send_kafka_message},
#endif

    /* Debug */
    {"toggleNewDeleteTrace", ntop_toggle_new_delete_trace},

    /* License */
    {"getLicenseLimits", ntop_get_license_limits},

    /* InfluxDB */
    {"getInfluxDBInternalDBName", ntop_get_influxdb_internal_db_name},
    {"setInfluxDBInternalDBName", ntop_set_influxdb_internal_db_name},
    {"isInfluxDBInternalAvailable", ntop_get_influxdb_internal_available},
    {"setInfluxDBInternalAvailable", ntop_set_influxdb_internal_available},

#if defined(NTOPNG_PRO)
    /* TODO: move to message_broker engine */
    {"publish", m_broker_publish},
    {"rpcCall", m_broker_rpc_call},
#endif

    /* Modbus */
    {"readModbusDeviceInfo", read_modbus_device_info},
    {"readEthernetIPDeviceInfo", read_ether_ip_device_info},

    {"reloadServersConfiguration", reload_servers_configuration},
    {"reloadASNConfiguration", reload_asn_configuration},

#if defined(NTOPNG_PRO)
    {"reloadNetworksPolicyConfiguration", reload_networks_policy_configuration},
#endif

    /* In Memory cache */
    {"getLuaCache", ntop_get_lua_cache},
    {"setLuaCache", ntop_set_lua_cache},
    {"dumpLuaCache", ntop_dump_lua_cache},

    {NULL, NULL}};

luaL_Reg* ntop_reg = _ntop_reg;

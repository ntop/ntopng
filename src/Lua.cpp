/*
 *
 * (C) 2013-17 - ntop.org
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

#ifndef _GETOPT_H
#define _GETOPT_H
#endif

#ifndef LIB_VERSION
#define LIB_VERSION "1.4.7"
#endif

extern "C" {
#include "rrd.h"
#ifdef HAVE_GEOIP
  extern const char * GeoIP_lib_version(void);
#endif

#include "../third-party/snmp/snmp.c"
#include "../third-party/snmp/asn1.c"
#include "../third-party/snmp/net.c"
};

#include "../third-party/lsqlite3/lsqlite3.c"

struct keyval string_to_replace[MAX_NUM_HTTP_REPLACEMENTS] = { { NULL, NULL } };

/* ******************************* */

Lua::Lua() {
  L = luaL_newstate();

  if(L == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create Lua interpreter");
    return;
  }
}

/* ******************************* */

Lua::~Lua() {
  if(L) lua_close(L);
}

/* ******************************* */

/**
 * @brief Check the expected type of lua function.
 * @details Find in the lua stack the function and check the function parameters types.
 *
 * @param vm The lua state.
 * @param func The function name.
 * @param pos Index of lua stack.
 * @param expected_type Index of expected type.
 * @return @ref CONST_LUA_ERROR if the expected type is equal to function type, @ref CONST_LUA_PARAM_ERROR otherwise.
 */
int ntop_lua_check(lua_State* vm, const char* func, int pos, int expected_type) {
  if(lua_type(vm, pos) != expected_type) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "%s : expected %s, got %s", func,
				 lua_typename(vm, expected_type),
				 lua_typename(vm, lua_type(vm,pos)));
    return(CONST_LUA_PARAM_ERROR);
  }

  return(CONST_LUA_ERROR);
}

/* ****************************************** */

static void get_host_vlan_info(char* lua_ip, char** host_ip,
			       u_int16_t* vlan_id,
			       char *buf, u_int buf_len) {
  char *where, *vlan = NULL;

  snprintf(buf, buf_len, "%s", lua_ip);

  if(((*host_ip) = strtok_r(buf, "@", &where)) != NULL)
    vlan = strtok_r(NULL, "@", &where);

  if(*host_ip == NULL)
    *host_ip = lua_ip;

  if(vlan)
    (*vlan_id) = (u_int16_t)atoi(vlan);
}

/* ****************************************** */

static NetworkInterface* handle_null_interface(lua_State* vm) {
  char allowed_ifname[MAX_INTERFACE_NAME_LEN];

  ntop->getTrace()->traceEvent(TRACE_INFO, "NULL interface: did you restart ntopng in the meantime?");

  if(ntop->getInterfaceAllowed(vm, allowed_ifname)) {
    NetworkInterface *iface = ntop->getNetworkInterface(allowed_ifname);

    if(iface != NULL)
      return(iface);
  }

  return(ntop->getInterfaceAtId(0));
}

/* ****************************************** */

static int ntop_dump_file(lua_State* vm) {
  char *fname;
  FILE *fd;
  struct mg_connection *conn;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_getglobal(vm, CONST_HTTP_CONN);
  if((conn = (struct mg_connection*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: null HTTP connection");
    return(CONST_LUA_ERROR);
  }

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((fname = (char*)lua_tostring(vm, 1)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  ntop->fixPath(fname);
  if((fd = fopen(fname, "r")) != NULL) {
    char tmp[1024];

    ntop->getTrace()->traceEvent(TRACE_INFO, "[HTTP] Serving file %s", fname);

    while((fgets(tmp, sizeof(tmp)-256 /* To make sure we have room for replacements */, fd)) != NULL) {
      for(int i=0; string_to_replace[i].key != NULL; i++)
	Utils::replacestr(tmp, string_to_replace[i].key, string_to_replace[i].val);

      mg_printf(conn, "%s", tmp);
    }

    fclose(fd);
    return(CONST_LUA_OK);
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read file %s", fname);
    return(CONST_LUA_ERROR);
  }
}

/* ****************************************** */

/**
 * @brief Get default interface name.
 * @details Push the default interface name of ntop into the lua stack.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK.
 */
static int ntop_get_default_interface_name(lua_State* vm) {
  char ifname[MAX_INTERFACE_NAME_LEN];
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop->getInterfaceAllowed(vm, ifname)) {
    // if there is an allowed interface for the user
    // we return that interface
    lua_pushstring(vm,
		   ntop->getNetworkInterface(ifname)->get_name());
  } else {
    lua_pushstring(vm, ntop->getInterfaceAtId(NULL, /* no need to check as there is no constraint */
					      0)->get_name());
  }
  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Set the name of active interface id into lua stack.
 *
 * @param vm The lua stack.
 * @return @ref CONST_LUA_OK.
 */
static int ntop_set_active_interface_id(lua_State* vm) {
  NetworkInterface *iface;
  int id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  id = (u_int32_t)lua_tonumber(vm, 1);

  iface = ntop->getNetworkInterface(vm, id);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Index: %d, Name: %s", id, iface ? iface->get_name() : "<unknown>");

  if(iface != NULL)
    lua_pushstring(vm, iface->get_name());
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */
/**
 * @brief Get the ntopng interface names.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK.
 */
static int ntop_get_interface_names(lua_State* vm) {
  lua_newtable(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  for(int i=0; i<ntop->get_num_interfaces(); i++) {
    NetworkInterface *iface;

    if((iface = ntop->getInterfaceAtId(vm, i)) != NULL) {
      char num[8], *name = iface->get_name();

      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Returning name %s", name);
      snprintf(num, sizeof(num), "%d", i);
      lua_push_str_table_entry(vm, num, name);
    }
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static AddressTree* get_allowed_nets(lua_State* vm) {
  AddressTree *ptree;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_getglobal(vm, CONST_ALLOWED_NETS);
  ptree = (AddressTree*)lua_touserdata(vm, lua_gettop(vm));
  //ntop->getTrace()->traceEvent(TRACE_WARNING, "GET %p", ptree);
  return(ptree);
}

/* ****************************************** */

static NetworkInterface* getCurrentInterface(lua_State* vm) {
  NetworkInterface *ntop_interface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_getglobal(vm, "ntop_interface");
  if((ntop_interface = (NetworkInterface*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop_interface = handle_null_interface(vm);
  }

  return(ntop_interface);
}

/* ****************************************** */

/**
 * @brief Find the network interface and set it as global variable to lua.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_select_interface(lua_State* vm) {
  char *ifname;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNIL)
    ifname = (char*)"any";
  else {
    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
    ifname = (char*)lua_tostring(vm, 1);
  }

  lua_pushlightuserdata(vm, (char*)ntop->getNetworkInterface(vm, ifname));
  lua_setglobal(vm, "ntop_interface");

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get the nDPI statistics of interface.
 * @details Get the ntop interface global variable of lua, get nDpistats of interface and push it into lua stack.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_ndpi_interface_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  char *host_ip = NULL;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Optional host */
  if(lua_type(vm, 1) == LUA_TSTRING) get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_interface) {
    ntop_interface->getnDPIStats(&stats, get_allowed_nets(vm), host_ip, vlan_id);

    lua_newtable(vm);
    stats.lua(ntop_interface, vm);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef NTOPNG_PRO
/**
 * @brief Get the Host Pool statistics of interface.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_pool_interface_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface && ntop_interface->getHostPools()) {
    ntop_interface->luaHostPoolsStats(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);

}

/**
 * @brief Get the Host Pool volatile members
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_host_pool_volatile_members(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface && ntop_interface->getHostPools()) {
    ntop_interface->luaHostPoolsVolatileMembers(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);

}

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
    ntop_interface->getFlowInterfacesStats()->lua(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}
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
  u_int16_t vlan_id = 0;
  char buf[128];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((!ntop_interface))
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((h = ntop_interface->getHost(host_ip, vlan_id)))
    h->luaUsedQuotas(vm);
  else
    lua_newtable(vm);

  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

/**
 * @brief Get the ndpi flows count of interface.
 * @details Get the ntop interface global variable of lua, get nDpi flow count of interface and push it into lua stack.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_ndpi_interface_flows_count(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {
    lua_newtable(vm);
    ntop_interface->getnDPIFlowsCount(vm);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get the flow status for flows in cache
 * @details Get the ntop interface global variable of lua, get flow stats of interface and push it into lua stack.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK
 */
static int ntop_get_ndpi_interface_flows_status(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {
    lua_newtable(vm);
    ntop_interface->getFlowsStatus(vm);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get the ndpi protocol name of protocol id of network interface.
 * @details Get the ntop interface global variable of lua. Once do that, get the protocol id of lua stack and return into lua stack "Host-to-Host Contact" if protocol id is equal to host family id; the protocol name or null otherwise.
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_ndpi_protocol_name(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
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

static int ntop_get_ndpi_protocol_id(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats stats;
  char *proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  proto = (char*)lua_tostring(vm, 1);

  if(ntop_interface && proto)
    lua_pushnumber(vm, ntop_interface->get_ndpi_proto_id(proto));
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_protocol_category(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  proto = (u_int)lua_tonumber(vm, 1);

  if(ntop_interface) {
    ndpi_protocol_category_t category = ntop_interface->get_ndpi_proto_category(proto);

    lua_newtable(vm);
    lua_push_int32_table_entry(vm, "id", category);
    lua_push_str_table_entry(vm, "name", (char*)ndpi_category_str(category));
  } else
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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
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

static int ntop_get_interface_hosts(lua_State* vm, LocationPolicy location) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool show_details = true, filtered_hosts = false;
  char *sortColumn = (char*)"column_ip", *country = NULL, *os_filter = NULL, *mac_filter = NULL;
  bool a2zSortOrder = true;
  u_int16_t vlan_filter = 0;
  u_int32_t asn_filter = (u_int32_t)-1;
  int16_t network_filter = -2;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t ipver_filter = 0;
  int proto_filter = -1;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TBOOLEAN) show_details   = lua_toboolean(vm, 1) ? true : false;
  if(lua_type(vm, 2) == LUA_TSTRING)  sortColumn     = (char*)lua_tostring(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER)  maxHits        = (u_int16_t)lua_tonumber(vm, 3);
  if(lua_type(vm, 4) == LUA_TNUMBER)  toSkip         = (u_int16_t)lua_tonumber(vm, 4);
  if(lua_type(vm, 5) == LUA_TBOOLEAN) a2zSortOrder   = lua_toboolean(vm, 5) ? true : false;
  if(lua_type(vm, 6) == LUA_TSTRING)  country        = (char*)lua_tostring(vm, 6);
  if(lua_type(vm, 7) == LUA_TSTRING)  os_filter      = (char*)lua_tostring(vm, 7);
  if(lua_type(vm, 8) == LUA_TNUMBER)  vlan_filter    = (u_int16_t)lua_tonumber(vm, 8);
  if(lua_type(vm, 9) == LUA_TNUMBER)  asn_filter     = (u_int32_t)lua_tonumber(vm, 9);
  if(lua_type(vm,10) == LUA_TNUMBER)  network_filter = (int16_t)lua_tonumber(vm, 10);
  if(lua_type(vm,11) == LUA_TSTRING)  mac_filter     = (char*)lua_tostring(vm, 11);
  if(lua_type(vm,12) == LUA_TNUMBER)  pool_filter    = (u_int16_t)lua_tonumber(vm, 12);
  if(lua_type(vm,13) == LUA_TNUMBER)  ipver_filter   = (u_int8_t)lua_tonumber(vm, 13);
  if(lua_type(vm,14) == LUA_TNUMBER)  proto_filter   = (int)lua_tonumber(vm, 14);
  if(lua_type(vm,15) == LUA_TBOOLEAN) filtered_hosts = lua_toboolean(vm, 15);

  if(!ntop_interface ||
     ntop_interface->getActiveHostsList(vm,
					0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
					get_allowed_nets(vm),
					show_details, location,
					country, mac_filter,
					vlan_filter, os_filter, asn_filter,
					network_filter, pool_filter, filtered_hosts, ipver_filter, proto_filter,
					sortColumn, maxHits,
					toSkip, a2zSortOrder) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_latest_activity_hosts_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->getLatestActivityHostsList(vm, get_allowed_nets(vm));

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get the host information of network interface grouped according to the criteria.
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null or the host is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_grouped_interface_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool show_details = true, hostsOnly = true;
  char *country = NULL, *os_filter = NULL;
  char *groupBy = (char*)"column_ip";
  bool filtered_hosts = false;
  u_int16_t vlan_filter = 0;
  u_int32_t asn_filter = (u_int32_t)-1;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t ipver_filter = (u_int8_t)-1;
  int16_t network_filter = -2;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TBOOLEAN) show_details = lua_toboolean(vm, 1) ? true : false;
  if(lua_type(vm, 2) == LUA_TSTRING)  groupBy    = (char*)lua_tostring(vm, 2);
  if(lua_type(vm, 3) == LUA_TSTRING)  country = (char*)lua_tostring(vm, 3);
  if(lua_type(vm, 4) == LUA_TSTRING)  os_filter      = (char*)lua_tostring(vm, 4);
  if(lua_type(vm, 5) == LUA_TNUMBER)  vlan_filter    = (u_int16_t)lua_tonumber(vm, 5);
  if(lua_type(vm, 6) == LUA_TNUMBER)  asn_filter     = (u_int32_t)lua_tonumber(vm, 6);
  if(lua_type(vm, 7) == LUA_TNUMBER)  network_filter = (int16_t)lua_tonumber(vm, 7);
  if(lua_type(vm, 8) == LUA_TBOOLEAN) hostsOnly      = lua_toboolean(vm, 8) ? true : false;
  if(lua_type(vm, 9) == LUA_TNUMBER)  pool_filter    = (u_int16_t)lua_tonumber(vm, 9);
  if(lua_type(vm, 10) == LUA_TNUMBER) ipver_filter   = (u_int8_t)lua_tonumber(vm, 10);

  if((!ntop_interface)
     || ntop_interface->getActiveHostsGroup(vm, get_allowed_nets(vm),
					    show_details, location_all,
					    country,
					    vlan_filter, os_filter,
					    asn_filter, network_filter,
					    pool_filter, filtered_hosts, ipver_filter,
					    hostsOnly, groupBy) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get the hosts information of network interface.
 * @details Get the ntop interface global variable of lua and return into lua stack a new hash table of hash tables containing the host information.
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_interface_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_all));
}

/* ****************************************** */

static int ntop_get_interface_macs_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *sortColumn = (char*)"column_mac";
  const char* manufacturer = NULL;
  u_int32_t toSkip = 0, maxHits = CONST_MAX_NUM_HITS;
  u_int16_t vlan_id = 0, pool_filter = (u_int16_t)-1;
  bool a2zSortOrder = true, sourceMacsOnly = false, hostMacsOnly = false;

  if(lua_type(vm, 1) == LUA_TSTRING) sortColumn = (char*)lua_tostring(vm, 1);
  if(lua_type(vm, 2) == LUA_TNUMBER) maxHits = (u_int16_t)lua_tonumber(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER) toSkip = (u_int16_t)lua_tonumber(vm, 3);
  if(lua_type(vm, 4) == LUA_TBOOLEAN) a2zSortOrder = lua_toboolean(vm, 4);
  if(lua_type(vm, 5) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 5);
  if(lua_type(vm, 6) == LUA_TBOOLEAN) sourceMacsOnly = lua_toboolean(vm, 6);
  if(lua_type(vm, 7) == LUA_TBOOLEAN) hostMacsOnly = lua_toboolean(vm, 7);
  if(lua_type(vm, 8) == LUA_TSTRING) manufacturer = lua_tostring(vm, 8);
  if(lua_type(vm, 9) == LUA_TNUMBER) pool_filter = (u_int16_t)lua_tonumber(vm, 9);

  if(!ntop_interface ||
     ntop_interface->getActiveMacList(vm,
				      0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
				      vlan_id, sourceMacsOnly,
				      hostMacsOnly, manufacturer,
				      sortColumn, maxHits,
				      toSkip, a2zSortOrder, pool_filter) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_mac_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *mac = NULL;
  u_int16_t vlan_id = 0;

  if(lua_type(vm, 1) == LUA_TSTRING) {
    mac = (char*)lua_tostring(vm, 1);

    if(lua_type(vm, 2) == LUA_TNUMBER) {
      vlan_id = (u_int16_t)lua_tonumber(vm, 2);
    }
  }

  if((!ntop_interface)
     || (!mac)
     || (!ntop_interface->getMacInfo(vm, mac, vlan_id)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_ases_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *sortColumn = (char*)"column_asn";
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
     ntop_interface->getActiveASList(vm,
				     sortColumn, maxHits,
				     toSkip, a2zSortOrder, details_level) < 0)
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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  asn = (u_int32_t)lua_tonumber(vm, 1);

  if((!ntop_interface)
     || (!ntop_interface->getASInfo(vm, asn)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_get_interface_vlan_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int16_t vlan_id;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
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
  u_int16_t vlan_id = 0;
  bool sourceMacsOnly = false, hostMacsOnly = false;

  if(lua_type(vm, 1) == LUA_TNUMBER) {
    vlan_id = (u_int16_t)lua_tonumber(vm, 1);

    if(lua_type(vm, 2) == LUA_TNUMBER) {
      maxHits = (u_int16_t)lua_tonumber(vm, 2);

      if(lua_type(vm, 3) == LUA_TBOOLEAN) {
        sourceMacsOnly = lua_toboolean(vm, 3) ? true : false;

        if(lua_type(vm, 4) == LUA_TBOOLEAN) {
          hostMacsOnly = lua_toboolean(vm, 4) ? true : false;
        }
      }
    }
  }

  if(!ntop_interface ||
     ntop_interface->getActiveMacManufacturers(vm,
					       0, /* bridge_iface_idx - TODO */
					       vlan_id, sourceMacsOnly,
					       hostMacsOnly,maxHits) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_mac_manufacturer(lua_State* vm) {
  const char *mac = NULL;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  mac = (char*)lua_tostring(vm, 1);

  ntop->getMacManufacturer(mac, vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_site_categories(lua_State* vm) {
  Flashstart *flash = ntop->get_flashstart();

  if(!flash)
    lua_pushnil(vm);
  else
    flash->lua(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get local hosts information of network interface.
 * @details Get the ntop interface global variable of lua and return into lua stack a new hash table of hash tables containing the local host information.
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_interface_local_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_local_only));
}

/* ****************************************** */

/**
 * @brief Get remote hosts information of network interface.
 * @details Get the ntop interface global variable of lua and return into lua stack a new hash table of hash tables containing the remote host information.
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_interface_remote_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_remote_only));
}

/* ****************************************** */

/**
 * @brief Check if the specified path is a directory and it exists.
 * @details True if if the specified path is a directory and it exists, false otherwise.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK
 */
static int ntop_is_dir(lua_State* vm) {
  char *path;
  struct stat buf;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  rc = ((stat(path, &buf) != 0) || (!S_ISDIR(buf.st_mode))) ? 0 : 1;
  lua_pushboolean(vm, rc);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Check if the file is exists and is not empty
 * @details Simple check for existence + non empty file
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK
 */
static int ntop_is_not_empty_file(lua_State* vm) {
  char *path;
  struct stat buf;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  rc = (stat(path, &buf) != 0) ? 0 : 1;
  if(rc && (buf.st_size == 0)) rc = 0;
  lua_pushboolean(vm, rc);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Check if the file or directory exists.
 * @details Get the path of file/directory from to lua stack and push true into lua stack if it exists, false otherwise.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK
 */
static int ntop_get_file_dir_exists(lua_State* vm) {
  char *path;
  struct stat buf;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  rc = (stat(path, &buf) != 0) ? 0 : 1;
  //   ntop->getTrace()->traceEvent(TRACE_ERROR, "%s: %d", path, rc);
  lua_pushboolean(vm, rc);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Return the epoch of the file last change
 * @details This function return that time (epoch) of the last change on a file, or -1 if the file does not exist.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK
 */
static int ntop_get_file_last_change(lua_State* vm) {
  char *path;
  struct stat buf;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  if(stat(path, &buf) == 0)
    lua_pushnumber(vm, (lua_Number)buf.st_mtime);
  else
    lua_pushnumber(vm, -1); /* not found */

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Check if ntop has seen VLAN tagged packets on this interface.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_has_vlans(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    lua_pushboolean(vm, ntop_interface->hasSeenVlanTaggedPackets());
  else
    lua_pushboolean(vm, 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Check if ntop has loaded ASN information (via GeoIP)
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_has_geoip(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->getGeolocation() ? 1 : 0);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Check if ntop is running on windows.
 * @details Push into lua stack 1 if ntop is running on windows, 0 otherwise.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_is_windows(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm,
#ifdef WIN32
		  1
#else
		  0
#endif
		  );

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_allocHostBlacklist(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  ntop->allocHostBlacklist();
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_swapHostBlacklist(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  ntop->swapHostBlacklist();
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_addToHostBlacklist(lua_State* vm) {
  char *net;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  net = (char*)lua_tostring(vm, 1);

  ntop->addToHostBlacklist(net);
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Wrapper for the libc call getservbyport()
 * @details Wrapper for the libc call getservbyport()
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_getservbyport(lua_State* vm) {
  int port;
  char *proto;
  struct servent *s = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  port = (int)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  proto = (char*)lua_tostring(vm, 2);

  if((port > 0) && (proto != NULL))
    s = getservbyport(htons(port), proto);

  if(s && s->s_name)
    lua_pushstring(vm, s->s_name);
  else {
    char buf[32];

    snprintf(buf, sizeof(buf), "%d", port);
    lua_pushstring(vm, buf);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Scan the input directory and return the list of files.
 * @details Get the path from the lua stack and push into a new hashtable the files name existing in the directory.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_list_dir_files(lua_State* vm) {
  char *path;
  DIR *dirp;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);
  ntop->fixPath(path);

  lua_newtable(vm);

  if((dirp = opendir(path)) != NULL) {
    struct dirent *dp;

    while ((dp = readdir(dirp)) != NULL)
      if((dp->d_name[0] != '\0')
	 && (dp->d_name[0] != '.')) {
	lua_push_str_table_entry(vm, dp->d_name, dp->d_name);
      }
    (void)closedir(dirp);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

/* Adapted from http://stackoverflow.com/questions/2256945/removing-a-non-empty-directory-programmatically-in-c-or-c */
static int remove_recursively(const char * path) {
  DIR *d = opendir(path);
  size_t path_len = strlen(path);
  int r = -1;
  size_t len;
  char *buf;

  if(d) {
    struct dirent *p;

    r = 0;

    while ((r==0) && (p=readdir(d))) {
      /* Skip the names "." and ".." as we don't want to recurse on them. */
      if(!strcmp(p->d_name, ".") || !strcmp(p->d_name, ".."))
	continue;

      len = path_len + strlen(p->d_name) + 2;
      buf = (char *) malloc(len);

      if(buf) {
        struct stat statbuf;

        snprintf(buf, len, "%s/%s", path, p->d_name);

        if(stat(buf, &statbuf) == 0) {
          if(S_ISDIR(statbuf.st_mode))
            r = remove_recursively(buf);
          else
            r = unlink(buf);
        }

        free(buf);
      }
    }

    closedir(d);
  }

  if(r == 0)
    r = rmdir(path);

  return r;
}

/**
 * @brief Scan the input directory, removes it and its contents.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_remove_dir_recursively(lua_State* vm) {
  char *path;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);
  ntop->fixPath(path);

  remove_recursively(path);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get the system time and push it into the lua stack.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_gettimemsec(lua_State* vm) {
  struct timeval tp;
  double ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  gettimeofday(&tp, NULL);

  ret = (((double)tp.tv_usec) / (double)1000) + tp.tv_sec;

  lua_pushnumber(vm, ret);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Lua-equivalent to C inet_ntoa
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_inet_ntoa(lua_State* vm) {
  u_int32_t ip;
  struct in_addr in;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING)
    ip = atol((char*)lua_tostring(vm, 1));
  else if(lua_type(vm, 1) == LUA_TNUMBER)
    ip = (u_int32_t)lua_tonumber(vm, 1);
  else
    return(CONST_LUA_ERROR);

  in.s_addr = htonl(ip);
  lua_pushstring(vm, inet_ntoa(in));
  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Mask an IPv4/v6 address with a bitmask and return the network prefix.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_network_prefix(lua_State* vm) {
  char *address;
  char buf[64];
  u_int8_t mask;
  IpAddress ip;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((address = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_PARAM_ERROR);
  mask = (int)lua_tonumber(vm, 2);

  ip.set(address);
  lua_pushstring(vm, ip.print(buf, sizeof(buf), mask));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_zmq_connect(lua_State* vm) {
  char *endpoint, *topic;
  void *context, *subscriber;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((endpoint = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((topic = (char*)lua_tostring(vm, 2)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  context = zmq_ctx_new(), subscriber = zmq_socket(context, ZMQ_SUB);

  if(zmq_connect(subscriber, endpoint) != 0) {
    zmq_close(subscriber);
    zmq_ctx_destroy(context);
    return(CONST_LUA_PARAM_ERROR);
  }

  if(zmq_setsockopt(subscriber, ZMQ_SUBSCRIBE, topic, strlen(topic)) != 0) {
    zmq_close(subscriber);
    zmq_ctx_destroy(context);
    return -1;
  }

  lua_pushlightuserdata(vm, context);
  lua_setglobal(vm, "zmq_context");

  lua_pushlightuserdata(vm, subscriber);
  lua_setglobal(vm, "zmq_subscriber");

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Delete the specified member(field) from the redis hash stored at key.
 * @details Get the key parameter from the lua stack and delete it from redis.
 *
 * @param vm The lua stack.
 * @return CONST_LUA_OK.
 */
static int ntop_delete_redis_key(lua_State* vm) {
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  ntop->getRedis()->del(key);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/* ****************************************** */

/**
 * @brief Add a member to the a redis set.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_add_set_member_redis(lua_State* vm) {
  char *key, *value;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop->getRedis()->sadd(key, value) == 0)
    return(CONST_LUA_OK);
  else
    return(CONST_LUA_ERROR);
}

/**
 * @brief Removes a member from a redis set.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_del_set_member_redis(lua_State* vm) {
  char *key, *value;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop->getRedis()->srem(key, value) == 0)
    return(CONST_LUA_OK);
  else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

/**
 * @brief Get the members of a redis set.
 * @details Get the set key form the lua stack and push the members name into lua stack.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_get_set_members_redis(lua_State* vm) {
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  ntop->getRedis()->smembers(vm, key);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Delete the specified member(field) from the redis hash stored at key.
 * @details Get the member name and the hash key form the lua stack and remove the specified member.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_delete_hash_redis_key(lua_State* vm) {
  char *key, *member;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((member = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  ntop->getRedis()->hashDel(key, member);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_zmq_disconnect(lua_State* vm) {
  void *context, *subscriber;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_getglobal(vm, "zmq_context");
  if((context = (void*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: NULL context");
    return(CONST_LUA_ERROR);
  }

  lua_getglobal(vm, "zmq_subscriber");
  if((subscriber = (void*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: NULL subscriber");
    return(CONST_LUA_ERROR);
  }

  zmq_close(subscriber);
  zmq_ctx_destroy(context);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_zmq_receive(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  void *subscriber;
  int size;
  struct zmq_msg_hdr h;
  char *payload;
  int payload_len;
  zmq_pollitem_t item;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_getglobal(vm, "zmq_subscriber");
  if((subscriber = (void*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: NULL subscriber");
    return(CONST_LUA_ERROR);
  }

  item.socket = subscriber;
  item.events = ZMQ_POLLIN;
  do {
    rc = zmq_poll(&item, 1, 1000);
    if(rc < 0 || !ntop_interface->isRunning()) /* CHECK */
      return(CONST_LUA_PARAM_ERROR);
  } while (rc == 0);

  size = zmq_recv(subscriber, &h, sizeof(h), 0);

  if(size != sizeof(h) || h.version != ZMQ_MSG_VERSION) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unsupported publisher version [%d]", h.version);
    return -1;
  }

  payload_len = h.size + 1;
  if((payload = (char*)malloc(payload_len)) != NULL) {
    size = zmq_recv(subscriber, payload, payload_len, 0);
    payload[h.size] = '\0';

    if(size > 0) {
      enum json_tokener_error jerr = json_tokener_success;
      json_object *o = json_tokener_parse_verbose(payload, &jerr);

      if(o != NULL) {
	struct json_object_iterator it = json_object_iter_begin(o);
	struct json_object_iterator itEnd = json_object_iter_end(o);

	while (!json_object_iter_equal(&it, &itEnd)) {
	  char *key   = (char*)json_object_iter_peek_name(&it);
	  const char *value = json_object_get_string(json_object_iter_peek_value(&it));

	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s]=[%s]", key, value);

	  json_object_iter_next(&it);
	}

	json_object_put(o);
      } else
	ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s]: %s",
				     json_tokener_error_desc(jerr),
				     payload);

      lua_pushfstring(vm, "%s", payload);
      ntop->getTrace()->traceEvent(TRACE_INFO, "[%u] %s", h.size, payload);
      free(payload);
      return(CONST_LUA_OK);
    } else {
      free(payload);
      return(CONST_LUA_PARAM_ERROR);
    }
  } else
    return(CONST_LUA_PARAM_ERROR);
}

/* ****************************************** */

static int ntop_get_local_networks(lua_State* vm) {
  lua_newtable(vm);
  ntop->getLocalNetworks(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reload_preferences(lua_State* vm) {
  lua_newtable(vm);
  ntop->getPrefs()->reloadPrefsFromRedis();

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_temporary_disable_alerts(lua_State* vm) {
  bool to_disable;
  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);
  if(ntop->getPrefs()->hasCmdlDisableAlerts()) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN)) return(CONST_LUA_PARAM_ERROR);
  to_disable = lua_toboolean(vm, 1);

  ntop->getPrefs()->set_alerts_status(!to_disable);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Check if the trace level of ntop is verbose.
 * @details Push true into the lua stack if the trace level of ntop is set to MAX_TRACE_LEVEL, false otherwise.
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_verbose_trace(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, (ntop->getTrace()->get_trace_level() == MAX_TRACE_LEVEL) ? true : false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_send_udp_data(lua_State* vm) {
  int rc, port, sockfd = ntop->getUdpSock();
  char *host, *data;

  if(sockfd == -1)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  host = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  port = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_ERROR);
  data = (char*)lua_tostring(vm, 3);

  if(strchr(host, ':') != NULL) {
    struct sockaddr_in6 server_addr;

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin6_family = AF_INET6;
    inet_pton(AF_INET6, host, &server_addr.sin6_addr);
    server_addr.sin6_port = htons(port);

    rc = sendto(sockfd, data, strlen(data),0,
		(struct sockaddr *)&server_addr,
		sizeof(server_addr));
  } else {
    struct sockaddr_in server_addr;

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = inet_addr(host); /* FIX: add IPv6 support */
    server_addr.sin_port = htons(port);

    rc = sendto(sockfd, data, strlen(data),0,
		(struct sockaddr *)&server_addr,
		sizeof(server_addr));
  }

  if(rc == -1)
    return(CONST_LUA_ERROR);
  else
    return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_flows_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char buf[64];
  char *host_ip = NULL;
  u_int16_t vlan_id = 0;
  Host *host = NULL;
  Paginator *p = NULL;
  int numFlows = -1;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));
    host = ntop_interface->getHost(host_ip, vlan_id);
  }

  if(lua_type(vm, 2) == LUA_TTABLE)
    p->readOptions(vm, 2);

  if(ntop_interface)
    numFlows = ntop_interface->getFlows(vm, get_allowed_nets(vm), host, p);

  if(p) delete p;
  return numFlows < 0 ? CONST_LUA_ERROR : CONST_LUA_OK;
}

/* ****************************************** */

/**
 * @brief Get nDPI stats for flows
 * @details Compute nDPI flow statistics
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_get_interface_flows_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) ntop_interface->getFlowsStats(vm);

  return(CONST_LUA_OK);
}
/* ****************************************** */

/**
 * @brief Get interface stats for local networks
 * @details Returns traffic statistics per local network
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */
static int ntop_get_interface_networks_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) ntop_interface->getNetworksStats(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Get the host information of network interface.
 * @details Get the ntop interface global variable of lua, the host ip and optional the VLAN id form the lua stack and push a new hash table of hash tables containing the host information into lua stack.
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null or the host is null, CONST_LUA_OK otherwise.
 */
static int ntop_get_interface_host_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((!ntop_interface) || !ntop_interface->getHostInfo(vm, get_allowed_nets(vm), host_ip, vlan_id))
    return(CONST_LUA_ERROR);
  else
    return(CONST_LUA_OK);
}

/* ****************************************** */
#ifdef NOTUSED
static int ntop_get_grouped_interface_host(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *country_s = NULL, *os_s = NULL;
  u_int16_t vlan_n,    *vlan_ptr    = NULL;
  u_int32_t as_n,      *as_ptr      = NULL;
  int16_t   network_n, *network_ptr = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNUMBER) vlan_n    = (u_int16_t)lua_tonumber(vm, 1), vlan_ptr  = &vlan_n;
  if(lua_type(vm, 2) == LUA_TNUMBER) as_n      = (u_int32_t)lua_tonumber(vm, 2), as_ptr    = &as_n;
  if(lua_type(vm, 3) == LUA_TNUMBER) network_n = (int16_t)lua_tonumber(vm, 3), network_ptr = &network_n;
  if(lua_type(vm, 4) == LUA_TSTRING) country_s = (char*)lua_tostring(vm, 4);
  if(lua_type(vm, 5) == LUA_TSTRING) os_s      = (char*)lua_tostring(vm, 5);

  if(!ntop_interface || ntop_interface->getActiveHostsGroup(vm, get_allowed_nets(vm), false, false, country_s, vlan_ptr, os_s, as_ptr,
							    network_ptr, (char*)"column_ip", (char*)"country", CONST_MAX_NUM_HITS, 0 /* toSkip */, true /* a2zSortOrder */) < 0)
    return(CONST_LUA_ERROR);
  else
    return(CONST_LUA_OK);
}
#endif

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
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
  
  try {
    NetworkDiscovery *d = new NetworkDiscovery(ntop_interface);
    
    if(d) {
      d->discover(vm, timeout);
      delete d;
    }
  } catch(...) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to perform network discovery");
  }

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
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

static int ntop_host_reset_periodic_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  return ntop_interface->resetPeriodicHostStats(get_allowed_nets(vm), host_ip, vlan_id);
}

/* ****************************************** */

static int ntop_correlate_host_activity(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((!ntop_interface) || !ntop_interface->correlateHostActivity(vm, get_allowed_nets(vm), host_ip, vlan_id))
    return(CONST_LUA_ERROR);
  else
    return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_similar_host_activity(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((!ntop_interface) || !ntop_interface->similarHostActivity(vm, get_allowed_nets(vm), host_ip, vlan_id))
    return(CONST_LUA_ERROR);
  else
    return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_host_activitymap(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  GenericHost *h;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)  return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  h = ntop_interface->getHost(host_ip, vlan_id);

  if(h == NULL)
    return(CONST_LUA_ERROR);
  else {
    if(h->match(get_allowed_nets(vm))) {
      char *json = h->getJsonActivityMap();

      lua_pushfstring(vm, "%s", json);
      free(json);
    }

    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

/**
 * @brief Restore the host of network interface.
 * @details Get the ntop interface global variable of lua and the IP address of host form the lua stack and restore the host into hash host of network interface.
 *
 * @param vm The lua state.
 * @return CONST_LUA_ERROR if ntop_interface is null or if is impossible to restore the host, CONST_LUA_OK otherwise.
 */
static int ntop_restore_interface_host(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  bool skip_privileges_check = false;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);



  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* make sure skip privileges check cannot be set from the web interface */
  if(lua_type(vm, 2) == LUA_TBOOLEAN) skip_privileges_check = lua_toboolean(vm, 2);

  if(!skip_privileges_check && !Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if((!ntop_interface) || !ntop_interface->restoreHost(host_ip, vlan_id))
    return(CONST_LUA_ERROR);
  else
    return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_flow_key(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  Host *cli, *srv;
  char *cli_name = NULL; u_int16_t cli_vlan = 0; u_int16_t cli_port = 0;
  char *srv_name = NULL; u_int16_t srv_vlan = 0; u_int16_t srv_port = 0;
  u_int16_t protocol;
  char cli_buf[256], srv_buf[256];

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)    /* cli_host@cli_vlan */
     || ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) /* cli port          */
     || ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) /* srv_host@srv_vlan */
     || ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) /* srv port          */
     || ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) /* protocol          */
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
     ||(cli = ntop_interface->getHost(cli_name, cli_vlan)) == NULL
     ||(srv = ntop_interface->getHost(srv_name, srv_vlan)) == NULL) {
    lua_pushnil(vm);
  } else {
    lua_pushnumber(vm, Flow::key(cli, cli_port, srv, srv_port, cli_vlan, protocol));
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_flow_by_key(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t key;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  key = (u_int32_t)lua_tonumber(vm, 1);

  if(!ntop_interface) return(false);

  f = ntop_interface->findFlowByKey(key, ptree);

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
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  key = (u_int32_t)lua_tonumber(vm, 1);

  if(!ntop_interface) return(false);

  f = ntop_interface->findFlowByKey(key, ptree);

  if(f == NULL)
    return(CONST_LUA_ERROR);
  else {
    f->setDropVerdict();
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_dump_flow_traffic(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t key, what;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  key = (u_int32_t)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  what = (u_int32_t)lua_tonumber(vm, 2);

  if(!ntop_interface) return(false);

  f = ntop_interface->findFlowByKey(key, ptree);

  if(f == NULL)
    return(CONST_LUA_ERROR);
  else {
    f->setDumpFlowTraffic(what ? true : false);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_dump_local_hosts_2_redis(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->dumpLocalHosts2redis(true /* must disable purge as we are called from lua */);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_user_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  key = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  ntop_interface->findUserFlows(vm, key);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_pid_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t pid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  pid = (u_int32_t)lua_tonumber(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  ntop_interface->findPidFlows(vm, pid);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_father_pid_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t father_pid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  father_pid = (u_int32_t)lua_tonumber(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  ntop_interface->findFatherPidFlows(vm, father_pid);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_proc_name_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *proc_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  proc_name = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  ntop_interface->findProcNameFlows(vm, proc_name);
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

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_find_host(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  key = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->findHostsByName(vm, get_allowed_nets(vm), key);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_update_host_traffic_policy(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(!ntop_interface)
    return CONST_LUA_ERROR;

  return ntop_interface->updateHostTrafficPolicy(get_allowed_nets(vm), host_ip, vlan_id);
}

/* ****************************************** */

static int ntop_refresh_hosts_alerts_configuration(lua_State* vm) {
  bool full_refresh = false;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(lua_type(vm, 1) == LUA_TBOOLEAN) full_refresh = lua_toboolean(vm, 1);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->refreshHostsAlertPrefs(full_refresh);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_second_traffic(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->updateSecondTraffic(time(NULL));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_host_dump_policy(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  bool dump_traffic_to_disk;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN)) return(CONST_LUA_ERROR);
  dump_traffic_to_disk = lua_toboolean(vm, 1) ? true : false;

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 2), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 3) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 3);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  return ntop_interface->setHostDumpTrafficPolicy(get_allowed_nets(vm), host_ip, vlan_id, dump_traffic_to_disk);
}

/* ****************************************** */

static int ntop_get_host_hit_rate(lua_State* vm) {
#ifdef NOTUSED
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  Host *h;
  u_int32_t peer_key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  peer_key = (u_int32_t)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 2), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 3) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 3);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  return ntop_interface->getPeerBytes(get_allowed_nets(vm), vm, host_ip, vlan_id, peer_key);
#else
  return(CONST_LUA_ERROR); // not supported
#endif
}

/* ****************************************** */

static int ntop_get_interface_dump_tap_policy(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool dump_traffic_to_tap;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  dump_traffic_to_tap = ntop_interface->getDumpTrafficTapPolicy();

  lua_pushboolean(vm, dump_traffic_to_tap ? 1 : 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_dump_tap_name(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  lua_pushstring(vm, ntop_interface->getDumpTrafficTapName());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_dump_disk_policy(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool dump_traffic_to_disk;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  dump_traffic_to_disk = ntop_interface->getDumpTrafficDiskPolicy();

  lua_pushboolean(vm, dump_traffic_to_disk ? 1 : 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_dump_max_pkts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  int max_pkts;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  max_pkts = ntop_interface->getDumpTrafficMaxPktsPerFile();

  lua_pushnumber(vm, max_pkts);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_dump_max_sec(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  int max_sec;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  max_sec = ntop_interface->getDumpTrafficMaxSecPerFile();

  lua_pushnumber(vm, max_sec);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_dump_max_files(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  int max_files;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  max_files = ntop_interface->getDumpTrafficMaxFiles();

  lua_pushnumber(vm, max_files);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_pkts_dumped_file(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  int num_pkts;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  PacketDumper *dumper = ntop_interface->getPacketDumper();
  if(!dumper)
    return(CONST_LUA_ERROR);

  num_pkts = dumper->get_num_dumped_packets();

  lua_pushnumber(vm, num_pkts);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_interface_pkts_dumped_tap(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  int num_pkts;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  PacketDumperTuntap *dumper = ntop_interface->getPacketDumperTap();
  if(!dumper)
    return(CONST_LUA_ERROR);

  num_pkts = dumper->get_num_dumped_packets();

  lua_pushnumber(vm, num_pkts);

  return(CONST_LUA_OK);
}

/* ****************************************** */

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
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_packet_interface(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  lua_pushboolean(vm, ntop_interface->isPacketInterface());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_bridge_interface(lua_State* vm) {
  int ifid;
  NetworkInterface *iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((lua_type(vm, 1) == LUA_TNUMBER)) {
    ifid = lua_tointeger(vm, 1);

    if(ifid < 0 || !(iface = ntop->getNetworkInterface(ifid)))
      return (CONST_LUA_ERROR);
  }

  lua_pushboolean(vm, iface->is_bridge_interface());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_pcap_dump_interface(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  const char *interface_type;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface
     || ((interface_type = ntop_interface->get_type()) == NULL))
    return(CONST_LUA_ERROR);

  lua_pushboolean(vm, strcmp(interface_type, CONST_INTERFACE_TYPE_PCAP_DUMP) == 0);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_is_running(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  return(ntop_interface->isRunning());
}

/* ****************************************** */

static int ntop_interface_is_idle(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface) return(CONST_LUA_ERROR);
  return(ntop_interface->idle());
}

/* ****************************************** */

static int ntop_interface_set_idle(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool state;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN)) return(CONST_LUA_ERROR);
  state = lua_toboolean(vm, 1) ? true : false;

  ntop_interface->setIdleState(state);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_name2id(lua_State* vm) {
  char *if_name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNIL)
    if_name = NULL;
  else {
    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
    if_name = (char*)lua_tostring(vm, 1);
  }

  lua_pushinteger(vm, ntop->getInterfaceIdByName(if_name));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_protocols(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  ndpi_protocol_category_t category_filter;

  if(ntop_interface == NULL) {
    ntop_interface = getCurrentInterface(vm);
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((lua_type(vm, 1) == LUA_TNUMBER)) {
    category_filter = (ndpi_protocol_category_t)lua_tointeger(vm, 1);

    if(category_filter >= NDPI_PROTOCOL_NUM_CATEGORIES)
      return (CONST_LUA_ERROR);

    ntop_interface->getnDPIProtocols(vm, category_filter);
  } else
    ntop_interface->getnDPIProtocols(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_ndpi_categories(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  for (int i=0; i < NDPI_PROTOCOL_NUM_CATEGORIES; i++) {
    char buf[8];

    snprintf(buf, sizeof(buf), "%d", i);
    lua_push_str_table_entry(vm, ndpi_category_str((ndpi_protocol_category_t)i), buf);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_load_dump_prefs(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  ntop_interface->loadDumpPrefs();

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_load_scaling_factor_prefs(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  ntop_interface->loadScalingFactorPrefs();

  return(CONST_LUA_OK);
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

static const char **make_argv(lua_State * vm, u_int offset) {
  const char **argv;
  int i;
  int argc = lua_gettop(vm) - offset;

  if(!(argv = (const char**)calloc(argc, sizeof (char *))))
    /* raise an error and never return */
    luaL_error(vm, "Can't allocate memory for arguments array");

  /* fprintf(stderr, "%s\n", argv[0]); */
  for(i=0; i<argc; i++) {
    u_int idx = i + offset;
    /* accepts string or number */
    if(lua_isstring(vm, idx) || lua_isnumber(vm, idx)) {
      if(!(argv[i] = (char*)lua_tostring (vm, idx))) {
	/* raise an error and never return */
	luaL_error(vm, "Error duplicating string area for arg #%d", i);
      }
    } else {
      /* raise an error and never return */
      luaL_error(vm, "Invalid arg #%d: args must be strings or numbers", i);
    }

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%d] %s", i, argv[i]);
  }

  return(argv);
}

/* ****************************************** */

static int ntop_rrd_create(lua_State* vm) {
  const char *filename;
  unsigned long pdp_step;
  const char **argv;
  int argc, status, offset = 3;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((filename = (const char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  pdp_step = (unsigned long)lua_tonumber(vm, 2);

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  argc = lua_gettop(vm) - offset;
  argv = make_argv(vm, offset);

  reset_rrd_state();
  status = rrd_create_r(filename, pdp_step, time(NULL)-86400 /* 1 day */, argc, argv);
  free(argv);

  if(status != 0) {
    char *err = rrd_get_error();

    if(err != NULL) {
      luaL_error(vm, err);
      return(CONST_LUA_ERROR);
    }
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_rrd_update(lua_State* vm) {
  const char *filename, *update_arg;
  int status;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((filename = (const char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((update_arg = (const char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s(%s) %s", __FUNCTION__, filename, update_arg);

  reset_rrd_state();
  status = rrd_update_r(filename, NULL, 1, &update_arg);

  if(status != 0) {
    char *err = rrd_get_error();

    if(err != NULL) {
      luaL_error(vm, err);
      return(CONST_LUA_ERROR);
    }
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_rrd_lastupdate(lua_State* vm) {
  const char *filename;
  time_t    last_update;
  char    **ds_names;
  char    **last_ds;
  unsigned long ds_count, i;
  int status;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((filename = (const char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  status = rrd_lastupdate_r(filename, &last_update, &ds_count, &ds_names, &last_ds);

  if(status != 0) {
    return(CONST_LUA_ERROR);
  } else {
    for(i = 0; i < ds_count; i++)
      free(last_ds[i]), free(ds_names[i]);

    free(last_ds), free(ds_names);

    lua_pushnumber(vm, last_update);
    lua_pushnumber(vm, ds_count);
    return(2 /* 2 values returned */);
  }
}

/* ****************************************** */

/* positional 1:4 parameters for ntop_rrd_fetch */
static int __ntop_rrd_args (lua_State* vm, char **filename, char **cf, time_t *start, time_t *end) {
  char *start_s, *end_s, *err;
  rrd_time_value_t start_tv, end_tv;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((*filename = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((*cf = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if((lua_type(vm, 3) == LUA_TNUMBER) && (lua_type(vm, 4) == LUA_TNUMBER))
    *start = (time_t)lua_tonumber(vm, 3), *end = (time_t)lua_tonumber(vm, 4);
  else {
    if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
    if((start_s = (char*)lua_tostring(vm, 3)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    if((err = rrd_parsetime(start_s, &start_tv)) != NULL) {
      luaL_error(vm, err);
      return(CONST_LUA_PARAM_ERROR);
    }

    if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
    if((end_s = (char*)lua_tostring(vm, 4)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    if((err = rrd_parsetime(end_s, &end_tv)) != NULL) {
      luaL_error(vm, err);
      return(CONST_LUA_PARAM_ERROR);
    }

    if(rrd_proc_start_end(&start_tv, &end_tv, start, end) == -1)
      return(CONST_LUA_PARAM_ERROR);
  }

  return(CONST_LUA_OK);
}

static int __ntop_rrd_status(lua_State* vm, int status, char *filename, char *cf) {
  char * err;

  if(status != 0) {
    err = rrd_get_error();

    if(err != NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Error '%s' while calling rrd_fetch_r(%s, %s): is the RRD corrupted perhaps?",
                                   err, filename, cf);
      lua_pushnil(vm);
      lua_pushnil(vm);
      lua_pushnil(vm);
      lua_pushnil(vm);
      return(CONST_LUA_ERROR);
    }
  }

  return(CONST_LUA_OK);
}

/* Fetches data from RRD by rows */
static int ntop_rrd_fetch(lua_State* vm) {
  unsigned long i, j, step = 0, ds_cnt = 0;
  rrd_value_t *data, *p;
  char **names;
  char *filename, *cf;
  time_t t, start, end;
  int status;

  if((status = __ntop_rrd_args(vm, &filename, &cf, &start, &end)) != CONST_LUA_OK) return status;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  reset_rrd_state();

  if((status = __ntop_rrd_status(vm, rrd_fetch_r(filename, cf, &start, &end, &step, &ds_cnt, &names, &data), filename, cf)) != CONST_LUA_OK) return status;

  lua_pushnumber(vm, (lua_Number) start);
  lua_pushnumber(vm, (lua_Number) step);
  /* fprintf(stderr, "%lu, %lu, %lu, %lu\n", start, end, step, num_points); */

  /* create the ds names array */
  lua_newtable(vm);
  for(i=0; i<ds_cnt; i++) {
    lua_pushstring(vm, names[i]);
    lua_rawseti(vm, -2, i+1);
    rrd_freemem(names[i]);
  }
  rrd_freemem(names);

  /* create the data points array */
  lua_newtable(vm);
  p = data;
  for(t=start+1, i=0; t<end; t+=step, i++) {
    lua_newtable(vm);
    for(j=0; j<ds_cnt; j++) {
      rrd_value_t value = *p++;

      if(value != DNAN /* Skip NaN */) {
        lua_pushnumber(vm, (lua_Number)value);
        lua_rawseti(vm, -2, j+1);
        // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u / %.f", t, value);
      }
    }
    lua_rawseti(vm, -2, i+1);
  }
  rrd_freemem(data);

  /* return the end as the last value */
  lua_pushnumber(vm, (lua_Number) end);

  /* number of return values: start, step, names, data, end */
  return(5);
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
 *     data: a table, where each key is an RRD name, and the value is its series data
 *      end: the time of the last data in each series
 *  npoints: the number of points in each series
 */
static int ntop_rrd_fetch_columns(lua_State* vm) {
  char *filename, *cf;
  time_t start, end;
  int status;
  unsigned int npoints = 0, i, j;
  char **names;
  unsigned long step = 0, ds_cnt = 0;
  rrd_value_t *data, *p;

  if((status = __ntop_rrd_args(vm, &filename, &cf, &start, &end)) != CONST_LUA_OK) return status;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  reset_rrd_state();

  if((status = __ntop_rrd_status(vm, rrd_fetch_r(filename, cf, &start, &end, &step, &ds_cnt, &names, &data), filename, cf)) != CONST_LUA_OK) return status;

  npoints = (end - start) / step;

  lua_pushnumber(vm, (lua_Number) start);
  lua_pushnumber(vm, (lua_Number) step);

  /* create the data series table */
  lua_createtable(vm, 0, ds_cnt);

  for(i=0; i<ds_cnt; i++) {
    /* a single series table, preallocated */
    lua_createtable(vm, npoints, 0);
    p = data + i;

    for(j=0; j<npoints; j++) {
      rrd_value_t value = *p;
      /* we are accessing data table by columns */
      p = p + ds_cnt;
      lua_pushnumber(vm, (lua_Number)value);
      lua_rawseti(vm, -2, j+1);
    }

    /* add the single series to the series table */
    lua_setfield(vm, -2, names[i]);
    rrd_freemem(names[i]);
  }

  rrd_freemem(names);
  rrd_freemem(data);

  /* end and npoints as last values */
  lua_pushnumber(vm, (lua_Number) end);
  lua_pushnumber(vm, (lua_Number) npoints);

  /* number of return values */
  return(5);
}

/* ****************************************** */

static int ntop_http_redirect(lua_State* vm) {
  char *url, str[512];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  snprintf(str, sizeof(str), "HTTP/1.1 302 Found\r\n"
	   "Location: %s\r\n\r\n"
	   "<html>\n"
	   "<head>\n"
	   "<title>Moved</title>\n"
	   "</head>\n"
	   "<body>\n"
	   "<h1>Moved</h1>\n"
	   "<p>This page has moved to <a href=\"%s\">%s</a>.</p>\n"
	   "</body>\n"
	   "</html>\n", url, url, url);

  lua_pushstring(vm, str);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_http_get(lua_State* vm) {
  char *url, *username = NULL, *pwd = NULL;
  int timeout = 30;
  bool return_content = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 2) == LUA_TSTRING) {
    username = (char*)lua_tostring(vm, 2);

    if(lua_type(vm, 3) == LUA_TSTRING) {
      pwd = (char*)lua_tostring(vm, 3);

      if(lua_type(vm, 4) == LUA_TNUMBER) {
	timeout = lua_tointeger(vm, 4);
	if(timeout < 1) timeout = 1;

	/*
	  This optional parameter specifies if the result of HTTP GET has to be returned
	  to LUA or not. Usually the content has to be returned, but in some causes
	  it just matters to time (for instance when use for testing HTTP services)
	*/
	if(lua_type(vm, 4) == LUA_TBOOLEAN) {
	  return_content = lua_toboolean(vm, 5) ? true : false;
	}
      }
    }
  }

  if(Utils::httpGet(vm, url, username, pwd, timeout, return_content))
    return(CONST_LUA_OK);
  else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_http_get_prefix(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, ntop->getPrefs()->get_http_prefix());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_prefs(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getPrefs()->lua(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_nologin_username(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, NTOP_NOLOGIN_USER);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_users(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getUsers(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_user_group(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getUserGroup(vm);
  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_get_allowed_networks(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getAllowedNetworks(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reset_user_password(lua_State* vm) {
  char *who, *username, *old_password, *new_password;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Username who requested the password change */
  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((who = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((old_password = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((new_password = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if((!Utils::isUserAdministrator(vm)) && (strcmp(who, username)))
    return(CONST_LUA_ERROR);

  return(ntop->resetUserPassword(username, old_password, new_password));
}

/* ****************************************** */

static int ntop_change_user_role(lua_State* vm) {
  char *username, *user_role;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((user_role = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  return ntop->changeUserRole(username, user_role);
}

/* ****************************************** */

static int ntop_change_allowed_nets(lua_State* vm) {
  char *username, *allowed_nets;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((allowed_nets = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  return ntop->changeAllowedNets(username, allowed_nets);
}

/* ****************************************** */

static int ntop_change_allowed_ifname(lua_State* vm) {
  char *username, *allowed_ifname;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((allowed_ifname = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  return ntop->changeAllowedIfname(username, allowed_ifname);
}

/* ****************************************** */

static int ntop_change_user_host_pool(lua_State* vm) {
  char *username, *host_pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((host_pool_id = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  return ntop->changeUserHostPool(username, host_pool_id);
}

/* ****************************************** */

static int ntop_post_http_json_data(lua_State* vm) {
  char *username, *password, *url, *json;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((password = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((json = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(Utils::postHTTPJsonData(username, password, url, json))
    return(CONST_LUA_OK);
  else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_add_user(lua_State* vm) {
  char *username, *full_name, *password, *host_role, *allowed_networks, *allowed_interface, *host_pool_id = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((full_name = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((password = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((host_role = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((allowed_networks = (char*)lua_tostring(vm, 5)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 6, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((allowed_interface = (char*)lua_tostring(vm, 6)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 7) == LUA_TSTRING)
    if((host_pool_id = (char*)lua_tostring(vm, 7)) == NULL) return(CONST_LUA_PARAM_ERROR);

  return ntop->addUser(username, full_name, password, host_role,
		       allowed_networks, allowed_interface, host_pool_id);
}

/* ****************************************** */

static int ntop_add_user_lifetime(lua_State* vm) {
  char *username;
  int32_t num_secs;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_PARAM_ERROR);
  num_secs = (int32_t)lua_tonumber(vm, 2);

  if(num_secs > 0)
    return ntop->addUserLifetime(username, num_secs) ? CONST_LUA_OK : CONST_LUA_ERROR;

  return CONST_LUA_OK; /* Negative or zero lifetimes means unlimited */
}

/* ****************************************** */

static int ntop_clear_user_lifetime(lua_State* vm) {
  char *username;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  return ntop->clearUserLifetime(username) ? CONST_LUA_OK : CONST_LUA_ERROR;
}

/* ****************************************** */

static int ntop_delete_user(lua_State* vm) {
  char *username;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  return ntop->deleteUser(username);
}

/* ****************************************** */

/* Similar to ntop_get_resolved_address but actually perfoms the address resolution now */
static int ntop_resolve_address(lua_State* vm) {
  char *numIP, symIP[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((numIP = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  ntop->resolveHostName(numIP, symIP, sizeof(symIP));
  lua_pushstring(vm, symIP);
  return(CONST_LUA_OK);
}

/* ****************************************** */

void lua_push_str_table_entry(lua_State *L, const char *key, char *value) {
  if(L) {
    lua_pushstring(L, key);
    lua_pushstring(L, value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_nil_table_entry(lua_State *L, const char *key) {
  if(L) {
    lua_pushstring(L, key);
    lua_pushnil(L);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_bool_table_entry(lua_State *L, const char *key, bool value) {
  if(L) {
    lua_pushstring(L, key);
    lua_pushboolean(L, value ? 1 : 0);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_int_table_entry(lua_State *L, const char *key, u_int64_t value) {
  if(L) {
    lua_pushstring(L, key);
    /* using LUA_NUMBER (double: 64 bit) in place of LUA_INTEGER (ptrdiff_t: 32 or 64 bit
     * according to the platform, as defined in luaconf.h) to handle big counters */
    lua_pushnumber(L, (lua_Number)value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_int32_table_entry(lua_State *L, const char *key, int32_t value) {
  if(L) {
    lua_pushstring(L, key);
    lua_pushnumber(L, (lua_Number)value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_float_table_entry(lua_State *L, const char *key, float value) {
  if(L) {
    lua_pushstring(L, key);
    lua_pushnumber(L, value);
    lua_settable(L, -3);
  }
}

/* ****************************************** */

static int ntop_get_interface_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  /*
    ntop_interface->getAlertsManager()->engageAlert(alert_entity_host, "127.0.0.1",
    "min_bytes",
    alert_threshold_exceeded,
    alert_level_warning,
    "miao");
    ntop_interface->getAlertsManager()->releaseAlert(alert_entity_host, "127.0.0.1",
    "min_bytes",
    alert_threshold_exceeded,
    alert_level_warning,
    "miao");
  */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) ntop_interface->lua(vm);
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
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_pro(lua_State *vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_pro_edition());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_enterprise(lua_State *vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_enterprise_edition());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reload_host_pools(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {

    ntop_interface->getHostPools()->reloadPools();

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

#ifdef NTOPNG_PRO

static int ntop_reset_pools_stats(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {
    ntop_interface->resetPoolsStats();

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

static int ntop_purge_expired_host_pools_members(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface && ntop_interface->getHostPools()) {

    ntop_interface->getHostPools()->purgeExpiredVolatileMembers();

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

static int ntop_remove_volatile_member_from_pool(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_or_mac;
  u_int16_t pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((host_or_mac = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_PARAM_ERROR);
  pool_id = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_interface && ntop_interface->getHostPools()) {

    ntop_interface->getHostPools()->removeVolatileMemberFromPool(host_or_mac, pool_id);

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}
#endif
/* ****************************************** */

static int ntop_find_member_pool(lua_State *vm) {
  char *address;
  u_int16_t vlan_id;
  bool is_mac;
  patricia_node_t *target_node = NULL;
  u_int16_t pool_id;
  bool pool_found;
  char buf[64];

  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  if((address = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_PARAM_ERROR);
  vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN)) return(CONST_LUA_PARAM_ERROR);
  is_mac = lua_toboolean(vm, 3);

  if(ntop_interface && ntop_interface->getHostPools()) {
    if(is_mac) {
      u_int8_t mac_bytes[6];
      Utils::parseMac(mac_bytes, address);
      Mac mac(ntop_interface, mac_bytes, vlan_id);

      pool_found = ntop_interface->getHostPools()->findMacPool(&mac, &pool_id);
    } else {
      IpAddress ip;
      ip.set(address);

      pool_found = ntop_interface->getHostPools()->findIpPool(&ip, vlan_id, &pool_id, &target_node);
    }

    if(pool_found) {
      lua_newtable(vm);
      lua_push_int_table_entry(vm, "pool_id", pool_id);

      if(target_node != NULL) {
        lua_push_str_table_entry(vm, "matched_prefix", (char *)inet_ntop(target_node->prefix->family,
									 (target_node->prefix->family == AF_INET6) ?
									 (void*)(&target_node->prefix->add.sin6) :
									 (void*)(&target_node->prefix->add.sin),
									 buf, sizeof(buf)));
        lua_push_int_table_entry(vm, "matched_bitmask", target_node->bit);
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
  u_int16_t vlan_id;
  u_int16_t pool_id;

  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
  mac = lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_PARAM_ERROR);
  vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  Utils::parseMac(mac_parsed, mac);

  if(ntop_interface && ntop_interface->getHostPools()) {
    if(ntop_interface->getHostPools()->findMacPool(mac_parsed, vlan_id, &pool_id))
      lua_pushnumber(vm, pool_id);
    else
      lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* *******************************************/

static int ntop_reload_l7_rules(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_PARAM_ERROR);

  if(ntop_interface) {
#ifdef NTOPNG_PRO
    u_int16_t host_pool_id = (u_int16_t)lua_tonumber(vm, 1);

#ifdef SHAPER_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%i)", __FUNCTION__, host_pool_id);
#endif

    ntop_interface->refreshL7Rules();
    ntop_interface->updateHostsL7Policy(host_pool_id);
    ntop_interface->updateFlowsL7Policy();
#endif

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
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
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

    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_PARAM_ERROR);
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

static int ntop_get_dirs(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "installdir", ntop->get_install_dir());
  lua_push_str_table_entry(vm, "workingdir", ntop->get_working_dir());
  lua_push_str_table_entry(vm, "scriptdir", ntop->getPrefs()->get_scripts_dir());
  lua_push_str_table_entry(vm, "httpdocsdir", ntop->getPrefs()->get_docs_dir());
  lua_push_str_table_entry(vm, "callbacksdir", ntop->getPrefs()->get_callbacks_dir());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_uptime(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushinteger(vm, ntop->getGlobals()->getUptime());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_system_host_stat(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  Utils::luaCpuLoad(vm);
  Utils::luaMeminfo(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_check_license(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef NTOPNG_PRO
  ntop->getPro()->check_license();
#endif

  lua_pushinteger(vm,1);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_info(lua_State* vm) {
  char rsp[256];
  int major, minor, patch;
  bool verbose = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TBOOLEAN)
    verbose = lua_toboolean(vm, 1) ? true : false;

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "product", (char*)"ntopng");
  lua_push_str_table_entry(vm, "copyright", (char*)"&copy; 1998-17 - ntop.org");
  lua_push_str_table_entry(vm, "authors", (char*)"The ntop.org team");
  lua_push_str_table_entry(vm, "license", (char*)"GNU GPLv3");

  lua_push_str_table_entry(vm, "version", (char*)PACKAGE_VERSION);
  lua_push_str_table_entry(vm, "git", (char*)NTOPNG_GIT_RELEASE);

  snprintf(rsp, sizeof(rsp), "%s [%s][%s]",
	   PACKAGE_OSNAME, PACKAGE_MACHINE, PACKAGE_OS);
  lua_push_str_table_entry(vm, "platform", rsp);
  lua_push_str_table_entry(vm, "OS",
#ifdef WIN32
			   (char*)"Windows"
#else
			   (char*)PACKAGE_OS
#endif
			   );
  lua_push_int_table_entry(vm, "bits", (sizeof(void*) == 4) ? 32 : 64);
  lua_push_int_table_entry(vm, "uptime", ntop->getGlobals()->getUptime());
  lua_push_str_table_entry(vm, "command_line", ntop->getPrefs()->get_command_line());

  if(verbose) {
    lua_push_str_table_entry(vm, "version.rrd", rrd_strversion());
    lua_push_str_table_entry(vm, "version.redis", ntop->getRedis()->getVersion(rsp, sizeof(rsp)));
    lua_push_str_table_entry(vm, "version.httpd", (char*)mg_version());
    lua_push_str_table_entry(vm, "version.git", (char*)NTOPNG_GIT_RELEASE);
    lua_push_str_table_entry(vm, "version.luajit", (char*)LUAJIT_VERSION);
#ifdef HAVE_GEOIP
    lua_push_str_table_entry(vm, "version.geoip", (char*)GeoIP_lib_version());
#endif
    lua_push_str_table_entry(vm, "version.ndpi", ndpi_revision());
    lua_push_bool_table_entry(vm, "version.enterprise_edition", ntop->getPrefs()->is_enterprise_edition());
    lua_push_bool_table_entry(vm, "version.embedded_edition", ntop->getPrefs()->is_embedded_edition());

    lua_push_bool_table_entry(vm, "pro.release", ntop->getPrefs()->is_pro_edition());
    lua_push_int_table_entry(vm, "pro.demo_ends_at", ntop->getPrefs()->pro_edition_demo_ends_at());
#ifdef NTOPNG_PRO
    lua_push_str_table_entry(vm, "pro.license", ntop->getPro()->get_license());
    lua_push_bool_table_entry(vm, "pro.out_of_maintenance", ntop->getPro()->is_out_of_maintenance());
    lua_push_bool_table_entry(vm, "pro.use_redis_license", ntop->getPro()->use_redis_license());
    lua_push_str_table_entry(vm, "pro.systemid", ntop->getPro()->get_system_id());
#endif
    lua_push_int_table_entry(vm, "constants.max_num_host_pools", MAX_NUM_HOST_POOLS);
    lua_push_int_table_entry(vm, "constants.max_num_pool_members",    MAX_NUM_POOL_MEMBERS);
    lua_push_int_table_entry(vm, "constants.max_num_profiles",    MAX_NUM_PROFILES);

#if 0
    ntop->getRedis()->get((char*)CONST_STR_NTOPNG_LICENSE, rsp, sizeof(rsp));
    lua_push_str_table_entry(vm, "ntopng.license", rsp);
#endif

    zmq_version(&major, &minor, &patch);
    snprintf(rsp, sizeof(rsp), "%d.%d.%d", major, minor, patch);
    lua_push_str_table_entry(vm, "version.zmq", rsp);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_resolved_address(lua_State* vm) {
  char *key, *tmp,rsp[256],value[64];
  Redis *redis = ntop->getRedis();
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &key, &vlan_id, buf, sizeof(buf));

  if(key == NULL)
    return(CONST_LUA_ERROR);

  if((redis->getAddress(key, rsp, sizeof(rsp), true) == 0) && (rsp[0] != '\0'))
    tmp = rsp;
  else
    tmp = key;

  if(vlan_id != 0)
    snprintf(value, sizeof(value), "%s@%u", tmp, vlan_id);
  else
    snprintf(value, sizeof(value), "%s", tmp);

#if 0
  if(!strcmp(value, key)) {
    char rsp[64];

    if((ntop->getRedis()->hashGet((char*)HOST_LABEL_NAMES, key, rsp, sizeof(rsp)) == 0)
       && (rsp[0] !='\0'))
      lua_pushfstring(vm, "%s", rsp);
    else
      lua_pushfstring(vm, "%s", value);
  } else
    lua_pushfstring(vm, "%s", value);
#else
  lua_pushfstring(vm, "%s", value);
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_snmp_get_fctn(lua_State* vm, int operation) {
  char *agent_host, *oid, *community;
  u_int agent_port = 161, timeout = 5, request_id = (u_int)time(NULL);
  int sock, i = 0, rc = CONST_LUA_OK;
  SNMPMessage *message;
  int len;
  unsigned char *buf;
  bool debug = false;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING))  return(CONST_LUA_ERROR);
  agent_host = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING))  return(CONST_LUA_ERROR);
  community = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING))  return(CONST_LUA_ERROR);
  oid = (char*)lua_tostring(vm, 3);

  /* Optional timeout: take the minimum */
  if(lua_type(vm, 4) == LUA_TNUMBER) timeout = min(timeout, (u_int)lua_tointeger(vm, 4));

  sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

  if(sock < 0) return(CONST_LUA_ERROR);

  message = snmp_create_message();
  snmp_set_version(message, 1 /* SNMPv2c */);
  snmp_set_community(message, community);
  snmp_set_pdu_type(message, operation);
  snmp_set_request_id(message, request_id);
  snmp_set_error(message, 0);
  snmp_set_error_index(message, 0);
  snmp_add_varbind_null(message, oid);

  /* Add additional OIDs */
  i = 4;
  while(lua_type(vm, i) == LUA_TSTRING) {
    snmp_add_varbind_null(message, (char*)lua_tostring(vm, i));
    i++;
  }

  len = snmp_message_length(message);
  buf = (unsigned char*)malloc(len);
  snmp_render_message(message, buf);
  snmp_destroy_message(message);

  send_udp_datagram(buf, len, sock, agent_host, agent_port);
  free(buf);

  if(debug)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "SNMP %s %s@%s %s",
				 (operation == SNMP_GET_REQUEST_TYPE) ? "Get" : "GetNext",
				 agent_host, community, oid);

  if(input_timeout(sock, timeout) == 0) {
    /* Timeout */

    if(debug)
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "SNMP Timeout %s@%s %s", agent_host, community, oid);
    rc = CONST_LUA_ERROR;
    lua_pushnil(vm);
  } else {
    char buf[BUFLEN];
    SNMPMessage *message;
    char *sender_host, *oid_str,  *value_str;
    int sender_port, added = 0, len;

    len = receive_udp_datagram(buf, BUFLEN, sock, &sender_host, &sender_port);
    message = snmp_parse_message(buf, len);

    i = 0;
    while(snmp_get_varbind_as_string(message, i, &oid_str, NULL, &value_str)) {
      if(!added) lua_newtable(vm), added = 1;
      lua_push_str_table_entry(vm, oid_str, value_str);
      if(value_str) free(value_str);
      if(debug)
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "SNMP OK %s@%s %s=%s", agent_host, community, oid_str, value_str);
      i++;
    }

    snmp_destroy_message(message);

    if(!added) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "SNMP Error %s@%s", agent_host, community);
      lua_pushnil(vm), rc = CONST_LUA_ERROR;
    }
  }

  closesocket(sock);
  return(rc);
}

/* ****************************************** */

static int ntop_snmpget(lua_State* vm)     { return(ntop_snmp_get_fctn(vm, SNMP_GET_REQUEST_TYPE)); }
static int ntop_snmpgetnext(lua_State* vm) { return(ntop_snmp_get_fctn(vm, SNMP_GETNEXT_REQUEST_TYPE)); }

/* ****************************************** */

/**
 * @brief Send a message to the system syslog
 * @details Send a message to the syslog syslog: callers can specify if it is an error or informational message
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_ERROR if the expected type is equal to function type, @ref CONST_LUA_PARAM_ERROR otherwise.
 */
static int ntop_syslog(lua_State* vm) {
#ifndef WIN32
  char *msg;
  bool is_error;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN)) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING))  return(CONST_LUA_ERROR);

  is_error = lua_toboolean(vm, 1) ? true : false;
  msg = (char*)lua_tostring(vm, 2);

  syslog(is_error ? LOG_ERR : LOG_INFO, "%s", msg);
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Generate a random value to prevent CSRF and XSRF attacks
 * @details See http://blog.codinghorror.com/preventing-csrf-and-xsrf-attacks/
 *
 * @param vm The lua state.
 * @return The random value just generated
 */
static int ntop_generate_csrf_value(lua_State* vm) {
  char random_a[32], random_b[32], csrf[33], user[64] = { '\0' };
  Redis *redis = ntop->getRedis();
  struct mg_connection *conn;

  lua_getglobal(vm, CONST_HTTP_CONN);
  if((conn = (struct mg_connection*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: null HTTP connection");
    return(CONST_LUA_OK);
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef __OpenBSD__
  snprintf(random_a, sizeof(random_a), "%d", arc4random());
  snprintf(random_b, sizeof(random_b), "%lu", time(NULL)*arc4random());
#else
  snprintf(random_a, sizeof(random_a), "%d", rand());
  snprintf(random_b, sizeof(random_b), "%lu", time(NULL)*rand());
#endif

  mg_get_cookie(conn, "user", user, sizeof(user));
  mg_md5(csrf, random_a, random_b, NULL);

  redis->set(csrf, (char*)user, MAX_CSRF_DURATION);
  lua_pushfstring(vm, "%s", csrf);
  return(CONST_LUA_OK);
}

/* ****************************************** */

struct ntopng_sqlite_state {
  lua_State* vm;
  u_int num_rows;
};

static int sqlite_callback(void *data, int argc,
			   char **argv, char **azColName) {
  struct ntopng_sqlite_state *s = (struct ntopng_sqlite_state*)data;

  lua_newtable(s->vm);

  for(int i=0; i<argc; i++)
    lua_push_str_table_entry(s->vm, (const char*)azColName[i],
			     (char*)(argv[i] ? argv[i] : "NULL"));

  lua_pushinteger(s->vm, ++s->num_rows);
  lua_insert(s->vm, -2);
  lua_settable(s->vm, -3);

  return(0);
}

/* ****************************************** */

/**
 * @brief Exec SQL query
 * @details Execute the specified query and return the results
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_ERROR in case of error, CONST_LUA_OK otherwise.
 */
static int ntop_sqlite_exec_query(lua_State* vm) {
  char *db_path, *db_query;
  sqlite3 *db;
  char *zErrMsg = 0;
  struct ntopng_sqlite_state state;
  struct stat buf;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING))  return(CONST_LUA_ERROR);
  db_path = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING))  return(CONST_LUA_ERROR);
  db_query = (char*)lua_tostring(vm, 2);

  if(stat(db_path, &buf) != 0) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Not found database %s",
				 db_path);
    return(CONST_LUA_ERROR);
  }

  if(sqlite3_open(db_path, &db)) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to open %s: %s",
				 db_path, sqlite3_errmsg(db));
    return(CONST_LUA_ERROR);
  }

  state.vm = vm, state.num_rows = 0;
  lua_newtable(vm);
  if(sqlite3_exec(db, db_query, sqlite_callback, (void*)&state, &zErrMsg)) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "SQL Error: %s", zErrMsg);
    sqlite3_free(zErrMsg);
  }

  sqlite3_close(db);
  return(CONST_LUA_OK);
}

/**
 * @brief Insert a new minute sampling in the historical database
 * @details Given a certain sampling point, store statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_insert_minute_sampling(lua_State *vm) {
  char *sampling;
  time_t rawtime;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((sampling = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  time(&rawtime);

  if(sm->insertMinuteSampling(rawtime, sampling))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/**
 * @brief Insert a new hour sampling in the historical database
 * @details Given a certain sampling point, store statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_insert_hour_sampling(lua_State *vm) {
  char *sampling;
  time_t rawtime;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((sampling = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  time(&rawtime);
  rawtime -= (rawtime % 60);

  if(sm->insertHourSampling(rawtime, sampling))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/**
 * @brief Insert a new day sampling in the historical database
 * @details Given a certain sampling point, store statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_insert_day_sampling(lua_State *vm) {
  char *sampling;
  time_t rawtime;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((sampling = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  time(&rawtime);
  rawtime -= (rawtime % 60);

  if(sm->insertDaySampling(rawtime, sampling))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/**
 * @brief Get a minute sampling from the historical database
 * @details Given a certain sampling point, get statistics for said
 *          sampling point.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_get_minute_sampling(lua_State *vm) {
  time_t epoch;
  string sampling;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  epoch = (time_t)lua_tointeger(vm, 2);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  if(sm->getMinuteSampling(epoch, &sampling))
    return(CONST_LUA_ERROR);

  lua_pushstring(vm, sampling.c_str());

  return(CONST_LUA_OK);
}

/**
 * @brief Delete minute stats older than a certain number of days.
 * @details Given a number of days, delete stats for the current interface that
 *          are older than a certain number of days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_delete_minute_older_than(lua_State *vm) {
  int num_days;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 2);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  if(sm->deleteMinuteStatsOlderThan(num_days))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/**
 * @brief Delete hour stats older than a certain number of days.
 * @details Given a number of days, delete stats for the current interface that
 *          are older than a certain number of days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_delete_hour_older_than(lua_State *vm) {
  int num_days;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 2);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  if(sm->deleteHourStatsOlderThan(num_days))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/**
 * @brief Delete day stats older than a certain number of days.
 * @details Given a number of days, delete stats for the current interface that
 *          are older than a certain number of days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_delete_day_older_than(lua_State *vm) {
  int num_days;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!Utils::isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 2);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  if(sm->deleteDayStatsOlderThan(num_days))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/**
 * @brief Get an interval of minute stats samplings from the historical database
 * @details Given a certain interval of sampling points, get statistics for said
 *          sampling points.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_get_minute_samplings_interval(lua_State *vm) {
  time_t epoch_start, epoch_end;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  epoch_start = lua_tointeger(vm, 2);
  if(epoch_start < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 3);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  if(sm->retrieveMinuteStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
}

/**
 * @brief Given an epoch, get minute stats for the latest n minutes
 * @details Given a certain sampling point, get statistics for that point and
 *          for all timepoints spanning an interval of a given number of
 *          minutes.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_get_samplings_of_minutes_from_epoch(lua_State *vm) {
  time_t epoch_start, epoch_end;
  int num_minutes;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 2);
  epoch_end -= (epoch_end % 60);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  num_minutes = lua_tointeger(vm, 3);
  if(num_minutes < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  epoch_start = epoch_end - (60 * num_minutes);

  if(sm->retrieveMinuteStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
}

/**
 * @brief Given an epoch, get hour stats for the latest n hours
 * @details Given a certain sampling point, get statistics for that point and
 *          for all timepoints spanning an interval of a given number of
 *          hours.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_get_samplings_of_hours_from_epoch(lua_State *vm) {
  time_t epoch_start, epoch_end;
  int num_hours;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 2);
  epoch_end -= (epoch_end % 60);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  num_hours = lua_tointeger(vm, 3);
  if(num_hours < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  epoch_start = epoch_end - (num_hours * 60 * 60);

  if(sm->retrieveHourStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
}

/**
 * @brief Given an epoch, get hour stats for the latest n days
 * @details Given a certain sampling point, get statistics for that point and
 *          for all timepoints spanning an interval of a given number of
 *          days.
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_PARAM_ERROR in case of wrong parameter,
 *              CONST_LUA_ERROR in case of generic error, CONST_LUA_OK otherwise.
 */
static int ntop_stats_get_samplings_of_days_from_epoch(lua_State *vm) {
  time_t epoch_start, epoch_end;
  int num_days;
  int ifid;
  NetworkInterface* iface;
  StatsManager *sm;
  struct statsManagerRetrieval retvals;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 2);
  epoch_end -= (epoch_end % 60);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 3);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(ifid)) ||
     !(sm = iface->getStatsManager()))
    return (CONST_LUA_ERROR);

  epoch_start = epoch_end - (num_days * 24 * 60 * 60);

  if(sm->retrieveDayStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_delete_dump_files(lua_State *vm) {
  int ifid;
  char pcap_path[MAX_PATH];
  NetworkInterface *iface;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  if((ifid = lua_tointeger(vm, 1)) < 0) return(CONST_LUA_ERROR);
  if(!(iface = ntop->getNetworkInterface(ifid))) return(CONST_LUA_ERROR);

  snprintf(pcap_path, sizeof(pcap_path), "%s/%d/pcap/",
	   ntop->get_working_dir(), ifid);
  ntop->fixPath(pcap_path);

  if(Utils::discardOldFilesExceeding(pcap_path, iface->getDumpTrafficMaxFiles()))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_mkdir_tree(lua_State* vm) {
  char *dir;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((dir = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);
  if(dir[0] == '\0')                                   return(CONST_LUA_OK); /* Nothing to do */

  return(Utils::mkdir_tree(dir));
}

/* ****************************************** */

static int ntop_list_reports(lua_State* vm) {
  DIR *dir;
  char fullpath[MAX_PATH];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  snprintf(fullpath, sizeof(fullpath), "%s/%s", ntop->get_working_dir(), "reports");
  ntop->fixPath(fullpath);
  if((dir = opendir(fullpath)) != NULL) {
    struct dirent *ent;

    while ((ent = readdir(dir)) != NULL) {
      char filepath[MAX_PATH];
      snprintf(filepath, sizeof(filepath), "%s/%s", fullpath, ent->d_name);
      ntop->fixPath(filepath);
      struct stat buf;
      if(!stat(filepath, &buf) && !S_ISDIR(buf.st_mode))
	lua_push_str_table_entry(vm, ent->d_name, (char*)"");
    }
    closedir(dir);
  }
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_redis(lua_State* vm) {
  char *key, *rsp;
  u_int rsp_len = 32768;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);


  if((rsp = (char*)malloc(rsp_len)) != NULL) {
    lua_pushfstring(vm, "%s", (redis->get(key, rsp, rsp_len) == 0) ? rsp : (char*)"");
    free(rsp);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_get_hash_redis(lua_State* vm) {
  char *key, *member, rsp[CONST_MAX_LEN_REDIS_VALUE];
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);
  if((member = (char*)lua_tostring(vm, 2)) == NULL)    return(CONST_LUA_PARAM_ERROR);

  lua_pushfstring(vm, "%s", (redis->hashGet(key, member, rsp, sizeof(rsp)) == 0) ? rsp : (char*)"");

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_hash_redis(lua_State* vm) {
  char *key, *member, *value;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);
  if((member = (char*)lua_tostring(vm, 2)) == NULL)    return(CONST_LUA_PARAM_ERROR);
  if((value  = (char*)lua_tostring(vm, 3)) == NULL)    return(CONST_LUA_PARAM_ERROR);

  redis->hashSet(key, member, value);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_del_hash_redis(lua_State* vm) {
  char *key, *member;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);
  if((member = (char*)lua_tostring(vm, 2)) == NULL)    return(CONST_LUA_PARAM_ERROR);

  redis->hashDel(key, member);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_hash_keys_redis(lua_State* vm) {
  char *key, **vals;
  Redis *redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  rc = redis->hashKeys(key, &vals);

  if(rc > 0) {
    lua_newtable(vm);

    for(int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, vals[i] ? vals[i] : "", (char*)"");
      if(vals[i]) free(vals[i]);
    }
    free(vals);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_hash_all_redis(lua_State* vm) {
  char *key, **keys, **values;
  Redis *redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  rc = redis->hashGetAll(key, &keys, &values);

  if(rc > 0) {
    lua_newtable(vm);

    for(int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, keys[i] ? keys[i] : (char *)"", values[i] ? values[i] : (char *)"");
      if(values[i]) free(values[i]);
      if(keys[i]) free(keys[i]);
    }

    free(keys);
    free(values);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_keys_redis(lua_State* vm) {
  char *pattern, **keys;
  Redis *redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((pattern = (char*)lua_tostring(vm, 1)) == NULL)   return(CONST_LUA_PARAM_ERROR);

  rc = redis->keys(pattern, &keys);

  if(rc > 0) {
    lua_newtable(vm);

    for(int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, keys[i] ? keys[i] : "", (char*)"");
      if(keys[i]) free(keys[i]);
    }
    free(keys);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_lrange_redis(lua_State* vm) {
  char *l_name, **l_elements;
  Redis *redis = ntop->getRedis();
  int start_offset = 0, end_offset = -1;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((l_name = (char*)lua_tostring(vm, 1)) == NULL)   return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 2) == LUA_TNUMBER) {
    start_offset = lua_tointeger(vm, 2);
  }
  if(lua_type(vm, 3) == LUA_TNUMBER) {
    end_offset = lua_tointeger(vm, 3);
  }

  rc = redis->lrange(l_name, &l_elements, start_offset, end_offset);

  if(rc > 0) {
    lua_newtable(vm);

    for(int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, l_elements[i] ? l_elements[i] : "", (char*)"");
      if(l_elements[i]) free(l_elements[i]);
    }
    free(l_elements);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_redis_set_pop(lua_State* vm) {
  char *set_name, rsp[CONST_MAX_LEN_REDIS_VALUE];
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((set_name = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  lua_pushfstring(vm, "%s", redis->popSet(set_name, rsp, sizeof(rsp)));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_list_index_redis(lua_State* vm) {
  char *index_name, rsp[CONST_MAX_LEN_REDIS_VALUE];
  Redis *redis = ntop->getRedis();
  int idx;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING))  return(CONST_LUA_ERROR);
  if((index_name = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  idx = lua_tointeger(vm, 2);

  if(redis->lindex(index_name, idx, rsp, sizeof(rsp)) != 0)
    return(CONST_LUA_ERROR);

  lua_pushfstring(vm, "%s", rsp);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_lpop_redis(lua_State* vm) {
  char msg[1024], *list_name;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((list_name = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(redis->lpop(list_name, msg, sizeof(msg)) == 0) {
    lua_pushfstring(vm, "%s", msg);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_lpush_redis(lua_State* vm) {
  char *list_name, *value;
  u_int list_trim_size = 0;  // default 0 = no trim
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((list_name = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  /* Optional trim list up to the specified number of elements */
  if(lua_type(vm, 3) == LUA_TNUMBER)
    list_trim_size = (u_int)lua_tonumber(vm, 3);

  if(redis->lpush(list_name, value, list_trim_size) == 0) {
    return(CONST_LUA_OK);
  }else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_redis_get_host_id(lua_State* vm) {
  char *host_name;
  Redis *redis = ntop->getRedis();
  char daybuf[32];
  time_t when = time(NULL);
  bool new_key;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((host_name = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  strftime(daybuf, sizeof(daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
  lua_pushinteger(vm, redis->host_to_id(ntop_interface, daybuf, host_name, &new_key)); /* CHECK */

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_redis_get_id_to_host(lua_State* vm) {
  char *host_idx, rsp[CONST_MAX_LEN_REDIS_VALUE];
  Redis *redis = ntop->getRedis();
  char daybuf[32];
  time_t when = time(NULL);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((host_idx = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  strftime(daybuf, sizeof(daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
  lua_pushfstring(vm, "%d", redis->id_to_host(daybuf, host_idx, rsp, sizeof(rsp)));

  return(CONST_LUA_OK);
}

/* ****************************************** */
#ifdef NOTUSED
static int ntop_interface_store_alert(lua_State* vm) {
  int ifid;
  NetworkInterface* iface;
  AlertsManager *am;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TTABLE)) return(CONST_LUA_ERROR);

  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getNetworkInterface(vm, ifid)) ||
     !(am = iface->getAlertsManager()))
    return (CONST_LUA_ERROR);

  return am->storeAlert(vm, 2) ? CONST_LUA_ERROR : CONST_LUA_OK;
}
#endif

/* ****************************************** */

static int ntop_interface_engage_release_host_alert(lua_State* vm, bool engage) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  int alert_severity;
  int alert_type;
  int alert_engine;
  char *alert_json, *engaged_alert_id;
  int ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_engine = (int)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 2), &host_ip, &vlan_id, buf, sizeof(buf));

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_ERROR);
  engaged_alert_id = (char*)lua_tostring(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_type = (int)lua_tonumber(vm, 4);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_severity = (int)lua_tonumber(vm, 5);

  if(ntop_lua_check(vm, __FUNCTION__, 6, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_json = (char*)lua_tostring(vm, 6);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ret = ntop_interface->engageReleaseHostAlert(get_allowed_nets(vm), host_ip, vlan_id, engage,
					       (AlertEngine)alert_engine,
					       engaged_alert_id,
					       (AlertType)alert_type, (AlertLevel)alert_severity, alert_json);

  return ret >= 0 ? CONST_LUA_OK : CONST_LUA_ERROR;
}

/* ****************************************** */

static int ntop_interface_engage_release_network_alert(lua_State* vm, bool engage) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *cidr;
  int alert_severity;
  int alert_type;
  int alert_engine;
  char *alert_json, *engaged_alert_id;
  AlertsManager *am;
  int ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_engine = (int)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  cidr = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_ERROR);
  engaged_alert_id = (char*)lua_tostring(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_type = (int)lua_tonumber(vm, 4);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_severity = (int)lua_tonumber(vm, 5);

  if(ntop_lua_check(vm, __FUNCTION__, 6, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_json = (char*)lua_tostring(vm, 6);

  if((!ntop_interface)
     || ((am = ntop_interface->getAlertsManager()) == NULL))
    return(CONST_LUA_ERROR);

  if(engage)
    ret = am->engageNetworkAlert(cidr,
				 (AlertEngine)alert_engine,
				 engaged_alert_id,
				 (AlertType)alert_type, (AlertLevel)alert_severity, alert_json);
  else
    ret = am->releaseNetworkAlert(cidr,
				  (AlertEngine)alert_engine,
				  engaged_alert_id,
				  (AlertType)alert_type, (AlertLevel)alert_severity, alert_json);

  return ret >= 0 ? CONST_LUA_OK : CONST_LUA_ERROR;
}

/* ****************************************** */

static int ntop_interface_engage_release_interface_alert(lua_State* vm, bool engage) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  int alert_severity;
  int alert_type;
  int alert_engine;
  char *alert_json, *engaged_alert_id;
  AlertsManager *am;
  int ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_engine = (int)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  engaged_alert_id = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_type = (int)lua_tonumber(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  alert_severity = (int)lua_tonumber(vm, 4);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_json = (char*)lua_tostring(vm, 5);

  if((!ntop_interface)
     || ((am = ntop_interface->getAlertsManager()) == NULL))
    return(CONST_LUA_ERROR);

  if(engage)
    ret = am->engageInterfaceAlert(ntop_interface,
				   (AlertEngine)alert_engine,
				   engaged_alert_id,
				   (AlertType)alert_type, (AlertLevel)alert_severity, alert_json);
  else
    ret = am->releaseInterfaceAlert(ntop_interface,
				    (AlertEngine)alert_engine,
				    engaged_alert_id,
				    (AlertType)alert_type, (AlertLevel)alert_severity, alert_json);

  return ret >= 0 ? CONST_LUA_OK : CONST_LUA_ERROR;
}

/* ****************************************** */

static int ntop_interface_engage_host_alert(lua_State* vm) {
  return ntop_interface_engage_release_host_alert(vm, true /* engage */);
}

/* ****************************************** */

static int ntop_interface_release_host_alert(lua_State* vm) {
  return ntop_interface_engage_release_host_alert(vm, false /* release */);
}

/* ****************************************** */

static int ntop_interface_engage_network_alert(lua_State* vm) {
  return ntop_interface_engage_release_network_alert(vm, true /* engage */);
}

/* ****************************************** */

static int ntop_interface_release_network_alert(lua_State* vm) {
  return ntop_interface_engage_release_network_alert(vm, false /* release */);
}

/* ****************************************** */

static int ntop_interface_engage_interface_alert(lua_State* vm) {
  return ntop_interface_engage_release_interface_alert(vm, true /* engage */);
}

/* ****************************************** */

static int ntop_interface_release_interface_alert(lua_State* vm) {
  return ntop_interface_engage_release_interface_alert(vm, false /* release */);
}

/* ****************************************** */

static int ntop_interface_get_cached_num_alerts(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  AlertsManager *am;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!iface || !(am = iface->getAlertsManager()))
    return (CONST_LUA_ERROR);

  return (!am->getCachedNumAlerts(vm)) ? CONST_LUA_OK : CONST_LUA_ERROR;
}

/* ****************************************** */

static int ntop_interface_query_alerts_raw(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  AlertsManager *am;
  bool engaged = false;
  char *selection = NULL, *clauses = NULL;
  bool ignore_disabled = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!iface || !(am = iface->getAlertsManager()))
    return (CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TBOOLEAN)
    engaged = lua_toboolean(vm, 1);

  if(lua_type(vm, 2) == LUA_TSTRING)
    if((selection = (char*)lua_tostring(vm, 2)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 3) == LUA_TSTRING)
    if((clauses = (char*)lua_tostring(vm, 3)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 4) == LUA_TBOOLEAN)
    ignore_disabled = lua_toboolean(vm, 4);

  if(am->queryAlertsRaw(vm, engaged, selection, clauses, ignore_disabled))
    return(CONST_LUA_ERROR);

  return (CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_query_flow_alerts_raw(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  AlertsManager *am;
  char *selection = NULL, *clauses = NULL;
  bool ignore_disabled = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!iface || !(am = iface->getAlertsManager()))
    return (CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TSTRING)
    if((selection = (char*)lua_tostring(vm, 1)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 2) == LUA_TSTRING)
    if((clauses = (char*)lua_tostring(vm, 2)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 3) == LUA_TBOOLEAN)
    ignore_disabled = lua_toboolean(vm, 3);

  if(am->queryFlowAlertsRaw(vm, selection, clauses, ignore_disabled))
    return(CONST_LUA_ERROR);

  return (CONST_LUA_OK);
}

/* ****************************************** */

#if NTOPNG_PRO
#ifndef WIN32

static int ntop_nagios_reload_config(lua_State* vm) {
  NagiosManager *nagios = ntop->getNagios();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!nagios) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "%s(): unable to get the nagios manager",
				 __FUNCTION__);
    return(CONST_LUA_ERROR);
  }
  nagios->loadConfig();
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_nagios_send_alert(lua_State* vm) {
  NagiosManager *nagios = ntop->getNagios();
  char *alert_source;
  char *alert_key;
  char *alert_msg;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_source = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_key = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_msg = (char*)lua_tostring(vm, 3);

  nagios->sendAlert(alert_source, alert_key, alert_msg);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_nagios_withdraw_alert(lua_State* vm) {
  NagiosManager *nagios = ntop->getNagios();
  char *alert_source;
  char *alert_key;
  char *alert_msg;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_source = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_key = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING)) return(CONST_LUA_ERROR);
  alert_msg = (char*)lua_tostring(vm, 3);

  nagios->withdrawAlert(alert_source, alert_key, alert_msg);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}
#endif
#endif

/* ****************************************** */

#ifdef NTOPNG_PRO
static int ntop_check_profile_syntax(lua_State* vm) {
  char *filter;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  filter = (char*)lua_tostring(vm, 1);

  lua_pushboolean(vm, ntop_interface ? ntop_interface->checkProfileSyntax(filter) : false);

  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

#ifdef NTOPNG_PRO
static int ntop_reload_traffic_profiles(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    ntop_interface->updateFlowProfiles(); /* Reload profiles in memory */

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

static int ntop_set_redis(lua_State* vm) {
  char *key, *value;
  u_int expire_secs = 0;  // default 0 = no expiration
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  /* Optional key expiration in SECONDS */
  if(lua_type(vm, 3) == LUA_TNUMBER)
    expire_secs = (u_int)lua_tonumber(vm, 3);

  if(redis->set(key, value, expire_secs) == 0) {
    return(CONST_LUA_OK);
  }else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_set_preference(lua_State* vm) {
  char *key, *value;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  if(ntop->getPrefs()->refresh(key, value) == -1 && redis->set(key, value))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_preference(lua_State* vm) {
  char *key, *rsp = NULL;
  u_int rsp_len = 32768;
  int actual_rsp_len = -1;
  Redis *redis = ntop->getRedis();
  RuntimePrefs *prefs = ntop->getPrefs();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if((rsp = (char*)malloc(rsp_len)) != NULL) {
    actual_rsp_len = prefs->hashGet(key, rsp, rsp_len);

    if(actual_rsp_len > 0 || !redis->get(key, rsp, rsp_len))
      lua_pushfstring(vm, "%s", rsp);
    else
      lua_pushstring(vm, "");

    free(rsp);

    return(CONST_LUA_OK);

  } else {
    lua_pushstring(vm, "");
    return(CONST_LUA_ERROR);
  }

}

/* ****************************************** */

static int ntop_lua_http_print(lua_State* vm) {
  struct mg_connection *conn;
  char *printtype;
  int t;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_getglobal(vm, CONST_HTTP_CONN);
  if((conn = (struct mg_connection*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: null HTTP connection");
    return(CONST_LUA_OK);
  }

  /* Handle binary blob */
  if(lua_type(vm, 2) == LUA_TSTRING &&
     (printtype = (char*)lua_tostring(vm, 2)) != NULL)
    if(!strncmp(printtype, "blob", 4)) {
      char *str = NULL;

      if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)) return (CONST_LUA_ERROR);
      if((str = (char*)lua_tostring(vm, 1)) != NULL) {
	int len = strlen(str);

	if(len <= 1)
	  mg_printf(conn, "%c", str[0]);
	else
	  return (CONST_LUA_PARAM_ERROR);
      }

      return (CONST_LUA_OK);
    }

  switch(t = lua_type(vm, 1)) {
  case LUA_TNIL:
    mg_printf(conn, "%s", "nil");
    break;

  case LUA_TBOOLEAN:
    {
      int v = lua_toboolean(vm, 1);

      mg_printf(conn, "%s", v ? "true" : "false");
    }
    break;

  case LUA_TSTRING:
    {
      char *str = (char*)lua_tostring(vm, 1);

      if(str && (strlen(str) > 0))
	mg_printf(conn, "%s", str);
    }
    break;

  case LUA_TNUMBER:
    {
      char str[64];

      snprintf(str, sizeof(str), "%f", (float)lua_tonumber(vm, 1));
      mg_printf(conn, "%s", str);
    }
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(): Lua type %d is not handled",
				 __FUNCTION__, t);
    return(CONST_LUA_ERROR);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

int ntop_lua_cli_print(lua_State* vm) {
  int t;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  switch(t = lua_type(vm, 1)) {
  case LUA_TSTRING:
    {
      char *str = (char*)lua_tostring(vm, 1);

      if(str && (strlen(str) > 0))
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", str);
    }
    break;

  case LUA_TNUMBER:
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%f", (float)lua_tonumber(vm, 1));
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(): Lua type %d is not handled",
				 __FUNCTION__, t);
    return(CONST_LUA_ERROR);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef NTOPNG_PRO
static int __ntop_lua_handlefile(lua_State* L, char *script_path, bool ex)
{
  int rc;
  LuaHandler *lh = new LuaHandler(L, script_path);

  rc = lh->luaL_dofileM(ex);
  delete lh;
  return rc;
}

/* This function is called by Lua scripts when the call require(...) */
static int ntop_lua_require(lua_State* L)
{
  char *script_name;

  if(lua_type(L, 1) != LUA_TSTRING ||
     (script_name = (char*)lua_tostring(L, 1)) == NULL)
    return 0;

  lua_getglobal( L, "package" );
  lua_getfield( L, -1, "path" );

  string cur_path = lua_tostring( L, -1 ), parsed, script_path = "";
  stringstream input_stringstream(cur_path);
  while(getline(input_stringstream, parsed, ';')) {
    /* Example: package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path */
    unsigned found = parsed.find_last_of("?");
    if(found) {
      string s = parsed.substr(0, found) + script_name + ".lua";
      if(Utils::file_exists(s.c_str())) {
	script_path = s;
	break;
      }
    }
  }

  if(script_path == "" ||
     __ntop_lua_handlefile(L, (char *)script_path.c_str(), false))
    return 0;

  return 1;
}

static int ntop_lua_dofile(lua_State* L)
{
  char *script_path;

  if(lua_type(L, 1) != LUA_TSTRING ||
     (script_path = (char*)lua_tostring(L, 1)) == NULL ||
     __ntop_lua_handlefile(L, script_path, true))
    return 0;

  return 1;
}
#endif

/* ****************************************** */

/**
 * @brief Return true if login has been disabled
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK and push the return code into the Lua stack
 */
static int ntop_is_login_disabled(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  bool ret = ntop->getPrefs()->is_localhost_users_login_disabled()
    || !ntop->getPrefs()->is_users_login_enabled();

  lua_pushboolean(vm, ret);

  return(CONST_LUA_OK);
}

/* ****************************************** */

/**
 * @brief Convert the network Id to a symbolic name (network/mask)
 *
 * @param vm The lua state.
 * @return @ref CONST_LUA_OK and push the return code into the Lua stack
 */
static int ntop_network_name_by_id(lua_State* vm) {
  int id;
  char *name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  id = (u_int32_t)lua_tonumber(vm, 1);

  name = ntop->getLocalNetworkName(id);

  lua_pushstring(vm, name ? name : "");

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_logging_level(lua_State* vm) {
  char *lvlStr;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if(ntop->getPrefs()->hasCmdlTraceLevel()) return(CONST_LUA_OK);
  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING))  return(CONST_LUA_ERROR);
  lvlStr = (char*)lua_tostring(vm, 1);
  if(!strcmp(lvlStr, "trace")){
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_TRACE);
  }
  else if(!strcmp(lvlStr, "debug")){
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_DEBUG);
  }
  else if(!strcmp(lvlStr, "info")){
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_INFO);
  }
  else if(!strcmp(lvlStr, "normal")){
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_NORMAL);
  }
  else if(!strcmp(lvlStr, "warning")){
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_WARNING);
  }
  else if(!strcmp(lvlStr, "error")){
    ntop->getTrace()->set_trace_level(TRACE_LEVEL_ERROR);
  }
  else{
    return(CONST_LUA_ERROR);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static const luaL_Reg ntop_interface_reg[] = {
  { "getDefaultIfName",       ntop_get_default_interface_name },
  { "setActiveInterfaceId",   ntop_set_active_interface_id },
  { "getIfNames",             ntop_get_interface_names },
  { "select",                 ntop_select_interface },
  { "getStats",               ntop_get_interface_stats },
  { "resetCounters",          ntop_interface_reset_counters },

  { "getnDPIStats",           ntop_get_ndpi_interface_stats },
  { "getnDPIProtoName",       ntop_get_ndpi_protocol_name },
  { "getnDPIProtoId",         ntop_get_ndpi_protocol_id },
  { "getnDPIProtoCategory",   ntop_get_ndpi_protocol_category },
  { "getnDPIFlowsCount",      ntop_get_ndpi_interface_flows_count },
  { "getFlowsStatus",         ntop_get_ndpi_interface_flows_status },
  { "getnDPIProtoBreed",      ntop_get_ndpi_protocol_breed },
  { "getnDPIProtocols",       ntop_get_ndpi_protocols },
  { "getnDPICategories",      ntop_get_ndpi_categories },
  { "getHostsInfo",           ntop_get_interface_hosts_info },
  { "getLocalHostsInfo",      ntop_get_interface_local_hosts_info },
  { "getRemoteHostsInfo",     ntop_get_interface_remote_hosts_info },
  { "getHostInfo",            ntop_get_interface_host_info },
  { "getGroupedHosts",        ntop_get_grouped_interface_hosts },
  { "getNetworksStats",       ntop_get_interface_networks_stats },
  { "resetPeriodicStats",     ntop_host_reset_periodic_stats },
  { "correlateHostActivity",  ntop_correlate_host_activity },
  { "similarHostActivity",    ntop_similar_host_activity },
  { "getHostActivityMap",     ntop_get_interface_host_activitymap },
  { "restoreHost",            ntop_restore_interface_host },
  { "getFlowsInfo",           ntop_get_interface_flows_info },
  { "getFlowsStats",          ntop_get_interface_flows_stats },
  { "getFlowKey",             ntop_get_interface_flow_key   },
  { "findFlowByKey",          ntop_get_interface_find_flow_by_key },
  { "dropFlowTraffic",        ntop_drop_flow_traffic },
  { "dumpFlowTraffic",        ntop_dump_flow_traffic },
  { "dumpLocalHosts2redis",   ntop_dump_local_hosts_2_redis },
  { "findUserFlows",          ntop_get_interface_find_user_flows },
  { "findPidFlows",           ntop_get_interface_find_pid_flows },
  { "findFatherPidFlows",     ntop_get_interface_find_father_pid_flows },
  { "findNameFlows",          ntop_get_interface_find_proc_name_flows },
  { "listHTTPhosts",          ntop_list_http_hosts },
  { "findHost",               ntop_get_interface_find_host },
  { "updateHostTrafficPolicy", ntop_update_host_traffic_policy },
  { "refreshHostsAlertsConfiguration", ntop_refresh_hosts_alerts_configuration },
  { "setSecondTraffic",       ntop_set_second_traffic },
  { "setHostDumpPolicy",      ntop_set_host_dump_policy },
  { "getPeerHitRate",            ntop_get_host_hit_rate },
  { "getLatestActivityHostsInfo",     ntop_get_interface_latest_activity_hosts_info },
  { "getInterfaceDumpDiskPolicy",     ntop_get_interface_dump_disk_policy },
  { "getInterfaceDumpTapPolicy",      ntop_get_interface_dump_tap_policy },
  { "getInterfaceDumpTapName",        ntop_get_interface_dump_tap_name },
  { "getInterfaceDumpMaxPkts",        ntop_get_interface_dump_max_pkts },
  { "getInterfaceDumpMaxSec",         ntop_get_interface_dump_max_sec },
  { "getInterfaceDumpMaxFiles",       ntop_get_interface_dump_max_files },
  { "getInterfacePacketsDumpedFile",  ntop_get_interface_pkts_dumped_file },
  { "getInterfacePacketsDumpedTap",   ntop_get_interface_pkts_dumped_tap },
  { "getEndpoint",                    ntop_get_interface_endpoint },
  { "isPacketInterface",              ntop_interface_is_packet_interface },
  { "isBridgeInterface",              ntop_interface_is_bridge_interface },
  { "isPcapDumpInterface",            ntop_interface_is_pcap_dump_interface },
  { "isRunning",                      ntop_interface_is_running },
  { "isIdle",                         ntop_interface_is_idle },
  { "setInterfaceIdleState",          ntop_interface_set_idle },
  { "name2id",                        ntop_interface_name2id },
  { "loadDumpPrefs",                  ntop_load_dump_prefs },
  { "loadScalingFactorPrefs",         ntop_load_scaling_factor_prefs },

  /* Mac */
  { "getMacsInfo",                    ntop_get_interface_macs_info },
  { "getMacInfo",                     ntop_get_interface_mac_info },
  { "getMacManufacturers",            ntop_get_interface_macs_manufacturers },

  /* Autonomous Systems */
  { "getASesInfo",                    ntop_get_interface_ases_info },
  { "getASInfo",                      ntop_get_interface_as_info },

  /* VLANs */
  { "getVLANsInfo",                   ntop_get_interface_vlans_info },
  { "getVLANInfo",                    ntop_get_interface_vlan_info } ,
  
  /* L7 */
  { "reloadL7Rules",                  ntop_reload_l7_rules },
  { "reloadShapers",                  ntop_reload_shapers },

  /* Host pools */
  { "reloadHostPools",                ntop_reload_host_pools                },
  { "findMemberPool",                 ntop_find_member_pool                 },
  { "findMacPool",                    ntop_find_mac_pool                    },

#ifdef NTOPNG_PRO
  { "resetPoolsStats",                ntop_reset_pools_stats                },
  { "getHostPoolsStats",              ntop_get_host_pool_interface_stats    },
  { "getHostPoolsVolatileMembers",    ntop_get_host_pool_volatile_members   },
  { "purgeExpiredPoolsMembers",       ntop_purge_expired_host_pools_members },
  { "removeVolatileMemberFromPool",   ntop_remove_volatile_member_from_pool },
  { "getHostUsedQuotasStats",         ntop_get_host_used_quotas_stats       },
  
  /* SNMP */
  { "getSNMPStats",                   ntop_interface_get_snmp_stats },

  /* Flow Devices */
  { "getFlowDevices",                ntop_get_flow_devices     },
  { "getFlowDeviceInfo",             ntop_get_flow_device_info },

#endif

  /* Network Discovery */
  { "discoverHosts",                 ntop_discover_iface_hosts },
      
  /* DB */
  { "execSQLQuery",                  ntop_interface_exec_sql_query },

  /* sFlow */
  { "getSFlowDevices",               ntop_getsflowdevices      },
  { "getSFlowDeviceInfo",            ntop_getsflowdeviceinfo   },

  /* New generation alerts */
  { "getCachedNumAlerts",   ntop_interface_get_cached_num_alerts    },
  { "queryAlertsRaw",       ntop_interface_query_alerts_raw         },
  { "queryFlowAlertsRaw",   ntop_interface_query_flow_alerts_raw    },
  { "engageHostAlert",      ntop_interface_engage_host_alert        },
  { "releaseHostAlert",     ntop_interface_release_host_alert       },
  { "engageNetworkAlert",   ntop_interface_engage_network_alert     },
  { "releaseNetworkAlert",  ntop_interface_release_network_alert    },
  { "engageInterfaceAlert", ntop_interface_engage_interface_alert   },
  { "releaseInterfaceAlert",ntop_interface_release_interface_alert  },
  
  { NULL,                             NULL }
};

/* **************************************************************** */

static const luaL_Reg ntop_reg[] = {
  { "getDirs",        ntop_get_dirs },
  { "getInfo",        ntop_get_info },
  { "getUptime",      ntop_get_uptime },
  { "dumpFile",       ntop_dump_file },
  { "checkLicense",   ntop_check_license },
  { "systemHostStat", ntop_system_host_stat },

  /* Redis */
  { "getCache",        ntop_get_redis },
  { "setCache",        ntop_set_redis },
  { "delCache",        ntop_delete_redis_key },
  { "listIndexCache",  ntop_list_index_redis },
  { "lpushCache",      ntop_lpush_redis },
  { "lpopCache",       ntop_lpop_redis },
  { "lrangeCache",     ntop_lrange_redis },
  { "setMembersCache", ntop_add_set_member_redis },
  { "delMembersCache", ntop_del_set_member_redis },
  { "getMembersCache", ntop_get_set_members_redis },
  { "getHashCache",    ntop_get_hash_redis },
  { "setHashCache",    ntop_set_hash_redis },
  { "delHashCache",    ntop_del_hash_redis },
  { "getHashKeysCache",ntop_get_hash_keys_redis },
  { "getHashAllCache", ntop_get_hash_all_redis },
  { "getKeysCache",    ntop_get_keys_redis },
  { "delHashCache",    ntop_delete_hash_redis_key },
  { "setPopCache",     ntop_get_redis_set_pop },
  { "getHostId",       ntop_redis_get_host_id },
  { "getIdToHost",     ntop_redis_get_id_to_host },

  /* Redis Preferences */
  { "setPref",         ntop_set_preference },
  { "getPref",         ntop_get_preference },

  { "isdir",          ntop_is_dir },
  { "mkdir",          ntop_mkdir_tree },
  { "notEmptyFile",   ntop_is_not_empty_file },
  { "exists",         ntop_get_file_dir_exists },
  { "listReports",    ntop_list_reports },
  { "fileLastChange", ntop_get_file_last_change },
  { "readdir",        ntop_list_dir_files },
  { "rmdir",          ntop_remove_dir_recursively },
  { "zmq_connect",    ntop_zmq_connect },
  { "zmq_disconnect", ntop_zmq_disconnect },
  { "zmq_receive",    ntop_zmq_receive },
  { "getLocalNetworks",  ntop_get_local_networks },
  { "reloadPreferences", ntop_reload_preferences },
  { "setAlertsTemporaryDisabled", ntop_temporary_disable_alerts },

#ifdef NTOPNG_PRO
#ifndef WIN32
  { "sendNagiosAlert",      ntop_nagios_send_alert },
  { "withdrawNagiosAlert",  ntop_nagios_withdraw_alert },
  { "reloadNagiosConfig",   ntop_nagios_reload_config },
#endif
  { "checkProfileSyntax",   ntop_check_profile_syntax },
  { "reloadProfiles",       ntop_reload_traffic_profiles },
#endif

  /* Pro */
  { "isPro",                ntop_is_pro },
  { "isEnterprise",         ntop_is_enterprise },

  /* Historical database */
  { "insertMinuteSampling",        ntop_stats_insert_minute_sampling },
  { "insertHourSampling",          ntop_stats_insert_hour_sampling },
  { "insertDaySampling",           ntop_stats_insert_day_sampling },
  { "getMinuteSampling",           ntop_stats_get_minute_sampling },
  { "deleteMinuteStatsOlderThan",  ntop_stats_delete_minute_older_than },
  { "deleteHourStatsOlderThan",    ntop_stats_delete_hour_older_than },
  { "deleteDayStatsOlderThan",     ntop_stats_delete_day_older_than },
  { "getMinuteSamplingsFromEpoch", ntop_stats_get_samplings_of_minutes_from_epoch },
  { "getHourSamplingsFromEpoch",   ntop_stats_get_samplings_of_hours_from_epoch },
  { "getDaySamplingsFromEpoch",    ntop_stats_get_samplings_of_days_from_epoch },
  { "getMinuteSamplingsInterval",  ntop_stats_get_minute_samplings_interval },

  { "deleteDumpFiles", ntop_delete_dump_files },

  /* Time */
  { "gettimemsec",    ntop_gettimemsec },

  /* Trace */
  { "verboseTrace",   ntop_verbose_trace },

  /* UDP */
  { "send_udp_data",  ntop_send_udp_data },

  /* IP */
  { "inet_ntoa",      ntop_inet_ntoa },
  { "networkPrefix",  ntop_network_prefix },

  /* RRD */
  { "rrd_create",     ntop_rrd_create },
  { "rrd_update",     ntop_rrd_update },
  { "rrd_fetch",      ntop_rrd_fetch  },
  { "rrd_fetch_columns", ntop_rrd_fetch_columns },
  { "rrd_lastupdate", ntop_rrd_lastupdate  },

  /* Prefs */
  { "getPrefs",          ntop_get_prefs },

  /* HTTP */
  { "httpRedirect",   ntop_http_redirect },
  { "httpGet",        ntop_http_get },
  { "getHttpPrefix",  ntop_http_get_prefix },

  /* Admin */
  { "getNologinUser",     ntop_get_nologin_username },
  { "getUsers",           ntop_get_users },
  { "getUserGroup",       ntop_get_user_group },
  { "getAllowedNetworks", ntop_get_allowed_networks },
  { "resetUserPassword",  ntop_reset_user_password },
  { "changeUserRole",     ntop_change_user_role },
  { "changeAllowedNets",  ntop_change_allowed_nets },
  { "changeAllowedIfname",ntop_change_allowed_ifname },
  { "changeUserHostPool", ntop_change_user_host_pool },
  { "addUser",            ntop_add_user },
  { "addUserLifetime",    ntop_add_user_lifetime },
  { "clearUserLifetime",  ntop_clear_user_lifetime },
  { "deleteUser",         ntop_delete_user },
  { "isLoginDisabled",    ntop_is_login_disabled },
  { "getNetworkNameById", ntop_network_name_by_id },

  /* Security */
  { "getRandomCSRFValue",     ntop_generate_csrf_value },

  /* HTTP */
  { "postHTTPJsonData",       ntop_post_http_json_data },

  /* Address Resolution */
  { "resolveName",     ntop_resolve_address },       /* Note: you should use resolveAddress() to call from Lua */
  { "getResolvedName", ntop_get_resolved_address },  /* Note: you should use getResolvedAddress() to call from Lua */

  /* Logging */
  { "syslog",         ntop_syslog },
  { "setLoggingLevel",ntop_set_logging_level },

  /* SNMP */
  { "snmpget",        ntop_snmpget },
  { "snmpgetnext",    ntop_snmpgetnext },

  /* SQLite */
  { "execQuery",      ntop_sqlite_exec_query },

  /* Runtime */
  { "hasVLANs",       ntop_has_vlans },
  { "hasGeoIP",       ntop_has_geoip },
  { "isWindows",      ntop_is_windows },

  /* Host Blacklist */
  { "allocHostBlacklist", ntop_allocHostBlacklist },
  { "swapHostBlacklist",  ntop_swapHostBlacklist  },
  { "addToHostBlacklist", ntop_addToHostBlacklist },

  /* Misc */
  { "getservbyport",      ntop_getservbyport      },
  { "getMacManufacturer", ntop_get_mac_manufacturer },
  { "getSiteCategories",  ntop_get_site_categories },

  { NULL,          NULL}
};

/* ****************************************** */

void Lua::luaRegister(lua_State *L, const ntop_class_reg *reg) {
  static const luaL_Reg _meta[] = { { NULL, NULL } };
  int lib_id, meta_id;

  /* newclass = {} */
  lua_createtable(L, 0, 0);
  lib_id = lua_gettop(L);

  /* metatable = {} */
  luaL_newmetatable(L, reg->class_name);
  meta_id = lua_gettop(L);
  luaL_register(L, NULL, _meta);

  /* metatable.__index = class_methods */
  lua_newtable(L), luaL_register(L, NULL, reg->class_methods);
  lua_setfield(L, meta_id, "__index");

  /* class.__metatable = metatable */
  lua_setmetatable(L, lib_id);

  /* _G["Foo"] = newclass */
  lua_setglobal(L, reg->class_name);
}

void Lua::luaRegisterInternalRegs(lua_State *L) {
  int i;

  ntop_class_reg ntop_lua_reg[] = {
    { "interface", ntop_interface_reg },
    { "ntop",      ntop_reg },
    {NULL,         NULL}
  };

  for(i=0; ntop_lua_reg[i].class_name != NULL; i++)
    Lua::luaRegister(L, &ntop_lua_reg[i]);
}

void Lua::lua_register_classes(lua_State *L, bool http_mode) {
  if(!L) return;

  luaopen_lsqlite3(L);

  Lua::luaRegisterInternalRegs(L);

  if(http_mode) {
    /* Overload the standard Lua print() with ntop_lua_http_print that dumps data on HTTP server */
    lua_register(L, "print", ntop_lua_http_print);
  } else
    lua_register(L, "print", ntop_lua_cli_print);

#ifdef NTOPNG_PRO
  if(ntop->getPro()->has_valid_license()) {
    lua_register(L, "ntopRequire", ntop_lua_require);
    luaL_dostring(L, "table.insert(package.loaders, 1, ntopRequire)");
    lua_register(L, "dofile", ntop_lua_dofile);
  }
#endif
}

/* ****************************************** */

#if 0
/**
 * Iterator over key-value pairs where the value
 * maybe made available in increments and/or may
 * not be zero-terminated.  Used for processing
 * POST data.
 *
 * @param cls user-specified closure
 * @param kind type of the value
 * @param key 0-terminated key for the value
 * @param filename name of the uploaded file, NULL if not known
 * @param content_type mime-type of the data, NULL if not known
 * @param transfer_encoding encoding of the data, NULL if not known
 * @param data pointer to size bytes of data at the
 *              specified offset
 * @param off offset of data in the overall value
 * @param size number of bytes in data available
 * @return MHD_YES to continue iterating,
 *         MHD_NO to abort the iteration
 */
static int post_iterator(void *cls,
			 enum MHD_ValueKind kind,
			 const char *key,
			 const char *filename,
			 const char *content_type,
			 const char *transfer_encoding,
			 const char *data, uint64_t off, size_t size)
{
  struct Request *request = cls;
  char tmp[1024];
  u_int len = min(size, sizeof(tmp)-1);

  memcpy(tmp, &data[off], len);
  tmp[len] = '\0';

  fprintf(stdout, "[POST] [%s][%s]\n", key, tmp);
  return MHD_YES;
}
#endif

/* ****************************************** */

/*
  Run a Lua script from within ntopng (no HTTP GUI)
*/
int Lua::run_script(char *script_path) {
  int rc = 0;

  if(!L) return(-1);

  try {
    luaL_openlibs(L); /* Load base libraries */
    lua_register_classes(L, false); /* Load custom classes */

#ifndef NTOPNG_PRO
    rc = luaL_dofile(L, script_path);
#else
    if(ntop->getPro()->has_valid_license())
      rc = __ntop_lua_handlefile(L, script_path, true);
    else
      rc = luaL_dofile(L, script_path);
#endif

    if(rc != 0) {
      const char *err = lua_tostring(L, -1);

      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path, err);
      rc = -1;
    }
  } catch(...) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s]", script_path);
    rc = -2;
  }

  return(rc);
}

/* ****************************************** */

/* http://www.geekhideout.com/downloads/urlcode.c */

#if 0
/* Converts an integer value to its hex character*/
static char to_hex(char code) {
  static char hex[] = "0123456789abcdef";
  return hex[code & 15];
}

/* ****************************************** */

/* Returns a url-encoded version of str */
/* IMPORTANT: be sure to free() the returned string after use */
static char* http_encode(char *str) {
  char *pstr = str, *buf = (char*)malloc(strlen(str) * 3 + 1), *pbuf = buf;
  while (*pstr) {
    if(isalnum(*pstr) || *pstr == '-' || *pstr == '_' || *pstr == '.' || *pstr == '~')
      *pbuf++ = *pstr;
    else if(*pstr == ' ')
      *pbuf++ = '+';
    else
      *pbuf++ = '%', *pbuf++ = to_hex(*pstr >> 4), *pbuf++ = to_hex(*pstr & 15);
    pstr++;
  }
  *pbuf = '\0';
  return buf;
}
#endif

/* ****************************************** */

void Lua::purifyHTTPParameter(char *param) {
  char *ampersand;
  bool utf8_found = false;

  if((ampersand = strchr(param, '%')) != NULL) {
    /* We allow only a few chars, removing all the others */

    if((ampersand[1] != 0) && (ampersand[2] != 0)) {
      char c;
      char b = ampersand[3];

      ampersand[3] = '\0';
      c = (char)strtol(&ampersand[1], NULL, 16);
      ampersand[3] = b;

      switch(c) {
      case '/':
      case ':':
      case '(':
      case ')':
      case '{':
      case '}':
      case '[':
      case ']':
      case '?':
      case '!':
      case '$':
      case ',':
      case '^':
      case '*':
      case '_':
      case '&':
      case ' ':
      case '=':
      case '<':
      case '>':
      case '@':
      case '#':
	break;

      default:
        if(((u_char)c == 0xC3) && (ampersand[3] == '%')) {
          /* Latin-1 within UTF-8 */
          b = ampersand[6];
          ampersand[6] = '\0';
          c = (char)strtol(&ampersand[4], NULL, 16);
          ampersand[6] = b;

          /* Align to ASCII encoding */
          c |= 0x40;
          utf8_found = true;
        }

	if(!Utils::isPrintableChar(c)) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarded char '0x%02x' in URI [%s]", c, param);
	  ampersand[0] = '\0';
	  return;
	}
      }

      purifyHTTPParameter(utf8_found ? &ampersand[6] : &ampersand[3]);
    } else
      ampersand[0] = '\0';
  }
}

/* ****************************************** */

void Lua::setInterface(const char *user) {
  char key[64], ifname[MAX_INTERFACE_NAME_LEN];
  bool enforce_allowed_interface = false;

  if(user[0] != '\0') {
    // check if the user is restricted to browse only a given interface

    if(snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, user)
       && !ntop->getRedis()->get(key, ifname, sizeof(ifname))) {
      // there is only one allowed interface for the user
      enforce_allowed_interface = true;
      goto set_preferred_interface;
    } else if(snprintf(key, sizeof(key), "ntopng.prefs.%s.ifname", user)
	      && ntop->getRedis()->get(key, ifname, sizeof(ifname)) < 0) {
      // no allowed interface and no default set interface
    set_default_if_name_in_session:
      snprintf(ifname, sizeof(ifname), "%s",
	       ntop->getInterfaceAtId(NULL /* allowed user interface check already enforced */,
				      0)->get_name());
      lua_push_str_table_entry(L, "ifname", ifname);
      ntop->getRedis()->set(key, ifname, 3600 /* 1h */);
    } else {
      goto set_preferred_interface;
    }
  } else {
    // We need to check if ntopng is running with the option --disable-login
    snprintf(key, sizeof(key), "ntopng.prefs.ifname");
    if(ntop->getRedis()->get(key, ifname, sizeof(ifname)) < 0) {
      goto set_preferred_interface;
    }

  set_preferred_interface:
    NetworkInterface *iface;

    if((iface = ntop->getNetworkInterface(NULL /* allowed user interface check already enforced */,
					  ifname)) != NULL) {
      /* The specified interface still exists */
      lua_push_str_table_entry(L, "ifname", iface->get_name());
    } else if(!enforce_allowed_interface) {
      goto set_default_if_name_in_session;
    } else {
      // TODO: handle the case where the user has
      // an allowed interface that is not presently available
      // (e.g., not running?)
    }
  }
}

/* ****************************************** */

void Lua::setParamsTable(lua_State* vm, const char* table_name,
			 const char* query) const {
  char outbuf[FILENAME_MAX];
  char *where;
  char *tok;

  char *query_string = query ? strdup(query) : NULL;

  lua_newtable(L);

  if(query_string) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] %s", query_string);

    tok = strtok_r(query_string, "&", &where);

    while(tok != NULL) {
      char *_equal;

      if(strncmp(tok, "csrf", strlen("csrf")) /* Do not put csrf into the params table */
	 && (_equal = strchr(tok, '='))){
	char *decoded_buf;
        int len;

        _equal[0] = '\0';
        _equal = &_equal[1];
        len = strlen(_equal);

        purifyHTTPParameter(tok), purifyHTTPParameter(_equal);

	// ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %s", tok, _equal);

        if((decoded_buf = (char*)malloc(len+1)) != NULL) {

          Utils::urlDecode(_equal, decoded_buf, len+1);

	  Utils::purifyHTTPparam(tok, true, false);
	  Utils::purifyHTTPparam(decoded_buf, false, false);

	  /* Now make sure that decoded_buf is not a file path */
	  FILE *fd;
	  if((decoded_buf[0] == '.')
	     && ((fd = fopen(decoded_buf, "r"))
		 || (fd = fopen(realpath(decoded_buf, outbuf), "r")))) {

	    ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarded '%s'='%s' as argument is a valid file path",
					 tok, decoded_buf);
	    decoded_buf[0] = '\0';
	    fclose(fd);
	  }

	  /* ntop->getTrace()->traceEvent(TRACE_WARNING, "'%s'='%s'", tok, decoded_buf); */

	  /* put tok and the decoded buffer in to the table */
	  lua_push_str_table_entry(vm, tok, decoded_buf);

          free(decoded_buf);
        } else
          ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      }

      tok = strtok_r(NULL, "&", &where);
    } /* while */
  }

  if(query_string) free(query_string);

  if(table_name)
    lua_setglobal(L, table_name);
  else
    lua_setglobal(L, (char*)"_GET"); /* Default */
}

/* ****************************************** */

int Lua::handle_script_request(struct mg_connection *conn,
			       const struct mg_request_info *request_info,
			       char *script_path) {
  char buf[64], key[64], ifname[MAX_INTERFACE_NAME_LEN];
  char *_cookies, user[64] = { '\0' };
  AddressTree ptree;
  int rc, post_data_len;
  const char * content_type;
  u_int8_t valid_csrf = 1;
  char *post_data = NULL;
  char rsp[32];
  char csrf[64] = { '\0' };

  if(!L) return(-1);

  luaL_openlibs(L); /* Load base libraries */
  lua_register_classes(L, true); /* Load custom classes */

  lua_pushlightuserdata(L, (char*)conn);
  lua_setglobal(L, CONST_HTTP_CONN);

  content_type = mg_get_header(conn, "Content-Type");

  /* Check for POST requests */
  if((strcmp(request_info->request_method, "POST") == 0) &&
     ((content_type != NULL) && (strstr(content_type, "application/x-www-form-urlencoded") == content_type))) {

    if((post_data = (char*)malloc(HTTP_MAX_POST_DATA_LEN * sizeof(char))) == NULL
       || (post_data_len = mg_read(conn, post_data, HTTP_MAX_POST_DATA_LEN)) == 0) {
      valid_csrf = 0;

    } else if(post_data_len > HTTP_MAX_POST_DATA_LEN - 1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Too much data submitted with the form. [post_data_len: %u]", post_data_len);
      valid_csrf = 0;
    } else {
      post_data[post_data_len] = '\0';

      /* CSRF is mandatory in POST request */
      mg_get_var(post_data, post_data_len, "csrf", csrf, sizeof(csrf));
      mg_get_cookie(conn, "user", user, sizeof(user));

      if((ntop->getRedis()->get(csrf, rsp, sizeof(rsp)) == -1)
	 || (strcmp(rsp, user) != 0)) {
#if 0
	const char *msg = "The submitted form is expired. Please reload the page and try again. <p>[ <A HREF=/>Home</A> ]";

	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Invalid CSRF parameter specified [%s][%s][%s][%s]: page expired?",
				     csrf, rsp, user, "csrf");

	return(send_error(conn, 500 /* Internal server error */,
			  msg, PAGE_ERROR, script_path, msg));
#else
	valid_csrf = 0;
#endif
      } else {
	/* Invalidate csrf */
	ntop->getRedis()->del(csrf);
      }
    }

    if(valid_csrf) {
      setParamsTable(L, "_POST", post_data); /* CSRF is valid here, now fill the _POST table with POST parameters */
      if(post_data) {
	free(post_data);
      }
    }
    else
      setParamsTable(L, "_POST", NULL /* Empty */);
  } else
    setParamsTable(L, "_POST", NULL /* Empty */);

  /* Grafana */
  if(!strcmp(request_info->request_method, "POST")
     && ((content_type != NULL) && (strstr(content_type, "application/json") == content_type))
     && !strncmp(request_info->uri, GRAFANA_URL, strlen(GRAFANA_URL))
     && (post_data = (char*)malloc(HTTP_MAX_POST_DATA_LEN * sizeof(char)))) {

    lua_newtable(L);

    if((post_data_len = mg_read(conn, post_data, HTTP_MAX_POST_DATA_LEN)) <= HTTP_MAX_POST_DATA_LEN - 1) {
      post_data[post_data_len + 1] = '\0';
      lua_push_str_table_entry(L, "payload", post_data);
    } else {
      lua_push_nil_table_entry(L, "payload");
    }
    lua_push_str_table_entry(L, "payload", post_data);
    lua_setglobal(L, "_GRAFANA");

    free(post_data);
  }

  /* Put the GET params into the environment */
  if(request_info->query_string)
    setParamsTable(L, "_GET", request_info->query_string);
  else
    setParamsTable(L, "_GET", NULL /* Empty */);

  /* _SERVER */
  lua_newtable(L);
  lua_push_str_table_entry(L, "REQUEST_METHOD", (char*)request_info->request_method);
  lua_push_str_table_entry(L, "URI", (char*)request_info->uri ? (char*)request_info->uri : (char*)"");
  lua_push_str_table_entry(L, "REFERER", (char*)mg_get_header(conn, "Referer") ? (char*)mg_get_header(conn, "Referer") : (char*)"");
  if(request_info->remote_user)  lua_push_str_table_entry(L, "REMOTE_USER", (char*)request_info->remote_user);
  if(request_info->query_string) lua_push_str_table_entry(L, "QUERY_STRING", (char*)request_info->query_string);

  for(int i=0; ((request_info->http_headers[i].name != NULL) 
		&& request_info->http_headers[i].name[0] != '\0'); i++)
    lua_push_str_table_entry(L,
			     request_info->http_headers[i].name,
			     (char*)request_info->http_headers[i].value);  
  lua_setglobal(L, (char*)"_SERVER");

  /* Cookies */
  lua_newtable(L);
  if((_cookies = (char*)mg_get_header(conn, "Cookie")) != NULL) {
    char *cookies = strdup(_cookies);
    char *tok, *where;

    // ntop->getTrace()->traceEvent(TRACE_WARNING, "=> '%s'", cookies);
    tok = strtok_r(cookies, "=", &where);
    while(tok != NULL) {
      char *val;

      while(tok[0] == ' ') tok++;

      if((val = strtok_r(NULL, ";", &where)) != NULL) {
	lua_push_str_table_entry(L, tok, val);
	// ntop->getTrace()->traceEvent(TRACE_WARNING, "'%s'='%s'", tok, val);
      } else
	break;

      tok = strtok_r(NULL, "=", &where);
    }

    free(cookies);
  }
  lua_setglobal(L, "_COOKIE"); /* Like in php */

  /* Put the _SESSION params into the environment */
  lua_newtable(L);

  mg_get_cookie(conn, "user", user, sizeof(user));
  lua_push_str_table_entry(L, "user", user);
  mg_get_cookie(conn, "session", buf, sizeof(buf));
  lua_push_str_table_entry(L, "session", buf);

  // now it's time to set the interface.
  setInterface(user);

  lua_setglobal(L, "_SESSION"); /* Like in php */

  if(user[0] != '\0') {
    char val[255];

    lua_pushlightuserdata(L, user);
    lua_setglobal(L, "user");

    snprintf(key, sizeof(key), "ntopng.user.%s.allowed_nets", user);
    if((ntop->getRedis()->get(key, val, sizeof(val)) != -1)
       && (val[0] != '\0')) {
      ptree.addAddresses(val);
      lua_pushlightuserdata(L, &ptree);
      lua_setglobal(L, CONST_ALLOWED_NETS);
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "SET %p", ptree);
    }

    snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, user);
    if(snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, user)
       && !ntop->getRedis()->get(key, ifname, sizeof(ifname))) {
      if(!ntop->isExistingInterface(ifname)) {
	NetworkInterface *iface = ntop->getFirstInterface();

	ntop->getRedis()->set(key, iface->get_name());
	lua_pushlightuserdata(L, iface);
      } else
	lua_pushlightuserdata(L, ifname);

      lua_setglobal(L, CONST_ALLOWED_IFNAME);
    }
  }


#ifndef NTOPNG_PRO
  rc = luaL_dofile(L, script_path);
#else
  if(ntop->getPro()->has_valid_license())
    rc = __ntop_lua_handlefile(L, script_path, true);
  else
    rc = luaL_dofile(L, script_path);
#endif

  if(rc != 0) {
    const char *err = lua_tostring(L, -1);

    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path, err);
    return(send_error(conn, 500 /* Internal server error */,
		      "Internal server error", PAGE_ERROR, script_path, err));
  }

  return(CONST_LUA_OK);
}

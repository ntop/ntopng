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


#include "ntop_includes.h"

#ifndef _GETOPT_H
#define _GETOPT_H
#endif

#ifndef LIB_VERSION
#define LIB_VERSION "1.4.7"
#endif

extern "C" {
#include "rrd.h"
};

struct keyval string_to_replace[MAX_NUM_HTTP_REPLACEMENTS] = { { NULL, NULL } }; /* TODO remove */
static int live_extraction_num = 0;
static Mutex live_extraction_num_lock;

/* ******************************* */

struct ntopngLuaContext* getUserdata(struct lua_State *vm) {
  if(vm) {
    struct ntopngLuaContext *userdata;

    lua_getglobal(vm, "userdata");
    userdata = (struct ntopngLuaContext*) lua_touserdata(vm, lua_gettop(vm));
    lua_pop(vm, 1); // undo the push done by lua_getglobal

    return(userdata);
  } else
    return(NULL);
}

/* ******************************* */

#ifdef DUMP_STACK
static void stackDump(lua_State *L) {
  int i;
  int top = lua_gettop(L);

  for(i = 1; i <= top; i++) {  /* repeat for each level */
    int t = lua_type(L, i);

    switch(t) {
    case LUA_TSTRING:  /* strings */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %s", i, lua_tostring(L, i));
      break;

    case LUA_TBOOLEAN:  /* booleans */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %s", i, lua_toboolean(L, i) ? "true" : "false");
      break;

    case LUA_TNUMBER:  /* numbers */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %g", i, lua_tonumber(L, i));
      break;

    default:  /* other values */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %s", i, lua_typename(L, t));
      break;
    }
  }
}
#endif

/* ******************************* */

LuaEngine::LuaEngine(lua_State *vm) {
  std::bad_alloc bax;
  void *ctx;
  loaded_script_path = NULL;

#ifdef HAVE_NEDGE
  if(!ntop->getPro()->has_valid_license()) {
    ntop->getGlobals()->shutdown();
    ntop->shutdown();
    exit(0);
  }
#endif

  L = luaL_newstate();

  if(!L) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create a new Lua state.");
    throw bax;
  }

  ctx = (void*)calloc(1, sizeof(struct ntopngLuaContext));

  if(!ctx) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to create a context for the new Lua state.");
    lua_close(L);
    throw bax;
  }

  lua_pushlightuserdata(L, ctx);
  lua_setglobal(L, "userdata");

  if(vm)
    setThreadedActivityData(vm);
}

/* ******************************* */

LuaEngine::~LuaEngine() {
  if(L) {
    struct ntopngLuaContext *ctx;

#ifdef DUMP_STACK
    stackDump(L);
#endif

    ctx = getLuaVMContext(L);

    if(ctx) {
#ifndef HAVE_NEDGE
      SNMP *snmp = ctx->snmp;
      if(snmp) delete snmp;
#endif

      if(ctx->pkt_capture.end_capture > 0) {
	ctx->pkt_capture.end_capture = 0; /* Force stop */
	pthread_join(ctx->pkt_capture.captureThreadLoop, NULL);
      }

      if((ctx->iface != NULL) && ctx->live_capture.pcaphdr_sent)
	ctx->iface->deregisterLiveCapture(ctx);

#ifndef WIN32
      if(ctx->ping != NULL)
	delete ctx->ping;
#endif

      if(ctx->addr_tree != NULL)
        delete ctx->addr_tree;

      if(ctx->flow_acle)
        delete ctx->flow_acle;

      if(ctx->sqlite_hosts_filter)
	free(ctx->sqlite_hosts_filter);

      if(ctx->sqlite_flows_filter)
	free(ctx->sqlite_flows_filter);

      free(ctx);
    }

    lua_close(L);
  }

  if(loaded_script_path) free(loaded_script_path);
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
				 "%s : expected %s[@pos %d], got %s", func,
				 lua_typename(vm, expected_type), pos,
				 lua_typename(vm, lua_type(vm,pos)));
    return(CONST_LUA_PARAM_ERROR);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

void get_host_vlan_info(char* lua_ip, char** host_ip,
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
  else
    (*vlan_id) = 0;
}

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

static int ntop_dump_file(lua_State* vm) {
  char *fname;
  FILE *fd;
  struct mg_connection *conn;

  conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
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
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read file %s", fname);
    return(CONST_LUA_ERROR);
  }
}

/* ****************************************** */

static int ntop_dump_binary_file(lua_State* vm) {
  char *fname;
  FILE *fd;
  struct mg_connection *conn;

  conn = getLuaVMUserdata(vm, conn);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((fname = (char*)lua_tostring(vm, 1)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  ntop->fixPath(fname);
  if((fd = fopen(fname, "rb")) != NULL) {
    char tmp[1024];
    size_t n;

    while((n = fread(tmp, 1, sizeof(tmp), fd)) > 0) {
      if(mg_write(conn, tmp, n) < (int) n) break;
    }

    fclose(fd);
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to read file %s", fname);
    return(CONST_LUA_ERROR);
  }
}

/* ****************************************** */

// ***API***
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

static inline bool matches_allowed_ifname(char *allowed_ifname, char *iface) {
  return (((allowed_ifname == NULL) || (allowed_ifname[0] == '\0')) /* Periodic script / unrestricted user */
	  || (!strncmp(allowed_ifname, iface, strlen(allowed_ifname))));
}

/* ****************************************** */

// ***API***
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

static AddressTree* get_allowed_nets(lua_State* vm) {
  AddressTree *ptree;

  ptree = getLuaVMUserdata(vm, allowedNets);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return(ptree);
}

/* ****************************************** */

static char *getAllowedNetworksHostsSqlFilter(lua_State* vm) {
  /* Lazy initialization */
  if(!getLuaVMUservalue(vm, sqlite_filters_loaded))
    AlertsManager::buildSqliteAllowedNetworksFilters(vm);

  return(getLuaVMUserdata(vm, sqlite_hosts_filter));
}

/* ****************************************** */

static char *getAllowedNetworksFlowsSqlFilter(lua_State* vm) {
  /* Lazy initialization */
  if(!getLuaVMUservalue(vm, sqlite_filters_loaded))
    AlertsManager::buildSqliteAllowedNetworksFilters(vm);

  return(getLuaVMUserdata(vm, sqlite_flows_filter));
}

/* ****************************************** */

static NetworkInterface* getCurrentInterface(lua_State* vm) {
  NetworkInterface *ntop_interface;

  ntop_interface = getLuaVMUserdata(vm, iface);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  return(ntop_interface ? ntop_interface : handle_null_interface(vm));
}

/* ****************************************** */

// ***API***
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

// ***API***
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

#ifndef HAVE_NEDGE
// ***API***
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
  }

  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

// ***API***
static int ntop_get_active_flows_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  nDPIStats ndpi_stats;
  FlowStats stats;
  char *host_ip = NULL;
  u_int16_t vlan_id = 0;
  char buf[64];
  Host *host = NULL;
  Paginator *p = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  /* Optional host */
  if(lua_type(vm, 1) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));
    host = ntop_interface->getHost(host_ip, vlan_id, false /* Not an inline call */);
  }

  if(lua_type(vm, 2) == LUA_TTABLE)
    p->readOptions(vm, 2);

  if(ntop_interface) {
    ntop_interface->getActiveFlowsStats(&ndpi_stats, &stats, get_allowed_nets(vm), host, p);

    lua_newtable(vm);
    ndpi_stats.lua(ntop_interface, vm);
    stats.lua(vm);
  } else
    lua_pushnil(vm);

  if(p) delete p;

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

/* ****************************************** */

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

/* ****************************************** */

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((h = ntop_interface->getHost(host_ip, vlan_id, false /* Not an inline call */)))
    h->luaUsedQuotas(vm);
  else
    lua_newtable(vm);

  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

// ***API***
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

// ***API***
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

// ***API***
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

// ***API***
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

// ***API***
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

// ***API***
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

static int ntop_get_ndpi_protocol_category(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int proto;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proto = (u_int)lua_tonumber(vm, 1);

  ndpi_protocol_category_t category = ntop->get_ndpi_proto_category(proto);

  lua_newtable(vm);
  lua_push_int32_table_entry(vm, "id", category);
  lua_push_str_table_entry(vm, "name", (char*)ntop_interface->get_ndpi_category_name(category));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_ndpi_protocol_category(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  u_int16_t proto;
  ndpi_protocol_category_t category;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  proto = (u_int16_t)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  category = (ndpi_protocol_category_t)lua_tointeger(vm, 2);

  ntop->setnDPIProtocolCategory(proto, category);

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_ptree_clear(lua_State* vm) {
  if(getLuaVMUservalue(vm, addr_tree) != NULL) {
    delete getLuaVMUservalue(vm, addr_tree);
    getLuaVMUservalue(vm, addr_tree) = NULL;
  }

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_ptree_insert(lua_State* vm) {
  char *addr;
  int16_t value;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  addr = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  value = (int16_t)lua_tointeger(vm, 2);

  if(value < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Negative values not allowed in ptreeInsert");
    return(CONST_LUA_ERROR);
  }

  if(getLuaVMUservalue(vm, addr_tree) == NULL) {
    AddressTree *tree = new AddressTree(true);

    if(tree == NULL)
      return(CONST_LUA_ERROR);

    getLuaVMUservalue(vm, addr_tree) = tree;
  }

  lua_pushboolean(vm, getLuaVMUservalue(vm, addr_tree)->addAddress(addr, value));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_ptree_match(lua_State* vm) {
  char *addr;
  int16_t value;
  u_int8_t found_mask;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  addr = (char*)lua_tostring(vm, 1);

  if(!addr) return(CONST_LUA_ERROR);

  if(getLuaVMUservalue(vm, addr_tree) == NULL) {
    /* This corresponds to an empty tree, return no match */
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  }

  value = getLuaVMUservalue(vm, addr_tree)->find(addr, &found_mask);

  if(value == -1) {
    /* Not found */
    lua_pushnil(vm);
  } else
    lua_pushinteger(vm, value);

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
  OperatingSystem os_filter = ((OperatingSystem)-1);
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
  OperatingSystem os_filter = ((OperatingSystem)-1);
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
  if(lua_type(vm, 7) == LUA_TNUMBER)  os_filter            = (OperatingSystem)lua_tointeger(vm, 7);
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

// ***API***
static int ntop_get_grouped_interface_hosts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool show_details = true;
  char *country = NULL;
  OperatingSystem os_filter = ((OperatingSystem)-1);
  char *groupBy = (char*)"column_ip";
  bool filtered_hosts = false;
  u_int16_t vlan_filter = (u_int16_t)-1;
  u_int32_t asn_filter = (u_int32_t)-1;
  u_int16_t pool_filter = (u_int16_t)-1;
  u_int8_t ipver_filter = (u_int8_t)-1;
  int16_t network_filter = -2;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TBOOLEAN) show_details = lua_toboolean(vm, 1) ? true : false;
  if(lua_type(vm, 2) == LUA_TSTRING)  groupBy    = (char*)lua_tostring(vm, 2);
  if(lua_type(vm, 3) == LUA_TSTRING)  country = (char*)lua_tostring(vm, 3);
  if(lua_type(vm, 4) == LUA_TNUMBER)  os_filter      = (OperatingSystem)lua_tointeger(vm, 4);
  if(lua_type(vm, 5) == LUA_TNUMBER)  vlan_filter    = (u_int16_t)lua_tonumber(vm, 5);
  if(lua_type(vm, 6) == LUA_TNUMBER)  asn_filter     = (u_int32_t)lua_tonumber(vm, 6);
  if(lua_type(vm, 7) == LUA_TNUMBER)  network_filter = (int16_t)lua_tonumber(vm, 7);
  if(lua_type(vm, 8) == LUA_TNUMBER)  pool_filter    = (u_int16_t)lua_tonumber(vm, 8);
  if(lua_type(vm, 9) == LUA_TNUMBER)  ipver_filter   = (u_int8_t)lua_tonumber(vm, 9);

  if((!ntop_interface)
     || ntop_interface->getActiveHostsGroup(vm,
					    &begin_slot, walk_all,
					    get_allowed_nets(vm),
					    show_details, location_all,
					    country,
					    vlan_filter, os_filter,
					    asn_filter, network_filter,
					    pool_filter, filtered_hosts, ipver_filter, groupBy) < 0)
    return(CONST_LUA_ERROR);

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

// ***API***
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
  bool walk_all = true;

  if(lua_type(vm, 1) == LUA_TSTRING)  sortColumn = (char*)lua_tostring(vm, 1);
  if(lua_type(vm, 2) == LUA_TNUMBER)  maxHits = (u_int16_t)lua_tonumber(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER)  toSkip = (u_int16_t)lua_tonumber(vm, 3);
  if(lua_type(vm, 4) == LUA_TBOOLEAN) a2zSortOrder = lua_toboolean(vm, 4);
  if(lua_type(vm, 5) == LUA_TBOOLEAN) sourceMacsOnly = lua_toboolean(vm, 5);
  if(lua_type(vm, 6) == LUA_TSTRING)  manufacturer = lua_tostring(vm, 6);
  if(lua_type(vm, 7) == LUA_TNUMBER)  pool_filter = (u_int16_t)lua_tonumber(vm, 7);
  if(lua_type(vm, 8) == LUA_TNUMBER) devtype_filter = (u_int8_t)lua_tonumber(vm, 8);
  if(lua_type(vm, 9) == LUA_TSTRING) location_filter = str_2_location(lua_tostring(vm, 9));

  if(!ntop_interface ||
     ntop_interface->getActiveMacList(vm,
				      &begin_slot, walk_all,
				      0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
				      sourceMacsOnly, manufacturer,
				      sortColumn, maxHits,
				      toSkip, a2zSortOrder, pool_filter, devtype_filter, location_filter) < 0)
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
  u_int32_t begin_slot = 0;
  bool walk_all = false;

  if(lua_type(vm, 1) == LUA_TNUMBER)  begin_slot     = (u_int16_t)lua_tonumber(vm, 1);

  if(!ntop_interface ||
     ntop_interface->getActiveMacList(vm,
				      &begin_slot, walk_all,
				      0, /* bridge InterfaceId - TODO pass Id 0,1 for bridge devices*/
				      sourceMacsOnly, manufacturer,
				      sortColumn, maxHits,
				      toSkip, a2zSortOrder, pool_filter, devtype_filter, location_filter) < 0)
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
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

// ***API***
static int ntop_set_host_operating_system(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip = NULL, buf[64];
  u_int16_t vlan_id = 0;
  OperatingSystem os = os_unknown;
  Host *host;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  os = (OperatingSystem)lua_tointeger(vm, 2);

  host = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id);

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[iface: %s][host_ip: %s][vlan_id: %u][host: %p][os: %u]", ntop_interface->get_name(), host_ip, vlan_id, host, os);
#endif

  if(ntop_interface && host && os < os_max_os && os != os_unknown)
    host->setOS(os);

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_compute_hosts_score(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->computeHostsScore();

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

// ***API***
static int ntop_set_mac_device_type(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *mac = NULL;
  DeviceType dtype = device_unknown;
  bool overwriteType;
  int i;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  mac = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  i = lua_tonumber(vm, 2);
  dtype = (DeviceType)i;
  if(dtype > device_max_type) dtype = device_unknown;

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  overwriteType = (bool)lua_toboolean(vm, 3);

  if((!ntop_interface)
     || (!mac)
     || (!ntop_interface->setMacDeviceType(mac, dtype, overwriteType)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
static int ntop_get_interface_ases_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  Paginator *p = NULL;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TTABLE)
    p->readOptions(vm, 1);

  if(ntop_interface->getActiveASList(vm, p) < 0) {
    if(p) delete(p);
    return(CONST_LUA_ERROR);
  }

  if(p) delete(p);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
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

// ***API***
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

/* ****************************************** */

// ***API***
static int ntop_get_interface_vlan_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int16_t vlan_id;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  vlan_id = (u_int16_t)lua_tonumber(vm, 1);

  if((!ntop_interface)
     || (!ntop_interface->getVLANInfo(vm, vlan_id)))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
static int ntop_get_mac_manufacturer(lua_State* vm) {
  const char *mac = NULL;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  mac = (char*)lua_tostring(vm, 1);

  ntop->getMacManufacturer(mac, vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_host_information(lua_State* vm) {
  struct in_addr management_addr;
  management_addr.s_addr = Utils::getHostManagementIPv4Address();

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "ip", inet_ntoa(management_addr));
  lua_push_str_table_entry(vm, "instance_name", ntop->getPrefs()->get_instance_name());

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef HAVE_NEDGE
static int ntop_set_bind_addr(lua_State* vm, bool http) {
  char *addr, *addr2 = (char *) CONST_LOOPBACK_ADDRESS;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  addr = (char*)lua_tostring(vm, 1);

  if(lua_type(vm, 2) == LUA_TSTRING)
    addr2 = (char*)lua_tostring(vm, 2);

  if(http)
    ntop->getPrefs()->bind_http_to_address(addr, addr2);
  else /* https */
    ntop->getPrefs()->bind_https_to_address(addr, addr2);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_set_http_bind_addr(lua_State* vm) {
  return ntop_set_bind_addr(vm, true /* http */);
}

static int ntop_set_https_bind_addr(lua_State* vm) {
  return ntop_set_bind_addr(vm, false /* https */);
}

#endif

/* ****************************************** */

#ifdef HAVE_NEDGE
static int ntop_shutdown(lua_State* vm) {
  char *action;
  extern AfterShutdownAction afterShutdownAction;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    action = (char*)lua_tostring(vm, 1);

    if(!strcmp(action, "poweroff"))
      afterShutdownAction = after_shutdown_poweroff;
    else if(!strcmp(action, "reboot"))
      afterShutdownAction = after_shutdown_reboot;
    else if(!strcmp(action, "restart_self"))
      afterShutdownAction = after_shutdown_restart_self;
  }

  ntop->getGlobals()->requestShutdown();
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

// ***API***
static int ntop_is_shutdown(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getGlobals()->isShutdownRequested());
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_list_interfaces(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_newtable(vm);
  Utils::listInterfaces(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_ip_cmp(lua_State* vm) {
  IpAddress a, b;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  a.set((char*)lua_tostring(vm, 1));
  b.set((char*)lua_tostring(vm, 2));

  lua_pushinteger(vm, a.compare(&b));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_load_malicious_ja3_hash(lua_State* vm) {
  const char *ja3_hash;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ja3_hash = lua_tostring(vm, 1);

  ntop->loadMaliciousJA3Hash(ja3_hash);
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}
/* ****************************************** */

static int ntop_reload_ja3_hashes(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->reloadJA3Hashes();
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef HAVE_NEDGE
static int ntop_set_routing_mode(lua_State* vm) {
  bool routing_enabled;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  routing_enabled = lua_toboolean(vm, 1);
  ntop->getPrefs()->set_routing_mode(routing_enabled);

  lua_pushnil(vm);

  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

#ifdef HAVE_NEDGE
static int ntop_is_routing_mode(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm,  ntop->getPrefs()->is_routing_mode());

  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

// ***API***
static int ntop_get_interface_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_all));
}

// ***API***
static int ntop_get_interface_local_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_local_only));
}

// ***API***
static int ntop_get_interface_remote_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_remote_only));
}

// ***API***
static int ntop_get_interface_broadcast_domain_hosts_info(lua_State* vm) {
  return(ntop_get_interface_hosts(vm, location_broadcast_domain_only));
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

// ***API***
static int ntop_is_dir(lua_State* vm) {
  char *path;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  lua_pushboolean(vm, Utils::dir_exists(path));

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_is_not_empty_file(lua_State* vm) {
  char *path;
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  rc = (stat(path, &buf) != 0) ? 0 : 1;
  if(rc && (buf.st_size == 0)) rc = 0;
  lua_pushboolean(vm, rc);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_file_dir_exists(lua_State* vm) {
  char *path;
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif
  int rc;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s(%s) called", __FUNCTION__, path ? path : "???");
  rc = (stat(path, &buf) != 0) ? 0 : 1;
  //   ntop->getTrace()->traceEvent(TRACE_ERROR, "%s: %d", path, rc);
  lua_pushboolean(vm, rc);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_file_last_change(lua_State* vm) {
  char *path;
#ifdef WIN32
  struct _stat64 buf;
#else
  struct stat buf;
#endif

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);

  if(stat(path, &buf) == 0)
    lua_pushinteger(vm, (lua_Integer)buf.st_mtime);
  else
    lua_pushinteger(vm, -1); /* not found */

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_interface_has_vlans(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface)
    lua_pushboolean(vm, ntop_interface->hasSeenVlanTaggedPackets());
  else
    lua_pushboolean(vm, 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
static int ntop_interface_has_high_res_ts(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  if(ntop_interface && ntop_interface != ntop->getSystemInterface())
    rv = TimeseriesRing::isRingEnabled(ntop_interface);

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_has_geoip(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->getGeolocation() && ntop->getGeolocation()->isAvailable() ? 1 : 0);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

static int ntop_startCustomCategoriesReload(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop->isnDPIReloadInProgress() || (!ntop->startCustomCategoriesReload())) {
    /* startCustomCategoriesReload, abort */
    lua_pushboolean(vm, false);
    return(CONST_LUA_OK);
  }
  
  lua_pushboolean(vm, true /* can now start reloading */);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_loadCustomCategoryIp(lua_State* vm) {
  char *net;
  ndpi_protocol_category_t catid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  net = (char*)lua_tostring(vm, 1);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  catid = (ndpi_protocol_category_t)lua_tointeger(vm, 2);
  ntop->nDPILoadIPCategory(net, catid);
  
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_loadCustomCategoryHost(lua_State* vm) {
  char *host;
  ndpi_protocol_category_t catid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  host = (char*)lua_tostring(vm, 1);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  catid = (ndpi_protocol_category_t)lua_tointeger(vm, 2);
  ntop->nDPILoadHostnameCategory(host, catid);  
  
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/* NOTE: ntop.startCustomCategoriesReload() must be called before this */
static int ntop_reloadCustomCategories(lua_State* vm) {
  
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Starting category lists reload");
  ntop->reloadCustomCategories();
  
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Category lists reload done");
  ntop->setLastInterfacenDPIReload(time(NULL));
  ntop->setnDPICleanupNeeded(true);

  lua_pushboolean(vm, true /* reload performed */);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_match_custom_category(lua_State* vm) {
  char *host_to_match;
  NetworkInterface *iface;
  unsigned long match;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  iface = ntop->getFirstInterface();

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  host_to_match = (char*)lua_tostring(vm, 1);

  if((!iface) || (ndpi_get_custom_category_match(iface->get_ndpi_struct(), host_to_match, strlen(host_to_match), &match) != 0))
    lua_pushnil(vm);
  else
    lua_pushinteger(vm, (int)match);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_tls_version_name(lua_State* vm) {
  u_int16_t tls_version;
  u_int8_t unknown_version = 0;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  tls_version = (u_int16_t)lua_tonumber(vm, 1);

  lua_pushstring(vm, ndpi_ssl_version2str(tls_version, &unknown_version));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_ipv6(lua_State* vm) {
  char *ip;
  struct in6_addr addr6;
  bool rv;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ip = (char*)lua_tostring(vm, 1);

  if(!ip || (inet_pton(AF_INET6, ip, &addr6) != 1))
    rv = false;
  else
    rv = true;

  lua_pushboolean(vm, rv);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_reload_periodic_scripts(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->reloadPeriodicScripts();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_gainWriteCapabilities(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushnil(vm);
  return(Utils::gainWriteCapabilities() == 0 ? CONST_LUA_OK : CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_dropWriteCapabilities(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushnil(vm);
  return(Utils::dropWriteCapabilities() == 0 ? CONST_LUA_OK : CONST_LUA_ERROR);
}

/* ****************************************** */

// ***API***
static int ntop_getservbyport(lua_State* vm) {
  int port;
  char *proto;
  struct servent *s = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  port = (int)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
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

// ***API***
static int ntop_msleep(lua_State* vm) {
  u_int duration, max_duration = 60000 /* 1 min */;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  duration = (u_int)lua_tonumber(vm, 1);

  if(duration > max_duration) duration = max_duration;

  _usleep(duration*1000);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/* https://www.linuxquestions.org/questions/programming-9/connect-timeout-change-145433/ */
static int non_blocking_connect(int sock, struct sockaddr_in *sa, int timeout) {
  int flags = 0, error = 0, ret = 0;
  fd_set rset, wset;
  socklen_t len = sizeof(error);
  struct timeval  ts;

  ts.tv_sec = timeout, ts.tv_usec = 0;

  //clear out descriptor sets for select
  //add socket to the descriptor sets
  FD_ZERO(&rset);
  FD_SET(sock, &rset);
  wset = rset; //structure assignment ok

#ifdef WIN32
  // Wndows sockets are created in blocking mode by default
  // currently on windows, there is no easy way to obtain the socket's current blocking mode since WSAIsBlocking was deprecated
  u_long f = 1;
  if(ioctlsocket(sock, FIONBIO, &f) != NO_ERROR)
    return -1;
#else
  //set socket nonblocking flag
  if((flags = fcntl(sock, F_GETFL, 0)) < 0)
    return -1;

  if(fcntl(sock, F_SETFL, flags | O_NONBLOCK) < 0)
    return -1;
#endif

  //initiate non-blocking connect
  if( (ret = connect(sock, (struct sockaddr *)sa, sizeof(struct sockaddr_in))) < 0 )
    if(errno != EINPROGRESS)
      return -1;

  if(ret == 0) // then connect succeeded right away
    goto done;

  //we are waiting for connect to complete now
  if( (ret = select(sock + 1, &rset, &wset, NULL, (timeout) ? &ts : NULL)) < 0)
    return -1;

  if(ret == 0) {
    // we had a timeout
    errno = ETIMEDOUT;
    return -1;
  }

  // we had a positivite return so a descriptor is ready
  if(FD_ISSET(sock, &rset) || FD_ISSET(sock, &wset)){
    if(getsockopt(sock, SOL_SOCKET, SO_ERROR,
#ifdef WIN32
		  (char*)
#endif
		  &error, &len) < 0)
      return -1;
  }else
    return -1;

  if(error){  //check if we had a socket error
    errno = error;
    return -1;
  }

 done:
#ifdef WIN32
  f = 0;

  if(ioctlsocket(sock, FIONBIO, &f) != NO_ERROR)
    return -1;
#else
  //put socket back in blocking mode
  if(fcntl(sock, F_SETFL, flags) < 0)
    return -1;
#endif

  return 0;
}

/* ****************************************** */

/* Millisecond sleep */
static int ntop_tcp_probe(lua_State* vm) {
  char *server_ip;
  u_int server_port, timeout = 3;
  int sockfd;
  struct sockaddr_in serv_addr;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  server_ip = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  server_port = (u_int)lua_tonumber(vm, 2);

  if(lua_type(vm, 3) == LUA_TNUMBER) timeout = (u_int16_t)lua_tonumber(vm, 3);

  if((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    return(CONST_LUA_ERROR);

  memset(&serv_addr, '0', sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_port = htons(server_port);
  serv_addr.sin_addr.s_addr = inet_addr(server_ip);

  if(non_blocking_connect(sockfd, &serv_addr, timeout) < 0)
    lua_pushnil(vm);
  else {
    u_int timeout = 1, offset = 0;
    char buf[512];

    while(true) {
      fd_set rset;
      struct timeval tv;
      int rc;

      FD_ZERO(&rset);
      FD_SET(sockfd, &rset);

      tv.tv_sec = timeout, tv.tv_usec = 0;
      rc = select(sockfd + 1, &rset, NULL, NULL, &tv);
      timeout = 0;

      if(rc <= 0)
	break;
      else {
	int l = read(sockfd, &buf[offset], sizeof(buf)-offset-1);

	if(l <= 0)
	  break;
	else
	  offset += l;
      }
    }

    buf[offset] = 0;
    lua_pushstring(vm, buf);
  }

  closesocket(sockfd);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_list_dir_files(lua_State* vm) {
  char *path;
  DIR *dirp;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  path = (char*)lua_tostring(vm, 1);  
  ntop->fixPath(path);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Listing directory %s", path);
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

// ***API***
static int ntop_remove_dir_recursively(lua_State* vm) {
  char *path = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING)
    path = (char*)lua_tostring(vm, 1);

  if(path)
    ntop->fixPath(path);

  lua_pushboolean(vm, path && !Utils::remove_recursively(path) ? true /* OK */ : false /* Errors */);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_gettimemsec(lua_State* vm) {
  struct timeval tp;
  double ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  gettimeofday(&tp, NULL);

  ret = (((double)tp.tv_usec) / (double)1000000) + tp.tv_sec;

  lua_pushnumber(vm, ret);
  return(CONST_LUA_OK);
}


/* ****************************************** */

// ***API***
static int ntop_getticks(lua_State* vm) {
  lua_pushnumber(vm, Utils::getticks());
  return(CONST_LUA_OK);
}


/* ****************************************** */

// ***API***
static int ntop_gettickspersec(lua_State* vm) {
  lua_pushnumber(vm, Utils::gettickspersec());
  return(CONST_LUA_OK);
}

/**
 * @brief Refreshes the timezone after a change
 *
 * @param vm The lua state.
 * @return CONST_LUA_OK.
 */

static int ntop_tzset(lua_State* vm) {
#ifndef WIN32
  tzset();
#endif
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_round_time(lua_State* vm) {
  time_t now;
  u_int32_t rounder;
  bool align_to_localtime;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  now = lua_tonumber(vm, 1);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  rounder = lua_tonumber(vm, 2);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  align_to_localtime = lua_toboolean(vm, 3);

  lua_pushinteger(vm, Utils::roundTime(now, rounder, align_to_localtime ? ntop->get_time_offset() : 0));
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
static int ntop_network_prefix(lua_State* vm) {
  char *address;
  char buf[64];
  u_int8_t mask;
  IpAddress ip;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((address = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  mask = (int)lua_tonumber(vm, 2);

  ip.set(address);
  lua_pushstring(vm, ip.print(buf, sizeof(buf), mask));
  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifndef HAVE_NEDGE
static int ntop_zmq_connect(lua_State* vm) {
  char *endpoint, *topic;
  void *context, *subscriber;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((endpoint = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
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

  getLuaVMUservalue(vm, zmq_context)    = context;
  getLuaVMUservalue(vm, zmq_subscriber) = subscriber;
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

// ***API***
static int ntop_get_redis_stats(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getRedis()->lua(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_delete_redis_key(lua_State* vm) {
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  ntop->getRedis()->del(key);
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_flush_redis(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  lua_pushboolean(vm, (ntop->getRedis()->flushDb() == 0) ? true : false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_add_set_member_redis(lua_State* vm) {
  char *key, *value;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop->getRedis()->sadd(key, value) == 0) {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

// ***API***
static int ntop_del_set_member_redis(lua_State* vm) {
  char *key, *value;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop->getRedis()->srem(key, value) == 0) {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

// ***API***
static int ntop_get_set_members_redis(lua_State* vm) {
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  ntop->getRedis()->smembers(vm, key);
  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifndef HAVE_NEDGE

static int ntop_zmq_disconnect(lua_State* vm) {
  void *context;
  void *subscriber;

  context = getLuaVMUserdata(vm, zmq_context);
  subscriber = getLuaVMUserdata(vm, zmq_subscriber);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  zmq_close(subscriber);
  zmq_ctx_destroy(context);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

#endif

/* ****************************************** */

#ifndef HAVE_NEDGE
static int ntop_zmq_receive(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  void *subscriber;
  int size;
  struct zmq_msg_hdr h;
  char *payload;
  int payload_len;
  zmq_pollitem_t item;
  int rc;

  subscriber = getLuaVMUserdata(vm, zmq_subscriber);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

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
#endif

/* ****************************************** */

// ***API***
static int ntop_reload_preferences(lua_State* vm) {
  lua_newtable(vm);
  ntop->getPrefs()->reloadPrefsFromRedis();

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_reload_plugins(lua_State* vm) {
#ifdef NTOPNG_PRO
  ntop->getPro()->set_plugins_reloaded();
#endif

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_has_plugins_reloaded(lua_State* vm) {
#ifdef NTOPNG_PRO
  lua_pushboolean(vm, ntop->getPro()->has_plugins_reloaded());
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_check_hosts_alerts(lua_State* vm, ScriptPeriodicity p) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else
    ntop_interface->checkHostsAlerts(p, vm);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_check_hosts_alerts_min(lua_State* vm)  { return(ntop_check_hosts_alerts(vm, minute_script)); }
static int ntop_check_hosts_alerts_5min(lua_State* vm) { return(ntop_check_hosts_alerts(vm, five_minute_script)); }
static int ntop_check_hosts_alerts_hour(lua_State* vm) { return(ntop_check_hosts_alerts(vm, hour_script));   }
static int ntop_check_hosts_alerts_day(lua_State* vm)  { return(ntop_check_hosts_alerts(vm, day_script));    }

/* ****************************************** */

static int ntop_check_networks_alerts(lua_State* vm, ScriptPeriodicity p) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else
    ntop_interface->checkNetworksAlerts(p, vm);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_check_networks_alerts_min(lua_State* vm)  { return(ntop_check_networks_alerts(vm, minute_script)); }
static int ntop_check_networks_alerts_5min(lua_State* vm) { return(ntop_check_networks_alerts(vm, five_minute_script)); }
static int ntop_check_networks_alerts_hour(lua_State* vm) { return(ntop_check_networks_alerts(vm, hour_script));   }
static int ntop_check_networks_alerts_day(lua_State* vm)  { return(ntop_check_networks_alerts(vm, day_script));    }

/* ****************************************** */

static int ntop_check_interface_alerts(lua_State* vm, ScriptPeriodicity p) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else
    ntop_interface->checkInterfaceAlerts(p, vm);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_check_interface_alerts_min(lua_State* vm)  { return(ntop_check_interface_alerts(vm, minute_script)); }
static int ntop_check_interface_alerts_5min(lua_State* vm) { return(ntop_check_interface_alerts(vm, five_minute_script)); }
static int ntop_check_interface_alerts_hour(lua_State* vm) { return(ntop_check_interface_alerts(vm, hour_script));   }
static int ntop_check_interface_alerts_day(lua_State* vm)  { return(ntop_check_interface_alerts(vm, day_script));    }

/* ****************************************** */

static int ntop_check_system_scripts(lua_State* vm, ScriptPeriodicity p) {
  ntop->checkSystemScripts(p, vm);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_check_system_scripts_min(lua_State* vm)   { return(ntop_check_system_scripts(vm, minute_script)); }
static int ntop_check_system_scripts_5min(lua_State* vm)  { return(ntop_check_system_scripts(vm, five_minute_script)); }
static int ntop_check_system_scripts_hour(lua_State* vm)  { return(ntop_check_system_scripts(vm, hour_script)); }
static int ntop_check_system_scripts_day(lua_State* vm)   { return(ntop_check_system_scripts(vm, day_script)); }

/* ****************************************** */

static int ntop_check_snmp_device_alerts(lua_State* vm, ScriptPeriodicity p) {
  ntop->checkSNMPDeviceAlerts(p, vm);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

static int ntop_check_snmp_device_alerts_5min(lua_State* vm)  { return(ntop_check_snmp_device_alerts(vm, five_minute_script)); }

/* ****************************************** */

static int ntop_temporary_disable_alerts(lua_State* vm) {
  bool to_disable;
  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  to_disable = lua_toboolean(vm, 1);

  ntop->getPrefs()->set_alerts_status(!to_disable);
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_set_default_file_permissions(lua_State* vm) {
  char *fpath;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  fpath = (char*)lua_tostring(vm, 1);

  if(!fpath)
    return(CONST_LUA_ERROR);

#ifndef WIN32
  chmod(fpath, CONST_DEFAULT_FILE_MODE);
#endif

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_verbose_trace(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, (ntop->getTrace()->get_trace_level() == MAX_TRACE_LEVEL) ? true : false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_send_udp_data(lua_State* vm) {
  int rc, port, sockfd = ntop->getUdpSock();
  char *host, *data;

  if(sockfd == -1)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  host = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  port = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
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
  else {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

// ***API***
static int ntop_script_is_deadline_approaching(lua_State* vm) {
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);

  if(ctx && ctx->deadline && ctx->threaded_activity)
    lua_pushboolean(vm, ctx->threaded_activity->isDeadlineApproaching(ctx->deadline));
  else
    lua_pushboolean(vm, false);

  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_script_get_deadline(lua_State* vm) {
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);

  lua_pushinteger(vm, ctx && ctx->deadline ? ctx->deadline : 0);

  return CONST_LUA_OK;
}

/* ****************************************** */

static bool is_table_empty(lua_State *L, int index) {
    lua_pushnil(L);

    if(lua_next(L, index)) {
      lua_pop(L, 1);
      return(false);
    }

    return(true);
}

/* ****************************************** */

static inline int line_protocol_concat_table_fields(lua_State *L, int index, char *buf, int buf_len,
						    int (*escape_fn)(char *outbuf, int outlen, const char *orig)) {
  bool first = true;
  char val_buf[128];
  int cur_buf_len = 0, n;
  bool write_ok;

  // table traversal from https://www.lua.org/ftp/refman-5.0.pdf
  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
    write_ok = false;

    if(escape_fn)
      n = escape_fn(val_buf, sizeof(val_buf), lua_tostring(L, -1));
    else
      n = snprintf(val_buf, sizeof(val_buf), "%s", lua_tostring(L, -1));

    if(n > 0 && n < (int)sizeof(val_buf)) {
      n = snprintf(buf + cur_buf_len, buf_len - cur_buf_len,
		   "%s%s=%s", first ? "" : ",", lua_tostring(L, -2), val_buf);

      if(n > 0 && n < buf_len - cur_buf_len) {
	write_ok = true;
	cur_buf_len += n;
	if(first) first = false;
      }
    }

    lua_pop(L, 1);
    if(!write_ok)
      goto line_protocol_concat_table_fields_err;
  }

  return cur_buf_len;

 line_protocol_concat_table_fields_err:
  if(buf_len)
    buf[0] = '\0';

  return -1;
}

/* ****************************************** */

static int line_protocol_write_line(lua_State* vm,
				    char *dst_line,
				    int dst_line_len,
				    int (*escape_fn)(char *outbuf, int outlen, const char *orig)) {
  char *schema;
  time_t tstamp;
  int cur_line_len = 0, n;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return -1;
  schema = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return -1;
  tstamp = (time_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TTABLE) != CONST_LUA_OK)  return -1;
  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TTABLE) != CONST_LUA_OK)  return -1;

  /* A line of the protocol is: "iface:traffic,ifid=0 bytes=0 1539358699\n" */

  /* measurement name (with a comma if no tags are found) */
  n = snprintf(dst_line, dst_line_len, is_table_empty(vm, 3) ? "%s" : "%s,", schema);
  if(n < 0 || n >= dst_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* tags */
  n = line_protocol_concat_table_fields(vm, 3, dst_line + cur_line_len, dst_line_len - cur_line_len, escape_fn); // tags
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* space to separate tags and metrics */
  n = snprintf(dst_line + cur_line_len, dst_line_len - cur_line_len, " ");
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* metrics */
  n = line_protocol_concat_table_fields(vm, 4, dst_line + cur_line_len, dst_line_len - cur_line_len, escape_fn); // metrics
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* timestamp (in seconds, not nanoseconds) and a \n */
  n = snprintf(dst_line + cur_line_len, dst_line_len - cur_line_len, " %lu\n", tstamp);
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  return cur_line_len;

 line_protocol_write_line_err:
  if(dst_line_len)
    dst_line[0] = '\0';

  return -1;
}

/* ****************************************** */

/* NOTE: outbuf and unescaped buffers must not overlap.
   Need to escape spaces at least.

   See https://docs.influxdata.com/influxdb/v1.7/write_protocols/line_protocol_tutorial/#special-characters
*/
static inline int influx_escape_char(char *buf, int buf_len, const char *unescaped) {
  int cur_len = 0;

  while(*unescaped) {
    if(cur_len >= buf_len - 2)
      goto influx_escape_char_err;

    switch(*unescaped) {
    case ' ':
      *buf++ = '\\';
      cur_len++;
      /* No break */
    default:
      *buf++ = *unescaped++;
      cur_len++;
      break;
    }
  }

  *buf = '\0';
  return cur_len;

 influx_escape_char_err:
  *(buf - cur_len) = '\0';
  return -1;
}

/* ****************************************** */

/* curl -i -XPOST "http://localhost:8086/write?precision=s&db=ntopng" --data-binary 'profile:traffic,ifid=0,profile=a profile bytes=2506351 1559634840' */
static int ntop_append_influx_db(lua_State* vm) {
  bool rv = false;
  char data[LINE_PROTOCOL_MAX_LINE];
  NetworkInterface *ntop_interface;

  if((ntop_interface = getCurrentInterface(vm))
     && ntop_interface->getTSExporter()
     && line_protocol_write_line(vm, data, sizeof(data), influx_escape_char) >= 0) {
    ntop_interface->getTSExporter()->exportData(data);
    rv = true;
  }

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_flows_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char buf[64];
  char *host_ip = NULL;
  u_int16_t vlan_id = 0;
  Host *host = NULL;
  Paginator *p = NULL;
  int numFlows = -1;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));
    host = ntop_interface->getHost(host_ip, vlan_id, false /* Not an inline call */);
  }

  if(lua_type(vm, 2) == LUA_TTABLE)
    p->readOptions(vm, 2);

  if(ntop_interface
     && (!host_ip || host))
    numFlows = ntop_interface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm), host, p);
  else
    lua_pushnil(vm);

  if(p) delete p;
  return numFlows < 0 ? CONST_LUA_ERROR : CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_get_batched_interface_flows_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char buf[64];
  char *host_ip = NULL;
  u_int16_t vlan_id = 0;
  Host *host = NULL;
  Paginator *p = NULL;
  int numFlows = -1;
  u_int32_t begin_slot = 0;
  bool walk_all = false;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if((p = new(std::nothrow) Paginator()) == NULL)
    return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNUMBER)
    begin_slot = (u_int32_t)lua_tonumber(vm, 1);

  if(lua_type(vm, 2) == LUA_TSTRING) {
    get_host_vlan_info((char*)lua_tostring(vm, 2), &host_ip, &vlan_id, buf, sizeof(buf));
    host = ntop_interface->getHost(host_ip, vlan_id, false /* Not an inline call */);
  }

  if(lua_type(vm, 3) == LUA_TTABLE)
    p->readOptions(vm, 3);

  if(ntop_interface
     && (!host_ip || host))
    numFlows = ntop_interface->getFlows(vm, &begin_slot, walk_all, get_allowed_nets(vm), host, p);
  else
    lua_pushnil(vm);

  if(p) delete p;
  return numFlows < 0 ? CONST_LUA_ERROR : CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_get_grouped_flows(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  Paginator *p = NULL;
  int numGroups = -1;
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
    numGroups = ntop_interface->getFlowsGroup(vm, get_allowed_nets(vm), p, group_col);
  else
    lua_pushnil(vm);

  delete p;

  return numGroups < 0 ? CONST_LUA_ERROR : CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_flows_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) ntop_interface->getFlowsStats(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_network_get_network_stats(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  NetworkStats *ns = c ? c->network : NULL;

  if(ns) {
    lua_newtable(vm);
    ns->lua(vm);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_networks_stats(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface)
    ntop_interface->getNetworksStats(vm, get_allowed_nets(vm));
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
static int ntop_checkpoint_host_talker(lua_State* vm) {
  int ifid;
  NetworkInterface *iface = NULL;
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  ifid = (int)lua_tointeger(vm, 1);
  iface = ntop->getInterfaceById(ifid);

  get_host_vlan_info((char*)lua_tostring(vm, 2), &host_ip, &vlan_id, buf, sizeof(buf));

  if(iface && !iface->isView())
    iface->checkPointHostTalker(vm, host_ip, vlan_id);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_host_info(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
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

static int ntop_get_interface_host_used_ports(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  Host *h;
    
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if(!ntop_interface) return(CONST_LUA_ERROR);

  h = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id);
  
  if(!h)
    return(CONST_LUA_ERROR);
  else {
    h->luaPortsDump(vm);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_get_interface_host_timeseries(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  Host *h;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* Optional VLAN id */
  if(lua_type(vm, 2) == LUA_TNUMBER) vlan_id = (u_int16_t)lua_tonumber(vm, 2);

  if((!ntop_interface) || !(h = ntop_interface->getHost(host_ip, vlan_id, false /* Not an inline call */)))
    return(CONST_LUA_ERROR);
  else {
    h->tsLua(vm);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_get_interface_timeseries(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    ntop_interface->tsLua(vm);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_host_country(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_ip;
  u_int16_t vlan_id = 0;
  char buf[64];
  Host* h = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if((!ntop_interface) || ((h = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id)) == NULL))
    return(CONST_LUA_ERROR);
  else {
    lua_pushstring(vm, h->get_country(buf, sizeof(buf)));
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */
#ifdef NOTUSED
static int ntop_get_grouped_interface_host(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *country_s = NULL, *os_s = NULL;
  u_int16_t vlan_n,    *vlan_ptr    = NULL;
  u_int32_t as_n,      *as_ptr      = NULL;
  int16_t   network_n, *network_ptr = NULL;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TNUMBER) vlan_n    = (u_int16_t)lua_tonumber(vm, 1), vlan_ptr  = &vlan_n;
  if(lua_type(vm, 2) == LUA_TNUMBER) as_n      = (u_int32_t)lua_tonumber(vm, 2), as_ptr    = &as_n;
  if(lua_type(vm, 3) == LUA_TNUMBER) network_n = (int16_t)lua_tonumber(vm, 3), network_ptr = &network_n;
  if(lua_type(vm, 4) == LUA_TSTRING) country_s = (char*)lua_tostring(vm, 4);
  if(lua_type(vm, 5) == LUA_TSTRING) os_s      = (char*)lua_tostring(vm, 5);

  if(!ntop_interface
     || ntop_interface->getActiveHostsGroup(vm,
					    &begin_slot, walk_all,
					    get_allowed_nets(vm), false, false,
					    country_s, vlan_ptr, os_s, as_ptr,
					    network_ptr, (char*)"column_ip", (char*)"country",
					    CONST_MAX_NUM_HITS, 0 /* toSkip */, true /* a2zSortOrder */) < 0)
    return(CONST_LUA_ERROR);

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

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      if(Utils::gainWriteCapabilities() == -1)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

      d = ntop_interface->getNetworkDiscovery();

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      Utils::dropWriteCapabilities();
#endif

      if(d)
	d->arpScan(vm);
    } catch(...) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to perform network scan");
#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
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

#ifndef HAVE_NEDGE
static int ntop_snmp_batch_get(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *oid[SNMP_MAX_NUM_OIDS] = { NULL };
  SNMP *snmp;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  oid[0] = (char*)lua_tostring(vm, 3);

  snmp = getLuaVMUserdata(vm, snmp);

  if(snmp == NULL) {
    snmp = new SNMP();

    if(!snmp) return(CONST_LUA_ERROR);
    getLuaVMUservalue(vm, snmp) = snmp;
  }

  snmp->send_snmp_request((char*)lua_tostring(vm, 1),
			  (char*)lua_tostring(vm, 2),
			  false /* SNMP GET */, oid,
			  (u_int)lua_tonumber(vm, 4));

  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

#ifndef HAVE_NEDGE
static int ntop_snmp_read_responses(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  SNMP *snmp;

  snmp = getLuaVMUserdata(vm, snmp);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((!ntop_interface) || (!snmp))
    return(CONST_LUA_ERROR);

  snmp->snmp_fetch_responses(vm);
  return(CONST_LUA_OK);
}
#endif

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

// ***API***
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

// ***API***
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
  u_int16_t vlan_id = 0;
  bool skip_privileges_check = false;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  /* make sure skip privileges check cannot be set from the web interface */
  if(lua_type(vm, 2) == LUA_TBOOLEAN) skip_privileges_check = lua_toboolean(vm, 2);

  if(!skip_privileges_check && !ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if((!ntop_interface) || !ntop_interface->restoreHost(host_ip, vlan_id))
    return(CONST_LUA_ERROR);
  else {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

// ***API***
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
     ||(cli = ntop_interface->getHost(cli_name, cli_vlan, false /* Not an inline call */)) == NULL
     ||(srv = ntop_interface->getHost(srv_name, srv_vlan, false /* Not an inline call */)) == NULL) {
    lua_pushnil(vm);
  } else
    lua_pushinteger(vm, Flow::key(cli, cli_port, srv, srv_port, cli_vlan, protocol));

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_find_flow_by_key_and_hash_id(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  u_int32_t key;
  u_int hash_id;
  Flow *f;
  AddressTree *ptree = get_allowed_nets(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  key = (u_int32_t)lua_tonumber(vm, 1);
  hash_id = (u_int)lua_tonumber(vm, 2);

  if(!ntop_interface) return(false);

  f = ntop_interface->findFlowByKeyAndHashId(key, hash_id, ptree);

  if(f == NULL)
    return(CONST_LUA_ERROR);
  else {
    f->lua(vm, ptree, details_high, false);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

// ***API***
static int ntop_get_interface_find_flow_by_tuple(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  IpAddress src_ip_addr, dst_ip_addr;
  u_int16_t vlan_id, src_port, dst_port;
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

  f = ntop_interface->findFlowByTuple(vlan_id, &src_ip_addr, &dst_ip_addr, htons(src_port), htons(dst_port), l4_proto, ptree);

  if(f == NULL)
    return(CONST_LUA_ERROR);
  else {
    f->lua(vm, ptree, details_high, false);
    return(CONST_LUA_OK);
  }
}

/* ****************************************** */

// ***API***
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

  if(f == NULL)
    return(CONST_LUA_ERROR);
  else {
    f->setDropVerdict();
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  }
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

// ***API***
static int ntop_get_interface_find_host(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *key;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  key = (char*)lua_tostring(vm, 1);

  if(!ntop_interface) return(CONST_LUA_ERROR);
  ntop_interface->findHostsByName(vm, get_allowed_nets(vm), key);
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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
  /* TODO check if we need lua_pushnil(vm); in case of no match */
  return(CONST_LUA_OK);
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
  u_int16_t vlan_id = 0;
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

// ***API***
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

// ***API***
static int ntop_interface_is_view(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isView();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
static int ntop_interface_is_viewed(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isViewed();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_interface_is_loopback(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isLoopback();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_interface_is_running(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->isRunning();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_interface_is_idle(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(ntop_interface) rv = ntop_interface->idle();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
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

// ***API***
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
    u_int16_t vlan_id = 0;

    get_host_vlan_info((char*)lua_tostring(vm, 1), &key, &vlan_id, host_ip, sizeof(host_ip));

    if((!ntop_interface) || ((h = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id)) == NULL))
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

// ***API***
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

// ***API***
static int ntop_get_ndpi_protocols(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  ndpi_protocol_category_t category_filter = (ndpi_protocol_category_t)((u_int8_t)-1);
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

// ***API***
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
  u_int16_t vlan_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop_interface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if((host = ntop_interface->getHost(host_ip, vlan_id, false /* Not an inline call */)))
    host->reloadPrefs();

  lua_pushboolean(vm, (host != NULL));
  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef HAVE_NEDGE

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

static int ntop_set_lan_interface(lua_State* vm) {
  char *lan_ifname;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  lan_ifname = (char*)lua_tostring(vm, 1);

  ntop->getPrefs()->set_lan_interface(lan_ifname);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_refresh_device_protocols_policies_pref(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getPrefs()->refreshDeviceProtocolsPolicyPref();

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

static int ntop_update_flows_shapers(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface)
    ntop_interface->updateFlowsL7Policy();

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

static const char **make_argv(lua_State * vm, int *argc_out, u_int offset, int extra_args) {
  const char **argv;
  int i;
  int argc = lua_gettop(vm) + 1 - offset + extra_args;

  if(!(argv = (const char**)calloc(argc, sizeof (char *))))
    /* raise an error and never return */
    luaL_error(vm, "Can't allocate memory for arguments array");

  /* fprintf(stderr, "%s\n", argv[0]); */
  for(i=0; i<argc; i++) {
    if(i < extra_args) {
      argv[i] = ""; /* put an empty extra argument */
    } else {
      int idx = (i-extra_args) + offset;

      /* accepts string or number */
      if(lua_isstring(vm, idx) || lua_isnumber(vm, idx)) {
        if(!(argv[i] = (char*)lua_tostring (vm, idx))) {
          /* raise an error and never return */
          luaL_error(vm, "Error duplicating string area for arg #%d", i);
        }
        //printf("@%u: %s\n", i, argv[i]);
      } else {
        /* raise an error and never return */
        luaL_error(vm, "Invalid arg #%d: args must be strings or numbers", i);
      }
    }

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%d] %s", i, argv[i]);
  }

  *argc_out = argc;
  return(argv);
}

/* ****************************************** */

#if defined(HAVE_NINDEX) && defined(NTOPNG_PRO)

static int ntop_nindex_select(lua_State* vm) {
  u_int8_t id = 1;
  char *select = NULL, *where = NULL;
  bool use_aggregated_flows, export_results = false;
  char *timestamp_begin, *timestamp_end;
  unsigned long skip_initial_records, max_num_hits;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  NIndexFlowDB *nindex;
  struct mg_connection *conn;

  if(!ntop_interface)
    return(CONST_LUA_ERROR);
  else {
    nindex = ntop_interface->getNindex();
    if(!nindex) return(CONST_LUA_ERROR);
  }

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  use_aggregated_flows = lua_toboolean(vm, id++) ? true : false;

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((timestamp_begin = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((timestamp_end = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((select = (char*)lua_tostring(vm, id++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  where = (char*)lua_tostring(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  skip_initial_records = (unsigned long)lua_tonumber(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  max_num_hits = (unsigned long)lua_tonumber(vm, id++);

  if(lua_type(vm, id) == LUA_TBOOLEAN)
    export_results = lua_toboolean(vm, id++) ? true : false;

  conn = getLuaVMUserdata(vm, conn);

  return(nindex->select(vm, use_aggregated_flows,
			timestamp_begin, timestamp_end, select,
			where, skip_initial_records, max_num_hits,
			export_results ? conn : NULL));
}

/* ****************************************** */

static int ntop_nindex_topk(lua_State* vm) {
  u_int8_t id = 1;
  char *select_keys = NULL, *select_values = NULL,*where = NULL;
  bool use_aggregated_flows;
  char *timestamp_begin, *timestamp_end;
  unsigned long skip_initial_records, max_num_hits;
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

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  use_aggregated_flows = lua_toboolean(vm, id++) ? true : false;

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
  skip_initial_records = (unsigned long)lua_tonumber(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  max_num_hits = (unsigned long)lua_tonumber(vm, id++);

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  topToBottomSort = lua_toboolean(vm, id++) ? true : false;

  if(ntop_lua_check(vm, __FUNCTION__, id, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  useApproxQuery = lua_toboolean(vm, id++) ? true : false;

  return(nindex->topk(vm, use_aggregated_flows,
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

      if(h->ts.tv_sec > c->pkt_capture.end_capture)
	break;
    } else if(rc < 0) {
      break;
    } else if(rc == 0) {
      if(time(NULL) > c->pkt_capture.end_capture)
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

static int ntop_rrd_create(lua_State* vm) {
  const char *filename;
  unsigned long pdp_step;
  const char **argv;
  int argc, status, offset = 3;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((filename = (const char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  pdp_step = (unsigned long)lua_tonumber(vm, 2);

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  argv = make_argv(vm, &argc, offset, 0);

  reset_rrd_state();
  status = rrd_create_r(filename, pdp_step, time(NULL)-86400 /* 1 day */, argc, argv);
  free(argv);

  if(status != 0) {
    char *err = rrd_get_error();

    if(err != NULL) {
      char error_buf[256];
      snprintf(error_buf, sizeof(error_buf), "Unable to create %s [%s]", filename, err);

      lua_pushstring(vm, error_buf);
    } else
      lua_pushstring(vm, "Unknown RRD error");
  } else {
    lua_pushnil(vm);
    chmod(filename, CONST_DEFAULT_FILE_MODE);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_rrd_update(lua_State* vm) {
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);
  const char *filename, *when = NULL, *v1 = NULL, *v2 = NULL, *v3 = NULL;
  int status;
  ticks ticks_duration;
#ifdef WIN32
  struct _stat64 s;
#else
  struct stat s;
#endif

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((filename = (const char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(stat(filename, &s) != 0) {
    char error_buf[256];

    snprintf(error_buf, sizeof(error_buf), "File %s does not exist", filename);
    lua_pushstring(vm, error_buf);

    return(CONST_LUA_OK);
  }

  if(lua_type(vm, 2) == LUA_TSTRING) {
    if((when = (const char*)lua_tostring(vm, 2)) == NULL)
      return(CONST_LUA_PARAM_ERROR);
  } else if(lua_type(vm, 2) != LUA_TNIL)
    return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 3) == LUA_TSTRING) v1 = (const char*)lua_tostring(vm, 3);
  if(lua_type(vm, 4) == LUA_TSTRING) v2 = (const char*)lua_tostring(vm, 4);
  if(lua_type(vm, 5) == LUA_TSTRING) v3 = (const char*)lua_tostring(vm, 5);

  /* Apparently RRD does not like static buffers, so we need to malloc */
  u_int buf_len = 64;
  char *buf = (char*)malloc(buf_len);

  if(buf) {
    snprintf(buf, buf_len, "%s:%s%s%s%s%s",
	     when ? when : "N", v1,
	     v2 ? ":" : "", v2 ? v2 : "",
	     v3 ? ":" : "", v3 ? v3 : "");

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%s) %s", __FUNCTION__, filename, buf);

    ticks_duration = Utils::getticks();
    reset_rrd_state();
    status = rrd_update_r(filename, NULL, 1, (const char**)&buf);
    ticks_duration = Utils::getticks() - ticks_duration;

    if(ctx && ctx->threaded_activity_stats)
      ctx->threaded_activity_stats->updateRRDWriteStats(ticks_duration);

    if(status != 0) {
      char *err = rrd_get_error();

      if(err != NULL) {
        char error_buf[256];

        snprintf(error_buf, sizeof(error_buf), "rrd_update_r() [%s][%s] failed [%s]", filename, buf, err);
        lua_pushstring(vm, error_buf);
      } else
        lua_pushstring(vm, "Unknown RRD error");
    } else
      lua_pushnil(vm);

    free(buf);
    return(CONST_LUA_OK);
  }

  return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_rrd_get_lastupdate(const char *filename, time_t *last_update, unsigned long *ds_count) {
  char    **ds_names;
  char    **last_ds;
  unsigned long i;
  int status;

  reset_rrd_state();
  status = rrd_lastupdate_r(filename, last_update, ds_count, &ds_names, &last_ds);

  if(status != 0) {
    return(-1);
  } else {
    for(i = 0; i < *ds_count; i++)
      free(last_ds[i]), free(ds_names[i]);

    free(last_ds), free(ds_names);
    return(0);
  }
}

/* ****************************************** */

static int ntop_rrd_lastupdate(lua_State* vm) {
  const char *filename;
  time_t    last_update;
  unsigned long ds_count;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((filename = (const char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  reset_rrd_state();

  if(ntop_rrd_get_lastupdate(filename, &last_update, &ds_count) == -1) {
    return(CONST_LUA_ERROR);
  } else {
    lua_pushinteger(vm, last_update);
    lua_pushinteger(vm, ds_count);
    return(2 /* 2 values returned */);
  }
}

/* ****************************************** */

static int ntop_rrd_tune(lua_State* vm) {
  const char *filename;
  const char **argv;
  int argc, status, offset = 1;
  int extra_args = 1; /* Program name arg*/

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  argv = make_argv(vm, &argc, offset, extra_args);

  if(argc < 2) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "ntop_rrd_tune: invalid number of arguments");
    free(argv);
    return(CONST_LUA_ERROR);
  }
  filename = argv[1];

  reset_rrd_state();
  status = rrd_tune(argc, (char**)argv);

  if(status != 0) {
    char *err = rrd_get_error();

    if(err != NULL) {
      char error_buf[256];
      snprintf(error_buf, sizeof(error_buf), "Unable to run rrd_tune on %s [%s]", filename, err);

      lua_pushstring(vm, error_buf);
    } else
      lua_pushstring(vm, "Unknown RRD error");
  } else
    lua_pushnil(vm);

  free(argv);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_rrd_is_slow(lua_State* vm) {
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);

  if(ctx && ctx->threaded_activity_stats)
    lua_pushboolean(vm, ctx->threaded_activity_stats->isRRDSlow());
  else
    lua_pushboolean(vm, false);

  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_rrd_inc_num_drops(lua_State* vm) {
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);

  if(ctx && ctx->threaded_activity_stats)
    ctx->threaded_activity_stats->incRRDWriteDrops();

  return CONST_LUA_OK;
}

/* ****************************************** */

/* positional 1:4 parameters for ntop_rrd_fetch */
static int __ntop_rrd_args (lua_State* vm, char **filename, char **cf, time_t *start, time_t *end) {
  char *start_s, *end_s, *err;
  rrd_time_value_t start_tv, end_tv;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((*filename = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((*cf = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if((lua_type(vm, 3) == LUA_TNUMBER) && (lua_type(vm, 4) == LUA_TNUMBER))
    *start = (time_t)lua_tonumber(vm, 3), *end = (time_t)lua_tonumber(vm, 4);
  else {
    if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
    if((start_s = (char*)lua_tostring(vm, 3)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    if((err = rrd_parsetime(start_s, &start_tv)) != NULL) {
      lua_pushstring(vm, err);
      return(CONST_LUA_PARAM_ERROR);
    }

    if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
    if((end_s = (char*)lua_tostring(vm, 4)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    if((err = rrd_parsetime(end_s, &end_tv)) != NULL) {
      lua_pushstring(vm, err);
      return(CONST_LUA_PARAM_ERROR);
    }

    if(rrd_proc_start_end(&start_tv, &end_tv, start, end) == -1)
      return(CONST_LUA_PARAM_ERROR);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

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

/* ****************************************** */

/* Fetches data from RRD by rows */
static int ntop_rrd_fetch(lua_State* vm) {
  unsigned long i, j, step = 0, ds_cnt = 0;
  rrd_value_t *data, *p;
  char **names;
  char *filename, *cf;
  time_t t, start, end;
#if 0
  time_t last_update;
  unsigned long ds_count;
#endif
  int status;

  reset_rrd_state();

  if((status = __ntop_rrd_args(vm, &filename, &cf, &start, &end)) != CONST_LUA_OK) {
    return status;
  }

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  if((status = __ntop_rrd_status(vm, rrd_fetch_r(filename, cf, &start, &end,
						 &step, &ds_cnt, &names, &data),
				 filename, cf)) != CONST_LUA_OK) return status;

  lua_pushinteger(vm, (lua_Integer) start);
  lua_pushinteger(vm, (lua_Integer) step);
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

      for(j=0; j<ds_cnt; j++) {
	rrd_value_t value = *p++;

	if(value != DNAN /* Skip NaN */) {
	  lua_pushnumber(vm, (lua_Number)value);
	  lua_rawseti(vm, -2, j+1);
	  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u / %.f", t, value);
	}
      }

      lua_rawseti(vm, -2, i+1);
#if 0
    } else
      break;
#endif
  }

  rrd_freemem(data);

  /* return the end as the last value */
  lua_pushinteger(vm, (lua_Integer) end);

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

  reset_rrd_state();

  if((status = __ntop_rrd_args(vm, &filename,
			       &cf, &start, &end)) != CONST_LUA_OK) {
    return status;
  }

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%s)", __FUNCTION__, filename);

  if((status = __ntop_rrd_status(vm,
				 rrd_fetch_r(filename, cf, &start,
					     &end, &step, &ds_cnt,
					     &names, &data), filename,
				 cf)) != CONST_LUA_OK) {
    return status;
  }

  npoints = (end - start) / step;

  lua_pushinteger(vm, (lua_Integer) start);
  lua_pushinteger(vm, (lua_Integer) step);

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
  lua_pushinteger(vm, (lua_Integer) end);
  lua_pushinteger(vm, (lua_Integer) npoints);

  /* number of return values */
  return(5);
}

/* ****************************************** */

static void build_redirect(const char *url, const char * query_string,
	char *buf, size_t bufsize) {
  snprintf(buf, bufsize, "HTTP/1.1 302 Found\r\n"
     "Location: %s%s%s\r\n\r\n"
     "<html>\n"
     "<head>\n"
     "<title>Moved</title>\n"
     "</head>\n"
     "<body>\n"
     "<h1>Moved</h1>\n"
     "<p>This page has moved to <a href=\"%s\">%s</a>.</p>\n"
     "</body>\n"
     "</html>\n", url,
     query_string ? "?" : "",
     query_string ? query_string : "",
     url, url);
}

/* ****************************************** */

// *** API ***
static int ntop_http_redirect(lua_State* vm) {
  char *url, str[512];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  build_redirect(url, NULL, str, sizeof(str));
  lua_pushstring(vm, str);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// *** API ***
static int ntop_http_get(lua_State* vm) {
  char *url, *username = NULL, *pwd = NULL;
  int timeout = 30;
  bool return_content = true, use_cookie_authentication = false;
  HTTPTranferStats stats;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);

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
	if(lua_type(vm, 5) == LUA_TBOOLEAN) {
	  return_content = lua_toboolean(vm, 5) ? true : false;
	  if(lua_type(vm, 6) == LUA_TBOOLEAN) {
	    use_cookie_authentication = lua_toboolean(vm, 6) ? true : false;
	  }
	}
      }
    }
  }

  Utils::httpGetPost(vm, url, username, pwd, timeout, return_content,
		    use_cookie_authentication, &stats, NULL, NULL);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_http_get_prefix(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, ntop->getPrefs()->get_http_prefix());
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_http_get_startup_epoch(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, ntop->getStarttimeString());
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_http_purify_param(lua_State* vm) {
  char *str, *buf;
  bool strict = false, allowURL = false, allowDots = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) {
    lua_pushnil(vm);
    return(CONST_LUA_PARAM_ERROR);
  }

  if((str = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);
  if(lua_type(vm, 2) == LUA_TBOOLEAN)  strict    = lua_toboolean(vm, 2) ? true : false;
  if(lua_type(vm, 3) == LUA_TBOOLEAN)  allowURL  = lua_toboolean(vm, 3) ? true : false;
  if(lua_type(vm, 4) == LUA_TBOOLEAN)  allowDots = lua_toboolean(vm, 4) ? true : false;

  buf = strdup(str);

  if(buf == NULL) {
    lua_pushnil(vm);
    return(CONST_LUA_PARAM_ERROR);
  }

  Utils::purifyHTTPparam(buf, strict, allowURL, allowDots);
  lua_pushstring(vm, buf);
  free(buf);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_prefs(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getPrefs()->lua(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_ping_host(lua_State* vm) {
#ifdef WIN32
  lua_pushnil(vm);
  return(CONST_LUA_PARAM_ERROR);
#else
  char *host;
  bool is_v6;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((host = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  is_v6 = (bool)lua_toboolean(vm, 2);

  if(getLuaVMUservalue(vm, ping) == NULL) {
    Ping *ping;

    try {
      #if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      if(Utils::gainWriteCapabilities() == -1)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

      ping = new Ping();

#if !defined(__APPLE__) && !defined(WIN32) && !defined(HAVE_NEDGE)
      Utils::dropWriteCapabilities();
#endif
    } catch(...) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create ping socket: are you root?");
      ping = NULL;
    }
    
    if(ping == NULL) {
      lua_pushnil(vm);
      return(CONST_LUA_PARAM_ERROR);
    } else
      getLuaVMUservalue(vm, ping) = ping;
  }

  getLuaVMUservalue(vm, ping)->ping(host, is_v6);
  
  return(CONST_LUA_OK);
#endif
}

/* ****************************************** */

static int ntop_collect_ping_results(lua_State* vm) {
#ifdef WIN32
  lua_pushnil(vm);
  return(CONST_LUA_PARAM_ERROR);
#else
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(getLuaVMUservalue(vm, ping) == NULL) {
    lua_pushnil(vm);
    return(CONST_LUA_PARAM_ERROR);
  } else {
    getLuaVMUservalue(vm, ping)->collectResponses(vm);  
    return(CONST_LUA_OK);
  }
  #endif
}

/* ****************************************** */

static int ntop_get_nologin_username(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushstring(vm, NTOP_NOLOGIN_USER);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_users(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getUsers(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_allowed_interface(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getAllowedInterface(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_allowed_networks(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->getAllowedNetworks(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_is_pcap_download_allowed(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->isPcapDownloadAllowed(vm, ntop_interface->get_name()));
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_is_administrator(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->isUserAdministrator(vm));
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_reset_user_password(lua_State* vm) {
  char *who, *username, *old_password, *new_password;
  bool is_admin = ntop->isUserAdministrator(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  /* Username who requested the password change */
  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((who = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((old_password = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((new_password = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  /* non-local users cannot change their local password */
  if(!ntop->isLocalUser(vm))
    return(CONST_LUA_ERROR);

  /* only the administrator can change other users passwords */
  if(!is_admin && (strcmp(who, username)))
    return(CONST_LUA_ERROR);

  /* only the administrator can use and empty old password */
  if((old_password[0] == '\0') && !is_admin)
    return(CONST_LUA_ERROR);

  lua_pushboolean(vm, ntop->resetUserPassword(username, old_password, new_password));
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_change_user_role(lua_State* vm) {
  char *username, *user_role;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((user_role = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  lua_pushboolean(vm, ntop->changeUserRole(username, user_role));
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_change_allowed_nets(lua_State* vm) {
  char *username, *allowed_nets;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((allowed_nets = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  lua_pushboolean(vm, ntop->changeAllowedNets(username, allowed_nets));
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_change_allowed_ifname(lua_State* vm) {
  char *username, *allowed_ifname;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((allowed_ifname = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  lua_pushboolean(vm, ntop->changeAllowedIfname(username, allowed_ifname));
  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_change_user_host_pool(lua_State* vm) {
  char *username, *host_pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((host_pool_id = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  lua_pushboolean(vm, ntop->changeUserHostPool(username, host_pool_id));
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_change_user_language(lua_State* vm) {
  char *username, *language;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((language = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  lua_pushboolean(vm, ntop->changeUserLanguage(username, language));
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_change_user_permission(lua_State* vm) {
  char *username;
  bool allow_pcap_download = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
    allow_pcap_download = lua_toboolean(vm, 2) ? true : false;

  lua_pushboolean(vm, ntop->changeUserPermission(username, allow_pcap_download));
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_post_http_json_data(lua_State* vm) {
  char *username, *password, *url, *json;
  HTTPTranferStats stats;
  int timeout = 0;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((password = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((json = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  /* Optional timeout */
  if(lua_type(vm, 5) == LUA_TNUMBER) timeout = lua_tonumber(vm, 5);

  bool rv = Utils::postHTTPJsonData(username, password, url, json, timeout, &stats);

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_http_post(lua_State* vm) {
  char *username = (char*)"", *password = (char*)"", *url, *form_data;
  int timeout = 30;
  bool return_content = false;
  bool use_cookie_authentication = false;
  HTTPTranferStats stats;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((form_data = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 3) == LUA_TSTRING) /* Optional */
    if((username = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 4) == LUA_TSTRING) /* Optional */
    if((password = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 5) == LUA_TNUMBER) /* Optional */
    timeout = lua_tonumber(vm, 5);

  if(lua_type(vm, 6) == LUA_TBOOLEAN) /* Optional */
    return_content = lua_toboolean(vm, 6) ? true : false;

  if(lua_type(vm, 7) == LUA_TBOOLEAN) /* Optional */
    use_cookie_authentication = lua_toboolean(vm, 7) ? true : false;

  Utils::httpGetPost(vm, url, username, password, timeout, return_content,
    use_cookie_authentication, &stats, form_data, NULL);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_http_fetch(lua_State* vm) {
  char *url, *f, fname[PATH_MAX];
  HTTPTranferStats stats;
  int timeout = 30;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((f = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 3) == LUA_TNUMBER) /* Optional */
    timeout = lua_tonumber(vm, 3);

  snprintf(fname, sizeof(fname), "%s", f);
  ntop->fixPath(fname);

  Utils::httpGetPost(vm, url, NULL, NULL, timeout,
    false, false, &stats, NULL, fname);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_post_http_text_file(lua_State* vm) {
  char *username, *password, *url, *path;
  bool delete_file_after_post = false;
  int timeout = 30;
  HTTPTranferStats stats;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((password = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((url = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((path = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 5) == LUA_TBOOLEAN) /* Optional */
    delete_file_after_post = lua_toboolean(vm, 5) ? true : false;

  if(lua_type(vm, 6) == LUA_TNUMBER) /* Optional */
    timeout = lua_tonumber(vm, 6);

  if(timeout < 1)
    timeout = 1;

  if(Utils::postHTTPTextFile(vm, username, password, url, path, timeout, &stats)) {
    if(delete_file_after_post) {
      if(unlink(path) != 0)
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to delete file %s", path);
      else
	ntop->getTrace()->traceEvent(TRACE_INFO, "Deleted file %s", path);
    }
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef HAVE_CURL_SMTP
static int ntop_send_mail(lua_State* vm) {
  char *from, *to, *msg, *smtp_server, *username = NULL, *password = NULL;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((from = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((to = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((msg = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((smtp_server = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 5) == LUA_TSTRING) /* Optional */
    username = (char*)lua_tostring(vm, 5);

  if(lua_type(vm, 6) == LUA_TSTRING) /* Optional */
    password = (char*)lua_tostring(vm, 6);

  bool rv = Utils::sendMail(from, to, msg, smtp_server, username, password);

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

// ***API***
static int ntop_add_user(lua_State* vm) {
  char *username, *full_name, *password, *host_role, *allowed_networks, *allowed_interface;
  char *host_pool_id = NULL, *language = NULL;
  bool allow_pcap_download = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((full_name = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((password = (char*)lua_tostring(vm, 3)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((host_role = (char*)lua_tostring(vm, 4)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((allowed_networks = (char*)lua_tostring(vm, 5)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 6, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((allowed_interface = (char*)lua_tostring(vm, 6)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 7) == LUA_TSTRING)
    if((host_pool_id = (char*)lua_tostring(vm, 7)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 8) == LUA_TSTRING)
    if((language = (char*)lua_tostring(vm, 8)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 9) == LUA_TBOOLEAN)
    allow_pcap_download = lua_toboolean(vm, 9);

  lua_pushboolean(vm, ntop->addUser(username, full_name, password, host_role,
				    allowed_networks, allowed_interface, host_pool_id, language, allow_pcap_download));

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_add_user_lifetime(lua_State* vm) {
  char *username;
  int32_t num_secs;
  bool rv = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  num_secs = (int32_t)lua_tonumber(vm, 2);

  if(num_secs > 0)
    rv = ntop->addUserLifetime(username, num_secs);

  lua_pushboolean(vm, rv);
  return CONST_LUA_OK; /* Negative or zero lifetimes means unlimited */
}

/* ****************************************** */

static int ntop_clear_user_lifetime(lua_State* vm) {
  char *username;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  lua_pushboolean(vm, ntop->clearUserLifetime(username));
  return CONST_LUA_OK;
}

/* ****************************************** */

// ***API***
static int ntop_delete_user(lua_State* vm) {
  char *username;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm) || !ntop->isLocalUser(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((username = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  lua_pushboolean(vm, ntop->deleteUser(username));
  return CONST_LUA_OK;
}

/* ****************************************** */

/* Similar to ntop_get_resolved_address but actually perfoms the address resolution now */
static int ntop_resolve_address(lua_State* vm) {
  char *numIP, symIP[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((numIP = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  ntop->resolveHostName(numIP, symIP, sizeof(symIP));
  lua_pushstring(vm, symIP);
  return(CONST_LUA_OK);
}

/* ****************************************** */

void lua_push_str_table_entry(lua_State *L, const char * const key, const char * const value) {
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

void lua_push_uint64_table_entry(lua_State *L, const char *key, u_int64_t value) {
  if(L) {
    lua_pushstring(L, key);
    /* NOTE since LUA 5.3 integers are 64 bits */

#if defined(__i686__)
    if(value > 0x7FFFFFFF)
#else
    if(value > 0xFFFFFFFF)
#endif
      lua_pushnumber(L, (lua_Number)value);
    else
      lua_pushinteger(L, (lua_Integer)value);

    lua_settable(L, -3);
  }
}

/* ****************************************** */

void lua_push_int32_table_entry(lua_State *L, const char *key, int32_t value) {
  if(L) {
    lua_pushstring(L, key);

#if defined(LUA_MAXINTEGER) && defined(LUA_MININTEGER)
    if((lua_Integer)value > LUA_MAXINTEGER || (lua_Integer)value < LUA_MININTEGER)
      lua_pushnumber(L, (lua_Number)value);
    else
#endif
      lua_pushinteger(L, (lua_Integer)value);

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
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface)
    ntop_interface->lua_periodic_activities_stats(vm);
  else
    lua_pushnil(vm);

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

static int ntop_periodic_ht_state_update(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  time_t deadline;
  bool skip_user_scripts = false;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK || !ntop_interface)
    return(CONST_LUA_ERROR);

  deadline = (time_t)lua_tonumber(vm, 1);

  if(lua_type(vm, 2) == LUA_TBOOLEAN)
    skip_user_scripts = lua_toboolean(vm, 2);

  ntop_interface->periodicHTStateUpdate(deadline, vm, skip_user_scripts);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_periodic_stats_update(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->periodicStatsUpdate(vm);
  lua_pushnil(vm);

  return(CONST_LUA_OK);
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

static int ntop_get_interface_stats_update_freq(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  if(ntop_interface)
    lua_pushinteger(vm, ntop_interface->periodicStatsUpdateFrequency());
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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
  u_int16_t vlan_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if(!ntop_interface) return(CONST_LUA_ERROR);

  host = ntop_interface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id);

  if(host) {
    if(delete_data)
      host->requestDataReset();
    else
      host->requestStatsReset();
  }

  lua_pushboolean(vm, (host != NULL));
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static inline int ntop_interface_reset_host_stats(lua_State* vm) {
  return(ntop_interface_reset_host_stats(vm, false));
}

/* ****************************************** */

// ***API***
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

// ***API***
static inline int ntop_interface_reset_mac_stats(lua_State* vm) {
  return(ntop_interface_reset_mac_stats(vm, false));
}

/* ****************************************** */

// ***API***
static int ntop_interface_delete_mac_data(lua_State* vm) {
  return(ntop_interface_reset_mac_stats(vm, true));
}

/* ****************************************** */

static int ntop_is_package(lua_State *vm) {
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

static int ntop_is_nedge(lua_State *vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_nedge_edition());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_nedge_enterprise(lua_State *vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  lua_pushboolean(vm, ntop->getPrefs()->is_nedge_enterprise_edition());
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_reload_host_pools(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface) {
    ntop_interface->getHostPools()->reloadPools();
    lua_pushnil(vm);

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
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

/* ****************************************** */

static int ntop_purge_expired_host_pools_members(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_interface && ntop_interface->getHostPools()) {
    ntop_interface->getHostPools()->purgeExpiredVolatileMembers();

    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_remove_volatile_member_from_pool(lua_State *vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *host_or_mac;
  u_int16_t pool_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((host_or_mac = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  pool_id = (u_int16_t)lua_tonumber(vm, 2);

  if(ntop_interface && ntop_interface->getHostPools()) {
    ntop_interface->getHostPools()->removeVolatileMemberFromPool(host_or_mac, pool_id);

    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}
#endif

/* ****************************************** */

static int ntop_find_member_pool(lua_State *vm) {
  char *address;
  u_int16_t vlan_id = 0;
  bool is_mac;
  patricia_node_t *target_node = NULL;
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
        lua_push_str_table_entry(vm, "matched_prefix", (char *)inet_ntop(target_node->prefix->family,
									 (target_node->prefix->family == AF_INET6) ?
									 (void*)(&target_node->prefix->add.sin6) :
									 (void*)(&target_node->prefix->add.sin),
									 buf, sizeof(buf)));
        lua_push_uint64_table_entry(vm, "matched_bitmask", target_node->bit);
      }
    } else
      lua_pushnil(vm);

    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* *******************************************/

// ***API***
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

static int ntop_reload_device_protocols(lua_State *vm) {
  DeviceType device_type = device_unknown;
  char *dir; /* client or server */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TTABLE) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);

  device_type = (DeviceType) lua_tointeger(vm, 1);
  if((dir = (char *) lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  ntop->refreshAllowedProtocolPresets(device_type, !!strcmp(dir, "server"), vm, 3);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_run_extraction(lua_State *vm) {
  int id, ifid;
  time_t time_from, time_to;
  char *filter;
  u_int64_t max_bytes;
  char * timeline_path = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if(lua_type(vm, 6) == LUA_TNUMBER) max_bytes = lua_tonumber(vm, 6);
  else max_bytes = 0; /* optional */
  if(lua_tostring(vm, 7)) timeline_path = (char *)lua_tostring(vm, 7);

  id = lua_tointeger(vm, 1);
  ifid = lua_tointeger(vm, 2);
  time_from = lua_tointeger(vm, 3);
  time_to = lua_tointeger(vm, 4);
  if((filter = (char *) lua_tostring(vm, 5)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  max_bytes = lua_tonumber(vm, 6);

  ntop->getTimelineExtract()->runExtractionJob(id,
					       ntop->getInterfaceById(ifid), time_from, time_to, filter, max_bytes, timeline_path);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_stop_extraction(lua_State *vm) {
  int id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);

  id = lua_tointeger(vm, 1);

  ntop->getTimelineExtract()->stopExtractionJob(id);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_extraction_running(lua_State *vm) {
  bool rv;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  rv = ntop->getTimelineExtract()->isRunning();

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_extraction_status(lua_State *vm) {

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  ntop->getTimelineExtract()->getStatus(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_run_live_extraction(lua_State *vm) {
  struct ntopngLuaContext *c;
  NetworkInterface *iface;
  TimelineExtract timeline;
  int ifid;
  time_t time_from, time_to;
  char *bpf;
  bool allow = false, success = false;
  char * timeline_path = NULL;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  c = getLuaVMContext(vm);

  if (!c)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK)
    return(CONST_LUA_PARAM_ERROR);

  ifid = lua_tointeger(vm, 1);
  time_from = lua_tointeger(vm, 2);
  time_to = lua_tointeger(vm, 3);
  if ((bpf = (char *) lua_tostring(vm, 4)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  if(lua_tostring(vm, 5)) timeline_path = (char *)lua_tostring(vm, 5);

  iface = ntop->getInterfaceById(ifid);
  if(!iface) return(CONST_LUA_ERROR);

  if(!ntop->isPcapDownloadAllowed(vm, iface->get_name()))
    return(CONST_LUA_ERROR);

  live_extraction_num_lock.lock(__FILE__, __LINE__);
  if (live_extraction_num < CONST_MAX_NUM_LIVE_EXTRACTIONS) {
    allow = true;
    live_extraction_num++;
  }
  live_extraction_num_lock.unlock(__FILE__, __LINE__);

  if (allow) {

    bpf = ntop->preparePcapDownloadFilter(vm, bpf);

    success = timeline.extractLive(c->conn, iface, time_from, time_to, bpf, timeline_path);

    live_extraction_num_lock.lock(__FILE__, __LINE__);
    live_extraction_num--;
    live_extraction_num_lock.unlock(__FILE__, __LINE__);

    free(bpf);
  }

  lua_pushboolean(vm, success);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_bitmap_is_set(lua_State *vm) {
  u_int64_t bitmap;
  u_int64_t val;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  bitmap = lua_tointeger(vm, 1);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  val = lua_tointeger(vm, 2);

  lua_pushboolean(vm, Utils::bitmapIsSet(bitmap, val));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_bitmap_set(lua_State *vm) {
  u_int64_t bitmap;
  u_int64_t val;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  bitmap = lua_tointeger(vm, 1);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  val = lua_tointeger(vm, 2);

  lua_pushinteger(vm, Utils::bitmapSet(bitmap, val));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_bitmap_clear(lua_State *vm) {
  u_int64_t bitmap;
  u_int64_t val;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  bitmap = lua_tointeger(vm, 1);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  val = lua_tointeger(vm, 2);

  lua_pushinteger(vm, Utils::bitmapClear(bitmap, val));
  return(CONST_LUA_OK);
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

static int ntop_interface_exec_single_sql_query(lua_State *vm) {
  char *sql;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((sql = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

#ifdef HAVE_MYSQL
  MySQLDB::exec_single_query(vm, sql);
  return(CONST_LUA_OK);
#else
  return(CONST_LUA_ERROR);
#endif
}

/* ****************************************** */

// ***API***
static int ntop_reset_stats(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->resetStats();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_dirs(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "installdir", ntop->get_install_dir());
  lua_push_str_table_entry(vm, "workingdir", ntop->get_working_dir());
  lua_push_str_table_entry(vm, "scriptdir", ntop->getPrefs()->get_scripts_dir());
  lua_push_str_table_entry(vm, "httpdocsdir", ntop->getPrefs()->get_docs_dir());
  lua_push_str_table_entry(vm, "callbacksdir", ntop->getPrefs()->get_callbacks_dir());
  lua_push_str_table_entry(vm, "pcapdir", ntop->getPrefs()->get_pcap_dir());

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_uptime(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_pushinteger(vm, ntop->getGlobals()->getUptime());
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_system_host_stat(lua_State* vm) {
  float cpu_load;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  if(ntop->getCpuLoad(&cpu_load)) lua_push_float_table_entry(vm, "cpu_load", cpu_load);
  Utils::luaMeminfo(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_refresh_cpu_load(lua_State* vm) {
  float cpu_load;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  ntop->refreshCpuLoad();

  if(ntop->getCpuLoad(&cpu_load))
    lua_pushnumber(vm, cpu_load);
  else
    lua_pushnil(vm);

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

// ***API***
static int ntop_get_info(lua_State* vm) {
  char rsp[256];
#ifndef HAVE_NEDGE
  int major, minor, patch;
#endif
  bool verbose = true;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(lua_type(vm, 1) == LUA_TBOOLEAN)
    verbose = lua_toboolean(vm, 1) ? true : false;

  lua_newtable(vm);
#ifdef HAVE_NEDGE
  lua_push_str_table_entry(vm, "product", ntop->getPro()->get_product_name());
  lua_push_bool_table_entry(vm, "oem", ntop->getPro()->is_oem());
#else
  lua_push_str_table_entry(vm, "product", (char*)"ntopng");
#endif
  lua_push_str_table_entry(vm, "copyright",
#ifdef HAVE_NEDGE
			   ntop->getPro()->is_oem() ? (char*)"" :
#endif
			   (char*)"&copy; 1998-20 - ntop.org");
  lua_push_str_table_entry(vm, "authors",   (char*)"The ntop.org team");
  lua_push_str_table_entry(vm, "license",   (char*)"GNU GPLv3");
  lua_push_str_table_entry(vm, "platform",  (char*)PACKAGE_MACHINE);
  lua_push_str_table_entry(vm, "version",   (char*)PACKAGE_VERSION);
  lua_push_str_table_entry(vm, "revision",  (char*)PACKAGE_REVISION);
  lua_push_str_table_entry(vm, "git",       (char*)NTOPNG_GIT_RELEASE);
#ifndef WIN32
  lua_push_uint64_table_entry(vm, "pid",       getpid());
#endif

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
  lua_push_uint64_table_entry(vm, "bits", (sizeof(void*) == 4) ? 32 : 64);
  lua_push_uint64_table_entry(vm, "uptime", ntop->getGlobals()->getUptime());
  lua_push_str_table_entry(vm, "command_line", ntop->getPrefs()->get_command_line());

  if(verbose) {
    lua_push_str_table_entry(vm, "version.rrd", rrd_strversion());
    lua_push_str_table_entry(vm, "version.redis", ntop->getRedis()->getVersion());
    lua_push_str_table_entry(vm, "version.httpd", (char*)mg_version());
    lua_push_str_table_entry(vm, "version.git", (char*)NTOPNG_GIT_RELEASE);
    lua_push_str_table_entry(vm, "version.curl", (char*)LIBCURL_VERSION);
    lua_push_str_table_entry(vm, "version.luajit", (char*)LUA_RELEASE);
#ifdef HAVE_MAXMINDDB
    lua_push_str_table_entry(vm, "version.geoip", (char*)MMDB_lib_version());
#endif
    lua_push_str_table_entry(vm, "version.ndpi", ndpi_revision());
    lua_push_bool_table_entry(vm, "version.enterprise_edition", ntop->getPrefs()->is_enterprise_edition());
    lua_push_bool_table_entry(vm, "version.embedded_edition", ntop->getPrefs()->is_embedded_edition());
    lua_push_bool_table_entry(vm, "version.nedge_edition", ntop->getPrefs()->is_nedge_edition());
    lua_push_bool_table_entry(vm, "version.nedge_enterprise_edition", ntop->getPrefs()->is_nedge_enterprise_edition());

    lua_push_bool_table_entry(vm, "pro.release", ntop->getPrefs()->is_pro_edition());
    lua_push_uint64_table_entry(vm, "pro.demo_ends_at", ntop->getPrefs()->pro_edition_demo_ends_at());
#ifdef NTOPNG_PRO
#ifndef FORCE_VALID_LICENSE
    time_t until_then;
    int days_left;
    if(ntop->getPro()->get_maintenance_expiration_time(&until_then, &days_left)) {
      lua_push_uint64_table_entry(vm, "pro.license_ends_at", (u_int64_t)until_then);
      lua_push_uint64_table_entry(vm, "pro.license_days_left", days_left);
    }
#endif
    lua_push_str_table_entry(vm, "pro.license", ntop->getPro()->get_license());
    lua_push_bool_table_entry(vm, "pro.out_of_maintenance", ntop->getPro()->is_out_of_maintenance());
    lua_push_bool_table_entry(vm, "pro.use_redis_license", ntop->getPro()->use_redis_license());
    lua_push_str_table_entry(vm, "pro.systemid", ntop->getPro()->get_system_id());
#if defined(HAVE_NINDEX)
    lua_push_str_table_entry(vm, "version.nindex", nindex_version());
#endif
#endif
    lua_push_uint64_table_entry(vm, "constants.max_num_host_pools", MAX_NUM_HOST_POOLS);
    lua_push_uint64_table_entry(vm, "constants.max_num_pool_members",    MAX_NUM_POOL_MEMBERS);
    lua_push_uint64_table_entry(vm, "constants.max_num_profiles",    MAX_NUM_PROFILES);

#ifndef HAVE_NEDGE
    zmq_version(&major, &minor, &patch);
    snprintf(rsp, sizeof(rsp), "%d.%d.%d", major, minor, patch);
    lua_push_str_table_entry(vm, "version.zmq", rsp);
#endif
  }

#ifdef HAVE_TEST_MODE
  lua_push_bool_table_entry(vm, "test_mode", true);
#endif

    return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_cookie_attributes(lua_State* vm) {
  struct mg_request_info *request_info;
  struct mg_connection *conn;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!(conn = getLuaVMUserdata(vm, conn)))
    return(CONST_LUA_ERROR);

  if(!(request_info = mg_get_request_info(conn)))
    return(CONST_LUA_ERROR);

  lua_pushstring(vm, (char*)get_secure_cookie_attributes(request_info));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_allowed_interface(lua_State* vm) {
  int id;
  NetworkInterface *iface;
  bool rv = false;
  char *allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  id = lua_tointeger(vm, 1);

  if((allowed_ifname == NULL) || (allowed_ifname[0] == '\0'))
    rv = true;
  else if(((iface = ntop->getNetworkInterface(vm, id)) != NULL) && (iface->get_id() == id) &&
      matches_allowed_ifname(allowed_ifname, iface->get_name()))
    rv = true;

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_allowed_network(lua_State* vm) {
  bool rv = false;
  u_int16_t vlan_id = 0;
  char *host, buf[64];
  AddressTree *allowed_nets = get_allowed_nets(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host, &vlan_id, buf, sizeof(buf));

  if(!allowed_nets /* e.g., when the user is 'nologin' there's no allowed network to enforce */
     || allowed_nets->match(host))
    rv = true;

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_resolved_address(lua_State* vm) {
  char *key, *tmp,rsp[256],value[64];
  Redis *redis = ntop->getRedis();
  u_int16_t vlan_id = 0;
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
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

static int ntop_resolve_host(lua_State* vm) {
  char buf[64];
  char *host;
  bool ipv4 = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)  != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  if((host = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);
  ipv4 = lua_toboolean(vm, 2);

  if(ntop->resolveHost(host, buf, sizeof(buf), ipv4))
    lua_pushstring(vm, buf);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifndef HAVE_NEDGE
static int ntop_snmpget(lua_State* vm)     { SNMP s; return(s.get(vm));     }
static int ntop_snmpgetnext(lua_State* vm) { SNMP s; return(s.getnext(vm)); }
#endif

/* ****************************************** */

// ***API***
#ifndef WIN32
static int ntop_syslog(lua_State* vm) {
  char *msg;
  int syslog_severity = LOG_INFO;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING)  != CONST_LUA_OK) {
    lua_pushnil(vm);
    return(CONST_LUA_ERROR);
  }

  msg = (char*)lua_tostring(vm, 1);
  if(lua_type(vm, 2) == LUA_TNUMBER)
    syslog_severity = (int)lua_tonumber(vm, 2);

  syslog(syslog_severity, "%s", msg);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}
#endif

/* ****************************************** */

/**
 * @brief Generate a random value to prevent CSRF and XSRF attacks
 * @details See http://blog.codinghorror.com/preventing-csrf-and-xsrf-attacks/
 */
// ***API***
static int ntop_generate_csrf_value(lua_State* vm) {
  char random_a[32], random_b[32], csrf[33];
  Redis *redis = ntop->getRedis();
  const char *user = getLuaVMUservalue(vm, user);

  if(!user) return(CONST_LUA_ERROR);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef __OpenBSD__
  snprintf(random_a, sizeof(random_a), "%d", arc4random());
  snprintf(random_b, sizeof(random_b), "%lu", time(NULL)*arc4random());
#else
  snprintf(random_a, sizeof(random_a), "%d", rand());
  snprintf(random_b, sizeof(random_b), "%lu", time(NULL)*rand());
#endif

  mg_md5(csrf, random_a, random_b, NULL);

  redis->set(csrf, (char*)user, MAX_CSRF_DURATION);
  lua_pushfstring(vm, "%s", csrf);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_md5(lua_State* vm) {
  char result[33];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  mg_md5(result, lua_tostring(vm, 1), NULL);

  lua_pushstring(vm, result);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_has_radius_support(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#ifdef HAVE_RADIUS
  lua_pushboolean(vm, true);
#else
  lua_pushboolean(vm, false);
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_has_ldap_support(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

#if defined(NTOPNG_PRO) && defined(HAVE_LDAP) && !defined(HAVE_NEDGE)
  lua_pushboolean(vm, true);
#else
  lua_pushboolean(vm, false);
#endif

  return(CONST_LUA_OK);
}

/* ****************************************** */

#ifdef UNUSED_CODE

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

#endif

/* ****************************************** */

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((sampling = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  time(&rawtime);

  if(sm->insertMinuteSampling(rawtime, sampling))
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((sampling = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  time(&rawtime);
  rawtime -= (rawtime % 60);

  if(sm->insertHourSampling(rawtime, sampling))
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((sampling = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  time(&rawtime);
  rawtime -= (rawtime % 60);

  if(sm->insertDaySampling(rawtime, sampling))
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  epoch = (time_t)lua_tointeger(vm, 2);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  if(sm->getMinuteSampling(epoch, &sampling))
    return(CONST_LUA_ERROR);

  lua_pushstring(vm, sampling.c_str());

  return(CONST_LUA_OK);
}

/* ****************************************** */

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

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 2);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  if(sm->deleteMinuteStatsOlderThan(num_days))
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

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

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 2);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  if(sm->deleteHourStatsOlderThan(num_days))
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

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

  if(!ntop->isUserAdministrator(vm)) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 2);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  if(sm->deleteDayStatsOlderThan(num_days))
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  epoch_start = lua_tointeger(vm, 2);
  if(epoch_start < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 3);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  if(sm->retrieveMinuteStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 2);
  epoch_end -= (epoch_end % 60);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_minutes = lua_tointeger(vm, 3);
  if(num_minutes < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  epoch_start = epoch_end - (60 * num_minutes);

  if(sm->retrieveMinuteStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 2);
  epoch_end -= (epoch_end % 60);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_hours = lua_tointeger(vm, 3);
  if(num_hours < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  epoch_start = epoch_end - (num_hours * 60 * 60);

  if(sm->retrieveHourStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
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

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  ifid = lua_tointeger(vm, 1);
  if(ifid < 0)
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  epoch_end = lua_tointeger(vm, 2);
  epoch_end -= (epoch_end % 60);
  if(epoch_end < 0)
    return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_days = lua_tointeger(vm, 3);
  if(num_days < 0)
    return(CONST_LUA_ERROR);

  if(!(iface = ntop->getInterfaceById(ifid)) ||
     !(sm = iface->getStatsManager()))
    return(CONST_LUA_ERROR);

  epoch_start = epoch_end - (num_days * 24 * 60 * 60);

  if(sm->retrieveDayStatsInterval(epoch_start, epoch_end, &retvals))
    return(CONST_LUA_ERROR);

  lua_newtable(vm);

  for (unsigned i = 0 ; i < retvals.rows.size() ; i++)
    lua_push_str_table_entry(vm, retvals.rows[i].c_str(), (char*)"");

  return(CONST_LUA_OK);
}

/* ****************************************** */

static bool ntop_delete_old_rrd_files_recursive(const char *dir_name, time_t now, int older_than_seconds) {
  struct dirent *result;
  int path_length;
  char path[MAX_PATH];
  DIR *d;
  time_t last_update;
  unsigned long ds_count;

  if(!dir_name || strlen(dir_name) > MAX_PATH)
    return false;

  d = opendir(dir_name);
  if(!d) return false;

  while((result = readdir(d)) != NULL) {
    if(result->d_type & DT_REG) {
      if((path_length = snprintf(path, MAX_PATH, "%s/%s", dir_name, result->d_name)) <= MAX_PATH) {
        ntop->fixPath(path);

        if(ntop_rrd_get_lastupdate(path, &last_update, &ds_count) == 0) {
          if((now >= last_update) && ((now - last_update) > older_than_seconds)) {
            //printf("DELETE %s\n", path);
            unlink(path);
          }
        }
      }
    } else if(result->d_type & DT_DIR) {
      if(strncmp(result->d_name, "..", 2) && strncmp(result->d_name, ".", 1)) {
        if((path_length = snprintf(path, MAX_PATH, "%s/%s", dir_name, result->d_name)) <= MAX_PATH) {
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

static int ntop_delete_old_rrd_files(lua_State *vm) {
  char path[PATH_MAX];
  int older_than_seconds;
  time_t now = time(NULL);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  strncpy(path, lua_tostring(vm, 1), sizeof(path));

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((older_than_seconds = lua_tointeger(vm, 2)) < 0) return(CONST_LUA_ERROR);

  ntop->fixPath(path);

  if(ntop_delete_old_rrd_files_recursive(path, now, older_than_seconds))
    return(CONST_LUA_ERROR);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_mkdir_tree(lua_State* vm) {
  char *dir;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);  
  lua_pushnil(vm);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((dir = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);
  if(dir[0] == '\0')                                   return(CONST_LUA_OK); /* Nothing to do */

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Trying to created directory %s", dir);
    
  lua_pushboolean(vm, Utils::mkdir_tree(dir));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_list_reports(lua_State* vm) {
  DIR *dir;
  char fullpath[MAX_PATH+64];

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);
  snprintf(fullpath, sizeof(fullpath)-1, "%s/%s", ntop->get_working_dir(), "reports");
  ntop->fixPath(fullpath);
  if((dir = opendir(fullpath)) != NULL) {
    struct dirent *ent;

    while ((ent = readdir(dir)) != NULL) {
      char filepath[MAX_PATH+16];
#ifdef WIN32
	  struct _stat64 buf;
#else
	  struct stat buf;
#endif

      snprintf(filepath, sizeof(filepath), "%s/%s", fullpath, ent->d_name);
      ntop->fixPath(filepath);

      if(!stat(filepath, &buf) && !S_ISDIR(buf.st_mode))
	lua_push_str_table_entry(vm, ent->d_name, (char*)"");
    }
    closedir(dir);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_info_redis(lua_State* vm) {
  char *rsp;
  u_int rsp_len = CONST_MAX_LEN_REDIS_VALUE;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  lua_newtable(vm);

  if((rsp = (char*)malloc(rsp_len)) != NULL) {
    lua_push_str_table_entry(vm, "info", (redis->info(rsp, rsp_len) == 0) ? rsp : (char*)"");
    lua_push_uint64_table_entry(vm, "dbsize", redis->dbsize());
    free(rsp);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_redis(lua_State* vm) {
  char *key, *rsp;
  u_int rsp_len = CONST_MAX_LEN_REDIS_VALUE;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if((rsp = (char*)malloc(rsp_len)) != NULL) {
    lua_pushfstring(vm, "%s", (redis->get(key, rsp, rsp_len) == 0) ? rsp : (char*)"");
    free(rsp);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

// ***API***
static int ntop_incr_redis(lua_State* vm) {
  char *key;
  u_int rsp;
  int amount = 1;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 2) == LUA_TNUMBER)
    amount = lua_tonumber(vm, 2);

  rsp = redis->incr(key, amount);

  lua_pushinteger(vm, rsp);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_hash_redis(lua_State* vm) {
  char *key, *member, *rsp;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);
  if((member = (char*)lua_tostring(vm, 2)) == NULL)    return(CONST_LUA_PARAM_ERROR);

  if((rsp = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL) return(CONST_LUA_PARAM_ERROR);
  lua_pushfstring(vm, "%s", (redis->hashGet(key, member, rsp, CONST_MAX_LEN_REDIS_VALUE) == 0) ? rsp : (char*)"");
  free(rsp);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_set_hash_redis(lua_State* vm) {
  char *key, *member, *value;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);
  if((member = (char*)lua_tostring(vm, 2)) == NULL)    return(CONST_LUA_PARAM_ERROR);
  if((value  = (char*)lua_tostring(vm, 3)) == NULL)    return(CONST_LUA_PARAM_ERROR);

  redis->hashSet(key, member, value);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_delete_hash_redis_key(lua_State* vm) {
  char *key, *member;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_PARAM_ERROR);
  if((member = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  ntop->getRedis()->hashDel(key, member);
  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_get_hash_keys_redis(lua_State* vm) {
  char *key, **vals;
  Redis *redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
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

// ***API***
static int ntop_get_hash_all_redis(lua_State* vm) {
  char *key, **keys, **values;
  Redis *redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
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

// ***API***
static int ntop_get_keys_redis(lua_State* vm) {
  char *pattern, **keys = NULL;
  Redis *redis = ntop->getRedis();
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((pattern = (char*)lua_tostring(vm, 1)) == NULL)   return(CONST_LUA_PARAM_ERROR);

  rc = redis->keys(pattern, &keys);

  if(rc > 0) {
    lua_newtable(vm);

    for(int i = 0; i < rc; i++) {
      lua_push_str_table_entry(vm, keys[i] ? keys[i] : "", (char*)"");
      if(keys[i]) free(keys[i]);
    }
  } else
    lua_pushnil(vm);

  if(keys) free(keys);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_lrange_redis(lua_State* vm) {
  char *l_name, **l_elements;
  Redis *redis = ntop->getRedis();
  int start_offset = 0, end_offset = -1;
  int rc;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
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
      lua_pushstring(vm, l_elements[i] ? l_elements[i] : "");
      lua_rawseti(vm, -2, i+1);
      if(l_elements[i]) free(l_elements[i]);
    }

    free(l_elements);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_llen_redis(lua_State* vm) {
  char *l_name;
  Redis *redis = ntop->getRedis();
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!redis) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((l_name = (char*)lua_tostring(vm, 1)) == NULL)   return(CONST_LUA_PARAM_ERROR);

  lua_pushinteger(vm, redis->llen(l_name));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_redis_dump(lua_State* vm) {
  char *key, *dump;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!redis->haveRedisDump())
    lua_pushnil(vm); /* This is old redis */
  else {
    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
    if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    dump = redis->dump(key);

    if(dump) {
      lua_pushfstring(vm, "%s", dump);
      free(dump);
    } else
      return(CONST_LUA_ERROR);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_redis_restore(lua_State* vm) {
  char *key, *dump;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!redis->haveRedisDump()) {
    lua_pushnil(vm); /* This is old redis */
    return(CONST_LUA_OK);
  } else {
    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
    if((key = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
    if((dump = (char*)lua_tostring(vm, 2)) == NULL)  return(CONST_LUA_PARAM_ERROR);

    return((redis->restore(key, dump) != 0) ? CONST_LUA_ERROR : CONST_LUA_OK);
  }
}

/* ****************************************** */

static int ntop_list_index_redis(lua_State* vm) {
  char *index_name, *rsp;
  Redis *redis = ntop->getRedis();
  int idx;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((index_name = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  idx = lua_tointeger(vm, 2);

  if((rsp = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL)
    return(CONST_LUA_PARAM_ERROR);

  if(redis->lindex(index_name, idx, rsp, CONST_MAX_LEN_REDIS_VALUE) != 0) {
    free(rsp);
    return(CONST_LUA_ERROR);
  }

  lua_pushfstring(vm, "%s", rsp);
  free(rsp);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_lrpop_redis(lua_State* vm, bool lpop) {
  char msg[1024], *list_name;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((list_name = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if((lpop ? redis->lpop(list_name, msg, sizeof(msg)) : redis->rpop(list_name, msg, sizeof(msg))) == 0) {
    lua_pushfstring(vm, "%s", msg);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

// ***API***
static int ntop_lpop_redis(lua_State* vm) {
  return ntop_lrpop_redis(vm, true /* LPOP */);
}

/* ****************************************** */

// ***API***
static int ntop_rpop_redis(lua_State* vm) {
  return ntop_lrpop_redis(vm, false /* RPOP */);
}

/* ****************************************** */

// ***API***
static int ntop_lrem_redis(lua_State* vm) {
  char *list_name, *rem_value;
  int ret;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);

  if((list_name = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);
  if((rem_value = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  ret = redis->lrem(list_name, rem_value);

  lua_pushnil(vm);

  if(ret == 0)
    return(CONST_LUA_OK);
  else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

// ***API***
static int ntop_ltrim_redis(lua_State* vm) {
  char *list_name;
  int start_idx, end_idx;
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((list_name = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  start_idx = lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  end_idx = lua_tonumber(vm, 3);

  if(redis && redis->ltrim(list_name, start_idx, end_idx) == 0) {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  }

  return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_push_redis(lua_State* vm, bool use_lpush) {
  char *list_name, *value;
  u_int list_trim_size = 0;  // default 0 = no trim
  Redis *redis = ntop->getRedis();
  int rv;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((list_name = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  /* Optional trim list up to the specified number of elements */
  if(lua_type(vm, 3) == LUA_TNUMBER)
    list_trim_size = (u_int)lua_tonumber(vm, 3);

  if(use_lpush)
    rv = redis->lpush(list_name, value, list_trim_size);
  else
    rv = redis->rpush(list_name, value, list_trim_size);

  if(rv == 0) {
    lua_pushnil(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

// ***API***
static int ntop_lpush_redis(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return ntop_push_redis(vm, true);
}

/* ****************************************** */

// ***API***
static int ntop_rpush_redis(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  return ntop_push_redis(vm, false);
}

/* ****************************************** */

// ***API***
static int ntop_add_local_network(lua_State* vm) {
  char *local_network;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((local_network = (char*)lua_tostring(vm, 1)) == NULL)  return(CONST_LUA_PARAM_ERROR);

  ntop->addLocalNetwork(local_network);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/* NOTE: do not call directly, use alerts_api instead */
static int ntop_interface_store_alert(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  char *entity_value;
  AlertLevel alert_severity;
  AlertType alert_type;
  AlertEntity alert_entity;
  char *alert_json;
  AlertsManager *am;
  int ret, granularity;
  char *alert_subtype;
  bool ignore_disabled = false, check_maximum = true, is_new_alert;
  time_t tstart, tend;
  u_int64_t rowid;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((!ntop_interface)
     || ((am = ntop_interface->getAlertsManager()) == NULL))
    return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  tstart = (time_t)lua_tonumber(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  tend = (time_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  granularity = (int)lua_tonumber(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_type = (AlertType)((int)lua_tonumber(vm, 4));

  if(ntop_lua_check(vm, __FUNCTION__, 5, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_subtype = (char*)lua_tostring(vm, 5);

  if(ntop_lua_check(vm, __FUNCTION__, 6, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_severity = (AlertLevel)((int)lua_tonumber(vm, 6));

  if(ntop_lua_check(vm, __FUNCTION__, 7, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_entity = (AlertEntity)((int)lua_tonumber(vm, 7));

  if(ntop_lua_check(vm, __FUNCTION__, 8, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  entity_value = (char*)lua_tostring(vm, 8);

  if(ntop_lua_check(vm, __FUNCTION__, 9, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_json = (char*)lua_tostring(vm, 9);

  ret = am->storeAlert(tstart, tend, granularity, alert_type, alert_subtype, alert_severity,
    alert_entity, entity_value, alert_json, &is_new_alert, &rowid, ignore_disabled, check_maximum);

  if(ret != 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "triggerAlert failed with code %d", ret);

  if(ret == 0) {
    lua_newtable(vm);
    lua_push_uint64_table_entry(vm, "rowid", rowid);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_store_flow_alert(lua_State* vm) {
  NetworkInterface *ntop_interface = getCurrentInterface(vm);
  AlertsManager *am;
  u_int64_t rowid = 0;
  int ret;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((!ntop_interface)
     || ((am = ntop_interface->getAlertsManager()) == NULL))
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) != LUA_TTABLE) 
    return(CONST_LUA_ERROR);

  ret = am->storeFlowAlert(vm, 1,  &rowid);

  if(ret == 0) {
    lua_newtable(vm);
    lua_push_uint64_table_entry(vm, "rowid", rowid);
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "storeFlowAlert failed (%d)", ret);
    lua_pushnil(vm);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_set_has_alerts(lua_State* vm) {
  bool has_alerts;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TBOOLEAN) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  has_alerts = lua_toboolean(vm, 1);

  if(!ntop_interface)
    return(CONST_LUA_ERROR);

  ntop_interface->setHasAlerts(has_alerts);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
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

  return CONST_LUA_OK;
}

/* ****************************************** */

static int ntop_host_get_fields(lua_State* vm, bool all_fields) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    h->lua(vm, NULL, all_fields, all_fields, false, false);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_host_get_basic_fields(lua_State* vm) {
  return(ntop_host_get_fields(vm, false));
}

static int ntop_host_get_all_fields(lua_State* vm) {
  return(ntop_host_get_fields(vm, true));
}

/* ****************************************** */

static int ntop_host_get_cached_alert_value(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;
  char *key;
  std::string val;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!h) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 2)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  val = h->getAlertCachedValue(std::string(key), periodicity);
  lua_pushstring(vm, val.c_str());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_set_cached_alert_value(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;
  char *key, *value;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!h) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 3)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  if((!key) || (!value))
    return(CONST_LUA_PARAM_ERROR);

  h->setAlertCacheValue(std::string(key), std::string(value), periodicity);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_get_alerts(lua_State* vm, AlertableEntity *entity) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  u_int idx = 0;
  ScriptPeriodicity periodicity = no_periodicity;

  if(!entity) return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TNUMBER) periodicity = (ScriptPeriodicity)lua_tointeger(vm, 1);

  lua_newtable(vm);
  entity->getAlerts(vm, periodicity, alert_none, alert_level_none, &idx);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_get_alerts(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_get_alerts(vm, c->iface);
}

static int ntop_host_get_alerts(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_get_alerts(vm, c->host);
}

static int ntop_network_get_alerts(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_get_alerts(vm, c->network);
}

/* ****************************************** */

static int ntop_network_check_context(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  char *entity_val;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((entity_val = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if((c->network == NULL) || (strcmp(c->network->getEntityValue().c_str(), entity_val)) != 0) {
    NetworkInterface *iface = getCurrentInterface(vm);
    u_int8_t network_id = ntop->getLocalNetworkId(entity_val);

    if(!iface || (network_id == (u_int8_t)-1) || ((c->network = iface->getNetworkStats(network_id)) == NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Could not set context for network %s", entity_val);
      return(CONST_LUA_ERROR);
    }
  }

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_check_context(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  char *entity_val;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((entity_val = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if((c->host == NULL) || (strcmp(c->host->getEntityValue().c_str(), entity_val)) != 0) {
    NetworkInterface *iface = getCurrentInterface(vm);
    char *host_ip, buf[64];
    u_int16_t vlan_id;

    get_host_vlan_info(entity_val, &host_ip, &vlan_id, buf, sizeof(buf));

    if(!iface || !host_ip || ((c->host = iface->getHost(host_ip, vlan_id, false /* not inline */)) == NULL)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Could not set context for host %s", entity_val);
      return(CONST_LUA_ERROR);
    }
  }

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

/* Manually refresh alerts for scripts outside the periodic scripts */
static int ntop_interface_refresh_alerts(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  if(c->host)
    c->host->refreshAlerts();
  else if(c->network)
    c->network->refreshAlerts();
  else if(c->iface)
    c->iface->refreshAlerts();

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_check_dropped_alerts(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);

  if(!iface)
    return(CONST_LUA_ERROR);

  lua_pushinteger(vm, iface->checkDroppedAlerts());
  return(CONST_LUA_OK);
}

/* ****************************************** */

static Host* ntop_host_get_context_host(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return c->host;
}

/* ****************************************** */

static int ntop_host_get_ip(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_ip(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_localhost_info(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_localhost_info(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_application_bytes(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);
  u_int app_id;

  lua_newtable(vm);

  if(h && ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) == CONST_LUA_OK) {
    app_id = lua_tonumber(vm, 1);
    h->lua_get_app_bytes(vm, app_id);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_category_bytes(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);
  ndpi_protocol_category_t cat_id;

  lua_newtable(vm);

  if(h && ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) == CONST_LUA_OK) {
    cat_id = (ndpi_protocol_category_t)lua_tointeger(vm, 1);
    h->lua_get_cat_bytes(vm, cat_id);
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_bytes(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_bytes(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_packets(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_packets(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_num_total_flows(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_num_total_flows(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_time(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_time(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_syn_flood(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_syn_flood(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_flow_flood(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_flow_flood(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_syn_scan(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_syn_scan(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_dns_info(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->luaDNS(vm, true /* Verbose */);

  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_host_get_http_info(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->luaHTTP(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_refresh_score(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  if(!h)
    return(CONST_LUA_ERROR);

  h->getScore()->refreshValue();
  lua_pushinteger(vm, h->getScore()->getValue());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_is_local(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  if(!h)
    return(CONST_LUA_ERROR);

  lua_pushboolean(vm, h->isLocalHost());

  return(CONST_LUA_OK);
}


/* ****************************************** */

static int ntop_host_get_ts_key(lua_State* vm) {
  char buf_id[64];
  Host *h = ntop_host_get_context_host(vm);

  if(!h)
    return(CONST_LUA_ERROR);

  lua_pushstring(vm, h->get_tskey(buf_id, sizeof(buf_id)));

  return(CONST_LUA_OK);
}

/* ****************************************** */

static Flow* ntop_flow_get_context_flow(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return c->flow;
}

/* ****************************************** */

// ***API***
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

// ***API***
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
  default:
    return(MUD_RECORDING_DISABLED);
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

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_flow_get_status(lua_State* vm) {
  Flow *f = ntop_flow_get_context_flow(vm);
  if(!f) return(CONST_LUA_ERROR);

  lua_pushinteger(vm, f->getStatusBitmap().get());

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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

// ***API***
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

static int ntop_get_predominant_status(lua_State* vm) {
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
        if(!sqlite_queue->enqueue(flow_str)) {
          f->getInterface()->incNumDroppedAlerts(1);

          if(ctx->threaded_activity_stats)
            ctx->threaded_activity_stats->setAlertsDrops();
        }

        notif_queue->enqueue(flow_str);
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

static int ntop_push_sqlite_alert(lua_State* vm) {
  struct ntopngLuaContext *ctx = getLuaVMContext(vm);
  const char *alert;
  bool rv;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert = lua_tostring(vm, 1);

  if(ntop->getSqliteAlertsQueue()->enqueue(alert))
    rv = true;
  else {
    NetworkInterface *iface = getCurrentInterface(vm);
    rv = false;

    if(iface) {
      iface->incNumDroppedAlerts(1);

      if(ctx->threaded_activity_stats)
        ctx->threaded_activity_stats->setAlertsDrops();
    }
  }

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_pop_sqlite_alert(lua_State* vm) {
  char *alert = ntop->getSqliteAlertsQueue()->dequeue();

  if(alert) {
    lua_pushstring(vm, alert);
    free(alert);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_push_alert_notification(lua_State* vm) {
  const char *notif;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  notif = lua_tostring(vm, 1);

  lua_pushboolean(vm, ntop->getAlertsNotificationsQueue()->enqueue(notif));
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_pop_alert_notification(lua_State* vm) {
  char *notification = ntop->getAlertsNotificationsQueue()->dequeue();

  if(notification) {
    lua_pushstring(vm, notification);
    free(notification);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_pop_internal_alerts(lua_State* vm) {
  ndpi_serializer *internal_alerts = (ndpi_serializer*) ntop->getInternalAlertsQueue()->dequeue();

  if(internal_alerts != NULL) {

    lua_newtable(vm);
    Utils::tlv2lua(vm, (ndpi_serializer*) internal_alerts);

    ndpi_term_serializer(internal_alerts);
    free(internal_alerts);
  } else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
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
  u_int16_t vlan_id = 0;
  AlertType alert_type;
  char buf[64], *host_ip;
  Host *h;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  get_host_vlan_info((char*)lua_tostring(vm, 1), &host_ip, &vlan_id, buf, sizeof(buf));

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_type = (AlertType)lua_tonumber(vm, 2);

  h = iface->findHostByIP(get_allowed_nets(vm), host_ip, vlan_id);

  if(h)
    h->incTotalAlerts(alert_type);

  lua_pushboolean(vm, h ? true : false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_network_get_cached_alert_value(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  NetworkStats *ns = c ? c->network : NULL;
  char *key;
  std::string val;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ns) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 2)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  val = ns->getAlertCachedValue(std::string(key), periodicity);
  lua_pushstring(vm, val.c_str());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_network_set_cached_alert_value(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  NetworkStats *ns = c ? c->network : NULL;
  char *key, *value;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!ns) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 3)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  if((!key) || (!value))
    return(CONST_LUA_PARAM_ERROR);

  ns->setAlertCacheValue(std::string(key), std::string(value), periodicity);

  return(CONST_LUA_OK);
}

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

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_store_triggered_alert(lua_State* vm, AlertableEntity *alertable, int idx = 1) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  char *key, *alert_subtype, *alert_json;
  ScriptPeriodicity periodicity;
  AlertLevel alert_severity;
  AlertType alert_type;
  Host *host;
  bool triggered;

  if(!alertable || !c->iface) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, idx++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, idx++)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_severity = (AlertLevel)lua_tointeger(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_type = (AlertType)lua_tonumber(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((alert_subtype = (char*)lua_tostring(vm, idx++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((alert_json = (char*)lua_tostring(vm, idx++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  triggered = alertable->triggerAlert(vm, std::string(key), periodicity, time(NULL),
    alert_severity, alert_type, alert_subtype, alert_json);

  if(triggered && (host = dynamic_cast<Host*>(alertable)))
    host->incTotalAlerts(alert_type);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_store_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_store_triggered_alert(vm, c->iface);
}

/* ****************************************** */

static int ntop_host_store_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_store_triggered_alert(vm, c->host);
}

/* ****************************************** */

static int ntop_network_store_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_store_triggered_alert(vm, c->network);
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

static int ntop_release_triggered_alert(lua_State* vm, AlertableEntity *alertable, int idx = 1) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  char *key;
  ScriptPeriodicity periodicity;
  time_t when;

  if(!c->iface || !alertable) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, idx++)) == NULL) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((periodicity = (ScriptPeriodicity)lua_tointeger(vm, idx++)) >= MAX_NUM_PERIODIC_SCRIPTS) return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  when = (time_t)lua_tonumber(vm, idx++);

  /* The released alert will be pushed to LUA */
  alertable->releaseAlert(vm, std::string(key), periodicity, when);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_release_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_release_triggered_alert(vm, c->iface);
}

/* ****************************************** */

static int ntop_host_release_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_release_triggered_alert(vm, c->host);
}

/* ****************************************** */

static int ntop_network_release_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_release_triggered_alert(vm, c->network);
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

static void parseEntityExcludes(const char *exclude_str, std::set<int> *entity_excludes) {
  /* NOTE: using std::set<int> instead of std::set<AlertableEntity> to provide automatic
   * comparison operator, required by the set. */
  const char *begin = exclude_str;
  const char *token;

  while((token = strchr(begin, ','))) {
    entity_excludes->insert(atoi(begin));
    begin = token+1;
  }

  /* Last value */
  if(*begin)
    entity_excludes->insert(atoi(begin));
}

/* ****************************************** */

static int ntop_interface_get_engaged_alerts_count(lua_State* vm) {
  AlertEntity entity_type = alert_entity_none;
  const char *entity_value = NULL;
  NetworkInterface *iface = getCurrentInterface(vm);
  std::set<int> entity_excludes;
  AddressTree *allowed_nets = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TNUMBER) entity_type = (AlertEntity)lua_tointeger(vm, 1);
  if(lua_type(vm, 2) == LUA_TSTRING) entity_value = (char*)lua_tostring(vm, 2);
  if(lua_type(vm, 3) == LUA_TSTRING) parseEntityExcludes(lua_tostring(vm, 3), &entity_excludes);

  iface->getEngagedAlertsCount(vm, entity_type, entity_value, &entity_excludes, allowed_nets);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_inc_num_dropped_alerts(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  u_int32_t num_dropped;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  num_dropped = lua_tonumber(vm, 1);

  iface->incNumDroppedAlerts(num_dropped);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_get_engaged_alerts(lua_State* vm) {
  AlertEntity entity_type = alert_entity_none;
  const char *entity_value = NULL;
  AlertType alert_type = alert_none;
  AlertLevel alert_severity = alert_level_none;
  NetworkInterface *iface = getCurrentInterface(vm);
  std::set<int> entity_excludes;
  AddressTree *allowed_nets = get_allowed_nets(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);
  if(!iface) return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TNUMBER) entity_type = (AlertEntity)lua_tointeger(vm, 1);
  if(lua_type(vm, 2) == LUA_TSTRING) entity_value = (char*)lua_tostring(vm, 2);
  if(lua_type(vm, 3) == LUA_TNUMBER) alert_type = (AlertType)lua_tointeger(vm, 3);
  if(lua_type(vm, 4) == LUA_TNUMBER) alert_severity = (AlertLevel)lua_tointeger(vm, 4);
  if(lua_type(vm, 5) == LUA_TSTRING) parseEntityExcludes(lua_tostring(vm, 5), &entity_excludes);

  iface->getEngagedAlerts(vm, entity_type, entity_value, alert_type, alert_severity, &entity_excludes, allowed_nets);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_optimize_alerts(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  AlertsManager *am;

  if(!iface || !(am = iface->getAlertsManager()))
    return(CONST_LUA_ERROR);

  if(am->optimizeStore())
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_query_alerts_raw(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  AlertsManager *am;
  char *selection = NULL, *filter = NULL, *group_by = NULL;
  bool ignore_disabled = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!iface || !(am = iface->getAlertsManager()))
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TSTRING)
    if((selection = (char*)lua_tostring(vm, 1)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 2) == LUA_TSTRING)
    if((filter = (char*)lua_tostring(vm, 2)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 3) == LUA_TSTRING)
    if((group_by = (char*)lua_tostring(vm, 3)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 4) == LUA_TBOOLEAN)
    ignore_disabled = lua_toboolean(vm, 4);

  if(am->queryAlertsRaw(vm, selection, filter,
            getAllowedNetworksHostsSqlFilter(vm), group_by, ignore_disabled))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_interface_query_flow_alerts_raw(lua_State* vm) {
  NetworkInterface *iface = getCurrentInterface(vm);
  AlertsManager *am;
  char *selection = NULL, *filter = NULL, *group_by = NULL;
  bool ignore_disabled = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(!iface || !(am = iface->getAlertsManager()))
    return(CONST_LUA_ERROR);

  if(lua_type(vm, 1) == LUA_TSTRING)
    if((selection = (char*)lua_tostring(vm, 1)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 2) == LUA_TSTRING)
    if((filter = (char*)lua_tostring(vm, 2)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 3) == LUA_TSTRING)
    if((group_by = (char*)lua_tostring(vm, 3)) == NULL)
      return(CONST_LUA_PARAM_ERROR);

  if(lua_type(vm, 4) == LUA_TBOOLEAN)
    ignore_disabled = lua_toboolean(vm, 4);

  if(am->queryFlowAlertsRaw(vm, selection, filter,
            getAllowedNetworksFlowsSqlFilter(vm), group_by, ignore_disabled))
    return(CONST_LUA_ERROR);

  return(CONST_LUA_OK);
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

/* ****************************************** */

static int ntop_nagios_send_alert(lua_State* vm) {
  NagiosManager *nagios = ntop->getNagios();
  char *alert_source;
  char *alert_key;
  char *alert_msg;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_source = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_key = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_msg = (char*)lua_tostring(vm, 3);

  bool rv = nagios->sendAlert(alert_source, alert_key, alert_msg);

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_nagios_withdraw_alert(lua_State* vm) {
  NagiosManager *nagios = ntop->getNagios();
  char *alert_source;
  char *alert_key;
  char *alert_msg;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_source = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_key = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  alert_msg = (char*)lua_tostring(vm, 3);

  bool rv = nagios->withdrawAlert(alert_source, alert_key, alert_msg);

  lua_pushboolean(vm, rv);
  return(CONST_LUA_OK);
}
#endif
#endif

/* ****************************************** */

#ifndef HAVE_NEDGE
#ifdef NTOPNG_PRO
static int ntop_check_sub_interface_syntax(lua_State* vm) {
  char *filter;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  filter = (char*)lua_tostring(vm, 1);

  lua_pushboolean(vm, ntop_interface ? ntop_interface->checkSubInterfaceSyntax(filter) : false);

  return(CONST_LUA_OK);
}
#endif
#endif

/* ****************************************** */

#ifndef HAVE_NEDGE
#ifdef NTOPNG_PRO
static int ntop_check_profile_syntax(lua_State* vm) {
  char *filter;
  NetworkInterface *ntop_interface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  filter = (char*)lua_tostring(vm, 1);

  lua_pushboolean(vm, ntop_interface ? ntop_interface->checkProfileSyntax(filter) : false);

  return(CONST_LUA_OK);
}
#endif
#endif

/* ****************************************** */

#ifndef HAVE_NEDGE
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
#endif

/* ****************************************** */

static int ntop_set_redis(lua_State* vm) {
  char *key, *value;
  u_int expire_secs = 0;  // default 0 = no expiration
  Redis *redis = ntop->getRedis();

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((key = (char*)lua_tostring(vm, 1)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((value = (char*)lua_tostring(vm, 2)) == NULL)     return(CONST_LUA_PARAM_ERROR);

  /* Optional key expiration in SECONDS */
  if(lua_type(vm, 3) == LUA_TNUMBER)
    expire_secs = (u_int)lua_tonumber(vm, 3);

  lua_pushnil(vm);

  if(redis->set(key, value, expire_secs) == 0)
    return(CONST_LUA_OK);

  return(CONST_LUA_ERROR);
}

/* ****************************************** */

static int ntop_set_preference(lua_State* vm) {
  return(ntop_set_redis(vm));
}

/* ****************************************** */

static int ntop_lua_http_print(lua_State* vm) {
  struct mg_connection *conn;
  char *printtype;
  int t;

  conn = getLuaVMUserdata(vm, conn);

  /* ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__); */

  /* Handle binary blob */
  if((lua_type(vm, 2) == LUA_TSTRING)
     && (printtype = (char*)lua_tostring(vm, 2)) != NULL)
    if(!strncmp(printtype, "blob", 4)) {
      char *str = NULL;

      if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
      if((str = (char*)lua_tostring(vm, 1)) != NULL) {
	int len = strlen(str);

	if(len <= 1)
	  mg_printf(conn, "%c", str[0]);
	else
	  return(CONST_LUA_PARAM_ERROR);
      }

      lua_pushnil(vm);
      return(CONST_LUA_OK);
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

  lua_pushnil(vm);
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

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

#if defined(NTOPNG_PRO) || defined(HAVE_NEDGE)

static int __ntop_lua_handlefile(lua_State* L, char *script_path, bool ex) {
  int rc;
  LuaHandler *lh = new LuaHandler(L, script_path);

  rc = lh->luaL_dofileM(ex);
  delete lh;
  return rc;
}

/* ****************************************** */

/* This function is called by Lua scripts when the call require(...) */
static int ntop_lua_require(lua_State* L) {
  char *script_name;

  if(lua_type(L, 1) != LUA_TSTRING ||
     (script_name = (char*)lua_tostring(L, 1)) == NULL)
    return 0;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s(%s)", __FUNCTION__, script_name);

  lua_getglobal( L, "package" );
  lua_getfield( L, -1, "path" );

  string cur_path = lua_tostring( L, -1 ), parsed, script_path = "";
  stringstream input_stringstream(cur_path);
  while(getline(input_stringstream, parsed, ';')) {
    /* Example: package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path */
    unsigned found = parsed.find_last_of("?");
    if(found) {
      string s = parsed.substr(0, found) + script_name + ".lua";
      size_t first_dot = s.find("."), last_dot  = s.rfind(".");

      /*
	Lua transforms file names when directories are used.
	Example:  i18n/version.lua -> i18n.version.lua

	So we need to revert this logic back and the code
	below is doing exactly this
      */
      if((first_dot != string::npos)
	 && (last_dot != string::npos)
	 && (first_dot != last_dot))
	s.replace(first_dot, 1, "/");

      ntop->getTrace()->traceEvent(TRACE_DEBUG, "[%s] Searching %s", __FUNCTION__, s.c_str());

      if(Utils::file_exists(s.c_str())) {
	script_path = s;
	ntop->getTrace()->traceEvent(TRACE_DEBUG, "[%s] Found %s", __FUNCTION__, s.c_str());
	break;
      }
    }
  }

  if(script_path == "" ||
	  __ntop_lua_handlefile(L, (char *)script_path.c_str(),  false)) {
    if(lua_type(L, -1) == LUA_TSTRING) {
      const char *err = lua_tostring(L, -1);
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path.c_str(), err ? err : "");
    }

    return 0;
  }

  return 1;
}

/* ****************************************** */

static int ntop_lua_xfile(lua_State* L, bool ex) {
  char *script_path;
  int ret;

  if(lua_type(L, 1) != LUA_TSTRING ||
     (script_path = (char*)lua_tostring(L, 1)) == NULL)
    return 0;

  ret = __ntop_lua_handlefile(L, script_path, ex);

  if(ret && (!lua_isnil(L, -1))) {
    const char *msg = lua_tostring(L, -1);
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure %s", msg);
  }

  return !ret;
}

/* ****************************************** */

static int ntop_lua_dofile(lua_State* L) {
  return ntop_lua_xfile(L, true);
}

/* ****************************************** */

static int ntop_lua_loadfile(lua_State* L) {
  return ntop_lua_xfile(L, false);
}

#endif

/* ****************************************** */

// ***API***
static int ntop_is_login_disabled(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  bool ret = ntop->getPrefs()->is_localhost_users_login_disabled()
    || !ntop->getPrefs()->is_users_login_enabled();

  lua_pushboolean(vm, ret);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_login_blacklisted(lua_State* vm) {
  struct mg_connection *conn;
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if((conn = getLuaVMUserdata(vm, conn)) == NULL)
    return(CONST_LUA_ERROR);

  lua_pushboolean(vm, ntop->isBlacklistedLogin(conn));
  return(CONST_LUA_OK);
}

/* ****************************************** */

// ***API***
static int ntop_network_name_by_id(lua_State* vm) {
  int id;
  char *name;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  id = (u_int32_t)lua_tonumber(vm, 1);

  name = ntop->getLocalNetworkName(id);

  lua_pushstring(vm, name ? name : "");

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_network_id_by_name(lua_State* vm) {
  u_int8_t num_local_networks = ntop->getNumLocalNetworks();
  int found_id = -1;
  char *name;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  name = (char*)lua_tostring(vm, 1);

  for(u_int8_t network_id = 0; network_id < num_local_networks; network_id++) {
    if(!strcmp(ntop->getLocalNetworkName(network_id), name)) {
      found_id = network_id;
      break;
    }
  }

  lua_pushinteger(vm, found_id);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_is_gui_access_restricted(lua_State* vm) {
  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  lua_pushboolean(vm, ntop->get_HTTPserver()->is_gui_access_restricted());

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_service_restart(lua_State* vm) {
#if defined(__linux__) && defined(NTOPNG_PRO)
  extern AfterShutdownAction afterShutdownAction;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if(!ntop->isUserAdministrator(vm))
    return(CONST_LUA_ERROR);

  if (getppid() == 1 /* parent is systemd */) {
    /* See also ntop_shutdown (used by nEdge) */
    afterShutdownAction = after_shutdown_restart_self;
    ntop->getGlobals()->requestShutdown();
    lua_pushnil(vm);
  }

  return(CONST_LUA_OK);
#else
  return(CONST_LUA_ERROR);
#endif
}

/* ****************************************** */

// ***API***
static int ntop_set_logging_level(lua_State* vm) {
  char *lvlStr;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if(ntop->getPrefs()->hasCmdlTraceLevel()) return(CONST_LUA_OK);
  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return(CONST_LUA_ERROR);

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

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/* NOTE: use lua traceError function */
static int ntop_trace_event(lua_State* vm) {
  char *msg, *fname;
  int level, line;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s() called", __FUNCTION__);

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  level = lua_tointeger(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((fname = (char*)lua_tostring(vm, 2)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  line = lua_tointeger(vm, 3);

  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
  if((msg = (char*)lua_tostring(vm, 4)) == NULL)       return(CONST_LUA_PARAM_ERROR);

  ntop->getTrace()->traceEvent(level, fname, line, "%s", msg);

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

static const luaL_Reg ntop_interface_reg[] = {
  { "setActiveInterfaceId",     ntop_set_active_interface_id },
  { "getIfNames",               ntop_get_interface_names },
  { "getFirstInterfaceId",      ntop_get_first_interface_id },
  { "select",                   ntop_select_interface },
  { "getId",                    ntop_get_interface_id },

  { "getMaxIfSpeed",            ntop_get_max_if_speed },
  { "hasVLANs",                 ntop_interface_has_vlans },
  { "hasEBPF",                  ntop_interface_has_ebpf  },
  { "hasHighResTs",             ntop_interface_has_high_res_ts },
  { "getStats",                 ntop_get_interface_stats },
  { "getStatsUpdateFreq",       ntop_get_interface_stats_update_freq },
  { "updateDirectionStats",     ntop_update_interface_direction_stats },
  { "getInterfaceTimeseries",   ntop_get_interface_timeseries },
  { "resetCounters",            ntop_interface_reset_counters },
  { "resetHostStats",           ntop_interface_reset_host_stats },
  { "deleteHostData",           ntop_interface_delete_host_data },
  { "resetMacStats",            ntop_interface_reset_mac_stats },
  { "deleteMacData",            ntop_interface_delete_mac_data },

  /* Functions related to the management of the internal hash tables */
  { "getHashTablesStats",       ntop_get_interface_hash_tables_stats },
  { "periodicHTStateUpdate",    ntop_periodic_ht_state_update        },

  /* Function for the periodic update of hash tables stats (e.g., throughputs) */
  { "periodicStatsUpdate",      ntop_periodic_stats_update           },

  /* Functions to get and reset the duration of periodic threaded activities */
  { "getPeriodicActivitiesStats",   ntop_get_interface_periodic_activities_stats   },
  { "setPeriodicActivityProgress",  ntop_set_interface_periodic_activity_progress  },

#ifndef HAVE_NEDGE
  { "processFlow",              ntop_process_flow },
#endif

  { "getActiveFlowsStats",      ntop_get_active_flows_stats },
  { "getnDPIProtoName",         ntop_get_ndpi_protocol_name },
  { "getnDPIProtoId",           ntop_get_ndpi_protocol_id },
  { "getnDPICategoryId",        ntop_get_ndpi_category_id },
  { "getnDPICategoryName",      ntop_get_ndpi_category_name },
  { "getnDPIFlowsCount",        ntop_get_ndpi_interface_flows_count },
  { "getFlowsStatus",           ntop_get_ndpi_interface_flows_status },
  { "getnDPIProtoBreed",        ntop_get_ndpi_protocol_breed },
  { "getnDPIProtocols",         ntop_get_ndpi_protocols },
  { "getnDPICategories",        ntop_get_ndpi_categories },
  { "getHostsInfo",             ntop_get_interface_hosts_info },
  { "getLocalHostsInfo",        ntop_get_interface_local_hosts_info },
  { "getRemoteHostsInfo",       ntop_get_interface_remote_hosts_info },
  { "getBroadcastDomainHostsInfo", ntop_get_interface_broadcast_domain_hosts_info },
  { "getBatchedFlowsInfo",         ntop_get_batched_interface_flows_info },
  { "getBatchedHostsInfo",         ntop_get_batched_interface_hosts_info },
  { "getBatchedLocalHostsInfo",    ntop_get_batched_interface_local_hosts_info },
  { "getBatchedRemoteHostsInfo",   ntop_get_batched_interface_remote_hosts_info },
  { "getBatchedLocalHostsTs",   ntop_get_batched_interface_local_hosts_ts },
  { "getHostInfo",              ntop_get_interface_host_info },
  { "getHostUsedPorts",         ntop_get_interface_host_used_ports },
  { "getHostTimeseries",        ntop_get_interface_host_timeseries },
  { "getHostCountry",           ntop_get_interface_host_country },
  { "getGroupedHosts",          ntop_get_grouped_interface_hosts },
  { "addMacsIpAddresses",       ntop_add_macs_ip_addresses },
  { "getNetworksStats",         ntop_get_interface_networks_stats       },
  { "getNetworkStats",          ntop_get_interface_network_stats        },
  { "restoreHost",              ntop_restore_interface_host             },
  { "checkpointHostTalker",     ntop_checkpoint_host_talker             },
  { "getFlowsInfo",             ntop_get_interface_flows_info           },
  { "getGroupedFlows",          ntop_get_interface_get_grouped_flows    },
  { "getFlowsStats",            ntop_get_interface_flows_stats          },
  { "getFlowKey",               ntop_get_interface_flow_key             },
  { "findFlowByKeyAndHashId",   ntop_get_interface_find_flow_by_key_and_hash_id },
  { "findFlowByTuple",          ntop_get_interface_find_flow_by_tuple   },
  { "dropFlowTraffic",          ntop_drop_flow_traffic                  },
  { "dumpLocalHosts2redis",     ntop_dump_local_hosts_2_redis           },
  { "dropMultipleFlowsTraffic", ntop_drop_multiple_flows_traffic        },
  { "findPidFlows",             ntop_get_interface_find_pid_flows       },
  { "findNameFlows",            ntop_get_interface_find_proc_name_flows },
  { "listHTTPhosts",            ntop_list_http_hosts },
  { "findHost",                 ntop_get_interface_find_host },
  { "findHostByMac",            ntop_get_interface_find_host_by_mac },
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
  { "reloadDhcpRanges",                 ntop_reload_dhcp_ranges },
  { "reloadHostPrefs",                  ntop_reload_host_prefs },
  { "setHostOperatingSystem",           ntop_set_host_operating_system },
  { "computeHostsScore",                ntop_compute_hosts_score },
  { "getNumLocalHosts",                 ntop_get_num_local_hosts },

  /* Mac */
  { "getMacsInfo",                      ntop_get_interface_macs_info },
  { "getBatchedMacsInfo",               ntop_get_batched_interface_macs_info },
  { "getMacInfo",                       ntop_get_interface_mac_info  },
  { "getMacHosts",                      ntop_get_interface_mac_hosts },
  { "getMacManufacturers",              ntop_get_interface_macs_manufacturers },
  { "setMacDeviceType",                 ntop_set_mac_device_type },
  { "getMacDeviceTypes",                ntop_get_mac_device_types },

  /* Autonomous Systems */
  { "getASesInfo",                      ntop_get_interface_ases_info },
  { "getASInfo",                        ntop_get_interface_as_info },

  /* Countries */
  { "getCountriesInfo",                 ntop_get_interface_countries_info },
  { "getCountryInfo",                   ntop_get_interface_country_info },

  /* VLANs */
  { "getVLANsList",                     ntop_get_interface_vlans_list },
  { "getVLANsInfo",                     ntop_get_interface_vlans_info },
  { "getVLANInfo",                      ntop_get_interface_vlan_info } ,

  /* Host pools */
  { "reloadHostPools",                  ntop_reload_host_pools                },
  { "findMemberPool",                   ntop_find_member_pool                 },
  { "findMacPool",                      ntop_find_mac_pool                    },
  { "getHostPoolsInfo",                 ntop_get_host_pools_info              },

  /* InfluxDB */
  { "appendInfluxDB",                   ntop_append_influx_db                 },

  { "getHostPoolsStats",                ntop_get_host_pools_interface_stats   },
  { "getHostPoolStats",                 ntop_get_host_pool_interface_stats    },
#ifdef NTOPNG_PRO
#ifdef HAVE_NEDGE
  { "resetPoolsQuotas",                 ntop_reset_pools_quotas               },
#endif
  { "getHostPoolsVolatileMembers",      ntop_get_host_pool_volatile_members   },
  { "purgeExpiredPoolsMembers",         ntop_purge_expired_host_pools_members },
  { "removeVolatileMemberFromPool",     ntop_remove_volatile_member_from_pool },
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
#ifndef HAVE_NEDGE
  { "snmpGetBatch",                    ntop_snmp_batch_get             },
  { "snmpReadResponses",               ntop_snmp_read_responses        },
#endif

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
  { "optimizeAlerts",         ntop_interface_optimize_alerts },
  { "queryAlertsRaw",         ntop_interface_query_alerts_raw         },
  { "queryFlowAlertsRaw",     ntop_interface_query_flow_alerts_raw    },
  { "storeAlert",             ntop_interface_store_alert              },
  { "storeFlowAlert",         ntop_interface_store_flow_alert         },
  { "setInterfaceHasAlerts",  ntop_interface_set_has_alerts           },
  { "getCachedAlertValue",    ntop_interface_get_cached_alert_value   },
  { "setCachedAlertValue",    ntop_interface_set_cached_alert_value   },
  { "storeTriggeredAlert",    ntop_interface_store_triggered_alert    },
  { "releaseTriggeredAlert",  ntop_interface_release_triggered_alert  },
  { "triggerExternalAlert",   ntop_interface_store_external_alert     },
  { "releaseExternalAlert",   ntop_interface_release_external_alert   },
  { "checkContext",           ntop_interface_check_context            },
  { "refreshAlerts",          ntop_interface_refresh_alerts           },
  { "checkDroppedAlerts",     ntop_interface_check_dropped_alerts     },
  { "getEngagedAlerts",       ntop_interface_get_engaged_alerts       },
  { "getEngagedAlertsCount",  ntop_interface_get_engaged_alerts_count },
  { "incNumDroppedAlerts",    ntop_interface_inc_num_dropped_alerts   },
  { "getAlerts",              ntop_interface_get_alerts               },
  { "releaseEngagedAlerts",   ntop_interface_release_engaged_alerts   },
  { "incTotalHostAlerts",     ntop_interface_inc_total_host_alerts    },

  /* Interface Alerts */
  { "checkInterfaceAlertsMin",    ntop_check_interface_alerts_min     },
  { "checkInterfaceAlerts5Min",   ntop_check_interface_alerts_5min    },
  { "checkInterfaceAlertsHour",   ntop_check_interface_alerts_hour    },
  { "checkInterfaceAlertsDay",    ntop_check_interface_alerts_day     },

  /* Host Alerts */
  { "checkHostsAlertsMin",        ntop_check_hosts_alerts_min         },
  { "checkHostsAlerts5Min",       ntop_check_hosts_alerts_5min        },
  { "checkHostsAlertsHour",       ntop_check_hosts_alerts_hour        },
  { "checkHostsAlertsDay",        ntop_check_hosts_alerts_day         },

  /* Network Alerts */
  { "checkNetworksAlertsMin",     ntop_check_networks_alerts_min      },
  { "checkNetworksAlerts5Min",    ntop_check_networks_alerts_5min     },
  { "checkNetworksAlertsHour",    ntop_check_networks_alerts_hour     },
  { "checkNetworksAlertsDay",     ntop_check_networks_alerts_day      },

  /* eBPF, Containers and Companion Interfaces */
  { "getPodsStats",           ntop_interface_get_pods_stats           },
  { "getContainersStats",     ntop_interface_get_containers_stats     },
  { "reloadCompanions",       ntop_interface_reload_companions        },

  { NULL,                     NULL }
};

/* **************************************************************** */

static const luaL_Reg ntop_host_reg[] = {
  { "getInfo",                ntop_host_get_basic_fields        },
  { "getFullInfo",            ntop_host_get_all_fields          },
  { "getCachedAlertValue",    ntop_host_get_cached_alert_value  },
  { "setCachedAlertValue",    ntop_host_set_cached_alert_value  },
  { "storeTriggeredAlert",    ntop_host_store_triggered_alert   },
  { "releaseTriggeredAlert",  ntop_host_release_triggered_alert },
  { "getAlerts",              ntop_host_get_alerts              },
  { "checkContext",           ntop_host_check_context           },

  { "getIp",                  ntop_host_get_ip                  },
  { "getLocalhostInfo",       ntop_host_get_localhost_info      },
  { "getApplicationBytes",    ntop_host_get_application_bytes   },
  { "getCategoryBytes",       ntop_host_get_category_bytes      },
  { "getBytes",               ntop_host_get_bytes               },
  { "getPackets",             ntop_host_get_packets             },
  { "getNumFlows",            ntop_host_get_num_total_flows     },
  { "getTime",                ntop_host_get_time                },
  { "getSynFlood",            ntop_host_get_syn_flood           },
  { "getFlowFlood",           ntop_host_get_flow_flood          },
  { "getSynScan",             ntop_host_get_syn_scan            },
  { "getDNSInfo",             ntop_host_get_dns_info            },
  { "getHTTPInfo",            ntop_host_get_http_info           },
  { "refreshScore",           ntop_host_refresh_score           },
  { "isLocal",                ntop_host_is_local                },
  { "getTsKey",               ntop_host_get_ts_key              },

  { NULL,                     NULL }
};

/* **************************************************************** */

static const luaL_Reg ntop_network_reg[] = {
  { "getNetworkStats",          ntop_network_get_network_stats       },
  { "getCachedAlertValue",      ntop_network_get_cached_alert_value  },
  { "setCachedAlertValue",      ntop_network_set_cached_alert_value  },
  { "storeTriggeredAlert",      ntop_network_store_triggered_alert   },
  { "releaseTriggeredAlert",    ntop_network_release_triggered_alert },
  { "getAlerts",                ntop_network_get_alerts              },
  { "checkContext",             ntop_network_check_context           },
  
  { NULL,                     NULL }
};

/* **************************************************************** */

static const luaL_Reg ntop_flow_reg[] = {
  /* Documented */
  { "getStatus",                ntop_flow_get_status                 },
  { "isBlacklisted",            ntop_flow_is_blacklisted             },
  { "setStatus",                ntop_flow_set_status                 },
  { "clearStatus",              ntop_flow_clear_status               },
  { "getInfo",                  ntop_flow_get_info                   },
  { "getFullInfo",              ntop_flow_get_full_info              },
  { "getUnicastInfo",           ntop_flow_get_unicast_info           },

  { "triggerAlert",             ntop_flow_trigger_alert              },
  { "getPredominantStatus",     ntop_get_predominant_status          },
  { "isStatusSet",              ntop_flow_is_status_set              },
  { "getKey",                   ntop_flow_get_key                    },
  { "getHashEntryId",           ntop_flow_get_hash_entry_id          },
  { "getICMPStatusInfo",        ntop_flow_get_icmp_status_info       },
  { "getAlertedStatusScore",    ntop_flow_get_alerted_status_score   },
  { "getFirstSeen",             ntop_flow_get_first_seen             },
  { "getLastSeen",              ntop_flow_get_last_seen              },
  { "getDuration",              ntop_flow_get_duration               },
  { "isTwhOK",                  ntop_flow_is_twh_ok                  },
  { "isBidirectional",          ntop_flow_is_bidirectional           },
  { "getPacketsSent",           ntop_flow_get_packets_sent           },
  { "getPacketsRcvd",           ntop_flow_get_packets_rcvd           },
  { "getPackets",               ntop_flow_get_packets                },
  { "getBytesSent",             ntop_flow_get_bytes_sent             },
  { "getBytesRcvd",             ntop_flow_get_bytes_rcvd             },
  { "getBytes",                 ntop_flow_get_bytes                  },
  { "getGoodputBytes",          ntop_flow_get_goodput_bytes          },
  { "getClientKey",             ntop_flow_get_client_key             },
  { "getServerKey",             ntop_flow_get_server_key             },
  { "isClientUnicast",          ntop_flow_is_client_unicast          },
  { "isServerUnicast",          ntop_flow_is_server_unicast          },
  { "isUnicast",                ntop_flow_is_unicast                 },
  { "isRemoteToRemote",         ntop_flow_is_remote_to_remote        },
  { "isLocalToRemote",          ntop_flow_is_local_to_remote         },
  { "isRemoteToLocal",          ntop_flow_is_remote_to_local         },
  { "getnDPICategoryName",      ntop_flow_get_ndpi_cat_name          },
  { "getnDPIProtocolName",      ntop_flow_get_ndpi_protocol_name     },
  { "getnDPICategoryId",        ntop_flow_get_ndpi_category_id       },
  { "getnDPIMasterProtoId",     ntop_flow_get_ndpi_master_proto_id   },
  { "getnDPIAppProtoId",        ntop_flow_get_ndpi_app_proto_id      },
  { "getClientTCPIssues",       ntop_flow_get_cli_tcp_issues         },
  { "getServerTCPIssues",       ntop_flow_get_srv_tcp_issues         },
  { "isDeviceProtocolNotAllowed", ntop_flow_is_dp_not_allowed        },
  { "isTCPConnectionRefused",   ntop_flow_is_tcp_connection_refused  },
  { "isTCPConnecting",          ntop_flow_is_tcp_connecting          },
  { "getServerCipherClass",     ntop_flow_get_ssl_cipher_class       },
  { "getICMPType",              ntop_flow_get_icmp_type              },
  { "getMaxSeenIcmpPayloadSize", ntop_flow_get_max_seen_icmp_size    },
  { "dnsQueryHasInvalidChars",  ntop_flow_dns_query_invalid_chars    },
  { "getDnsQuery",              ntop_flow_get_dns_query              },
  { "getProtoBreed",            ntop_flow_get_proto_breed            },
  { "hasMaliciousTlsSignature", ntop_flow_has_malicious_tls_signature },
  { "getClientCountry",         ntop_flow_get_client_country         },
  { "getServerCountry",         ntop_flow_get_server_country         },

  /* TODO document */
  { "isLocal",                  ntop_flow_is_local                   },
#ifdef NTOPNG_PRO
  { "getScore",                 ntop_flow_get_score                  },
  { "getScoreInfo",             ntop_flow_get_score_info             },
#endif
  { "getMUDInfo",               ntop_flow_get_mud_info               },
  { "isNotPurged",              ntop_flow_is_not_purged              },
  { "getTLSVersion",            ntop_flow_get_tls_version            },
  { "getTCPStats",              ntop_flow_get_tcp_stats              },
  { "getBlacklistedInfo",       ntop_flow_get_blacklisted_info       },
#ifdef HAVE_NEDGE
  { "isPassVerdict",            ntop_flow_is_pass_verdict            },
#endif
  { "retrieveExternalAlertInfo", ntop_flow_retrieve_external_alert_info },
  { "getDeviceProtoAllowedInfo", ntop_flow_get_device_proto_allowed_info},
  { "getClient2ServerIAT",      ntop_flow_get_cli2srv_iat            },
  { "getServer2ClientIAT",      ntop_flow_get_srv2cli_iat            },
  { "getTLSInfo",               ntop_flow_get_tls_info               },
  { "getSSHInfo",               ntop_flow_get_ssh_info               },
  { "getHTTPInfo",              ntop_flow_get_http_info              },
  { "getDNSInfo",               ntop_flow_get_dns_info               },

  { NULL,                     NULL }
};

/* **************************************************************** */

static const luaL_Reg ntop_reg[] = {
  { "getDirs",          ntop_get_dirs },
  { "getInfo",          ntop_get_info },
  { "getUptime",        ntop_get_uptime },
  { "dumpFile",         ntop_dump_file },
  { "dumpBinaryFile",   ntop_dump_binary_file },
  { "checkLicense",     ntop_check_license },
  { "systemHostStat",   ntop_system_host_stat },
  { "refreshCpuLoad",   ntop_refresh_cpu_load },
  { "getCookieAttributes", ntop_get_cookie_attributes },
  { "isAllowedInterface",  ntop_is_allowed_interface },
  { "isAllowedNetwork",    ntop_is_allowed_network },
  { "md5",              ntop_md5 },
  { "hasRadiusSupport", ntop_has_radius_support },
  { "hasLdapSupport",   ntop_has_ldap_support },
  { "execSingleSQLQuery", ntop_interface_exec_single_sql_query },
  { "resetStats",       ntop_reset_stats },

  /* Redis */
  { "getCacheStatus",    ntop_info_redis },
  { "getCache",          ntop_get_redis },
  { "setCache",          ntop_set_redis },
  { "incrCache",         ntop_incr_redis },
  { "getCacheStats",     ntop_get_redis_stats },
  { "delCache",          ntop_delete_redis_key },
  { "flushCache",        ntop_flush_redis },
  { "listIndexCache",    ntop_list_index_redis },
  { "lpushCache",        ntop_lpush_redis },
  { "rpushCache",        ntop_rpush_redis },
  { "lpopCache",         ntop_lpop_redis },
  { "rpopCache",         ntop_rpop_redis },
  { "lremCache",         ntop_lrem_redis },
  { "ltrimCache",        ntop_ltrim_redis },
  { "lrangeCache",       ntop_lrange_redis },
  { "llenCache",         ntop_llen_redis },
  { "setMembersCache",   ntop_add_set_member_redis },
  { "delMembersCache",   ntop_del_set_member_redis },
  { "getMembersCache",   ntop_get_set_members_redis },
  { "getHashCache",      ntop_get_hash_redis },
  { "setHashCache",      ntop_set_hash_redis },
  { "delHashCache",      ntop_delete_hash_redis_key },
  { "getHashKeysCache",  ntop_get_hash_keys_redis },
  { "getHashAllCache",   ntop_get_hash_all_redis },
  { "getKeysCache",      ntop_get_keys_redis },
  { "dumpCache",         ntop_redis_dump },
  { "restoreCache",      ntop_redis_restore },
  { "addLocalNetwork",   ntop_add_local_network },

  /* Redis Preferences */
  { "setPref",           ntop_set_preference },
  { "getPref",           ntop_get_redis      },

  { "isdir",            ntop_is_dir },
  { "mkdir",            ntop_mkdir_tree },
  { "notEmptyFile",     ntop_is_not_empty_file },
  { "exists",           ntop_get_file_dir_exists },
  { "listReports",      ntop_list_reports },
  { "fileLastChange",   ntop_get_file_last_change },
  { "readdir",          ntop_list_dir_files },
  { "rmdir",            ntop_remove_dir_recursively },
#ifndef HAVE_NEDGE
  { "zmq_connect",      ntop_zmq_connect },
  { "zmq_disconnect",   ntop_zmq_disconnect },
  { "zmq_receive",      ntop_zmq_receive },
#endif
  { "reloadPreferences",   ntop_reload_preferences },
  { "reloadPlugins",       ntop_reload_plugins        },
  { "hasPluginsReloaded",  ntop_has_plugins_reloaded  },
  { "setAlertsTemporaryDisabled", ntop_temporary_disable_alerts },
  { "setDefaultFilePermissions",  ntop_set_default_file_permissions },
  
#ifdef NTOPNG_PRO
#ifndef WIN32
  { "sendNagiosAlert",        ntop_nagios_send_alert     },
  { "withdrawNagiosAlert",    ntop_nagios_withdraw_alert },
  { "reloadNagiosConfig",     ntop_nagios_reload_config  },
#endif
#ifndef HAVE_NEDGE
  { "checkSubInterfaceSyntax", ntop_check_sub_interface_syntax },
  { "checkProfileSyntax",     ntop_check_profile_syntax    },
  { "reloadProfiles",         ntop_reload_traffic_profiles },
#endif
#endif

  { "isPro",                  ntop_is_pro },
  { "isEnterprise",           ntop_is_enterprise },
  { "isnEdge",                ntop_is_nedge },
  { "isnEdgeEnterprise",      ntop_is_nedge_enterprise },
  { "isPackage",              ntop_is_package },

  /* Historical database */
  { "insertMinuteSampling",          ntop_stats_insert_minute_sampling },
  { "insertHourSampling",            ntop_stats_insert_hour_sampling },
  { "insertDaySampling",             ntop_stats_insert_day_sampling },
  { "getMinuteSampling",             ntop_stats_get_minute_sampling },
  { "deleteMinuteStatsOlderThan",    ntop_stats_delete_minute_older_than },
  { "deleteHourStatsOlderThan",      ntop_stats_delete_hour_older_than },
  { "deleteDayStatsOlderThan",       ntop_stats_delete_day_older_than },
  { "getMinuteSamplingsFromEpoch",   ntop_stats_get_samplings_of_minutes_from_epoch },
  { "getHourSamplingsFromEpoch",     ntop_stats_get_samplings_of_hours_from_epoch },
  { "getDaySamplingsFromEpoch",      ntop_stats_get_samplings_of_days_from_epoch },
  { "getMinuteSamplingsInterval",    ntop_stats_get_minute_samplings_interval },

  { "deleteOldRRDs",     ntop_delete_old_rrd_files },

  /* Time */
  { "gettimemsec",      ntop_gettimemsec      },
  { "tzset",            ntop_tzset            },
  { "roundTime",        ntop_round_time       },

  /* Ticks */
  { "getticks",         ntop_getticks         },
  { "gettickspersec",   ntop_gettickspersec   },

  /* UDP */
  { "send_udp_data",    ntop_send_udp_data },

  /* IP */
  { "inet_ntoa",        ntop_inet_ntoa },
  { "networkPrefix",    ntop_network_prefix },

  /* RRD */
  { "rrd_create",        ntop_rrd_create        },
  { "rrd_update",        ntop_rrd_update        },
  { "rrd_fetch",         ntop_rrd_fetch         },
  { "rrd_fetch_columns", ntop_rrd_fetch_columns },
  { "rrd_lastupdate",    ntop_rrd_lastupdate    },
  { "rrd_tune",          ntop_rrd_tune          },
  { "rrd_is_slow",       ntop_rrd_is_slow       },
  { "rrd_inc_num_drops", ntop_rrd_inc_num_drops },

  /* Prefs */
  { "getPrefs",          ntop_get_prefs },

  /* Ping */
  { "pingHost",             ntop_ping_host              },
  { "collectPingResults",   ntop_collect_ping_results   },
  
  /* HTTP utils */
  { "httpRedirect",         ntop_http_redirect          },
  { "getHttpPrefix",        ntop_http_get_prefix        },
  { "getStartupEpoch",      ntop_http_get_startup_epoch },
  { "httpPurifyParam",      ntop_http_purify_param      },

  /* Admin */
  { "getNologinUser",       ntop_get_nologin_username },
  { "getUsers",             ntop_get_users },
  { "isAdministrator",      ntop_is_administrator },
  { "isPcapDownloadAllowed",ntop_is_pcap_download_allowed },
  { "getAllowedInterface",  ntop_get_allowed_interface },
  { "getAllowedNetworks",   ntop_get_allowed_networks },
  { "resetUserPassword",    ntop_reset_user_password },
  { "changeUserRole",       ntop_change_user_role },
  { "changeAllowedNets",    ntop_change_allowed_nets },
  { "changeAllowedIfname",  ntop_change_allowed_ifname },
  { "changeUserHostPool",   ntop_change_user_host_pool },
  { "changeUserLanguage",   ntop_change_user_language  },
  { "changeUserPermission", ntop_change_user_permission },
  { "addUser",              ntop_add_user },
  { "addUserLifetime",      ntop_add_user_lifetime },
  { "clearUserLifetime",    ntop_clear_user_lifetime },
  { "deleteUser",           ntop_delete_user },
  { "isLoginDisabled",      ntop_is_login_disabled },
  { "isLoginBlacklisted",   ntop_is_login_blacklisted },
  { "getNetworkNameById",   ntop_network_name_by_id },
  { "getNetworkIdByName",   ntop_network_id_by_name },
  { "isGuiAccessRestricted", ntop_is_gui_access_restricted },
  { "serviceRestart",       ntop_service_restart },

  /* Security */
  { "getRandomCSRFValue",   ntop_generate_csrf_value },

  /* HTTP */
  { "httpGet",              ntop_http_get            },
  { "httpPost",             ntop_http_post           },
  { "httpFetch",            ntop_http_fetch          },
  { "postHTTPJsonData",     ntop_post_http_json_data },
  { "postHTTPTextFile",     ntop_post_http_text_file },

#ifdef HAVE_CURL_SMTP
  /* SMTP */
  { "sendMail",             ntop_send_mail           },
#endif

  /* Address Resolution */
  { "resolveName",       ntop_resolve_address },       /* Note: you should use resolveAddress() to call from Lua */
  { "getResolvedName",   ntop_get_resolved_address },  /* Note: you should use getResolvedAddress() to call from Lua */
  { "resolveHost",       ntop_resolve_host         },

  /* Logging */
#ifndef WIN32
  { "syslog",            ntop_syslog },
#endif
  { "setLoggingLevel",   ntop_set_logging_level },
  { "traceEvent",        ntop_trace_event },
  { "verboseTrace",      ntop_verbose_trace },

  /* SNMP */
#ifndef HAVE_NEDGE
  { "snmpget",          ntop_snmpget },
  { "snmpgetnext",      ntop_snmpgetnext },
#endif

  /* Runtime */
  { "hasGeoIP",         ntop_has_geoip },
  { "isWindows",        ntop_is_windows },

  /* Custom Categories - only inteded to be called from housekeeping.lua */
  { "startCustomCategoriesReload", ntop_startCustomCategoriesReload },
  { "loadCustomCategoryIp",        ntop_loadCustomCategoryIp        },
  { "loadCustomCategoryHost",      ntop_loadCustomCategoryHost      },
  { "reloadCustomCategories",      ntop_reloadCustomCategories      },

  /* Privileges */
  { "gainWriteCapabilities",   ntop_gainWriteCapabilities },
  { "dropWriteCapabilities",   ntop_dropWriteCapabilities },

  /* Misc */
  { "getservbyport",        ntop_getservbyport        },
  { "msleep",               ntop_msleep               },
  { "tcpProbe",             ntop_tcp_probe            },
  { "getMacManufacturer",   ntop_get_mac_manufacturer },
  { "getHostInformation",   ntop_get_host_information },
  { "isShutdown",           ntop_is_shutdown          },
  { "listInterfaces",       ntop_list_interfaces      },
  { "ipCmp",                ntop_ip_cmp               },
  { "matchCustomCategory",    ntop_match_custom_category },
  { "getTLSVersionName",    ntop_get_tls_version_name },
  { "isIPv6",               ntop_is_ipv6              },
  { "reloadPeriodicScripts", ntop_reload_periodic_scripts },

  /* JA3 */
  { "loadMaliciousJA3Hash", ntop_load_malicious_ja3_hash },
  { "reloadJA3Hashes",      ntop_reload_ja3_hashes       },

  /* Device Protocols */
  { "reloadDeviceProtocols", ntop_reload_device_protocols },

  /* Traffic Recording/Extraction */
  { "runExtraction",         ntop_run_extraction        },
  { "stopExtraction",        ntop_stop_extraction       },
  { "isExtractionRunning",   ntop_is_extraction_running },
  { "getExtractionStatus",   ntop_get_extraction_status },
  { "runLiveExtraction",     ntop_run_live_extraction   },

  /* Bitmap functions */
  { "bitmapIsSet",           ntop_bitmap_is_set         },
  { "bitmapSet",             ntop_bitmap_set            },
  { "bitmapClear",           ntop_bitmap_clear          },

  /* Alerts queues */
  { "pushSqliteAlert",       ntop_push_sqlite_alert           },
  { "popSqliteAlert",        ntop_pop_sqlite_alert            },
  { "pushAlertNotification", ntop_push_alert_notification     },
  { "popAlertNotification",  ntop_pop_alert_notification      },
  { "popInternalAlerts",     ntop_pop_internal_alerts         },

  /* nDPI */
  { "getnDPIProtoCategory",   ntop_get_ndpi_protocol_category },
  { "setnDPIProtoCategory",   ntop_set_ndpi_protocol_category },

  /* Patricia Tree */
  { "ptreeClear",             ntop_ptree_clear             },
  { "ptreeInsert",            ntop_ptree_insert            },
  { "ptreeMatch",             ntop_ptree_match             },

  /* nEdge */
#ifdef HAVE_NEDGE
  { "setHTTPBindAddr",       ntop_set_http_bind_addr       },
  { "setHTTPSBindAddr",      ntop_set_https_bind_addr      },
  { "shutdown",              ntop_shutdown                 },
  { "setRoutingMode",        ntop_set_routing_mode         },
  { "isRoutingMode",         ntop_is_routing_mode          },
  { "setLanInterface",       ntop_set_lan_interface        },
  { "refreshDeviceProtocolsPoliciesConf", ntop_refresh_device_protocols_policies_pref },
#endif

  /* System User Scripts */
  { "checkSystemScriptsMin",     ntop_check_system_scripts_min       },
  { "checkSystemScripts5Min",    ntop_check_system_scripts_5min      }, 
  { "checkSystemScriptsHour",    ntop_check_system_scripts_hour      },
  { "checkSystemScriptsDay",     ntop_check_system_scripts_day       },
  { "checkSNMPDeviceAlerts5Min", ntop_check_snmp_device_alerts_5min  },

  /* Periodic scripts (ThreadedActivity.cpp) */
  { "isDeadlineApproaching",     ntop_script_is_deadline_approaching },
  { "getDeadline",               ntop_script_get_deadline            },

  { NULL,          NULL}
};

/* ****************************************** */

void LuaEngine::luaRegister(lua_State *L, const ntop_class_reg *reg) {
  static const luaL_Reg _meta[] = { { NULL, NULL } };
  int lib_id, meta_id;

  /* newclass = {} */
  lua_createtable(L, 0, 0);
  lib_id = lua_gettop(L);

  /* metatable = {} */
  luaL_newmetatable(L, reg->class_name);
  meta_id = lua_gettop(L);
  luaL_setfuncs(L, _meta, 0);

  /* metatable.__index = class_methods */
  lua_newtable(L);
  luaL_setfuncs(L, reg->class_methods, 0);
  lua_setfield(L, meta_id, "__index");

  /* class.__metatable = metatable */
  lua_setmetatable(L, lib_id);

  /* _G["Foo"] = newclass */
  lua_setglobal(L, reg->class_name);
}

void LuaEngine::luaRegisterInternalRegs(lua_State *L) {
  int i;

  ntop_class_reg ntop_lua_reg[] = {
    { "interface", ntop_interface_reg },
    { "ntop",      ntop_reg           },
    { "host",      ntop_host_reg      },
    { "network",   ntop_network_reg   },
    { "flow",      ntop_flow_reg      },
    {NULL,         NULL}
  };

  for(i=0; ntop_lua_reg[i].class_name != NULL; i++)
    LuaEngine::luaRegister(L, &ntop_lua_reg[i]);
}

void LuaEngine::lua_register_classes(lua_State *L, bool http_mode) {
  if(!L) return;

  LuaEngine::luaRegisterInternalRegs(L);

  if(http_mode) {
    /* Overload the standard Lua print() with ntop_lua_http_print that dumps data on HTTP server */
    lua_register(L, "print", ntop_lua_http_print);
  } else
    lua_register(L, "print", ntop_lua_cli_print);

#if defined(NTOPNG_PRO) || defined(HAVE_NEDGE)
  if(ntop->getPro()->has_valid_license()) {
    lua_register(L, "ntopRequire", ntop_lua_require);
    /* Lua 5.2.x uses package.loaders   */
    luaL_dostring(L, "package.loaders = { ntopRequire }");
    /* Lua 5.3.x uses package.searchers */
    luaL_dostring(L, "package.searchers = { ntopRequire }");
    lua_register(L, "dofile", ntop_lua_dofile);
    lua_register(L, "loadfile", ntop_lua_loadfile);
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

/* Loads a script into the engine from within ntopng (no HTTP GUI). */
int LuaEngine::load_script(char *script_path, NetworkInterface *iface) {
  int rc = 0;

  if(!L) return(-1);

  if(loaded_script_path)
    free(loaded_script_path);

  try {
    luaL_openlibs(L); /* Load base libraries */
    lua_register_classes(L, false); /* Load custom classes */

    if(iface) {
      /* Select the specified inteface */
      getLuaVMUservalue(L, iface) = iface;
    }

#ifdef NTOPNG_PRO
    if(ntop->getPro()->has_valid_license())
      rc = __ntop_lua_handlefile(L, script_path, false /* Do not execute */);
    else
#endif
      rc = luaL_loadfile(L, script_path);

    if(rc != 0) {
      const char *err = lua_tostring(L, -1);

      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path, err ? err : "");
      rc = -1;
    }
  } catch(...) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s]", script_path);
    rc = -2;
  }

  loaded_script_path = strdup(script_path);

  return(rc);
}

/* ****************************************** */

/*
  Run a loaded Lua script (via LuaEngine::load_script) from within ntopng (no HTTP GUI).
  The script is invoked without any additional parameters. run_loaded_script can be called
  multiple times to run the same script again.
*/
int LuaEngine::run_loaded_script() {
  int top = lua_gettop(L);
  int rv = 0;

  if(!loaded_script_path)
    return(-1);

  /* Copy the lua_chunk to be able to possibly run it again next time */
  lua_pushvalue(L, -1);

  /* Perform the actual call */
  if(lua_pcall(L, 0, 0, 0) != 0) {
    if(lua_type(L, -1) == LUA_TSTRING) {
      const char *err = lua_tostring(L, -1);
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", loaded_script_path, err ? err : "");
    }

    rv = -2;
  }

  /* Reset the stack */
  lua_settop(L, top);

  return(rv);
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

#ifdef NOT_USED

void LuaEngine::purifyHTTPParameter(char *param) {
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
#endif

/* ****************************************** */

bool LuaEngine::switchInterface(struct lua_State *vm, const char *ifid,
    const char *user, const char *session) {
  NetworkInterface *iface = NULL;
  char iface_key[64], ifname_key[64];
  char iface_id[16];

  iface = ntop->getNetworkInterface(vm, atoi(ifid));

  if(iface == NULL)
    return false;

  if(user != NULL) {
    if(!strlen(session) && strcmp(user, NTOP_NOLOGIN_USER))
      return false; 

    snprintf(iface_key, sizeof(iface_key), NTOPNG_PREFS_PREFIX ".%s.iface", user);
    snprintf(ifname_key, sizeof(ifname_key), NTOPNG_PREFS_PREFIX ".%s.ifname", user);
  } else { // Login disabled
    snprintf(iface_key, sizeof(iface_key), NTOPNG_PREFS_PREFIX ".iface");
    snprintf(ifname_key, sizeof(ifname_key), NTOPNG_PREFS_PREFIX ".ifname");
  }

  snprintf(iface_id, sizeof(iface_id), "%d", iface->get_id());
  ntop->getRedis()->set(iface_key, iface_id, 0);
  ntop->getRedis()->set(ifname_key, iface->get_name(), 0);

  return true;
}

/* ****************************************** */

void LuaEngine::setInterface(const char * user, char * const ifname,
			     u_int16_t ifname_len, bool * const is_allowed) const {
  NetworkInterface *iface = NULL;
  char key[CONST_MAX_LEN_REDIS_KEY];
  ifname[0] = '\0';

  if((user == NULL) || (user[0] == '\0'))
    user = NTOP_NOLOGIN_USER;

  if(is_allowed) *is_allowed = false;

  // check if the user is restricted to browse only a given interface
  if(snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, user)
     && ntop->getRedis()->get(key, ifname, ifname_len) == 0
     && ifname[0] != '\0') {
    /* If here is only one allowed interface for the user.
       The interface must exists otherwise we hould have prevented the login */
    if(is_allowed) *is_allowed = true;
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Allowed interface found. [Interface: %s][user: %s]",
				 ifname, user);
  } else if(snprintf(key, sizeof(key), "ntopng.prefs.%s.ifname", user)
	    && (ntop->getRedis()->get(key, ifname, ifname_len) < 0
		|| (!ntop->isExistingInterface(ifname)))) {
    /* No allowed interface and no default (or not existing) set interface */
    snprintf(ifname, ifname_len, "%s",
	     ntop->getFirstInterface()->get_name());
    ntop->getRedis()->set(key, ifname, 3600 /* 1h */);
    ntop->getTrace()->traceEvent(TRACE_DEBUG,
				 "No interface interface found. Using default. [Interface: %s][user: %s]",
				 ifname, user);
  }

  if((iface = ntop->getNetworkInterface(ifname, NULL /* allowed user interface check already enforced */)) != NULL) {
    /* The specified interface still exists */
    lua_push_str_table_entry(L, "ifname", iface->get_name());
    snprintf(ifname, ifname_len, "%s", iface->get_name());

    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Interface found [Interface: %s][user: %s]", iface->get_name(), user);
  }
}

/* ****************************************** */

bool LuaEngine::setParamsTable(lua_State* vm,
			       const struct mg_request_info *request_info,
			       const char* table_name,
			       const char* query) const {
  char *where;
  char *tok;
  char *query_string = query ? strdup(query) : NULL;
  bool ret = false;

  lua_newtable(L);

  if(query_string
     && strcmp(request_info->uri, CAPTIVE_PORTAL_INFO_URL) /* Ignore informative portal */
     ) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] %s", query_string);

    tok = strtok_r(query_string, "&", &where);

    while(tok != NULL) {
      char *_equal;

      if(strncmp(tok, "csrf", strlen("csrf")) != 0 /* Do not put csrf into the params table */
         && strncmp(tok, "switch_interface", strlen("switch_interface")) != 0
	 && (_equal = strchr(tok, '='))){
	char *decoded_buf;
        int len;

        _equal[0] = '\0';
        _equal = &_equal[1];
        len = strlen(_equal);

	// ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %s", tok, _equal);

        if((decoded_buf = (char*)malloc(len+1)) != NULL) {
	  bool rsp = false;

          Utils::urlDecode(_equal, decoded_buf, len + 1);

	  rsp = Utils::purifyHTTPparam(tok, true, false, false);
	  /* don't purify decoded_buf, it's purified in lua */

	  if(rsp) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] Invalid '%s'", query);
	    ret = true;
	  }

	  /* Now make sure that decoded_buf is not a file path */
	  if(strchr(decoded_buf, CONST_PATH_SEP)
	     && Utils::file_exists(decoded_buf)
	     && !Utils::dir_exists(decoded_buf)
	     && strcmp(tok, "pid_name") /* This is the only exception */
	     )
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarded '%s'='%s' as argument is a valid file path",
					 tok, decoded_buf);
	  else
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

  return(ret);
}

/* ****************************************** */

int LuaEngine::handle_script_request(struct mg_connection *conn,
				     const struct mg_request_info *request_info,
				     char *script_path, bool *attack_attempt,
				     const char *user,
				     const char *group, bool localuser) {
  NetworkInterface *iface = NULL;
  char key[64], ifname[MAX_INTERFACE_NAME_LEN];
  bool is_interface_allowed;
  AddressTree ptree;
  int rc, post_data_len;
  const char * content_type;
  u_int8_t valid_csrf = 1;
  char *post_data = NULL;
  char rsp[32];
  char csrf[64] = { '\0' };
  char switch_interface[2] = { '\0' };
  char addr_buf[64];
  char session_buf[64];
  char ifid_buf[32];
  bool send_redirect = false;
  IpAddress client_addr;

  *attack_attempt = false;

  if(!L) return(-1);

  luaL_openlibs(L); /* Load base libraries */
  lua_register_classes(L, true); /* Load custom classes */

  getLuaVMUservalue(L, conn) = conn;

  content_type = mg_get_header(conn, "Content-Type");
  mg_get_cookie(conn, "session", session_buf, sizeof(session_buf));

  /* Check for POST requests */
  if((strcmp(request_info->request_method, "POST") == 0) && (content_type != NULL)) {
    int content_len = mg_get_content_len(conn)+1;

    if (content_len > HTTP_MAX_POST_DATA_LEN)
      content_len = HTTP_MAX_POST_DATA_LEN;

    if((post_data = (char*)malloc(content_len * sizeof(char))) == NULL
       || (post_data_len = mg_read(conn, post_data, content_len)) == 0) {
      valid_csrf = 0;

    } else if(post_data_len > content_len - 1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Too much data submitted with the form. [post_data_len: %u]",
				   post_data_len);
      valid_csrf = 0;
    } else {
      post_data[post_data_len] = '\0';

      /* CSRF is mandatory in POST request */
      mg_get_var(post_data, post_data_len, "csrf", csrf, sizeof(csrf));

      if(strstr(content_type, "application/json"))
	valid_csrf = 1;
      else {
	if((ntop->getRedis()->get(csrf, rsp, sizeof(rsp)) == -1) || (strcmp(rsp, user) != 0))
	  valid_csrf = 0;
	else {
	  /* Invalidate csrf */
	  ntop->getRedis()->del(csrf);
	}
      }
    }

    if(valid_csrf) {
      if(strstr(content_type, "application/x-www-form-urlencoded") == content_type)
	*attack_attempt = setParamsTable(L, request_info, "_POST", post_data); /* CSRF is valid here, now fill the _POST table with POST parameters */
      else {
	/* application/json" */

	lua_newtable(L);
	lua_push_str_table_entry(L, "payload", post_data);
	lua_setglobal(L, "_POST");
      }

      /* Check for interface switch requests */
      mg_get_var(post_data, post_data_len, "switch_interface", switch_interface, sizeof(switch_interface));
      if (strlen(switch_interface) > 0 && request_info->query_string) {
        mg_get_var(request_info->query_string, strlen(request_info->query_string), "ifid", ifid_buf, sizeof(ifid_buf));
        if (strlen(ifid_buf) > 0) {
          switchInterface(L, ifid_buf, user, session_buf);

	  /* Sending a redirect is needed to prevent the current lua script
	   * from receiving the POST request, as it could exchange the request
	   * as a configuration save request. */
	  send_redirect = true;
	}
      }

    } else
      *attack_attempt = setParamsTable(L, request_info, "_POST", NULL /* Empty */);

    if(post_data)
      free(post_data);
  } else
    *attack_attempt = setParamsTable(L, request_info, "_POST", NULL /* Empty */);

  if(send_redirect) {
    char buf[512];

    build_redirect(request_info->uri, request_info->query_string, buf, sizeof(buf));

    /* Redirect the page and terminate this request */
    mg_printf(conn, "%s", buf);
    return(CONST_LUA_OK);
  }

  /* Put the GET params into the environment */
  if(request_info->query_string)
    *attack_attempt = setParamsTable(L, request_info, "_GET", request_info->query_string);
  else
    *attack_attempt = setParamsTable(L, request_info, "_GET", NULL /* Empty */);

  /* _SERVER */
  lua_newtable(L);
  lua_push_str_table_entry(L, "REQUEST_METHOD", (char*)request_info->request_method);
  lua_push_str_table_entry(L, "URI", (char*)request_info->uri ? (char*)request_info->uri : (char*)"");
  lua_push_str_table_entry(L, "REFERER", (char*)mg_get_header(conn, "Referer") ? (char*)mg_get_header(conn, "Referer") : (char*)"");

  const char *host = mg_get_header(conn, "Host");

  if(host) {
    lua_pushfstring(L, "%s://%s", (request_info->is_ssl) ? "https" : "http", host);
    lua_pushstring(L, "HTTP_HOST");
    lua_insert(L, -2);
    lua_settable(L, -3);
  }

  if(request_info->remote_user)  lua_push_str_table_entry(L, "REMOTE_USER", (char*)request_info->remote_user);
  if(request_info->query_string) lua_push_str_table_entry(L, "QUERY_STRING", (char*)request_info->query_string);

  for(int i=0; ((request_info->http_headers[i].name != NULL)
		&& request_info->http_headers[i].name[0] != '\0'); i++)
    lua_push_str_table_entry(L,
			     request_info->http_headers[i].name,
			     (char*)request_info->http_headers[i].value);

  client_addr.set(mg_get_client_address(conn));
  lua_push_str_table_entry(L, "REMOTE_ADDR", (char*) client_addr.print(addr_buf, sizeof(addr_buf)));

  lua_setglobal(L, (char*)"_SERVER");

#ifdef NOT_USED
  /* NOTE: ntopng cannot rely on user provided cookies, it must use session data */
  char *_cookies;

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
#endif

  /* Put the _SESSION params into the environment */
  lua_newtable(L);

  lua_push_str_table_entry(L, "session", session_buf);
  lua_push_str_table_entry(L, "user", (char*)user);
  lua_push_str_table_entry(L, "group", (char*)group);
  lua_push_bool_table_entry(L, "localuser", localuser);

  // now it's time to set the interface.
  setInterface(user, ifname, sizeof(ifname), &is_interface_allowed);

  if(!valid_csrf)
    lua_push_bool_table_entry(L, "INVALID_CSRF", true);

  lua_setglobal(L, "_SESSION"); /* Like in php */

  if(user[0] != '\0') {
    char val[MAX_USER_NETS_VAL_LEN];

    getLuaVMUservalue(L, user) = (char*)user;

    snprintf(key, sizeof(key), CONST_STR_USER_NETS, user);
    if(ntop->getRedis()->get(key, val, sizeof(val)) == -1)
      ptree.addAddresses(CONST_DEFAULT_ALL_NETS);
    else
      ptree.addAddresses(val);

    getLuaVMUservalue(L, allowedNets) = &ptree;
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "SET [p: %p][val: %s][user: %s]", &ptree, val, user);

    snprintf(key, sizeof(key), CONST_STR_USER_LANGUAGE, user);
    if((ntop->getRedis()->get(key, val, sizeof(val)) != -1)
       && (val[0] != '\0')) {
      lua_pushstring(L, val);
    } else {
      lua_pushstring(L, NTOP_DEFAULT_USER_LANG);
    }
    lua_setglobal(L, CONST_USER_LANGUAGE);
  }

  getLuaVMUservalue(L, group) = (char*)(group ? (group) : "");
  getLuaVMUservalue(L, localuser) = localuser;

  iface = ntop->getNetworkInterface(ifname); /* Can't be null */
  /* 'select' ther interface that has already been set into the _SESSION */
  getLuaVMUservalue(L,iface)  = iface;

  if(is_interface_allowed)
    getLuaVMUservalue(L, allowed_ifname) = iface->get_name();

#ifdef NTOPNG_PRO
  if(ntop->getPro()->has_valid_license())
    rc = __ntop_lua_handlefile(L, script_path, true);
  else
#endif
    rc = luaL_dofile(L, script_path);

  if(rc != 0) {
    const char *err = lua_tostring(L, -1);

    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path, err);
    return(send_error(conn, 500 /* Internal server error */,
		      "Internal server error", PAGE_ERROR, script_path, err));
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

void LuaEngine::setHost(Host* h) {
  struct ntopngLuaContext *c = getLuaVMContext(L);

  if(c) {
    c->host = h;

    if(h)
      c->iface = h->getInterface();
  }
}

/* ****************************************** */

void LuaEngine::setNetwork(NetworkStats* ns) {
  struct ntopngLuaContext *c = getLuaVMContext(L);

  if(c) {
    c->network = ns;
  }
}

/* ****************************************** */

void LuaEngine::setFlow(Flow* f) {
  struct ntopngLuaContext *c = getLuaVMContext(L);

  if(c) {
    c->flow = f;
    c->iface = f->getInterface();
  }
}

/* ****************************************** */

void LuaEngine::setThreadedActivityData(lua_State* from) {
  struct ntopngLuaContext *cur_ctx, *from_ctx;
  lua_State *cur_state = getState();

  if(from
     && (cur_ctx = getLuaVMContext(cur_state))
     && (from_ctx = getLuaVMContext(from))) {
    cur_ctx->deadline = from_ctx->deadline;
    cur_ctx->threaded_activity = from_ctx->threaded_activity;
    cur_ctx->threaded_activity_stats = from_ctx->threaded_activity_stats;
  }
}

/* ****************************************** */

void LuaEngine::setThreadedActivityData(const ThreadedActivity *ta, ThreadedActivityStats *tas, time_t deadline) {
  struct ntopngLuaContext *cur_ctx;
  lua_State *cur_state = getState();

  if((cur_ctx = getLuaVMContext(cur_state))) {
    cur_ctx->deadline = deadline;
    cur_ctx->threaded_activity = ta;
    cur_ctx->threaded_activity_stats = tas;
  }
}

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
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_network_store_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_store_triggered_alert(vm, c->network);
}

/* ****************************************** */

static int ntop_network_release_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  return ntop_release_triggered_alert(vm, c->network);
}

/* **************************************************************** */

static luaL_Reg _ntop_network_reg[] = {
/* Public User Scripts API, documented at doc/src/api/lua_c/network_checks/network.lua */
  { "getNetworkStats",          ntop_network_get_network_stats       },
/* END Public API */

  { "getCachedAlertValue",      ntop_network_get_cached_alert_value  },
  { "setCachedAlertValue",      ntop_network_set_cached_alert_value  },
  { "storeTriggeredAlert",      ntop_network_store_triggered_alert   },
  { "releaseTriggeredAlert",    ntop_network_release_triggered_alert },
  { "getAlerts",                ntop_network_get_alerts              },
  { "checkContext",             ntop_network_check_context           },
  
  { NULL,                     NULL }
};

luaL_Reg *ntop_network_reg = _ntop_network_reg;

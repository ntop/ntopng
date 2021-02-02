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

static int ntop_host_get_min_info(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    lua_newtable(vm);
    h->lua_get_min_info(vm);
    return(CONST_LUA_OK);
  } else
    return(CONST_LUA_ERROR);
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

/* ****************************************** */

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
  lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_alerts(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return ntop_get_alerts(vm, c->host);
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

static int ntop_host_get_application_bytes(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);
  u_int app_id;

  if(h && ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) == CONST_LUA_OK) {
    app_id = lua_tonumber(vm, 1);
    h->lua_get_app_bytes(vm, app_id);
  } else
    lua_pushinteger(vm, 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_category_bytes(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);
  ndpi_protocol_category_t cat_id;

  if(h && ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) == CONST_LUA_OK) {
    cat_id = (ndpi_protocol_category_t)lua_tointeger(vm, 1);
    h->lua_get_cat_bytes(vm, cat_id);
  } else
    lua_pushinteger(vm, 0);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static int ntop_host_get_bytes(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_bytes(vm);
  else
    lua_pushnumber(vm, 0);

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

static int ntop_host_get_pool_id(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_host_pool(vm);

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

static int ntop_host_get_score(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  lua_newtable(vm);

  if(h)
    h->lua_get_score(vm);

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

int ntop_host_get_dynamic_stats(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  if(!h)
    return(CONST_LUA_ERROR);

  /* The released alert will be pushed to LUA */
  h->lua_peers_stats(vm);

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

static int ntop_host_get_behaviour_info(lua_State* vm) {
  Host *h = ntop_host_get_context_host(vm);

  if(h)
    h->luaHostBehaviour(vm);
  else
    lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ****************************************** */

int ntop_store_triggered_alert(lua_State* vm, AlertableEntity *alertable, int idx) {
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

int ntop_release_triggered_alert(lua_State* vm, AlertableEntity *alertable, int idx) {
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

static int ntop_host_store_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return ntop_store_triggered_alert(vm, c->host);
}

/* ****************************************** */

static int ntop_host_release_triggered_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);

  return ntop_release_triggered_alert(vm, c->host);
}

/* **************************************************************** */

static luaL_Reg _ntop_host_reg[] = {
/* Public User Scripts API, documented at doc/src/api/lua_c/host_user_scripts/host.lua */
  { "getIp",                  ntop_host_get_ip                  },
  { "getApplicationBytes",    ntop_host_get_application_bytes   },
  { "getCategoryBytes",       ntop_host_get_category_bytes      },
  { "getBytes",               ntop_host_get_bytes               },
  { "getPackets",             ntop_host_get_packets             },
  { "getNumFlows",            ntop_host_get_num_total_flows     },
  { "getTime",                ntop_host_get_time                },
  { "getPoolId",              ntop_host_get_pool_id             },
  { "getDNSInfo",             ntop_host_get_dns_info            },
  { "getHTTPInfo",            ntop_host_get_http_info           },
  { "isLocal",                ntop_host_is_local                },
  { "getTsKey",               ntop_host_get_ts_key              },
/* END Public API */

  { "getMinInfo",             ntop_host_get_min_info            },
  { "getInfo",                ntop_host_get_basic_fields        },
  { "getFullInfo",            ntop_host_get_all_fields          },
  { "getCachedAlertValue",    ntop_host_get_cached_alert_value  },
  { "setCachedAlertValue",    ntop_host_set_cached_alert_value  },
  { "storeTriggeredAlert",    ntop_host_store_triggered_alert   },
  { "releaseTriggeredAlert",  ntop_host_release_triggered_alert },
  { "getAlerts",              ntop_host_get_alerts              },
  { "checkContext",           ntop_host_check_context           },
  { "getSynFlood",            ntop_host_get_syn_flood           },
  { "getFlowFlood",           ntop_host_get_flow_flood          },
  { "getSynScan",             ntop_host_get_syn_scan            },
  { "getScore",               ntop_host_get_score               },
  { "getBehaviourInfo",       ntop_host_get_behaviour_info      },
  { "getDynamicStats",        ntop_host_get_dynamic_stats       },
  
  { NULL,                     NULL }
};

luaL_Reg *ntop_host_reg = _ntop_host_reg;

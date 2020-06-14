/*
 *
 * (C) 2019 - ntop.org
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

AlertCheckLuaEngine::AlertCheckLuaEngine(AlertEntity alert_entity, ScriptPeriodicity script_periodicity,
					 NetworkInterface *_iface, lua_State *vm) : LuaEngine(vm) {
  const char *lua_file = NULL;
  iface = _iface;
  tps = Utils::gettickspersec();
  script_ok = false;
  reset_stats();

  p = script_periodicity;

  switch(alert_entity) {
  case alert_entity_host:
    lua_file = "host.lua";
    break;
  case alert_entity_network:
    lua_file = "network.lua";
    break;
  case alert_entity_interface:
    lua_file = "interface.lua";
    break;
  case alert_entity_flow:
    lua_file = "flow.lua";
    break;
  case alert_entity_snmp_device:
    lua_file = "snmp_device.lua";
    break;
  case alert_entity_process:
    lua_file = "system.lua";
    break;
  default:
    /* Example: lua_file = "generic.lua" to handle a generic entity */
    break;
  }

  if(lua_file) {
    snprintf(script_path, sizeof(script_path),
	     "%s/callbacks/%s/%s",
	     ntop->getPrefs()->get_scripts_dir(),
	     iface ? "interface" : "system",
	     lua_file);
    ntop->fixPath(script_path);

    if(load_script(script_path, iface) < 0)
      return;

    /* Execute the script so that the "setup" function will be exposed */
    if(lua_pcall(L, 0, 0, 0)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure[%s] [%s]", script_path, lua_tostring(L, -1));
      return;
    }

    lua_getglobal(L, "setup");         /* Called function   */
    lua_pushstring(L, Utils::periodicityToScriptName(p)); /* push 1st argument */

    if(lua_pcall(L, 1 /* 1 argument */, 0, 0)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure[%s] [%s]", script_path, lua_tostring(L, -1));
      return;
    }

    script_ok = true;
  } else {
    /* Possibly handle a generic entity */
    script_path[0] = '\0';
  }
}

/* ****************************************** */

AlertCheckLuaEngine::~AlertCheckLuaEngine() {
#if 0
  float elapsed_time = (float)total_ticks / tps;

  ntop->getTrace()->traceEvent(TRACE_WARNING, "[elapsed time: %.4f sec][num calls: %u][calls/sec: %.4f][%s][clocks/sec: %llu]", elapsed_time, num_calls, num_calls / elapsed_time, script_path, tps);
#endif

  if(script_ok) {
    lua_getglobal(L, "teardown"); /* Called function */

    if(lua_isfunction(L, -1)) {
      lua_pushstring(L, Utils::periodicityToScriptName(p)); /* push 1st argument */
      pcall(1 /* 1 argument */, 0);
    }
  }
}

/* ****************************************** */

void AlertCheckLuaEngine::reset_stats() {
  num_calls = 0;
  total_ticks = 0;
}

/* ****************************************** */

void AlertCheckLuaEngine::lua_stats(const char *key, lua_State *vm) {
  if(vm) {
    lua_newtable(vm);

    lua_newtable(vm);

    float elapsed_time = (float)total_ticks / tps;

    lua_push_uint64_table_entry(vm, "num_calls", (u_int64_t)num_calls);
    lua_push_float_table_entry(vm, "tot_duration_ms", elapsed_time * 1000);

    lua_stats_detail(vm);

    lua_pushstring(vm, "stats");
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    lua_pushstring(vm, key);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ****************************************** */

ScriptPeriodicity AlertCheckLuaEngine::getPeriodicity() const {
  return p;
}

/* ****************************************** */

const char * AlertCheckLuaEngine::getGranularity() const {
  return Utils::periodicityToScriptName(p);
}

/* ****************************************** */

bool AlertCheckLuaEngine::pcall(int num_args, int num_results) {
  ticks t_begin;

  if(!script_ok) {
    /* Remove possibly pushed values on the lua stack to avoid overflow */
    lua_settop(L, 0);
    return(false);
  }

  t_begin = Utils::getticks();
  if(lua_pcall(L, num_args, num_results, 0)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure[%s] [%s]", script_path, lua_tostring(L, -1));
    return(false);
  }

  num_calls++;
  total_ticks += Utils::getticks()  - t_begin;

  /*
    Refresh entity (if necessary): this guarantees that we do at most one
    refresh per entity, regardless of the number of triggered alerts
   */
  if(getHost())
    getHost()->refreshAlerts();
  else if(getNetwork())
    getNetwork()->refreshAlerts();
  else if(getNetworkInterface())
    getNetworkInterface()->refreshAlerts();

  return(true);
}

/* ****************************************** */

#ifdef TEST_CHECK_ENGINE

AfterShutdownAction afterShutdownAction = after_shutdown_nop;

int main() {
  const int num_runs = 1000;
  ntop = new Ntop((char*)"test");
  Prefs *prefs = new Prefs(ntop);
  ntop->registerPrefs(prefs, false);

  NetworkInterface *iface = new PcapInterface("lo");
  ntop->registerInterface(iface);

  /* Calls interface.lua for interface lo */
  AlertCheckLuaEngine *engine = new AlertCheckLuaEngine(alert_entity_interface, minute_script, iface);
  lua_State *L = engine->getState();

  /* Tip: try with a mix of lua compilation/runtime errors in interface.lua/required modules
   * to ensure that no crash occurs in any situation. */
  for(int i=0; i<num_runs; i++) {
    //printf("Run: %d/%d\n", i+1, num_runs);
    engine->reset_stats();

    lua_getglobal(L, USER_SCRIPTS_RUN_CALLBACK);
    lua_pushstring(L, engine->getGranularity());

    engine->pcall(1 /* num args */, 0);
  }

  delete engine;
  delete ntop;
}

#endif

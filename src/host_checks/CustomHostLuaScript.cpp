/*
 *
 * (C) 2013-22 - ntop.org
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
#include "host_checks_includes.h"

#define NUM_CONSECUTIVE_CHECKS_BEFORE_ALERTING 5

/* ***************************************************** */

CustomHostLuaScript::CustomHostLuaScript() : HostCheck(ntopng_edition_community, false /* All interfaces */, true /* Exclude for nEdge */, false /* NOT only for nEdge */) {
};

/* ***************************************************** */

LuaEngine* CustomHostLuaScript::initVM() {
  const char *script_path = "scripts/callbacks/checks/hosts/custom_host_lua_script.lua";
  char where[256];
  struct stat s;

  snprintf(where, sizeof(where), "%s/%s", ntop->get_install_dir(), script_path);
  
  if(stat(where, &s) != 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to find script %s", where);
    
    return(NULL);
  } else {
    LuaEngine *lua;
    
    try {
      lua = new LuaEngine(NULL);
      lua->load_script((char*)where, NULL /* NetworkInterface filled later below */);
    } catch(std::bad_alloc& ba) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[HTTP] Unable to start Lua interpreter.");
    }

    return(lua);
  }
}
/* ***************************************************** */

void CustomHostLuaScript::periodicUpdate(Host *h, HostAlert *engaged_alert) {
  LuaEngine *lua;
  
  if(!h)
    return;
  else {
    lua = h->getInterface()->getCustomHostLuaScript();

    if(lua == NULL) {
      lua = initVM();
      h->getInterface()->setCustomHostLuaScript(lua);
    }
  }
  
  if(lua != NULL) {
    if(false) {
      char buf[128];

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Running Lua script on %s", h->get_name(buf, sizeof(buf), false));
    }

#if 0
    lua->setFlow(f);
    lua->run_loaded_script(); /* Run script */
    
    if(f->isCustomFlowAlertTriggered()) {
      FlowAlertType alert_type = CustomHostLuaScriptAlert::getClassType();
      u_int8_t c_score, s_score;
      risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;

      computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

      f->triggerAlertAsync(alert_type, c_score, s_score);
    }
#endif
  }

#if 0
  HostAlert *alert = engaged_alert;

    if(!alert) { /* Alert not already triggered */
      /* Trigger the alert and add the host to the Default nProbe IPS host pool */
      alert = allocAlert(this, h, CLIENT_FULL_RISK_PERCENTAGE, h->getScore(), h->getConsecutiveHighScore());
    }

    /* Refresh the alert */
    if(alert) h->triggerAlert(alert);
#endif
}

/* ***************************************************** */

bool CustomHostLuaScript::loadConfiguration(json_object *config) {
  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  return(true);
}

/* ***************************************************** */


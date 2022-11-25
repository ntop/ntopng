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

CustomHostLuaScript::CustomHostLuaScript() : HostCheck(ntopng_edition_community, false /* All interfaces */,
						       true /* Exclude for nEdge */,
						       false /* NOT only for nEdge */) {
  disabled = false;
};

/* ***************************************************** */

LuaEngine* CustomHostLuaScript::initVM() {
  const char *script_path = "scripts/callbacks/checks/hosts/custom_host_lua_script.lua";
  char where[256];
  struct stat s;

  snprintf(where, sizeof(where), "%s/%s", ntop->get_install_dir(), script_path);
  
  if(stat(where, &s) != 0) {
    if(!disabled) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to find script %s: ignored `Host User Check Script` host check", where);
      disabled = true;
    }
    
    return(NULL);
  } else {
    LuaEngine *lua;
    
    try {
      lua = new LuaEngine(NULL);
      lua->load_script((char*)where, NULL /* NetworkInterface filled later below */);
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loaded custom user script %s", where);
    } catch(std::bad_alloc& ba) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to start Lua interpreter.");
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

    lua->setHost(h);
    lua->run_loaded_script(); /* Run script */
     
    if(h->isCustomHostAlertTriggered()) {
      HostAlert *alert = engaged_alert;
    
      if(!alert) {
	/* Alert not already triggered */
	alert = allocAlert(this, h, CLIENT_FULL_RISK_PERCENTAGE,
			   h->getCustomHostAlertScore(),
			   h->getCustomHostAlertMessage());
      }
    
      /* Refresh the alert */
      if(alert) h->triggerAlert(alert);
    }
  }
}

/* ***************************************************** */

bool CustomHostLuaScript::loadConfiguration(json_object *config) {
  HostCheck::loadConfiguration(config); /* Parse parameters in common */

  return(true);
}

/* ***************************************************** */


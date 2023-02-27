/*
 *
 * (C) 2013-23 - ntop.org
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
#include "flow_checks_includes.h"

/* ***************************************************** */

CustomFlowLuaScript::CustomFlowLuaScript() : FlowCheck(ntopng_edition_community,
						       false /* All interfaces */,
						       false /* Don't exclude for nEdge */,
						       false /* NOT only for nEdge */,
						       true  /* has_protocol_detected */,
						       true  /* has_periodic_update */,
						       true  /* has_flow_end */) {
  disabled_proto_detected = disabled_periodic_update = disabled_flow_end = false;
}

/* ***************************************************** */

LuaEngine* CustomFlowLuaScript::initVM(const char *script_path) {
  char where[256];
  struct stat s;

  snprintf(where, sizeof(where), "%s/%s", ntop->get_install_dir(), script_path);

  if(stat(where, &s) != 0) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Unable to find script %s: ignored `Flow User Check Script` flow check", where);
    return(NULL);
  } else {
    LuaEngine *lua;

    try {
      lua = new LuaEngine(NULL);
      lua->load_script((char*)where, NULL /* NetworkInterface filled later via lua->setFlow(f); */);
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loaded custom user script %s", where);
    } catch(std::bad_alloc& ba) {
      lua = NULL;
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to start Lua interpreter.");
    }

    return(lua);
  }
}
/* ***************************************************** */

CustomFlowLuaScript::~CustomFlowLuaScript() {
  for(int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
    NetworkInterface *iface;
    
    if((iface = ntop->getInterface(i)) != NULL) {
      LuaEngine* vm;

      vm = iface->getCustomFlowLuaScriptProtoDetected();

      if(vm != NULL) {
	iface->setCustomFlowLuaScriptProtoDetected(NULL /* remove VM */);
	delete vm;
      }

      /* ********************************* */
      
      vm = iface->getCustomFlowLuaScriptPeriodic();

      if(vm != NULL) {
	iface->setCustomFlowLuaScriptPeriodic(NULL /* remove VM */);
	delete vm;
      }

      /* ********************************* */
      
      vm = iface->getCustomFlowLuaScriptEnd();

      if(vm != NULL) {
	iface->setCustomFlowLuaScriptEnd(NULL /* remove VM */);
	delete vm;
      }
    }
  }
}

/* ***************************************************** */

void CustomFlowLuaScript::protocolDetected(Flow *f) {
  if((f == NULL) || disabled_proto_detected)
    return;
  else {
    LuaEngine *lua = f->getInterface()->getCustomFlowLuaScriptProtoDetected();
    
    if(lua == NULL) {
      lua = initVM(CUSTOM_FLOW_NDPI_SCRIPT);

      if(lua == NULL)
	disabled_proto_detected = true;
      else
	f->getInterface()->setCustomFlowLuaScriptProtoDetected(lua);
    }

    if(lua != NULL)
      checkFlow(f, lua);
  }
}

/* ***************************************************** */

void CustomFlowLuaScript::periodicUpdate(Flow *f) {
  if((f == NULL) || disabled_periodic_update)
    return;
  else {
    LuaEngine *lua = f->getInterface()->getCustomFlowLuaScriptPeriodic();

    if(lua == NULL) {
      lua = initVM(CUSTOM_FLOW_PERIODIC_SCRIPT);

      if(lua == NULL)
	disabled_periodic_update = true;
      else
	f->getInterface()->setCustomFlowLuaScriptPeriodic(lua);
    }

    if(lua != NULL)
      checkFlow(f, lua);
  }
}

/* ***************************************************** */

void CustomFlowLuaScript::flowEnd(Flow *f) {
  if((f == NULL) || disabled_flow_end)
    return;
  else {
    LuaEngine *lua = f->getInterface()->getCustomFlowLuaScriptEnd();
      
    if(lua == NULL) {
      lua = initVM(CUSTOM_FLOW_END_SCRIPT);

      if(lua == NULL)
	disabled_flow_end = true;
      else
	f->getInterface()->setCustomFlowLuaScriptEnd(lua);
    }

    if(lua != NULL)
      checkFlow(f, lua);
  }
}

/* ***************************************************** */

void CustomFlowLuaScript::checkFlow(Flow *f, LuaEngine *lua) {
  if(false) {
    char buf[128];
    
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Running Lua script on %s", f->print(buf, sizeof(buf)));
  }
  
  lua->setFlow(f);
  lua->run_loaded_script(); /* Run script */
  
  if(f->isCustomFlowAlertTriggered()) {
    FlowAlertType alert_type = CustomFlowLuaScriptAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;
    
    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);
    
    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *CustomFlowLuaScript::buildAlert(Flow *f) {
  CustomFlowLuaScriptAlert *alert = new (std::nothrow) CustomFlowLuaScriptAlert(this, f);

  if(alert) {
    alert->setAlertMessage(f->getCustomFlowAlertMessage());
    alert->setAlertScore(f->getCustomFlowAlertScore());
  }
  
  return alert;
}

/* ***************************************************** */

/* Sample configuration:
  "script_conf": {
    "severity": {
      "syslog_severity": 3,
      "severity_id": 5,
      "i18n_title": "alerts_dashboard.error",
      "emoji": "❗",
      "icon": "fas fa-exclamation-triangle text-danger",
      "label": "badge-danger"
    }
  }
*/

bool CustomFlowLuaScript::loadConfiguration(json_object *config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */

  /* Parse additional parameters */

  return(true);
}

/* ***************************************************** */

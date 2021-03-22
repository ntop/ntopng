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

/* **************************************************** */

FlowCallback::FlowCallback(NtopngEdition _edition,
			   bool _packet_interface_only, bool _nedge_exclude, bool _nedge_only,
			   bool _has_protocol_detected, bool _has_periodic_update, bool _has_flow_end) {
  packet_interface_only = nedge_exclude = nedge_only = has_protocol_detected = has_periodic_update = has_flow_end = 0;

  if(_packet_interface_only)  packet_interface_only = 1;
  if(_nedge_exclude)          nedge_exclude = 1;
  if(_nedge_only)             nedge_only = 1;
  if(_has_protocol_detected)  has_protocol_detected = 1;
  if(_has_periodic_update)    has_periodic_update = 1;
  if(_has_flow_end)           has_flow_end = 1;

  plugin_edition = _edition;
  enabled = 0, severity_id = alert_level_warning;
};

/* **************************************************** */

FlowCallback::~FlowCallback() {
};

/* **************************************************** */

bool FlowCallback::isCallbackCompatibleWithInterface(NetworkInterface *iface) {
  /* Check first if the license allows plugin to be enabled */
  switch(plugin_edition) {
  case ntopng_edition_community:
    /* Ok */
    break;
     
  case ntopng_edition_pro:
    if(!ntop->getPrefs()->is_pro_edition() /* includes Pro, Enterprise M/L */)
      return(false);
    break;
     
  case ntopng_edition_enterprise_m:
    if(!ntop->getPrefs()->is_enterprise_m_edition() /* includes Enterprise M/L */)
      return(false);
    break;
     
  case ntopng_edition_enterprise_l:
    if(!ntop->getPrefs()->is_enterprise_l_edition() /* includes L */)
      return(false);
    break;     
  }
  
  if(packet_interface_only && (!iface->isPacketInterface())) return(false);
  if(nedge_only && (!ntop->getPrefs()->is_nedge_edition()))  return(false);
  if(nedge_exclude && ntop->getPrefs()->is_nedge_edition())  return(false);

  return(true);
}

/* **************************************************** */

void FlowCallback::addCallback(std::list<FlowCallback*> *l, NetworkInterface *iface, FlowCallbacks callback) {
  if(!isCallbackCompatibleWithInterface(iface)) return;

  switch(callback) {
  case flow_callback_protocol_detected:
    if(has_protocol_detected) l->push_back(this);
    break;
    
  case flow_callback_periodic_update:
    if(has_periodic_update) l->push_back(this);
    break;
    
  case flow_callback_flow_end:
    if(has_flow_end) l->push_back(this);
    break;

  case flow_callback_flow_none:
    if(!(has_protocol_detected || has_periodic_update || has_flow_end))
      l->push_back(this);
    break;
  }
}

/* **************************************************** */

bool FlowCallback::loadConfiguration(json_object *config) {
  json_object *json_severity, *json_severity_id;
  bool rc = true;
  
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() %s", __FUNCTION__, json_object_to_json_string(config));

  /*
    Example of simple configuration without parameters:

    {
      "severity": {
        "i18n_title": "alerts_dashboard.error",
        "icon": "fas fa-exclamation-triangle text-danger",
        "label": "badge-danger",
        "syslog_severity": 3,
        "severity_id": 5
      }
    }
   */

  severity_id = alert_level_warning; /* Default */
  
  /* Read and parse the default severity */
  if(json_object_object_get_ex(config, "severity", &json_severity)
     && json_object_object_get_ex(json_severity, "severity_id", &json_severity_id)) {
    if((severity_id = (AlertLevel)json_object_get_int(json_severity_id)) >= ALERT_LEVEL_MAX_LEVEL)
      severity_id = alert_level_emergency;
  }
  
  return(rc);
}

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

FlowCheck::FlowCheck(NtopngEdition _edition,
			   bool _packet_interface_only, bool _nedge_exclude, bool _nedge_only,
			   bool _has_protocol_detected, bool _has_periodic_update, bool _has_flow_end) {
  packet_interface_only = nedge_exclude = nedge_only = has_protocol_detected = has_periodic_update = has_flow_end = 0;

  if(_packet_interface_only)  packet_interface_only = 1;
  if(_nedge_exclude)          nedge_exclude = 1;
  if(_nedge_only)             nedge_only = 1;
  if(_has_protocol_detected)  has_protocol_detected = 1;
  if(_has_periodic_update)    has_periodic_update = 1;
  if(_has_flow_end)           has_flow_end = 1;

  check_edition = _edition;
  enabled = 0;
};

/* **************************************************** */

FlowCheck::~FlowCheck() {
};

/* **************************************************** */

bool FlowCheck::isCheckCompatibleWithEdition() const {
  /* Check first if the license allows plugin to be enabled */
  switch(check_edition) {
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

  return(true);
}

/* **************************************************** */

bool FlowCheck::isCheckCompatibleWithInterface(NetworkInterface *iface) {
  /* Version check, done at runtime as versions can change */
  if(!isCheckCompatibleWithEdition())                     return(false);  

  if(packet_interface_only && (!iface->isPacketInterface())) return(false);
  if(nedge_only && (!ntop->getPrefs()->is_nedge_edition()))  return(false);
  if(nedge_exclude && ntop->getPrefs()->is_nedge_edition())  return(false);

  return(true);
}

/* **************************************************** */

void FlowCheck::addCheck(std::list<FlowCheck*> *l, NetworkInterface *iface, FlowChecks check) {
  if(!isCheckCompatibleWithInterface(iface)) return;

  switch(check) {
  case flow_check_protocol_detected:
    if(has_protocol_detected) l->push_back(this);
    break;
    
  case flow_check_periodic_update:
    if(has_periodic_update) l->push_back(this);
    break;
    
  case flow_check_flow_end:
    if(has_flow_end) l->push_back(this);
    break;

  case flow_check_flow_none:
    if(!(has_protocol_detected || has_periodic_update || has_flow_end))
      l->push_back(this);
    break;
  }
}

/* **************************************************** */

bool FlowCheck::loadConfiguration(json_object *config) {
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
  
  return(rc);
}

/* **************************************************** */

void FlowCheck::computeCliSrvScore(FlowAlertType alert_type, risk_percentage cli_pctg, u_int8_t *cli_score, u_int8_t *srv_score) {
  u_int8_t score = ntop->getFlowAlertScore(alert_type.id);
  *cli_score = (score * cli_pctg) / 100;
  *srv_score = score - (*cli_score);
}

/* **************************************************** */


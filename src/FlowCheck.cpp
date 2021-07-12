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
		     bool _has_protocol_detected, bool _has_periodic_update, bool _has_flow_end)
  : Check(_edition, _packet_interface_only, _nedge_exclude, _nedge_only) {
  has_protocol_detected  = _has_protocol_detected;
  has_periodic_update    = _has_periodic_update;
  has_flow_end           = _has_flow_end;
};

/* **************************************************** */

FlowCheck::~FlowCheck() {
};

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


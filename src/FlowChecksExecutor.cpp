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

FlowChecksExecutor::FlowChecksExecutor(FlowChecksLoader *fcl, NetworkInterface *_iface) {
  iface = _iface;
  loadFlowChecks(fcl);
};

/* **************************************************** */

FlowChecksExecutor::~FlowChecksExecutor() {
  if(protocol_detected) delete protocol_detected;
  if(periodic_update)   delete periodic_update;
  if(flow_end)          delete flow_end;
};

/* **************************************************** */

void FlowChecksExecutor::loadFlowChecks(FlowChecksLoader *fcl) {
  protocol_detected = fcl->getProtocolDetectedChecks(iface);
  periodic_update   = fcl->getPeriodicUpdateChecks(iface);
  flow_end          = fcl->getFlowEndChecks(iface);
}

/* **************************************************** */

FlowAlert *FlowChecksExecutor::execChecks(Flow *f, FlowChecks c) {
  FlowAlertType predominant_alert = f->getPredominantAlert();
  FlowCheck *predominant_check = NULL;
  std::list<FlowCheck*> *checks = NULL;
  FlowAlert *alert;

  switch (c) {
    case flow_check_protocol_detected:
      checks = protocol_detected;
      break;
    case flow_check_periodic_update:
      checks = periodic_update;
      break;
    case flow_check_flow_end:
      checks = flow_end;
      break;
    default:
      return NULL;
  }

  for(list<FlowCheck*>::iterator it = checks->begin(); it != checks->end(); ++it) {
    switch (c) {
      case flow_check_protocol_detected:
        (*it)->protocolDetected(f);
        break;
      case flow_check_periodic_update:
        (*it)->periodicUpdate(f);
        break;
      case flow_check_flow_end:
        (*it)->flowEnd(f);
        break;
      default:
	break;
    }
    
    /* Check if the check triggered a predominant alert */
    if (f->getPredominantAlert().id != predominant_alert.id) {
      predominant_alert = f->getPredominantAlert();
      predominant_check = (*it);
    }
  }

  /* Do NOT allocate any alert, there is nothing left to do as flow alerts don't have to be emitted */
  if(ntop->getPrefs()->dontEmitFlowAlerts()) return(NULL);

  /* Allocate the alert */
  alert = predominant_check ? predominant_check->buildAlert(f) : NULL;

  return alert;
}

/* **************************************************** */

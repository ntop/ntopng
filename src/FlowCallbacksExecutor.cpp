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

FlowCallbacksExecutor::FlowCallbacksExecutor(FlowCallbacksLoader *fcl, NetworkInterface *_iface) {
  iface = _iface;
  loadFlowCallbacks(fcl);
};

/* **************************************************** */

FlowCallbacksExecutor::~FlowCallbacksExecutor() {
  if(protocol_detected) delete protocol_detected;
  if(periodic_update)   delete periodic_update;
  if(flow_end)          delete flow_end;
  if(flow_none)         delete flow_none;
};

/* **************************************************** */

void FlowCallbacksExecutor::loadFlowCallbacks(FlowCallbacksLoader *fcl) {
  protocol_detected = fcl->getProtocolDetectedCallbacks(iface);
  periodic_update   = fcl->getPeriodicUpdateCallbacks(iface);
  flow_end          = fcl->getFlowEndCallbacks(iface);
  flow_none         = fcl->getNoneFlowCallbacks(iface);
}

/* **************************************************** */

FlowAlert *FlowCallbacksExecutor::execCallbacks(Flow *f, FlowCallbacks c) {
  FlowAlertType predominant_alert = f->getPredominantAlert();
  FlowCallback *predominant_callback = NULL;
  std::list<FlowCallback*> *callbacks = NULL;

  switch (c) {
    case flow_callback_protocol_detected:
      callbacks = protocol_detected;
      break;
    case flow_callback_periodic_update:
      callbacks = periodic_update;
      break;
    case flow_callback_flow_end:
      callbacks = flow_end;
      break;
    default:
      return NULL;
  }

  for(list<FlowCallback*>::iterator it = callbacks->begin(); it != callbacks->end(); ++it) {

    switch (c) {
      case flow_callback_protocol_detected:
        (*it)->protocolDetected(f);
        break;
      case flow_callback_periodic_update:
        (*it)->periodicUpdate(f);
        break;
      case flow_callback_flow_end:
        (*it)->flowEnd(f);
        break;
      default:
	break;
    }

    /* Check if the callback triggered a predominant alert */
    if (f->getPredominantAlert().id != predominant_alert.id) {
      predominant_alert = f->getPredominantAlert();
      predominant_callback = (*it);
    }
  }

  return predominant_callback ? predominant_callback->buildAlert(f) : NULL;
}

/* **************************************************** */

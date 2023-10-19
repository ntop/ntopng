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

/* **************************************************** */

FlowChecksExecutor::FlowChecksExecutor(FlowChecksLoader *fcl,
                                       NetworkInterface *_iface) {
  iface = _iface;
  loadFlowChecks(fcl);
};

/* **************************************************** */

FlowChecksExecutor::~FlowChecksExecutor() {
  if (protocol_detected) delete protocol_detected;
  if (periodic_update) delete periodic_update;
  if (flow_end) delete flow_end;
  if (flow_begin) delete flow_begin;
};

/* **************************************************** */

void FlowChecksExecutor::loadFlowChecks(FlowChecksLoader *fcl) {
  protocol_detected = fcl->getProtocolDetectedChecks(iface);
  periodic_update = fcl->getPeriodicUpdateChecks(iface);
  flow_end = fcl->getFlowEndChecks(iface);
  flow_begin = fcl->getFlowBeginChecks(iface);
}

/* **************************************************** */

FlowAlert *FlowChecksExecutor::execChecks(Flow *f, FlowChecks c) {
  FlowAlertType predominant_alert = f->getPredominantAlert();
  FlowCheck *predominant_check = NULL;
  std::list<FlowCheck *> *checks = NULL;
  FlowAlert *alert = NULL;
#ifdef CHECKS_PROFILING
  u_int64_t t1, t2;
#endif

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
    case flow_check_flow_begin:
      checks = flow_begin;
      break;
    default:
      return NULL;
  }

  for (list<FlowCheck *>::iterator it = checks->begin(); it != checks->end();
       ++it) {
    FlowCheck *fc = (*it);

#ifdef CHECKS_PROFILING
    t1 = Utils::getTimeNsec();
#endif

    // ntop->getTrace()->traceEvent(TRACE_ERROR, "->> %s",
    // fc->getName().c_str());

    switch (c) {
      case flow_check_protocol_detected:
        fc->protocolDetected(f);
        break;
      case flow_check_periodic_update:
        fc->periodicUpdate(f);
        break;
      case flow_check_flow_end:
        fc->flowEnd(f);
        break;
      case flow_check_flow_begin:
        fc->flowBegin(f);
        break;
      default:
        break;
    }

#ifdef CHECKS_PROFILING
    t2 = Utils::getTimeNsec();

    fc->incStats(t2 - t1);
#endif

    /* Check if the check triggered a predominant alert */
    if (f->getPredominantAlert().id != predominant_alert.id) {
      predominant_alert = f->getPredominantAlert();
      predominant_check = fc;
    }
  }

  /* Do NOT allocate any alert, there is nothing left to do as flow alerts don't
   * have to be emitted */
  if (ntop->getPrefs()->dontEmitFlowAlerts()) return (NULL);

  if (predominant_check) {
    /* Allocate the alert */
    alert = predominant_check->buildAlert(f);

    f->setPredominantAlertInfo(alert);
  }

  return alert;
}

/* **************************************************** */

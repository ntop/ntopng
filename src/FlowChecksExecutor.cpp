/*
 *
 * (C) 2013-24 - ntop.org
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
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  iface = _iface;
  loadFlowChecks(fcl);
};

/* **************************************************** */

FlowChecksExecutor::~FlowChecksExecutor() {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
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
  bool new_predominant_alert = false;
  std::list<FlowCheck *> *checks = NULL;
  FlowAlert *alert = NULL;
#ifdef CHECKS_PROFILING
  u_int64_t t1, t2;
#endif

  switch (c) {
    case flow_check_flow_begin:
      checks = flow_begin;
      break;
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

  for (list<FlowCheck *>::iterator it = checks->begin(); it != checks->end();
       ++it) {
    FlowCheck *fc = (*it);

#ifdef CHECKS_PROFILING
    t1 = Utils::getTimeNsec();
#endif

    // ntop->getTrace()->traceEvent(TRACE_ERROR, "->> %s",
    // fc->getName().c_str());

    switch (c) {
      case flow_check_flow_begin:
        fc->flowBegin(f);
        break;
      case flow_check_protocol_detected:
        fc->protocolDetected(f);
        break;
      case flow_check_periodic_update:
        fc->periodicUpdate(f);
        break;
      case flow_check_flow_end:
        fc->flowEnd(f);
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
      new_predominant_alert = true;
      predominant_alert = f->getPredominantAlert();
      predominant_check = fc;
    }
  }

  /* Do NOT allocate any alert, there is nothing left to do as flow alerts don't
   * have to be emitted */
  if (ntop->getPrefs()->dontEmitFlowAlerts())
    return (NULL);

  if(new_predominant_alert) {
    Host *cli_u = f->getViewSharedClient(), *srv_u = f->getViewSharedServer();
#ifdef DEBUG
    char buf[64];
#endif

#ifdef DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s/%u][%s] ->> %p/%p [%s]",
				 predominant_check->getName().c_str(), c,
				 f->getInterface()->get_name(),
				 cli_u, srv_u, f->print(buf, sizeof(buf)));
#endif

    if(cli_u && srv_u) {
      if(cli_u->isFlowAlertDisabled(predominant_alert)
	 || srv_u->isFlowAlertDisabled(predominant_alert)) {
#ifdef DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Skipping alert");
#endif

	return(NULL);
      }
    } else {
      /* This flow has not yet been walked by ViewInterface::viewed_flows_walker() */
      const IpAddress *cli_ip = f->get_cli_ip_addr(), *srv_ip = f->get_srv_ip_addr();
      Host *cli_host, *srv_host;
      Mac *srcMac = NULL, *dstMac = NULL;
      ViewInterface *viewedBy = f->getInterface()->viewedBy();

#ifdef DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Searching hosts %p", viewedBy);
#endif

      if(viewedBy) {
	viewedBy->findFlowHosts(f->getInterfaceIndex(),
				f->get_vlan_id(), f->get_observation_point_id(),
				f->getPrivateFlowId(), srcMac,
				(IpAddress *)cli_ip, &cli_host, dstMac,
				(IpAddress *)srv_ip, &srv_host);

	if(cli_host && srv_host) {
#ifdef DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Hosts found");
#endif

	  if(cli_host->isFlowAlertDisabled(predominant_alert)
	     || srv_host->isFlowAlertDisabled(predominant_alert)) {
#ifdef DEBUG
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Skipping alert");
#endif
	    return(NULL);
	  }
	} else {
#ifdef DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Hosts NOT found");
#endif
	}
      }
    }
  }

  if (new_predominant_alert) {
    /* Allocate the alert */
    alert = predominant_check->buildAlert(f);

    f->setPredominantAlertInfo(alert);
  }

  return alert;
}

/* **************************************************** */

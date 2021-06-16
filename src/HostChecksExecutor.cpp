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

HostChecksExecutor::HostChecksExecutor(HostChecksLoader *fcl, NetworkInterface *_iface) {
  iface = _iface;
  memset(host_cb_arr, 0, sizeof(host_cb_arr));
  loadHostChecks(fcl);
};

/* **************************************************** */

HostChecksExecutor::~HostChecksExecutor() {
  if(periodic_host_cb) delete periodic_host_cb;
};

/* **************************************************** */
  
void HostChecksExecutor::loadHostChecks(HostChecksLoader *fcl) {

  /* Load list of 'periodicUpdate' checks */
  periodic_host_cb = fcl->getChecks(iface);

  /* Initialize checks array for quick lookup */
  for(std::list<HostCheck*>::iterator it = periodic_host_cb->begin(); it != periodic_host_cb->end(); ++it) {
    HostCheck *cb = (*it);
    host_cb_arr[cb->getID()] = cb;
  }
}

/* **************************************************** */

void HostChecksExecutor::releaseAllDisabledAlerts(Host *h) {
  for (u_int i = 0; i < NUM_DEFINED_HOST_CHECKS; i++) {
    HostCheckID t = (HostCheckID) i;
    HostCheck *cb = getCheck(t);

    if (!cb) { /* check disabled, check engaged alerts with auto release */
      HostAlert *alert = h->getCheckEngagedAlert(t);
      if (alert && alert->hasAutoRelease())
        h->releaseAlert(alert);
    }
  }
}

/* **************************************************** */

void HostChecksExecutor::execChecks(Host *h) {
  bool run_min_cbs, run_5min_cbs; /* Checks to be executed during this run */
  time_t now = time(NULL);

  /* Release (auto-release) alerts for disabled checks */
  releaseAllDisabledAlerts(h);

  run_min_cbs = h->isTimeToRunMinChecks(now),
    run_5min_cbs = h->isTimeToRun5MinChecks(now);

  /* Exec all enabled checks */
  for(std::list<HostCheck*>::iterator it = periodic_host_cb->begin(); it != periodic_host_cb->end(); ++it) {
    HostCheck *cb = (*it);
    HostCheckID ct = cb->getID();

    /* Check if it's time to run the check on this host */
    if ((run_min_cbs && cb->isMinCheck())
	|| (run_5min_cbs && cb->is5MinCheck())) {
      HostAlert *alert;

      /* Initializing (auto-release) alert to expiring, to check if
       * it needs to be released when not engaged again */
      alert = h->getCheckEngagedAlert(ct);

      if(alert && alert->hasAutoRelease())
        alert->setExpiring();

      /* Call Handler */
      cb->periodicUpdate(h, alert);

      /* Check if alert is expired and should be released
       * NOTE: call getCheckEngagedAlert again in case the
       * alert ahs been explicitly released by the check.
       */
      alert = h->getCheckEngagedAlert(ct);
      if(alert /* There's an engaged alert */
	 && (/* Alert has not been `refreshed` inside the check */
	     alert->isExpired()
	     /* Alert has been disabled while it was engaged and a trigger didn't refresh it */
	     || h->isHostAlertDisabled(alert->getAlertType())))
	h->releaseAlert(alert);
    }
  }

  /* Update last call time */
  if(run_min_cbs)  h->setMinLastCallTime(now);
  if(run_5min_cbs) h->set5MinLastCallTime(now);
}

/* **************************************************** */


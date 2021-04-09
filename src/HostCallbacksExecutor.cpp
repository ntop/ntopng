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

HostCallbacksExecutor::HostCallbacksExecutor(HostCallbacksLoader *fcl, NetworkInterface *_iface) {
  iface = _iface;
  memset(host_cb_arr, 0, sizeof(host_cb_arr));
  loadHostCallbacks(fcl);
};

/* **************************************************** */

HostCallbacksExecutor::~HostCallbacksExecutor() {
  if(periodic_host_cb) delete periodic_host_cb;
};

/* **************************************************** */
  
void HostCallbacksExecutor::loadHostCallbacks(HostCallbacksLoader *fcl) {

  /* Load list of 'periodicUpdate' callbacks */
  periodic_host_cb = fcl->getCallbacks(iface);

  /* Initialize callbacks array for quick lookup */
  for(std::list<HostCallback*>::iterator it = periodic_host_cb->begin(); it != periodic_host_cb->end(); ++it) {
    HostCallback *cb = (*it);
    host_cb_arr[cb->getID()] = cb;
  }
}

/* **************************************************** */

void HostCallbacksExecutor::releaseAllDisabledAlerts(Host *h) {
  for (u_int i = 0; i < NUM_DEFINED_HOST_CALLBACKS; i++) {
    HostCallbackID t = (HostCallbackID) i;
    HostCallback *cb = getCallback(t);

    if (!cb) { /* callback disabled, check engaged alerts with auto release */
      HostAlert *alert = h->getCallbackEngagedAlert(t);
      if (alert && alert->hasAutoRelease())
        h->releaseAlert(alert);
    }
  }
}

/* **************************************************** */

void HostCallbacksExecutor::execCallbacks(Host *h) {
  bool run_min_cbs, run_5min_cbs; /* Callbacks to be executed during this run */
  time_t now = time(NULL);

  /* Release (auto-release) alerts for disabled callbacks */
  releaseAllDisabledAlerts(h);

  run_min_cbs = h->isTimeToRunMinCallbacks(now),
    run_5min_cbs = h->isTimeToRun5MinCallbacks(now);

  /* Exec all enabled callbacks */
  for(std::list<HostCallback*>::iterator it = periodic_host_cb->begin(); it != periodic_host_cb->end(); ++it) {
    HostCallback *cb = (*it);
    HostCallbackID ct = cb->getID();

    /* Check if it's time to run the callback on this host */
    if ((run_min_cbs && cb->isMinCallback())
	|| (run_5min_cbs && cb->is5MinCallback())) {
      HostAlert *alert;

      /* Initializing (auto-release) alert to expiring, to check if
       * it needs to be released when not engaged again */
      alert = h->getCallbackEngagedAlert(ct);
      if (alert && alert->hasAutoRelease())
        alert->setExpiring();

      /* Call Handler */
      cb->periodicUpdate(h, alert);

      /* Check if alert is expired and should be released
       * Note: call getCallbackEngagedAlert again in case the
       * alert ahs been explicitly released by the callback. */
      alert = h->getCallbackEngagedAlert(ct);
      if (alert && alert->isExpired())
        h->releaseAlert(alert);
    }
  }

  /* Update last call time */
  if(run_min_cbs)  h->setMinLastCallTime(now);
  if(run_5min_cbs) h->set5MinLastCallTime(now);
}

/* **************************************************** */


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

#ifndef _HOST_CALLBACKS_EXECUTOR_H_
#define _HOST_CALLBACKS_EXECUTOR_H_

#include "ntop_includes.h"

class Host;

class HostCallbacksExecutor { /* One instance per ntopng Interface */
 private:
  NetworkInterface *iface;
  std::list<HostCallback*> *periodic_host_cb;
  HostCallback *host_cb_arr[NUM_DEFINED_HOST_CALLBACKS];

  void loadHostCallbacksAlerts(std::list<HostCallback*> *cb_list);
  void loadHostCallbacks(HostCallbacksLoader *fcl);

  void releaseAllDisabledAlerts(Host *h);

 public:
  HostCallbacksExecutor(HostCallbacksLoader *fcl, NetworkInterface *_iface);
  virtual ~HostCallbacksExecutor();

  HostCallback *getCallback(HostCallbackID t) { return host_cb_arr[t]; }
  void execCallbacks(Host *h);
};

#endif /* _HOST_CALLBACKS_EXECUTOR_H_ */

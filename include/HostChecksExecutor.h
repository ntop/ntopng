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

#ifndef _HOST_CHECKS_EXECUTOR_H_
#define _HOST_CHECKS_EXECUTOR_H_

#include "ntop_includes.h"

class Host;

class HostChecksExecutor { /* One instance per ntopng Interface */
 private:
  NetworkInterface *iface;
  std::list<HostCheck*> *periodic_host_cb;
  HostCheck *host_cb_arr[NUM_DEFINED_HOST_CHECKS];

  void loadHostChecksAlerts(std::list<HostCheck*> *cb_list);
  void loadHostChecks(HostChecksLoader *fcl);

  void releaseAllDisabledAlerts(Host *h);

 public:
  HostChecksExecutor(HostChecksLoader *fcl, NetworkInterface *_iface);
  virtual ~HostChecksExecutor();

  HostCheck *getCheck(HostCheckID t) { return host_cb_arr[t]; }
  void execChecks(Host *h);
};

#endif /* _HOST_CHECKS_EXECUTOR_H_ */

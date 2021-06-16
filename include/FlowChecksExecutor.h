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

#ifndef _FLOW_CHECKS_EXECUTOR_H_
#define _FLOW_CHECKS_EXECUTOR_H_

#include "ntop_includes.h"

class Flow;

class FlowChecksExecutor { /* One instance per ntopng Interface */
 private:
  NetworkInterface *iface;
  std::list<FlowCheck*> *protocol_detected, *periodic_update, *flow_end;

  void loadFlowChecksAlerts(std::list<FlowCheck*> *cb_list);
  void loadFlowChecks(FlowChecksLoader *fcl);

 public:
  FlowChecksExecutor(FlowChecksLoader *fcl, NetworkInterface *_iface);
  virtual ~FlowChecksExecutor();

  FlowAlert *execChecks(Flow *f, FlowChecks c);
};

#endif /* _FLOW_CHECKS_EXECUTOR_H_ */

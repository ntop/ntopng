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

#ifndef _FLOW_CHECK_H_
#define _FLOW_CHECK_H_

#include "ntop_includes.h"

class FlowCheck : public Check {
 private:
  bool has_protocol_detected, has_periodic_update, has_flow_end;

 public:
  FlowCheck(NtopngEdition _edition, bool _packet_interface_only, bool _nedge_exclude, bool _nedge_only,
	       bool _has_protocok_detected, bool _has_periodic_update, bool _has_flow_end);
  virtual ~FlowCheck();
  
  /* Check hooks */
  virtual void protocolDetected(Flow *f) {};
  virtual void periodicUpdate(Flow *f)   {};
  virtual void flowEnd(Flow *f)          {};

  /* Used to build an alert when triggerAlertAsync is used */
  virtual FlowAlert *buildAlert(Flow *f) { return NULL; };

  void addCheck(std::list<FlowCheck*> *l, NetworkInterface *iface, FlowChecks check);
  virtual bool loadConfiguration(json_object *config);
  
  virtual std::string getName()        const = 0;

  static void computeCliSrvScore(FlowAlertType alert_type, risk_percentage cli_pctg, u_int8_t *cli_score, u_int8_t *srv_score);
};

#endif /* _FLOW_CHECK_H_ */

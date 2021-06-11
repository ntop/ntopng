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

#ifndef _FLOW_ALERTS_LOADER_H_
#define _FLOW_ALERTS_LOADER_H_

#include "ntop_includes.h"

class FlowAlertsLoader { /* A single instance inside Ntop */
 private:
  /* For each alert, keep the corresponding total score. */
  u_int8_t alert_to_score[MAX_DEFINED_FLOW_ALERT_TYPE];
  void registerAlert(FlowAlertType alert_type, u_int8_t alert_score);

 public:
  FlowAlertsLoader();
  virtual ~FlowAlertsLoader();

  u_int8_t getAlertScore(FlowAlertTypeEnum alert_id) const;
  void printRegisteredAlerts() const;
};

#endif /* _FLOW_ALERTS_LOADER_H_ */

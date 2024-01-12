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

#ifndef _RARE_DESTINATION_FLOW_ALERT_H_
#define _RARE_DESTINATION_FLOW_ALERT_H_

#include "ntop_includes.h"

class RareDestinationAlert : public FlowAlert {
 private:
  ndpi_serializer *getAlertJSON(ndpi_serializer *serializer);

 public:
  static FlowAlertType getClassType() {
    return {flow_alert_rare_destination, alert_category_network};
  }
  static u_int8_t getDefaultScore() { return SCORE_LEVEL_NOTICE; };

  RareDestinationAlert(FlowCheck *c, Flow *f) : FlowAlert(c, f){};
  ~RareDestinationAlert(){};

  FlowAlertType getAlertType() const { return getClassType(); }
};

#endif /* _RARE_DESTINATION_FLOW_ALERT_H_ */

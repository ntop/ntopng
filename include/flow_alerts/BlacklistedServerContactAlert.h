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

#ifndef _BLACKLIST_SERVER_CONTACT_ALERT_H_
#define _BLACKLIST_SERVER_CONTACT_ALERT_H_

#include "ntop_includes.h"

class BlacklistedServerContactAlert : public FlowAlert {
 private:
  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  static FlowAlertType getClassType() {
    return {flow_alert_blacklisted_server_contact, alert_category_security};
  }
  static u_int8_t getDefaultScore() { return SCORE_LEVEL_CRITICAL; };

  BlacklistedServerContactAlert(FlowCheck* c, Flow* f) : FlowAlert(c, f) {};
  ~BlacklistedServerContactAlert(){};

  bool autoAck() const { return false; };

  FlowAlertType getAlertType() const { return getClassType(); }
};

#endif /* _BLACKLIST_SERVER_CONTACT_ALERT_H_ */

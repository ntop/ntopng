/*
 *
 * (C) 2015-21 - ntop.org
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

#ifndef _CONTROL_GROUPS_H_
#define _CONTROL_GROUPS_H_

#include "ntop_includes.h"

class ControlGroups {
 private:
  time_t init_tstamp; /* Timestamp, set when the class instance is created */
  AddressTree *member_groups; /* A ptree holding, for each member, a Bitmap of control group ids */
  std::map<u_int, Bitmap> disabled_flow_alert; /* group_id is the key, Bitmap is the class holding disabled flow alerts */

  /* Load a group member (identififed as in IPv4/v6 CIDR) */
  void loadGroupMember(u_int group_id, const char * const member);
  /* Load a disabled flow alert for a group */
  void loadGroupDisabledFlowAlert(u_int group_id, FlowAlertTypeEnum disabled_flow_alert_type);

  void loadConfiguration(); /* Read the configuration from Redis and initialize internal data structures */

 public:
  ControlGroups();
  virtual ~ControlGroups();

  bool checkChange(time_t *last_change) const;
  Bitmap getDisabledFlowAlertsBitmap(Host *host) const;
};

#endif /* _CONTROL_GROUPS_H_ */

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

#ifndef _ALERT_EXCLUSIONS_H_
#define _ALERT_EXCLUSIONS_H_

#include "ntop_includes.h"

class AlertExclusions {
 private:
  time_t init_tstamp; /* Timestamp, set when the class instance is created */
  Bitmap default_host_filter; /* Allow all */
  AddressTree *host_filters; /* A ptree holding, for each host, a Bitmap with disabled flow alerts */

  /* Add a disabled flow alert for a host */
  bool addHostDisabledFlowAlert(const char * const host, FlowAlertTypeEnum disabled_flow_alert_type);

  void loadConfiguration(); /* Read the configuration from Redis and initialize internal data structures */

 public:
  AlertExclusions();
  virtual ~AlertExclusions();

  /* Check whether the filters have changed since last_change, setting last_change to the latest change time */
  bool checkChange(time_t *last_change) const;
  void setDisabledFlowAlertsBitmap(IpAddress *addr, Bitmap *bitmap) const;
};

#endif /* _ALERT_EXCLUSIONS_H_ */

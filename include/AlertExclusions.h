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

typedef struct {
  Bitmap16 *host_alert_filter;
  Bitmap128 *flow_alert_filter;
} alert_exclusion_host_tree_data;

class AlertExclusions {
 private:
  time_t init_tstamp; /* Timestamp, set when the class instance is created */
  Bitmap16  default_host_host_alert_filter; /* Allow all */
  Bitmap128 default_host_flow_alert_filter; /* Allow all */
  AddressTree *host_filters; /* A ptree holding, for each host, a Bitmap128 with disabled flow alerts and a Bitmap16 with disabled host alerts */

  /* Add a disabled host and flow alerts for a host */
  alert_exclusion_host_tree_data *getHostData(const char * const host);
  bool addHostDisabledHostAlert(const char * const host, HostAlertTypeEnum disabled_host_alert_type);
  bool addHostDisabledFlowAlert(const char * const host, FlowAlertTypeEnum disabled_flow_alert_type);

  void loadConfiguration(); /* Read the configuration from Redis and initialize internal data structures */

 public:
  AlertExclusions();
  virtual ~AlertExclusions();

  /* Check whether the filters have changed since last_change, setting last_change to the latest change time */
  bool checkChange(time_t *last_change) const;
  void setDisabledHostAlertsBitmaps(IpAddress *addr, Bitmap16 *host_alerts, Bitmap128 *flow_alerts) const;
};

#endif /* _ALERT_EXCLUSIONS_H_ */

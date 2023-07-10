/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _TRAFFIC_VOLUME_ALERT_
#define _TRAFFIC_VOLUME_ALERT_

#include "ntop_includes.h"

class TrafficVolumeAlert : public HostAlert {
 private:
  std::string metric;
  u_int32_t frequency_sec, threshold, value;
  bool sign;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  static HostAlertType getClassType() {
    return {host_alert_traffic_volume, alert_category_network};
  }

  TrafficVolumeAlert(HostCheckID check_id, Host* h, risk_percentage cli_pctg,
                     std::string _metric, u_int32_t _frequency_sec,
                     u_int32_t _threshold, u_int32_t _value, bool t_sign);
  ~TrafficVolumeAlert(){};

  HostAlertType getAlertType() const { return getClassType(); };
  u_int8_t getAlertScore() const { return SCORE_LEVEL_ERROR; };

  std::string getMetric() { return metric; };
};

#endif /* _TRAFFIC_VOLUME_ALERT_ */

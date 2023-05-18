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

#ifndef _SCORE_THRESHOLD_ALERT_H_
#define _SCORE_THRESHOLD_ALERT_H_

#include "ntop_includes.h"

class ScoreThresholdAlert : public HostAlert {
 private:
  bool is_client_alert;
  u_int32_t value, threshold;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer) {
    if (serializer == NULL) return NULL;

    getHost()->serialize_breakdown(serializer);

    ndpi_serialize_string_boolean(serializer, "is_client_alert",
                                  is_client_alert);
    ndpi_serialize_string_uint64(serializer, "value", value);
    ndpi_serialize_string_uint64(serializer, "threshold", threshold);

    return (serializer);
  }

 public:
  ScoreThresholdAlert(HostCheck* c, Host* h, risk_percentage cli_pctg,
                      u_int32_t _value, u_int32_t _threshold)
      : HostAlert(c, h, cli_pctg) {
    is_client_alert = cli_pctg != CLIENT_NO_RISK_PERCENTAGE;
    value = _value;
    threshold = _threshold;
  }
  ~ScoreThresholdAlert(){};

  static HostAlertType getClassType() {
    return {host_alert_score_threshold, alert_category_security};
  }
  HostAlertType getAlertType() const { return getClassType(); }
  u_int8_t getAlertScore() const { return SCORE_LEVEL_SEVERE; };
};

#endif /* _SCORE_THRESHOLD_ALERT_H_ */

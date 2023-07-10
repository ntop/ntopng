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

#include "host_alerts_includes.h"

/* ***************************************************** */

TrafficVolumeAlert::TrafficVolumeAlert(HostCheckID check_id, Host* h,
                                       risk_percentage cli_pctg,
                                       std::string _metric,
                                       u_int32_t _frequency_sec,
                                       u_int32_t _threshold, u_int32_t _value,
                                       bool t_sign)
    : HostAlert(check_id, _metric, h, cli_pctg) {
  metric = _metric, frequency_sec = _frequency_sec, threshold = _threshold,
  value = _value;
  sign = t_sign;
};

/* ***************************************************** */

ndpi_serializer* TrafficVolumeAlert::getAlertJSON(ndpi_serializer* serializer) {
  if (serializer == NULL) return NULL;

  ndpi_serialize_string_uint64(serializer, "value", value);
  ndpi_serialize_string_uint64(serializer, "threshold", threshold);
  ndpi_serialize_string_uint64(serializer, "frequency", frequency_sec);
  ndpi_serialize_string_string(serializer, "metric", metric.c_str());
  ndpi_serialize_string_boolean(serializer, "sign", sign);


  return (serializer);
}

/* ***************************************************** */

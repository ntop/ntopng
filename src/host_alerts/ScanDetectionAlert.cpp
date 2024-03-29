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

#include "host_alerts_includes.h"

/* ***************************************************** */

ScanDetectionAlert::ScanDetectionAlert(
    HostCheck* c, Host* f, risk_percentage cli_pctg,
    u_int32_t _num_incomplete_flows, u_int32_t _num_incomplete_flows_threshold)
    : HostAlert(c, f, cli_pctg) {
  num_incomplete_flows = _num_incomplete_flows,
  num_incomplete_flows_threshold = _num_incomplete_flows_threshold;
  is_rx_only = false;
  num_server_ports = 0;
  as_server =  0;
  as_server_threshold = 0;
};

ScanDetectionAlert::ScanDetectionAlert(
    HostCheck* c, Host* f, risk_percentage cli_pctg, 
    u_int16_t _num_server_ports,
    u_int32_t _as_server,
    u_int32_t _as_server_threshold)
    : HostAlert(c, f, cli_pctg) {
  num_incomplete_flows = 0,
  num_incomplete_flows_threshold = 0;
  is_rx_only = true;
  num_server_ports = _num_server_ports;
  as_server =  _as_server;
  as_server_threshold = _as_server_threshold;
}

/* ***************************************************** */

ndpi_serializer* ScanDetectionAlert::getAlertJSON(ndpi_serializer* serializer) {
  if (serializer == NULL) return NULL;

  if (is_rx_only) {
    ndpi_serialize_string_uint64(serializer, "num_server_ports", num_server_ports);
    ndpi_serialize_string_uint64(serializer, "as_server", as_server);
    ndpi_serialize_string_uint64(serializer, "as_server_threshold", as_server_threshold);
    ndpi_serialize_string_boolean(serializer, "is_rx_only", true);
  } else {
    ndpi_serialize_string_uint64(serializer, "value", num_incomplete_flows);
    ndpi_serialize_string_uint64(serializer, "threshold",
                               num_incomplete_flows_threshold);
    ndpi_serialize_string_boolean(serializer, "is_rx_only", false);
  }
  return serializer;
}

/* ***************************************************** */

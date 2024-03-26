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

#ifndef _HOST_BLACK_HOLE_CONTACTS_H_
#define _HOST_BLACK_HOLE_CONTACTS_H_

#include "ntop_includes.h"

class HostBlackHoleContactsAlert : public HostAlert {
 private:
  u_int16_t num_server_ports;
  u_int32_t as_client, as_server, as_client_threshold, as_server_threshold;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer) {
    if (serializer == NULL) return NULL;

    ndpi_serialize_string_uint64(serializer, "num_server_ports", num_server_ports);
    ndpi_serialize_string_uint64(serializer, "as_client", as_client);
    ndpi_serialize_string_uint64(serializer, "as_server", as_server);
    ndpi_serialize_string_uint64(serializer, "as_client_threshold", as_client_threshold);
    ndpi_serialize_string_uint64(serializer, "as_server_threshold", as_server_threshold);

    return (serializer);
  }

 public:
  HostBlackHoleContactsAlert(HostCheck* c, Host* h,risk_percentage cli_pctg, u_int16_t _num_server_ports,
                    u_int32_t _as_client, u_int32_t _as_server, u_int32_t _as_client_threshold,
                    u_int32_t _as_server_threshold)
      : HostAlert(c, h, cli_pctg) {
    num_server_ports = _num_server_ports;
    as_client = _as_client;
    as_client_threshold = _as_client_threshold;
    as_server = _as_server;
    as_server_threshold = _as_server_threshold;
  }
  ~HostBlackHoleContactsAlert(){};

  static HostAlertType getClassType() {
    return {host_alert_black_hole_contacts, alert_category_security};
  }
  HostAlertType getAlertType() const { return getClassType(); }
  u_int8_t getAlertScore() const { return SCORE_LEVEL_CRITICAL; };
};

#endif /* _HOST_BLACK_HOLE_CONTACTS_H_ */

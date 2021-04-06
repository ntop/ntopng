/*
 *
 * (C) 2013-21 - ntop.org
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

RepliesRequestsRatioAlert::RepliesRequestsRatioAlert(HostCallback *c, Host *f, u_int8_t _ratio_threshold) : HostAlert(c, f) {
  ratio_threshold = _ratio_threshold;
  dns_sent_rcvd_ratio = dns_rcvd_sent_ratio = 0;
  http_sent_rcvd_ratio = http_rcvd_sent_ratio = 0;
};

/* ***************************************************** */

ndpi_serializer* RepliesRequestsRatioAlert::getAlertJSON(ndpi_serializer* serializer) {
  if(serializer == NULL)
    return NULL;

  /* Sync fields with host_alert_dns_requests_errors_ratio.lua */
  ndpi_serialize_string_uint32(serializer, "ratio", ratio_threshold);
  ndpi_serialize_string_uint32(serializer, "dns_sent_rcvd_ratio", dns_sent_rcvd_ratio);
  ndpi_serialize_string_uint32(serializer, "dns_rcvd_sent_ratio", dns_rcvd_sent_ratio);
  ndpi_serialize_string_uint32(serializer, "http_sent_rcvd_ratio", http_sent_rcvd_ratio);
  ndpi_serialize_string_uint32(serializer, "http_rcvd_sent_ratio", http_rcvd_sent_ratio);

  return serializer;

}

/* ***************************************************** */

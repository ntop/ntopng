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

P2PTrafficAlert::P2PTrafficAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _p2p_bytes, u_int64_t _p2p_bytes_threshold) : HostAlert(c, f, cli_pctg) {
  p2p_bytes = _p2p_bytes,
    p2p_bytes_threshold = _p2p_bytes_threshold;
};

/* ***************************************************** */

ndpi_serializer* P2PTrafficAlert::getAlertJSON(ndpi_serializer* serializer) {
  if(serializer == NULL)
    return NULL;

  ndpi_serialize_string_uint64(serializer, "value", p2p_bytes);
  ndpi_serialize_string_uint64(serializer, "threshold", p2p_bytes_threshold);
  
  return serializer;
}

/* ***************************************************** */

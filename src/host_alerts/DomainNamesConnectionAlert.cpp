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

DomainNamesConnectionAlert::DomainNamesConnectionAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int32_t _num_domain_names, u_int8_t _domain_names_threshold) : HostAlert (c, f, cli_pctg) {

  num_domain_names = _num_domain_names;
  domain_names_threshold=_domain_names_threshold;
};

/* ***************************************************** */

ndpi_serializer* DomainNamesConnectionAlert::getAlertJSON(ndpi_serializer* serializer) {
  if(serializer == NULL)
    return NULL;

  ndpi_serialize_string_uint64(serializer, "num_domain_names", num_domain_names);
  ndpi_serialize_string_uint64(serializer, "threshold", domain_names_threshold);
  
  return serializer;
}

/* ***************************************************** */

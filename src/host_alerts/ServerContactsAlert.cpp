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

ServerContactsAlert::ServerContactsAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _contacts, u_int64_t _contacts_threshold) : HostAlert(c, f, cli_pctg) {
  contacts = _contacts,
    contacts_threshold = _contacts_threshold;
};

/* ***************************************************** */

ndpi_serializer* ServerContactsAlert::getAlertJSON(ndpi_serializer* serializer) {
  if(serializer == NULL)
    return NULL;

  ndpi_serialize_string_uint64(serializer, "value", contacts);
  ndpi_serialize_string_uint64(serializer, "threshold", contacts_threshold);
  
  return serializer;
}

/* ***************************************************** */

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

#include "ntop_includes.h"

/* **************************************************** */

HostAlert::HostAlert(HostCheck *c, Host *h, risk_percentage _cli_pctg) {
  host = h;
  expiring = released = false;
  check_id = c->getID();
  check_name = c->getName();
  engage_time = time(NULL);
  release_time = 0;
  cli_pctg = _cli_pctg;
  is_attacker = is_victim = false;
}

/* **************************************************** */

HostAlert::~HostAlert() {
}

/* ***************************************************** */

ndpi_serializer* HostAlert::getSerializedAlert() {
  char buf[64];
  ndpi_serializer *serializer = (ndpi_serializer *) malloc(sizeof(ndpi_serializer));
  
  if(serializer == NULL)
    return NULL;

  if(ndpi_init_serializer(serializer, ndpi_serialization_format_json) == -1) {
    free(serializer);
    return NULL;
  }

  /* Add here global check information, common to any alerted host */

  /* Add information relative to this check */
  ndpi_serialize_start_of_block(serializer, "alert_generation");
  ndpi_serialize_string_string(serializer, "script_key", getCheckName().c_str());
  ndpi_serialize_string_string(serializer, "subdir", "host");

  ndpi_serialize_start_of_block(serializer, "host_info");
  
  ndpi_serialize_string_string(serializer, "name", host->get_visual_name(buf, sizeof(buf)));
  ndpi_serialize_string_boolean(serializer, "localhost", host->isLocalHost());
  ndpi_serialize_string_boolean(serializer, "systemhost", host->isSystemHost());
  ndpi_serialize_string_boolean(serializer, "privatehost", host->isPrivateHost());
  ndpi_serialize_string_boolean(serializer, "broadcast_domain_host", host->isBroadcastDomainHost());
  ndpi_serialize_string_boolean(serializer, "dhcpHost", host->isDhcpHost());
  ndpi_serialize_string_boolean(serializer, "is_blacklisted", host->isBlacklisted());
  ndpi_serialize_string_boolean(serializer, "is_broadcast", host->isBroadcastHost());
  ndpi_serialize_string_boolean(serializer, "is_multicast", host->isMulticastHost());
  
#ifdef HAVE_NEDGE
  ndpi_serialize_string_boolean(serializer, "childSafe", host->isChildSafe());
  ndpi_serialize_string_boolean(serializer, "drop_all_host_traffic", host->dropAllTraffic());
#endif


  ndpi_serialize_end_of_block(serializer); /* host_info        */
  ndpi_serialize_end_of_block(serializer); /* alert_generation */
  
  /* This call adds check-specific information to the serializer */
  getAlertJSON(serializer);

  return serializer;
}

/* ***************************************************** */


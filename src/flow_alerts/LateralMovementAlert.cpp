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

#include "flow_checks_includes.h"

/* ***************************************************** */

ndpi_serializer *LateralMovementAlert::getAlertJSON(ndpi_serializer* serializer) {
  Flow *f = getFlow();
  Host *cli = f->get_cli_host(), *srv = f->get_srv_host(); 
  char buf[128];

  if(serializer == NULL)
    return NULL;

  if (cli && cli->get_ip()) {
    ndpi_serialize_string_string(serializer, "cli_ip", cli->get_ip()->print(buf, sizeof(buf)));
    ndpi_serialize_string_uint32(serializer, "cli_port", f->get_cli_port());
  }
    
  if (srv && srv->get_ip()) {
    ndpi_serialize_string_string(serializer, "srv_ip", srv->get_ip()->print(buf, sizeof(buf)));
    ndpi_serialize_string_uint32(serializer, "srv_port", f->get_srv_port());
  }

  ndpi_serialize_string_boolean(serializer, "create_or_delete", f->isCreateOrDelete());
  ndpi_serialize_string_string(serializer, "l7_proto", f->get_detected_protocol_name(buf, sizeof(buf)));
  ndpi_serialize_string_uint32(serializer, "vlan_id", f->get_vlan_id());
  ndpi_serialize_string_string(serializer, "info", f->getFlowInfo(buf, sizeof(buf)));

  return serializer;
}


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

#include "flow_alerts_includes.h"

ndpi_serializer* ElephantFlowAlert::getAlertJSON(ndpi_serializer* serializer) {
  Flow *f = getFlow();

  if(serializer == NULL)
    return NULL;

  ndpi_serialize_string_uint64(serializer, "l2r_bytes", f->isLocalToRemote() ? f->get_bytes_cli2srv() : f->get_bytes_srv2cli());
  ndpi_serialize_string_uint64(serializer, "r2l_bytes", f->isRemoteToLocal() ? f->get_bytes_cli2srv() : f->get_bytes_srv2cli());
  ndpi_serialize_string_uint64(serializer, "l2r_threshold", l2r_th);
  ndpi_serialize_string_uint64(serializer, "r2l_threshold", r2l_th);

  return serializer;
}


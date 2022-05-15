/*
 *
 * (C) 2013-22 - ntop.org
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

ndpi_serializer* IECInvalidCommandTransitionAlert::getAlertJSON(ndpi_serializer* serializer) {
  Flow *f = getFlow();

  if (serializer) {
    ndpi_serialize_string_uint32(serializer, "timestamp", packet_epoch);
    ndpi_serialize_string_uint32(serializer, "flow_key", f->key());
    ndpi_serialize_string_uint32(serializer, "flow_hash_entry_id", f->get_hash_entry_id());
    ndpi_serialize_string_uint32(serializer, "transitions_m_to_c", transitions_m_to_c);
    ndpi_serialize_string_uint32(serializer, "transitions_c_to_m", transitions_c_to_m);
    ndpi_serialize_string_uint32(serializer, "transitions_c_to_c", transitions_c_to_c);
  }

  return serializer;
}


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

ndpi_serializer* IECUnexpectedTypeIdAlert::getAlertJSON(ndpi_serializer* serializer) {

  if (serializer) {
    ndpi_serialize_string_uint32(serializer, "type_id", type_id);
    ndpi_serialize_string_uint32(serializer, "asdu", asdu);
    ndpi_serialize_string_uint32(serializer, "cause_tx", cause_tx);
    ndpi_serialize_string_boolean(serializer, "negative", negative ? 1 : 0);
  }

  return serializer;
}


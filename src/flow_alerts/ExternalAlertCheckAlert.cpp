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

ndpi_serializer* ExternalAlertCheckAlert::getAlertJSON(ndpi_serializer* serializer) {
  Flow *f = getFlow();
  json_object *json = f->getExternalAlert();

  if (serializer != NULL && json != NULL) {
    json_object *alert, *sign, *cat;
    const char *source, *category, *signature; 
    int severity_id;

    /*
     * JSON Content:
     * source
     * severity_id
     * alert {
     *  category
     *  signature
     * }
     */

    source = f->getExternalSource();
    if (source)
      ndpi_serialize_string_string(serializer, "source", source);

    severity_id = f->getExternalSeverity();
    ndpi_serialize_string_uint32(serializer, "severity_id", severity_id);

    ndpi_serialize_start_of_block(serializer, "alert");

    if (json_object_object_get_ex(json, "alert", &alert)) {
      if (json_object_object_get_ex(alert, "signature", &sign)) {
        signature = json_object_get_string(sign);
        ndpi_serialize_string_string(serializer, "signature", signature);
      }           

      if (json_object_object_get_ex(alert, "category", &cat)) {
        category = json_object_get_string(cat);
        ndpi_serialize_string_string(serializer, "category", category);
      }
    }

    ndpi_serialize_end_of_block(serializer);
  }

  return serializer;
} 

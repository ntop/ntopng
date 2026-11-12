/*
 *
 * (C) 2013-26 - ntop.org
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

FlowAlert::FlowAlert(FlowCheck* c, Flow* f) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  flow = f;
  cli_attacker = srv_attacker = false;
  cli_victim = srv_victim = false;
  cli_score = srv_score = 0;
  if (c) check_name = c->getName();
  tags_bitmap = c ? c->getTags() : 0;
  alert_score = SCORE_LEVEL_INFO;
  json_alert = NULL;
  refresh_json_alert = false;
}

/* **************************************************** */

FlowAlert::~FlowAlert() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
  if (json_alert) free(json_alert);
}

/* ***************************************************** */

const char* FlowAlert::getSerializedAlert() {
  ndpi_serializer serializer;
  char* json;
  u_int32_t json_len;

  if (refresh_json_alert) {
    if (json_alert) {
      free(json_alert);
      json_alert = NULL;
    }
  }

  if (json_alert) return json_alert;

  if (ndpi_init_serializer(&serializer, ndpi_serialization_format_json) == -1)
    return NULL;

  ndpi_serialize_start_of_block(&serializer, "alert_generation");
  ndpi_serialize_string_string(&serializer, "script_key",
                               getCheckName().c_str());
  ndpi_serialize_string_string(&serializer, "subdir", "flow");
  ndpi_serialize_end_of_block(&serializer);

  ndpi_serialize_string_uint32(&serializer, "score", getAlertScore());

  /* Roles of this alert: the flow alert notification reports the ones of the
   * predominant alert only (used to group alerts into issues) */
  ndpi_serialize_string_boolean(&serializer, "is_cli_attacker", isCliAttacker());
  ndpi_serialize_string_boolean(&serializer, "is_cli_victim", isCliVictim());
  ndpi_serialize_string_boolean(&serializer, "is_srv_attacker", isSrvAttacker());
  ndpi_serialize_string_boolean(&serializer, "is_srv_victim", isSrvVictim());

  /* Tags of the check, per type for the issues (the flow alert has the union) */
  if (tags_bitmap) ndpi_serialize_string_uint64(&serializer, "tags_bitmap", tags_bitmap);

  getAlertJSON(&serializer);

  json = ndpi_serializer_get_buffer(&serializer, &json_len);

  if (json) json_alert = strdup(json);

  ndpi_term_serializer(&serializer);

  return json_alert;
}

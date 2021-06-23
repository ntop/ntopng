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

DangerousHostAlert::DangerousHostAlert(HostCheck *c, Host *f, risk_percentage cli_pctg, u_int64_t _score, u_int8_t _consecutive_high_score) : HostAlert(c, f, cli_pctg) {
  score = _score;
  consecutive_high_score = _consecutive_high_score;
};

/* ***************************************************** */

ndpi_serializer* DangerousHostAlert::getAlertJSON(ndpi_serializer* serializer) {
  if(serializer == NULL)
    return NULL;

  ndpi_serialize_string_uint64(serializer, "consecutive_high_score", consecutive_high_score);
  ndpi_serialize_string_uint64(serializer, "score", score);
  
  return serializer;
}

/* ***************************************************** */

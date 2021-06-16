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
#include "flow_checks_includes.h"

/* ***************************************************** */

void FlowRisk::protocolDetected(Flow *f) {
  if (f->hasRisk(handledRisk())) {
    u_int16_t flow_score, cli_score, srv_score;
    ndpi_risk risk_bitmap = 0;

    NDPI_SET_BIT(risk_bitmap, handledRisk());

    flow_score = ndpi_risk2score(risk_bitmap, &cli_score, &srv_score);

    f->triggerAlertAsync(getAlertType(), cli_score, srv_score);
  }
}

/* ***************************************************** */

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
#include "flow_callbacks_includes.h"

/* **************************************************** */

FlowAlertsLoader::FlowAlertsLoader() {
  /* TODO: implement dynamic loading */
  alert_to_score[BlacklistedCountryAlert::getClassType().id] = BlacklistedCountryAlert::getClassScore();

  /* TODO: add all alerts */
}

/* **************************************************** */

FlowAlertsLoader::~FlowAlertsLoader() {
}

/* **************************************************** */

u_int8_t FlowAlertsLoader::getAlertScore(FlowAlertTypeEnum alert_id) const {
  std::map<FlowAlertTypeEnum, u_int8_t>::const_iterator it = alert_to_score.find(alert_id);

  if(it != alert_to_score.end())
    return it->second;

  return 0;
}

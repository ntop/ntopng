/*
 *
 * (C) 2019 - ntop.org
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

/* ****************************************** */

/* Relase the expired alerts and push them into the Lua table */
void AlertableEntity::getExpiredAlerts(ScriptPeriodicity p, lua_State* vm, time_t now) {
  std::map<std::string, time_t>::iterator it;
  int seconds = Utils::periodicityToSeconds(p);

  for(it = triggered_alerts[(u_int)p].begin(); it != triggered_alerts[(u_int)p].end(); ++it) {
    if((now - it->second) > seconds)
      lua_push_uint64_table_entry(vm, it->first.c_str(), it->second);
  }
}

/* ****************************************** */

/* Return true if the element was inserted, false if already present */
bool AlertableEntity::triggerAlert(std::string key, ScriptPeriodicity p, time_t now) {
  std::map<std::string, time_t>::iterator it = triggered_alerts[(u_int)p].find(key);

  if(it != triggered_alerts[(u_int)p].end()) {
    it->second = now;
    return(false); /* already present */
  } else {
    triggered_alerts[(u_int)p][key] = now;
    return(true); /* inserted */
  }
}

/* ****************************************** */

u_int AlertableEntity::getNumTriggeredAlerts() {
  int i;
  u_int num_alerts = 0;

  for(i = 0; i<MAX_NUM_PERIODIC_SCRIPTS; i++)
    num_alerts += getNumTriggeredAlerts((ScriptPeriodicity) i);

  return(num_alerts);
}

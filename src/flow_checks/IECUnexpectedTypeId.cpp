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

/* *********************************************************** */

bool IECUnexpectedTypeId::loadConfiguration(json_object *config) {
  json_object *items;

  FlowCheck::loadConfiguration(config); /* Parse parameters in common */

  /*
    Parse additional threshold parameters. Example:

    {
    "severity": {
    "i18n_title": "alerts_dashboard.warning",
    "icon": "fas fa-exclamation-triangle text-warning",
    "label": "badge-warning",
    "emoji": "⚠",
    "syslog_severity": 4,
    "severity_id": 4
    },
    "items": [9, 13, 36, 45, 46, 48, 30, 103, 100, 37]
    }
  */

  /* Remote to local threshold */
  if(json_object_object_get_ex(config, "items", &items)) {
    char str[512];
    u_int idx = 0;
    
    for(u_int i=0; i<json_object_array_length(items); i++) {
      json_object *item = json_object_array_get_idx(items, i);
      u_int32_t id      = json_object_get_int(item);
      int rx = snprintf(&str[idx], sizeof(str)-idx-1, "%s%u",
			(i > 0) ? "," : "", id);

      if(rx > 0)
	idx += rx;
      else
	break;
    } /* for */

    str[idx] = '\0';

    ntop->getPrefs()->setIEC104AllowedTypeIDs(str); 
  }

  return(true);
}

/* *********************************************************** */

void IECUnexpectedTypeId::scriptDisable() {
  ntop->getPrefs()->setIEC104AllowedTypeIDs("-1"); /* Enable all so no alerts are generated */
}

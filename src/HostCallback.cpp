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

/* **************************************************** */

HostCallback::HostCallback(NtopngEdition _edition) {
  callback_edition = _edition;
  enabled = 0, severity_id = alert_level_warning;
  periodicity_secs = 0;
};

/* **************************************************** */

HostCallback::~HostCallback() {
};

/* **************************************************** */

bool HostCallback::loadConfiguration(json_object *config) {
  json_object *json_severity, *json_severity_id;
  bool rc = true;
  
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() %s", __FUNCTION__, json_object_to_json_string(config));

  /*
    Example of simple configuration without parameters:

    {
      "severity": {
        "i18n_title": "alerts_dashboard.error",
        "icon": "fas fa-exclamation-triangle text-danger",
        "label": "badge-danger",
        "syslog_severity": 3,
        "severity_id": 5
      }
    }
   */

  severity_id = alert_level_warning; /* Default */
  
  /* Read and parse the default severity */
  if(json_object_object_get_ex(config, "severity", &json_severity)
     && json_object_object_get_ex(json_severity, "severity_id", &json_severity_id)) {
    if((severity_id = (AlertLevel)json_object_get_int(json_severity_id)) >= ALERT_LEVEL_MAX_LEVEL)
      severity_id = alert_level_emergency;
  }
  
  return(rc);
}

/* **************************************************** */

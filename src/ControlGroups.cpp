/*
 *
 * (C) 2015-21 - ntop.org
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

/* Keep these constants in sync with control_groups.lua */
#define CONTROL_GROUP_MAX_CONTROL_GROUP_ID 127 /* Constrained by class Bitmap */
#define CONTROL_GROUP_IDS_KEY "ntopng.prefs.control_groups.control_group_ids"
#define CONTROL_GROUP_DETAILS_KEY "ntopng.prefs.control_groups.control_group_id_%d.details"

/* *************************************** */

ControlGroups::ControlGroups() {
  init_tstamp = time(NULL);
  member_groups = NULL;
  loadConfiguration();
}

/* *************************************** */

ControlGroups::~ControlGroups() {
}

/* *************************************** */

void ControlGroups::loadGroupMember(u_int group_id, const char * const member) {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reloading [member: %s][control group id: %d]", member, group_id);
}

/* *************************************** */

void ControlGroups::loadGroupDisabledFlowAlert(u_int group_id, FlowAlertTypeEnum disabled_flow_alert_type) {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reloading [alert: %d][control group id: %d]", disabled_flow_alert_type, group_id);
}

/* *************************************** */

void ControlGroups::loadConfiguration() {
  json_object *json = NULL, *json_members, *json_member, *json_disabled_flow_alerts, *json_disabled_flow_alert;
  enum json_tokener_error jerr = json_tokener_success;
  char kname[CONST_MAX_LEN_REDIS_KEY], *control_group_details = NULL;
  u_int control_group_details_len;
  char **control_groups = NULL;
  int num_control_groups;
  Redis *redis = ntop->getRedis();
  u_int8_t _control_group_id;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reloading control groups");

  if((num_control_groups = redis->smembers(CONTROL_GROUP_IDS_KEY, &control_groups)) == -1) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Unable to read control group ids");
    return; /* Something went wrong with redis? */
  }

  for(int i = 0; i < num_control_groups; i++) {
    if(!control_groups[i])
      goto out;

    _control_group_id = (u_int8_t)atoi(control_groups[i]);

    if(_control_group_id > CONTROL_GROUP_MAX_CONTROL_GROUP_ID) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Ignoring control group with invalid id [control group id: %2d]. ", _control_group_id);
      goto out;
    }

    snprintf(kname, sizeof(kname), CONTROL_GROUP_DETAILS_KEY, _control_group_id);
    control_group_details_len = ntop->getRedis()->len(kname);

    if((control_group_details = (char *) malloc(control_group_details_len + 1)) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory to deserialize control group [control group id: %d]", _control_group_id);
      goto out;
    }

    if(ntop->getRedis()->get(kname, control_group_details, control_group_details_len + 1) != 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to find control group details [control group: %d]", _control_group_id);
      goto out;
    }

    if((json = json_tokener_parse_verbose(control_group_details, &jerr)) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "JSON Parse error [%s] %s [len: %u][strlen: %u]",
				   json_tokener_error_desc(jerr), control_group_details, control_group_details_len, strlen(control_group_details));
      goto out;
    }

    /* Iterathe through the members array */
    if(json_object_object_get_ex(json, "members", &json_members)) {
      for (int i = 0; i < json_object_array_length(json_members); i++) {
	json_member = json_object_array_get_idx(json_members, i);

	/* Add each country code to the set of blacklisted countries */
	std::string member = json_object_get_string(json_member);
	loadGroupMember(_control_group_id, member.c_str());
      }
    }

    /* Iterathe through the disabled alerts */
    if(json_object_object_get_ex(json, "disabled_alerts", &json_disabled_flow_alerts)) {
      for (int i = 0; i < json_object_array_length(json_disabled_flow_alerts); i++) {
	json_disabled_flow_alert = json_object_array_get_idx(json_disabled_flow_alerts, i);

	/* Add each country code to the set of blacklisted countries */
	FlowAlertTypeEnum alert_id = (FlowAlertTypeEnum)json_object_get_int(json_disabled_flow_alert);
	loadGroupDisabledFlowAlert(_control_group_id, alert_id);
      }
    }

  out:
    if(control_groups[i])       free(control_groups[i]);
    if(control_group_details) { free(control_group_details); control_group_details = NULL; }
    if(json)                  { json_object_put(json); json = NULL; }
  }

  if(control_groups) free(control_groups);
}

/* *************************************** */

bool ControlGroups::checkChange(time_t *last_change) const {
  bool changed = false;

  if(*last_change < init_tstamp)
    changed = true, *last_change = init_tstamp;

  return changed;
}

/* *************************************** */

Bitmap ControlGroups::getDisabledFlowAlertsBitmap(Host *h) const {
  Bitmap res;

  return res;
}


/* *************************************** */

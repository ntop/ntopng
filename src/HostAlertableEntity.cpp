/*
 *
 * (C) 2021 - ntop.org
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

HostAlertableEntity::HostAlertableEntity(NetworkInterface *iface, AlertEntity entity) : AlertableEntity(iface, entity) {
  memset(engaged_alerts, 0, sizeof(engaged_alerts));
}

/* ****************************************** */

HostAlertableEntity::~HostAlertableEntity() {
  clearEngagedAlerts();
}

/* *************************************** */

void HostAlertableEntity::clearEngagedAlerts() {
  for (u_int i = 0; i < NUM_DEFINED_HOST_CHECKS; i++) {
    HostAlert *alert = engaged_alerts[i];
    if (alert) {
      removeEngagedAlert(alert);
      delete alert;
    }
  }
}

/* *************************************** */

bool HostAlertableEntity::addEngagedAlert(HostAlert *a) {
  bool success = false;

  engaged_alerts_lock.wrlock(__FILE__, __LINE__);

  if (!engaged_alerts[a->getCheckType()]) {
    engaged_alerts[a->getCheckType()] = a; 
    engaged_alerts_map.setBit(a->getAlertType().id);
    incNumAlertsEngaged();
    success = true;
  }

  engaged_alerts_lock.unlock(__FILE__, __LINE__);

  return success;
} 

/* *************************************** */

bool HostAlertableEntity::removeEngagedAlert(HostAlert *a) {
  bool success = false;
 
  engaged_alerts_lock.wrlock(__FILE__, __LINE__);

  if (engaged_alerts[a->getCheckType()] == a) {
    engaged_alerts[a->getCheckType()] = NULL;
    engaged_alerts_map.clearBit(a->getAlertType().id);
    decNumAlertsEngaged();
    success = true;
  }

  engaged_alerts_lock.unlock(__FILE__, __LINE__);

  return success;
}

/* *************************************** */

bool HostAlertableEntity::hasCheckEngagedAlert(HostCheckID check_id) {
  return (engaged_alerts[check_id] ? true : false);
}

/* *************************************** */

HostAlert *HostAlertableEntity::findEngagedAlert(HostAlertType alert_id, HostCheckID check_id) {

  if (isEngagedAlert(alert_id)
      && engaged_alerts[check_id]
      && engaged_alerts[check_id]->getAlertType().id == alert_id.id)
    return engaged_alerts[check_id];

  return NULL;
}

/* ****************************************** */

void HostAlertableEntity::countAlerts(grouped_alerts_counters *counters) {
  engaged_alerts_lock.rdlock(__FILE__, __LINE__);

  for (u_int i = 0; i < NUM_DEFINED_HOST_CHECKS; i++) {
    HostAlert *alert = engaged_alerts[i];
    if (alert) {
      counters->severities[std::make_pair(getEntityType(), Utils::mapScoreToSeverity(alert->getAlertScore()))]++;
      counters->types[std::make_pair(getEntityType(), alert->getAlertType().id)]++;
    }
  }

  engaged_alerts_lock.unlock(__FILE__, __LINE__);
}

/* ****************************************** */

void HostAlertableEntity::luaAlert(lua_State* vm, HostAlert *alert) {
  char ip_buf[128], buf[128];
  ndpi_serializer *alert_json_serializer = NULL;
  char *alert_json = NULL;
  u_int32_t alert_json_len;

  /*
    NOTE: Keep in sync with Host::alert2JSON
  */
  lua_push_int32_table_entry(vm,  "alert_id", alert->getAlertType().id);
  lua_push_str_table_entry(vm,    "subtype", "" /* No subtype for hosts */);
  lua_push_int32_table_entry(vm,  "score", alert->getAlertScore());
  lua_push_int32_table_entry(vm,  "severity", Utils::mapScoreToSeverity(alert->getAlertScore()));
  lua_push_int32_table_entry(vm,  "entity_id", alert_entity_host);
  lua_push_str_table_entry(vm,    "entity_val", alert->getHost()->getEntityValue().c_str());
  lua_push_uint64_table_entry(vm, "tstamp", alert->getEngageTime());
  lua_push_uint64_table_entry(vm, "tstamp_end", alert->isReleased() ? alert->getReleaseTime() : time(NULL));

  lua_push_str_table_entry(vm, "ip", alert->getHost()->get_ip()->print(ip_buf, sizeof(ip_buf)));
  alert->getHost()->get_name(buf, sizeof(buf), false);
  lua_push_str_table_entry(vm, "name", buf);
  lua_push_uint64_table_entry(vm, "vlan_id", alert->getHost()->get_vlan_id());
  lua_push_bool_table_entry(vm, "is_attacker", alert->isAttacker());
  lua_push_bool_table_entry(vm, "is_victim", alert->isVictim());
  lua_push_bool_table_entry(vm, "is_client", alert->isClient());
  lua_push_bool_table_entry(vm, "is_server", alert->isServer());

  HostCheck *cb = getAlertInterface()->getCheck(alert->getCheckType());
  lua_push_int32_table_entry(vm,  "granularity", cb ? cb->getPeriod() : 0);

  alert_json_serializer = alert->getSerializedAlert();
  if(alert_json_serializer)
    alert_json = ndpi_serializer_get_buffer(alert_json_serializer, &alert_json_len);

  lua_push_str_table_entry(vm,    "json", alert_json ? alert_json : "");
 
  if(alert_json_serializer) {
    ndpi_term_serializer(alert_json_serializer);
    free(alert_json_serializer);
  }
}

/* ****************************************** */

void HostAlertableEntity::getAlerts(lua_State* vm, ScriptPeriodicity p /* not used */,
				    AlertType type_filter, AlertLevel severity_filter, AlertRole role_filter,
				    u_int *idx) {

  engaged_alerts_lock.rdlock(__FILE__, __LINE__);

  for (u_int i = 0; i < NUM_DEFINED_HOST_CHECKS; i++) {
    HostAlert *alert = engaged_alerts[i];
    if (alert) {
      if((type_filter == alert_none
	   || type_filter == alert->getAlertType().id)
	  && (severity_filter == alert_level_none
	      || severity_filter == Utils::mapScoreToSeverity(alert->getAlertScore()))
	  && (role_filter == alert_role_is_any
	      || (role_filter == alert_role_is_attacker && alert->isAttacker())
	      || (role_filter == alert_role_is_victim && alert->isVictim()))) {
        lua_newtable(vm);
        luaAlert(vm, alert);

        lua_pushinteger(vm, ++(*idx));
        lua_insert(vm, -2);
        lua_settable(vm, -3);
      }
    }
  }

  engaged_alerts_lock.unlock(__FILE__, __LINE__);
}

/* ****************************************** */

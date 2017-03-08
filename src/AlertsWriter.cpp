/*
 *
 * (C) 2017 - ntop.org
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

/* Used internally */
#define ALERT_KEY_THRESHOLD_CROSS_FORMAT "%s_%s"
#define ALERT_KEY_HOST_SCAN_ATTACKER "scan_attacker"
#define ALERT_KEY_HOST_SCAN_VICTIM "scan_victim"
#define ALERT_KEY_INTERFACE_APP_MISCONFIGURATION "app_misconfiguration"
#define ALERT_KEY_OPEN_FILES_LIMIT "open_files_limit_too_small"

/* SUBJECTS */
#define JSON_ALERT_SUBJECT "subject"
#define JSON_ALERT_SUBJECT_HOST "hostAlert"
#define JSON_ALERT_SUBJECT_INTERFACE "interfaceAlert"
#define JSON_ALERT_SUBJECT_NETWORK "networkAlert"
#define JSON_ALERT_SUBJECT_FLOW "flowAlert"

/* Generic */
#define JSON_ALERT_DETAIL "detail"
#define JSON_ALERT_DETAIL_THRESHOLD_CROSS "thresholdCross"
#define JSON_ALERT_TIMESTAMP_END "timestampEnd"
#define JSON_ALERT_DETAIL_ABOVE_QUOTA "aboveQuota"
#define JSON_ALERT_DETAIL_TOO_MANY_ALERTS "tooManyAlerts"
#define JSON_ALERT_DETAIL_TOO_MANY_FLOW_ALERTS "tooManyFlowAlerts"

/* Host */
#define JSON_ALERT_DETAIL_HOST_BLACKLISTED "hostBlacklisted"
#define JSON_ALERT_DETAIL_FLOW_FLOOD_ATTACKER "flowFloodAttacker"
#define JSON_ALERT_DETAIL_FLOW_FLOOD_VICTIM "flowFloodVictim"
#define JSON_ALERT_DETAIL_SYN_FLOOD_ATTACKER "synFloodAttacker"
#define JSON_ALERT_DETAIL_SYN_FLOOD_VICTIM "synFloodVictim"
#define JSON_ALERT_DETAIL_FLOW_LOW_GOODPUT_ATTACKER "flowLowGoodputAttacker"
#define JSON_ALERT_DETAIL_FLOW_LOW_GOODPUT_VICTIM "flowLowGoodputVictim"
#define JSON_ALERT_DETAIL_HOST_LOW_GOODPUT_FLOWS "lowGoodputFlows"

/* Interface */
#define JSON_ALERT_DETAIL_APP_MISCONFIGURATION "appMisconfiguration"
#define JSON_ALERT_APP_MISCONFIGURATION_SETTING "setting"
#define JSON_ALERT_APP_MISCONFIGURATION_FLOWS "numFlows"
#define JSON_ALERT_APP_MISCONFIGURATION_HOSTS "numHosts"
#define JSON_ALERT_APP_MISCONFIGURATION_MYSQL_OPEN_FILES "numOpenMysqlFilesLimit"

/* Flow */
#define JSON_ALERT_DETAIL_FLOW_PROBING "flowProbing"
#define JSON_ALERT_DETAIL_FLOW_BLACKLISTED_HOSTS "flowBlacklistedHosts"
#define JSON_ALERT_DETAIL_FLOW_MALWARE_SITE "flowMalwareSite"
#define JSON_ALERT_DETAIL_FLOW_ALERTED_INTERFACE "alertedInterface"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE "probingType"
/*    Flow Probing */
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SLOW_TCP "slow_tcp_connection"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SLOW_APP_HEADER "slow_application_header"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_LOW_GOODPUT "low_goodput"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SLOW_DATA "slow_data_exchange"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_TCP_ISSUES "tcp_connection_issues"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SYN_PROBING "syn_probing"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_TCP_PROBING "tcp_probing"
#define JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_CON_REFUSED "tcp_connection_refused"

/* Exposed Methods */

AlertsWriter::AlertsWriter(AlertsManager *am) {
  this->am = am;
}

/* Flow Alerts */

void AlertsWriter::createGenericFlowAlert(Flow *flow, const AlertType type, const AlertLevel severity,
    json_object *detail, const char *detail_name) {
  time_t when = time(0);

  json_object *alert = json_alert(severity, am->getNetworkInterface(), when);
  json_object *subject = json_flow_subject(flow);
  json_subject_add(alert, subject, JSON_ALERT_SUBJECT_FLOW);
  json_detail_add(subject, detail, detail_name);

  json_alert_ends(alert, when);

  am->storeFlowAlert(flow, when, type, severity, json_object_to_json_string(alert));

  json_object_put(alert);
}

void AlertsWriter::storeFlowProbing(Flow *flow, FlowStatus flow_status) {
  AlertType alert_type;
  const char *probing_type;

  switch(flow_status) {
    case status_slow_tcp_connection:
      alert_type = alert_flow_misbehaviour;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SLOW_TCP;
      break;
    case status_slow_application_header:
      alert_type = alert_flow_misbehaviour;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SLOW_APP_HEADER;
      break;
    case status_low_goodput:
      alert_type = alert_flow_misbehaviour;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_LOW_GOODPUT;
      break;
    case status_slow_data_exchange:
      alert_type = alert_flow_misbehaviour;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SLOW_DATA;
      break;
    case status_tcp_connection_issues:
      alert_type = alert_flow_misbehaviour;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_TCP_ISSUES;
      break;

    case status_suspicious_tcp_syn_probing:
      alert_type = alert_suspicious_activity;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_SYN_PROBING;
      break;
    case status_suspicious_tcp_probing:
      alert_type = alert_suspicious_activity;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_TCP_PROBING;
      break;
    case status_tcp_connection_refused:
      alert_type = alert_suspicious_activity;
      probing_type = JSON_ALERT_DETAIL_FLOW_PROBING_TYPE_CON_REFUSED;
      break;

    default:
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown flow status %d", flow_status);
      alert_type = alert_flow_misbehaviour;
      probing_type = "";
  }

  json_object *detail = json_object_new_object();
  json_object_object_add(detail, JSON_ALERT_DETAIL_FLOW_PROBING_TYPE, json_object_new_string(probing_type));

  createGenericFlowAlert(flow, alert_type, alert_level_warning, detail, JSON_ALERT_DETAIL_FLOW_PROBING);
}

void AlertsWriter::storeFlowBlacklistedHosts(Flow *flow) {
  createGenericFlowAlert(flow, alert_dangerous_host, alert_level_error, json_object_new_object(), JSON_ALERT_DETAIL_FLOW_BLACKLISTED_HOSTS);
}

void AlertsWriter::storeFlowAlertedInterface(Flow *flow) {
  createGenericFlowAlert(flow, alert_interface_alerted, alert_level_warning, json_object_new_object(), JSON_ALERT_DETAIL_FLOW_ALERTED_INTERFACE);
}

/* Interface Alerts */

void AlertsWriter::createGenericInterfaceAlert(const char *alert_key,
    const AlertType type, const AlertLevel severity,
    json_object *detail, const char *detail_name) {
  time_t when = time(0);

  json_object *alert = json_alert(severity, am->getNetworkInterface(), when);
  json_object *subject = json_interface_subject();
  json_subject_add(alert, subject, JSON_ALERT_SUBJECT_INTERFACE);
  json_detail_add(subject, detail, detail_name);

  if (alert_key == NULL)
    json_alert_ends(alert, when);

  const char* msg = json_object_to_json_string(alert);

  if (alert_key == NULL)
    am->storeInterfaceAlert(am->getNetworkInterface(), when, type, severity, msg, false /* force */);
  else
    am->engageInterfaceAlert(am->getNetworkInterface(), alert_key, when, type, severity, msg);

  json_object_put(alert);
}

void AlertsWriter::engageInterfaceThresholdCross(const char *time_period,
    const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold) {
  char alert_key[32];
  snprintf(alert_key, sizeof(alert_key), ALERT_KEY_THRESHOLD_CROSS_FORMAT, time_period, alarmable);

  json_object *detail_json = json_threshold_cross(alarmable, op, value, threshold);
  createGenericInterfaceAlert(alert_key, alert_threshold_exceeded, alert_level_error, detail_json, JSON_ALERT_DETAIL_THRESHOLD_CROSS);
}

void AlertsWriter::releaseInterfaceThresholdCross(const char *time_period, const char *alarmable) {
  char alert_key[32];
  snprintf(alert_key, sizeof(alert_key), ALERT_KEY_THRESHOLD_CROSS_FORMAT, time_period, alarmable);
  
  am->releaseInterfaceAlert(am->getNetworkInterface(), alert_key, alert_threshold_exceeded);
}

void AlertsWriter::storeInterfaceTooManyAlerts() {
  createGenericInterfaceAlert(NULL, alert_too_many_alerts, alert_level_error, json_object_new_object(), JSON_ALERT_DETAIL_TOO_MANY_ALERTS);
}

void AlertsWriter::storeInterfaceTooManyFlowAlerts() {
  createGenericInterfaceAlert(NULL, alert_too_many_alerts, alert_level_error, json_object_new_object(), JSON_ALERT_DETAIL_TOO_MANY_FLOW_ALERTS);
}

void AlertsWriter::storeInterfaceTooManyFlows() {
  json_object *detail_json = json_object_new_object();
  json_app_misconfiguration_setting_add(detail_json, JSON_ALERT_APP_MISCONFIGURATION_FLOWS);
  createGenericInterfaceAlert(NULL, alert_app_misconfiguration, alert_level_error, detail_json, JSON_ALERT_DETAIL_APP_MISCONFIGURATION);
}

void AlertsWriter::storeInterfaceTooManyHosts() {
  json_object *detail_json = json_object_new_object();
  json_app_misconfiguration_setting_add(detail_json, JSON_ALERT_APP_MISCONFIGURATION_HOSTS);
  createGenericInterfaceAlert(NULL, alert_app_misconfiguration, alert_level_error, detail_json, JSON_ALERT_DETAIL_APP_MISCONFIGURATION);
}

void AlertsWriter::engageInterfaceTooManyOpenFiles() {
  json_object *detail_json = json_object_new_object();
  json_app_misconfiguration_setting_add(detail_json, JSON_ALERT_APP_MISCONFIGURATION_MYSQL_OPEN_FILES);
  createGenericInterfaceAlert(ALERT_KEY_OPEN_FILES_LIMIT, alert_app_misconfiguration, alert_level_error, detail_json, JSON_ALERT_DETAIL_APP_MISCONFIGURATION);
}

void AlertsWriter::releaseInterfaceTooManyOpenFiles() {
  am->releaseInterfaceAlert(am->getNetworkInterface(), ALERT_KEY_OPEN_FILES_LIMIT, alert_app_misconfiguration);
}

/* Network Alerts */

void AlertsWriter::createGenericNetworkAlert(const char *alert_key, const char *network,
    const AlertType type, const AlertLevel severity,
    json_object *detail, const char *detail_name) {
  time_t when = time(0);

  json_object *alert = json_alert(severity, am->getNetworkInterface(), when);
  json_object *subject = json_network_subject(network);
  json_subject_add(alert, subject, JSON_ALERT_SUBJECT_NETWORK);
  json_detail_add(subject, detail, detail_name);

  if (alert_key == NULL)
    json_alert_ends(alert, when);

  const char* msg = json_object_to_json_string(alert);

  if (alert_key == NULL)
    am->storeNetworkAlert(network, when, type, severity, msg);
  else
    am->engageNetworkAlert(network, alert_key, when, type, severity, msg);

  json_object_put(alert);
}

void AlertsWriter::engageNetworkThresholdCross(const char *time_period, const char *network,
    const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold) {
  char alert_key[32];
  snprintf(alert_key, sizeof(alert_key), ALERT_KEY_THRESHOLD_CROSS_FORMAT, time_period, alarmable);

  json_object *detail_json = json_threshold_cross(alarmable, op, value, threshold);
  createGenericNetworkAlert(alert_key, network, alert_threshold_exceeded, alert_level_error, detail_json, JSON_ALERT_DETAIL_THRESHOLD_CROSS);
}

void AlertsWriter::releaseNetworkThresholdCross(const char *time_period, const char *network, const char *alarmable) {
  char alert_key[32];
  snprintf(alert_key, sizeof(alert_key), ALERT_KEY_THRESHOLD_CROSS_FORMAT, time_period, alarmable);
  
  am->releaseNetworkAlert(network, alert_key, alert_threshold_exceeded);
}

void AlertsWriter::storeNetworkTooManyAlerts(const char *network) {
  createGenericNetworkAlert(NULL, network, alert_too_many_alerts, alert_level_error, json_object_new_object(), JSON_ALERT_DETAIL_TOO_MANY_ALERTS);
}

/* Host Alerts */

void AlertsWriter::createGenericHostAlert(const char *alert_key, Host *host, const AlertType type, const AlertLevel severity,
      json_object *detail, const char*detail_name, Host *source, Host *target) {
  time_t when = time(0);

  json_object *alert = json_alert(severity, am->getNetworkInterface(), when);
  json_object *subject = json_host_subject(host);
  json_subject_add(alert, subject, JSON_ALERT_SUBJECT_HOST);
  json_detail_add(subject, detail, detail_name);

  if (alert_key == NULL)
    json_alert_ends(alert, when);

  const char* msg = json_object_to_json_string(alert);

  if (alert_key == NULL)
    am->storeHostAlert(host, when, type, severity, source, target, msg);
  else
    am->engageHostAlert(host, alert_key, when, type, severity, source, target, msg);

  json_object_put(alert);
}

void AlertsWriter::simple_host_alert(const char *alert_key, Host *host, const AlertType type, const AlertLevel severity, const char *detail_name) {
  json_object *detail_json = json_object_new_object();
  createGenericHostAlert(alert_key, host, type, severity, detail_json, detail_name, NULL, NULL);
}

void AlertsWriter::engageHostThresholdCross(const char *time_period, Host *host,
    const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold) {
  char alert_key[32];
  snprintf(alert_key, sizeof(alert_key), ALERT_KEY_THRESHOLD_CROSS_FORMAT, time_period, alarmable);
  json_object *detail_json = json_threshold_cross(alarmable, op, value, threshold);
  createGenericHostAlert(alert_key, host, alert_threshold_exceeded, alert_level_error, detail_json, JSON_ALERT_DETAIL_THRESHOLD_CROSS, NULL, NULL);
}

void AlertsWriter::releaseHostThresholdCross(const char *time_period, Host *host, const char *alarmable) {
  char alert_key[32];
  snprintf(alert_key, sizeof(alert_key), ALERT_KEY_THRESHOLD_CROSS_FORMAT, time_period, alarmable);
  
  am->releaseHostAlert(host, alert_key, alert_threshold_exceeded);
}

void AlertsWriter::storeHostTooManyAlerts(Host *host) {
  simple_host_alert(NULL, host, alert_too_many_alerts, alert_level_error, JSON_ALERT_DETAIL_TOO_MANY_ALERTS);
}

void AlertsWriter::storeHostAboveQuota(Host *host) {
  simple_host_alert(NULL, host, alert_quota, alert_level_error, JSON_ALERT_DETAIL_ABOVE_QUOTA);
}

void AlertsWriter::storeHostBlacklisted(Host *host) {
  simple_host_alert(NULL, host, alert_malware_detection, alert_level_error, JSON_ALERT_DETAIL_HOST_BLACKLISTED);
}

void AlertsWriter::attack_host_alert(const char *alert_key, Host *host, Host *attacker, Host *victim,
    u_int32_t current_hits, u_int32_t duration) {
  const char *detail_name = (host == attacker) ? JSON_ALERT_DETAIL_SYN_FLOOD_ATTACKER : JSON_ALERT_DETAIL_SYN_FLOOD_VICTIM;

  json_object *detail = json_object_new_object();
  json_object *attack_counter = json_object_new_object();
  json_object_object_add(detail, "attackCounter", attack_counter);
  json_object_object_add(attack_counter, "currentHits", json_object_new_int64(current_hits));
  json_object_object_add(attack_counter, "duration", json_object_new_int64(duration));

  if (host == victim)
    json_object_object_add(detail, "attacker", json_host(attacker));

  createGenericHostAlert(alert_key, host, alert_syn_flood, alert_level_error, detail, detail_name, attacker, victim);
}

void AlertsWriter::storeHostSynFloodAttacker(Host *host,
    Host *victim, u_int32_t current_hits, u_int32_t duration) {
  attack_host_alert(NULL, host, host, victim, current_hits, duration);
}

void AlertsWriter::storeHostSynFloodVictim(Host *host,
    Host *attacker, u_int32_t current_hits, u_int32_t duration) {
  attack_host_alert(NULL, host, attacker, host, current_hits, duration);
}

void AlertsWriter::engageHostFlowFloodAttacker(Host *host) {
  createGenericHostAlert(ALERT_KEY_HOST_SCAN_ATTACKER, host, alert_flow_flood, alert_level_error, json_object_new_object(), JSON_ALERT_DETAIL_FLOW_FLOOD_ATTACKER, host, NULL);
}

void AlertsWriter::releaseHostFlowFloodAttacker(Host *host) {
  am->releaseHostAlert(host, ALERT_KEY_HOST_SCAN_ATTACKER, alert_flow_flood);
}

void AlertsWriter::engageHostFlowFloodVictim(Host *host) {
  json_object *detail = json_object_new_object();
  createGenericHostAlert(ALERT_KEY_HOST_SCAN_VICTIM, host, alert_flow_flood, alert_level_error, detail, JSON_ALERT_DETAIL_FLOW_FLOOD_VICTIM, NULL, host);
}

void AlertsWriter::releaseHostFlowFloodVictim(Host *host) {
  am->releaseHostAlert(host, ALERT_KEY_HOST_SCAN_VICTIM, alert_flow_flood);
}

/* Internal Methods */

json_object* AlertsWriter::json_generic_alert(AlertLevel severity, time_t start_time) {
  const char *level = "";

  switch(severity) {
    case alert_level_error:   level = "error";   break;
    case alert_level_warning: level = "warning"; break;
    case alert_level_info:    level = "info";    break;
    default:
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown alert severity %d", severity);
  }

  json_object *alert = json_object_new_object();
  json_object_object_add(alert, "timestampStart", json_object_new_int64(start_time));
  json_object_object_add(alert, "severity", json_object_new_string(level));
  return alert;
}

json_object* AlertsWriter::json_interface(NetworkInterface *iface) {
  json_object *iface_json = json_object_new_object();
  json_object_object_add(iface_json, "id", json_object_new_int64(iface->get_id()));
  json_object_object_add(iface_json, "name", json_object_new_string(iface->get_name()));
  return iface_json;
}

json_object* AlertsWriter::json_flow(Flow *flow) {
  return flow->flow2alert();
}

json_object* AlertsWriter::json_network(const char *cidr) {
  json_object *network_json = json_object_new_object();
  json_object_object_add(network_json, "cidr", json_object_new_string(cidr));
  return network_json;
}

json_object* AlertsWriter::json_protocol(ndpi_protocol proto, const char *name) {
  json_object *proto_json = json_object_new_object();

  json_object_object_add(proto_json, "name", json_object_new_string(name));
  json_object_object_add(proto_json, "master", json_object_new_int64(proto.master_protocol));
  json_object_object_add(proto_json, "sub", json_object_new_int64(proto.protocol));
  return proto_json;
}

json_object* AlertsWriter::json_ip(IpAddress *ip) {
  char buf[64];
  char *ip_str;

  json_object* json = json_object_new_object();
  ip_str = ip->print(buf, sizeof(buf));

  json_object_object_add(json, ip->isIPv4() ? "ipv4" : "ipv6", json_object_new_string(ip_str));
  return json;
}

json_object* AlertsWriter::json_host(Host *host) {
  char buf[96];
  char ipbuf[64];
  IpAddress *host_ip = host->get_ip();

  json_object *host_json = json_object_new_object();
  json_object_object_add(host_json, "ref", json_object_new_string(host->get_host_key(buf, sizeof(buf))));
  json_object_object_add(host_json, "address", json_ip(host_ip));

  char *host_name = host->get_name(buf, sizeof(buf), false);
  char *ip_str = host_ip->print(ipbuf, sizeof(ipbuf));
  if((host_name != NULL) && (strcmp(ip_str, host_name) != 0))
    json_object_object_add(host_json, "name", json_object_new_string(host_name));

  json_object_object_add(host_json, "isLocal", json_object_new_boolean(host->isLocalHost()));
  json_object_object_add(host_json, "isBlacklisted", json_object_new_boolean(host->isBlacklisted()));

  if(host->get_country() && host->get_country()[0]) json_object_object_add(host_json, "country", json_object_new_string(host->get_country()));
  if(host->get_os() && host->get_os()[0]) json_object_object_add(host_json, "os", json_object_new_string(host->get_os()));
  if(host->get_asn()) {
    json_object *asn = json_object_new_object();
    json_object_object_add(host_json, "asn", asn);
    json_object_object_add(asn, "id", json_object_new_int64(host->get_asn()));
    json_object_object_add(asn, "name", json_object_new_string(host->get_asname()));
  }

  return host_json;
}

/* Utilities */

json_object* AlertsWriter::json_alert(AlertLevel severity, NetworkInterface *iface, time_t start_time) {
  json_object *alert = json_generic_alert(severity, start_time);
  json_object_object_add(alert, "interface", json_interface(iface));
  return alert;
}

json_object* AlertsWriter::json_alert_ends(json_object *alert, time_t end_time) {
  json_object_object_add(alert, JSON_ALERT_TIMESTAMP_END, json_object_new_int64(end_time));
  return alert;
}

json_object* AlertsWriter::json_alert_set_vlan(json_object *alert, u_int16_t vlan_id) {
  json_object_object_add(alert, "vlan", json_object_new_int64(vlan_id));
  return alert;
}

json_object* AlertsWriter::json_subject_add(json_object *alert, json_object *subject, const char *subject_value) {
  json_object *container = json_object_new_object();
  json_object_object_add(alert, JSON_ALERT_SUBJECT, container);
  json_object_object_add(container, subject_value, subject);
  return container;
}

json_object* AlertsWriter::json_detail_add(json_object *subject, json_object *detail, const char *detail_value) {
  json_object *detail_container = json_object_new_object();
  json_object_object_add(subject, JSON_ALERT_DETAIL, detail_container);
  json_object_object_add(detail_container, detail_value, detail);
  return detail_container;
}

json_object* AlertsWriter::json_app_misconfiguration_setting_add(json_object* detail_json, const char* setting_value) {
  json_object *setting = json_object_new_object();
  json_object_object_add(detail_json, JSON_ALERT_APP_MISCONFIGURATION_SETTING, setting);
  json_object *setting_obj = json_object_new_object();
  json_object_object_add(setting, setting_value, setting_obj);
  return setting_obj;
}

json_object* AlertsWriter::json_threshold_cross(const char *alarmable,
    const char *op, u_long value, u_long threshold) {
  json_object *detail = json_object_new_object();
  json_object_object_add(detail, "alarmable", json_object_new_string(alarmable));
  json_object_object_add(detail, "operator", json_object_new_string(op));
  json_object_object_add(detail, "value", json_object_new_int64(value));
  json_object_object_add(detail, "threshold", json_object_new_int64(threshold));
  return detail;
}

/* Subject builders */

json_object* AlertsWriter::json_interface_subject() {
  json_object *interface_subject = json_object_new_object();
  return interface_subject;
}

json_object* AlertsWriter::json_flow_subject(Flow *flow_obj) {
  json_object *flow_subject = json_object_new_object();
  json_object *flow = json_flow(flow_obj);
  json_object_object_add(flow_subject, "flow", flow);
  return flow_subject;
}

json_object* AlertsWriter::json_network_subject(const char *cidr) {
  json_object *network_subject = json_object_new_object();
  json_object *network = json_network(cidr);
  json_object_object_add(network_subject, "network", network);
  return network_subject;
}

json_object* AlertsWriter::json_host_subject(Host *host_obj) {
  json_object *host_subject = json_object_new_object();
  json_object *host = json_host(host_obj);
  json_object_object_add(host_subject, "host", host);
  return host_subject;
}

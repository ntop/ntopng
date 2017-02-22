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

json_object* AlertsBuilder::json_generic_alert(AlertLevel severity, time_t start_time) {
  const char *level = "";

  switch(severity) {
    case alert_level_error:   level = "error";   break;
    case alert_level_warning: level = "warning"; break;
    case alert_level_info:    level = "info";    break;
    default:
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown alert severity %d", severity);
  }

  json_object *alert = json_object_new_object();
  json_object_object_add(alert, "id", json_object_new_int64(next_alert_id++));
  json_object_object_add(alert, "timestampStart", json_object_new_int64(start_time));
  json_object_object_add(alert, "severity", json_object_new_string(level));
  return alert;
}

json_object* AlertsBuilder::json_interface(NetworkInterface *iface) {
  json_object *iface_json = json_object_new_object();
  json_object_object_add(iface_json, "id", json_object_new_int64(iface->get_id()));
  json_object_object_add(iface_json, "name", json_object_new_string(iface->get_name()));
  return iface_json;
}

json_object* AlertsBuilder::json_flow(Flow *flow) {
  return flow->flow2alert();
}

json_object* AlertsBuilder::json_network(const char *cidr) {
  json_object *network_json = json_object_new_object();
  json_object_object_add(network_json, "cidr", json_object_new_string(cidr));
  return network_json;
}

json_object* AlertsBuilder::json_protocol(ndpi_protocol proto, const char *name) {
  json_object *proto_json = json_object_new_object();

  json_object_object_add(proto_json, "name", json_object_new_string(name));
  json_object_object_add(proto_json, "master", json_object_new_int64(proto.master_protocol));
  json_object_object_add(proto_json, "sub", json_object_new_int64(proto.protocol));
  return proto_json;
}

json_object* AlertsBuilder::json_ip(IpAddress *ip) {
  char buf[64];
  char *ip_str;

  json_object* json = json_object_new_object();
  ip_str = ip->print(buf, sizeof(buf));

  json_object_object_add(json, ip->isIPv4() ? "ipv4" : "ipv6", json_object_new_string(ip_str));
  return json;
}

json_object* AlertsBuilder::json_host(Host *host) {
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

/* Utility methods */
json_object* AlertsBuilder::json_subject(json_object *alert, const char *subject_name) {
  json_object *subject_obj = json_object_new_object();
  json_object_object_add(alert, "subject", subject_obj);
  json_object *subject = json_object_new_object();
  json_object_object_add(subject_obj, subject_name, subject);
  return subject;
}

json_object* AlertsBuilder::json_detail(json_object *subject, const char *detail_name) {
  json_object *detail_obj = json_object_new_object();
  json_object_object_add(subject, "detail", detail_obj);
  json_object *detail = json_object_new_object();
  json_object_object_add(detail_obj, detail_name, detail);
  return detail;
}

AlertsBuilder::AlertsBuilder(u_long start_id) {
  next_alert_id = start_id;
}

/* Main builder */
json_object* AlertsBuilder::json_alert(AlertLevel severity, NetworkInterface *iface, time_t start_time) {
  json_object *alert = json_generic_alert(severity, start_time);
  json_object_object_add(alert, "interface", json_interface(iface));
  return alert;
}

json_object* AlertsBuilder::json_alert_ends(json_object *alert, time_t end_time) {
  json_object_object_add(alert, JSON_ALERT_TIMESTAMP_END, json_object_new_int64(end_time));
  return alert;
}

json_object* AlertsBuilder::json_alert_set_vlan(json_object *alert, u_int16_t vlan_id) {
  json_object_object_add(alert, "vlan", json_object_new_int64(vlan_id));
  return alert;
}

/* Details builders */
json_object* AlertsBuilder::json_interface_detail(json_object *alert, const char *detail_name) {
  json_object *interface_subject = json_subject(alert, "interfaceAlert");
  return json_detail(interface_subject, detail_name);
}

json_object* AlertsBuilder::json_flow_detail(json_object *alert, Flow *flow_obj, const char *detail_name) {
  json_object *startTime;

  if(json_object_object_get_ex(alert, "timestampStart", &startTime))
    json_alert_ends(alert, json_object_get_int64(startTime));
  else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "No start timestamp found");

  json_object *flow_subject = json_subject(alert, "flowAlert");
  if (flow_obj != NULL) {
    json_object *flow = json_flow(flow_obj);
    json_object_object_add(flow_subject, "flow", flow);
  }
  return json_detail(flow_subject, detail_name);
}

json_object* AlertsBuilder::json_network_detail(json_object *alert, const char *cidr, const char *detail_name) {
  json_object *network_subject = json_subject(alert, "networkAlert");
  json_object *network = json_network(cidr);
  json_object_object_add(network_subject, "network", network);
  return json_detail(network_subject, detail_name);
}

json_object* AlertsBuilder::json_host_detail(json_object *alert, Host *host_obj, const char *detail_name) {
  json_object *host_subject = json_subject(alert, "hostAlert");
  json_object *host = json_host(host_obj);
  json_object_object_add(host_subject, "host", host);
  return json_detail(host_subject, detail_name);
}

/* generic wrt alert_entity */
json_object* AlertsBuilder::json_entity_detail(json_object *alert, AlertEntity alert_entity,
        const char *alert_entity_value, const char *detail_name,
        NetworkInterface *iface) {
  json_object *detail;
  alert_entity_value = alert_entity_value ? alert_entity_value : "";

  switch (alert_entity) {
    case alert_entity_interface:
      detail = json_interface_detail(alert, detail_name);
      break;
    case alert_entity_network:
      detail = json_network_detail(alert, alert_entity_value, detail_name);
      break;
    case alert_entity_flow:
      detail = json_flow_detail(alert, NULL, detail_name);
      break;
    case alert_entity_host: {
      char *host_ip;
      u_int16_t vlan_id = 0;
      char buf[64];
      Host *host;

      Utils::getHostVlanInfo((char*)alert_entity_value, &host_ip, &vlan_id, buf, sizeof(buf));
      host = iface->getHost(host_ip, vlan_id);
      if (host != NULL)
        detail = json_host_detail(alert, host, detail_name);
      else
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Null host %s %s@%d", alert_entity_value, host_ip, vlan_id);
      break;
    } default:
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unsupported entity %d = %s", alert_entity, alert_entity_value);
  }

  if (! detail)
    detail = json_detail(alert, detail_name);

  return detail;
}

/* Detail specific */
json_object* AlertsBuilder::json_threshold_cross_detail(json_object *alert, AlertEntity alert_entity,
        const char *alert_entity_value, NetworkInterface *iface) {
  json_object *detail = json_entity_detail(alert, alert_entity, alert_entity_value, JSON_ALERT_DETAIL_THRESHOLD_CROSS, iface);
  return detail;
}

json_object* AlertsBuilder::json_threshold_cross_fill(json_object *detail, const char *allarmable, u_long threshold) {
  json_object_object_add(detail, "alarmable", json_object_new_string(allarmable));
  json_object_object_add(detail, "threshold", json_object_new_int64(threshold));
  return detail;
}

json_object* AlertsBuilder::json_app_misconfiguration_fill(json_object *detail, const char *setting) {
  json_object_object_add(detail, "setting", json_object_new_string(setting));
  return detail;
}

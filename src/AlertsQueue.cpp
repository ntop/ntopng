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

/* **************************************************** */

AlertsQueue::AlertsQueue(NetworkInterface *_iface) {
  iface = _iface;
}

/* **************************************************** */

void AlertsQueue::pushAlertJson(AlertType atype, json_object *alert) {
  /* These are mandatory fields, present in all the pushed alerts */
	json_object_object_add(alert, "ifid", json_object_new_int(iface->get_id()));
	json_object_object_add(alert, "alert_type", json_object_new_int(atype));
  json_object_object_add(alert, "alert_tstamp", json_object_new_int64(time(NULL)));

  ntop->getRedis()->rpush(CONST_ALERT_STORE_QUEUE, (char *)json_object_to_json_string(alert), 0 /* No trim */);
}

/* **************************************************** */

void AlertsQueue::pushOutsideDhcpRangeAlert(u_char *cli_mac, Mac *sender_mac,
    u_int32_t ip, u_int32_t router_ip, int vlan_id) {
  json_object *jobject = json_object_new_object();

  if(jobject) {
    char cli_mac_s[32], sender_mac_s[32];
    char ipbuf[64], router_ip_buf[64], *ip_s, *router_ip_s;

    Utils::formatMac(cli_mac, cli_mac_s, sizeof(cli_mac_s));
    sender_mac->print(sender_mac_s, sizeof(cli_mac_s));
    ip_s = Utils::intoaV4(ip, ipbuf, sizeof(ipbuf));
    router_ip_s = Utils::intoaV4(router_ip, router_ip_buf, sizeof(router_ip_buf));

    ntop->getTrace()->traceEvent(TRACE_INFO, "IP not in DHCP range: %s (mac=%s, sender=%s, router=%s)",
				       ipbuf, cli_mac_s, sender_mac_s, router_ip_s);

    json_object_object_add(jobject, "client_mac", json_object_new_string(cli_mac_s));
    json_object_object_add(jobject, "sender_mac", json_object_new_string(sender_mac_s));
    json_object_object_add(jobject, "client_ip", json_object_new_string(ip_s));
    json_object_object_add(jobject, "router_ip", json_object_new_string(router_ip_s));
    json_object_object_add(jobject, "vlan_id", json_object_new_int(vlan_id));

    pushAlertJson(misconfigured_dhcp_range, jobject);
    json_object_put(jobject);
  }
}

/* **************************************************** */

void AlertsQueue::pushSlowPeriodicActivity(u_long msec_diff,
    u_long max_duration_ms, const char *activity_path) {
  json_object *jobject = json_object_new_object();

  if(jobject) {
    json_object_object_add(jobject, "duration_ms", json_object_new_int64(msec_diff));
    json_object_object_add(jobject, "max_duration_ms", json_object_new_int64(max_duration_ms));
    json_object_object_add(jobject, "path", json_object_new_string(activity_path));

    pushAlertJson(slow_periodic_activity, jobject);
    json_object_put(jobject);
  }
}

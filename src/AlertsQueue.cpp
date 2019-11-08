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

void AlertsQueue::pushAlertJson(const char *atype, json_object *alert) {
  /* These are mandatory fields, present in all the pushed alerts */
  json_object_object_add(alert, "ifid", json_object_new_int(iface->get_id()));
  json_object_object_add(alert, "alert_type", json_object_new_string(atype));
  json_object_object_add(alert, "alert_tstamp", json_object_new_int64(time(NULL)));

  ntop->getRedis()->rpush(CONST_ALERT_STORE_QUEUE, (char *)json_object_to_json_string(alert), 1024 /* Trim */);
}

/* **************************************************** */

void AlertsQueue::pushOutsideDhcpRangeAlert(u_int8_t *cli_mac, Mac *sender_mac,
    u_int32_t ip, u_int32_t router_ip, int vlan_id) {
  json_object *jobject;

  if(ntop->getPrefs()->are_alerts_disabled())
    return;

  if((jobject = json_object_new_object())) {
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

    pushAlertJson("misconfigured_dhcp_range", jobject);
    json_object_put(jobject);
  }
}

/* **************************************************** */

void AlertsQueue::pushSlowPeriodicActivity(u_long msec_diff,
    u_long max_duration_ms, const char *activity_path) {
  json_object *jobject;

  if(ntop->getPrefs()->are_alerts_disabled())
    return;

  if((jobject = json_object_new_object())) {
    json_object_object_add(jobject, "duration_ms", json_object_new_int64(msec_diff));
    json_object_object_add(jobject, "max_duration_ms", json_object_new_int64(max_duration_ms));
    json_object_object_add(jobject, "path", json_object_new_string(activity_path));

    pushAlertJson("slow_periodic_activity", jobject);
    json_object_put(jobject);
  }
}

/* **************************************************** */

void AlertsQueue::pushMacIpAssociationChangedAlert(u_int32_t ip, u_int8_t *old_mac, u_int8_t *new_mac) {
  json_object *jobject;

  if(ntop->getPrefs()->are_alerts_disabled())
    return;

  if((jobject = json_object_new_object())) {
    char oldmac_s[32], newmac_s[32], ipbuf[32], *ip_s;

    Utils::formatMac(old_mac, oldmac_s, sizeof(oldmac_s));
    Utils::formatMac(new_mac, newmac_s, sizeof(newmac_s));
    ip_s = Utils::intoaV4(ip, ipbuf, sizeof(ipbuf));

    ntop->getTrace()->traceEvent(TRACE_INFO, "IP %s: modified MAC association %s -> %s",
				       ip_s, oldmac_s, newmac_s);

    json_object_object_add(jobject, "ip", json_object_new_string(ip_s));
    json_object_object_add(jobject, "old_mac", json_object_new_string(oldmac_s));
    json_object_object_add(jobject, "new_mac", json_object_new_string(newmac_s));

    pushAlertJson("mac_ip_association_change", jobject);
    json_object_put(jobject);
  }
}

/* **************************************************** */

void AlertsQueue::pushBroadcastDomainTooLargeAlert(const u_int8_t *src_mac, const u_int8_t *dst_mac,
    u_int32_t spa, u_int32_t tpa, int vlan_id) {
  json_object *jobject;

  if(ntop->getPrefs()->are_alerts_disabled())
    return;

  if((jobject = json_object_new_object())) {
    char src_mac_s[32], dst_mac_s[32], spa_buf[32], tpa_buf[32];
    char *spa_s, *tpa_s;

    Utils::formatMac(src_mac, src_mac_s, sizeof(src_mac_s));
    Utils::formatMac(dst_mac, dst_mac_s, sizeof(dst_mac_s));
    spa_s = Utils::intoaV4(spa, spa_buf, sizeof(spa_buf));
    tpa_s = Utils::intoaV4(tpa, tpa_buf, sizeof(tpa_buf));

    json_object_object_add(jobject, "vlan_id", json_object_new_int(vlan_id));
    json_object_object_add(jobject, "src_mac", json_object_new_string(src_mac_s));
    json_object_object_add(jobject, "dst_mac", json_object_new_string(dst_mac_s));
    json_object_object_add(jobject, "spa", json_object_new_string(spa_s));
    json_object_object_add(jobject, "tpa", json_object_new_string(tpa_s));

    pushAlertJson("broadcast_domain_too_large", jobject);
    json_object_put(jobject);
  }
}

/* **************************************************** */

void AlertsQueue::pushRemoteToRemoteAlert(Host *host) {
  json_object *jobject;

  if(ntop->getPrefs()->are_alerts_disabled())
    return;

  if((jobject = json_object_new_object())) {
    char ipbuf[64], macbuf[32];

    json_object_object_add(jobject, "host", json_object_new_string(host->get_ip()->print(ipbuf, sizeof(ipbuf))));
    json_object_object_add(jobject, "vlan", json_object_new_int(host->get_vlan_id()));
    json_object_object_add(jobject, "mac_address", json_object_new_string(host->getMac() ? host->getMac()->print(macbuf, sizeof(macbuf)) : ""));

    pushAlertJson("remote_to_remote", jobject);
    json_object_put(jobject);
  }
}

/* **************************************************** */

void AlertsQueue::pushLoginTrace(const char*user, bool authorized) {
  json_object *jobject;

  if(ntop->getPrefs()->are_alerts_disabled())
    return;

  if((jobject = json_object_new_object())) {
    json_object_object_add(jobject, "scope", json_object_new_string("login"));
    json_object_object_add(jobject, "user", json_object_new_string(user));

    pushAlertJson(authorized ? "user_activity" : "login_failed", jobject);
    json_object_put(jobject);
  }
}

/* **************************************************** */

void AlertsQueue::pushNfqFlushedAlert(int queue_len, int queue_len_pct, int queue_dropped) {
  json_object *jobject;

  if(ntop->getPrefs()->are_alerts_disabled())
    return;

  if((jobject = json_object_new_object())) {
    json_object_object_add(jobject, "tot",     json_object_new_int(queue_len));
    json_object_object_add(jobject, "pct",     json_object_new_int(queue_len_pct));
    json_object_object_add(jobject, "dropped", json_object_new_int(queue_dropped));

    pushAlertJson("nfq_flushed", jobject);
    json_object_put(jobject);
  }
}

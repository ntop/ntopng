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

#ifndef _ALERTS_BUILDER_H_
#define _ALERTS_BUILDER_H_

#include "ntop_includes.h"

/* Generic */
#define JSON_ALERT_DETAIL_THRESHOLD_CROSS "thresholdCross"

/* Host */
#define JSON_ALERT_DETAIL_HOST_BLACKLISTED "hostBlacklisted"
#define JSON_ALERT_DETAIL_FLOW_FLOOD_ATTACKER "flowFloodAttacker"
#define JSON_ALERT_DETAIL_FLOW_FLOOD_VICTIM "flowFloodVictim"
#define JSON_ALERT_DETAIL_SYN_FLOOD_ATTACKER "synFloodAttacker"
#define JSON_ALERT_DETAIL_SYN_FLOOD_VICTIM "synFloodVictim"
#define JSON_ALERT_DETAIL_FLOW_LOW_GOODPUT_ATTACKER "flowLowGoodputAttacker"
#define JSON_ALERT_DETAIL_FLOW_LOW_GOODPUT_VICTIM "flowLowGoodputVictim"

/* Interface */
#define JSON_ALERT_DETAIL_APP_MISCONFIGURATION "appMisconfiguration"
#define JSON_ALERT_DETAIL_APP_MISCONFIGURATION_FLOWS "numFlows"
#define JSON_ALERT_DETAIL_APP_MISCONFIGURATION_ALERTS "numAlerts"

/* Flow */
#define JSON_ALERT_DETAIL_FLOW_PROBING "flowProbing"
#define JSON_ALERT_DETAIL_FLOW_BLACKLISTED_HOSTS "flowBlacklistedHosts"
#define JSON_ALERT_DETAIL_FLOW_MALWARE_SITE "flowMalwareSite"

class AlertsBuilder {
  private:
    u_long next_alert_id;

  protected:
    json_object* json_generic_alert(AlertLevel severity, time_t start_time);
    json_object* json_interface(NetworkInterface *iface);
    json_object* json_detail(json_object *subject, const char *detail_name);
    json_object* json_subject(json_object *alert, const char *subject_name);

  public:
    AlertsBuilder(u_long start_id);

    /* Types */
    json_object* json_flow(Flow *flow);
    json_object* json_network(const char *cidr);
    json_object* json_host(Host *host);

    /* Exposed API */
    json_object* json_alert(AlertLevel severity, NetworkInterface *iface, time_t start_time);
    json_object* json_alert_ends(json_object *alert, time_t end_time);
    json_object* json_alert_set_vlan(json_object *alert, u_int16_t vlan_id);

    json_object* json_interface_detail(json_object *alert, const char *detail_name);
    json_object* json_flow_detail(json_object *alert, Flow *flow_obj, const char *detail_name);
    json_object* json_network_detail(json_object *alert, const char *cidr, const char *detail_name);
    json_object* json_host_detail(json_object *alert, Host *host_obj, const char *detail_name);

    json_object* json_entity_detail(json_object *alert, AlertEntity alert_entity,
            const char *alert_entity_value, const char *detail_name,
            NetworkInterface *iface);

    /* Specific */
    json_object* json_threshold_cross_detail(json_object *alert, AlertEntity alert_entity,
            const char *alert_entity_value, NetworkInterface *iface);
    json_object* json_threshold_cross_fill(json_object *detail, const char *allarmable, u_long threshold);

    json_object* json_app_misconfiguration_fill(json_object *detail, const char *setting);
};

#endif

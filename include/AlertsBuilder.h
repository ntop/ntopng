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

/* SUBJECTS */
#define JSON_ALERT_SUBJECT "subject"
#define JSON_ALERT_SUBJECT_HOST "hostAlert"
#define JSON_ALERT_SUBJECT_INTERFACE "interfaceAlert"
#define JSON_ALERT_SUBJECT_NETWORK "networkAlert"
#define JSON_ALERT_SUBJECT_FLOW "flowAlert"

/* Alert Keys */
#define ALERT_KEY_HOST_SCAN_ATTACKER "scan_attacker"
#define ALERT_KEY_HOST_SCAN_VICTIM "scan_victim"
#define ALERT_KEY_HOST_ABOVE_QUOTA "above_quota"
#define ALERT_KEY_INTERFACE_APP_MISCONFIGURATION "app_misconfiguration"

/* Generic */
#define JSON_ALERT_DETAIL "detail"
#define JSON_ALERT_DETAIL_THRESHOLD_CROSS "thresholdCross"
#define JSON_ALERT_TIMESTAMP_END "timestampEnd"
#define JSON_ALERT_DETAIL_ABOVE_QUOTA "aboveQuota"
#define JSON_ALERT_DETAIL_TOO_MANY_ALERTS "tooManyAlerts"

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

class AlertsManager;
class Flow;

class AlertsBuilder {
  /* TODO needed for dumpFlowAlert */
  friend class Flow;

  static Mutex mutex;
  static u_long next_alert_id;

  private:
    AlertsManager *am;

    /* Base */
    static json_object* json_generic_alert(AlertLevel severity, time_t start_time);

    /* Types */
    static json_object* json_interface(NetworkInterface *iface);
    static json_object* json_flow(Flow *flow);
    static json_object* json_network(const char *cidr);
    static json_object* json_host(Host *host);
    static json_object* json_protocol(ndpi_protocol proto, const char *name);
    static json_object* json_ip(IpAddress *ip);

    /* Subjects */
    static json_object* json_interface_subject();
    static json_object* json_flow_subject(Flow *flow_obj);
    static json_object* json_network_subject(const char *cidr);
    static json_object* json_host_subject(Host *host_obj);

    /* Utility */
    static json_object* json_alert(AlertLevel severity, NetworkInterface *iface, time_t start_time);
    static json_object* json_alert_ends(json_object *alert, time_t end_time);
    static json_object* json_alert_set_vlan(json_object *alert, u_int16_t vlan_id);
    static json_object* json_subject_add(json_object *alert, json_object *subject, const char *subject_value);
    static json_object* json_detail_add(json_object *subject, json_object *detail, const char *detail_value);
    static json_object* json_app_misconfiguration_setting_add(json_object* detail_json, const char* setting_value);

    static json_object* json_threshold_cross(const char *alarmable,
        const char *op, u_long value, u_long threshold);

    char* attack_host_alert(const char *alert_key, Host *host, Host *attacker, Host *victim,
        u_int32_t current_hits, u_int32_t duration);

  protected:
    char* complex_interface_alert(const char *alert_key, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name);

    char* simple_interface_alert(const char *alert_key, const AlertType type, const AlertLevel severity,
        const char *detail_name);

    char* complex_host_alert(const char *alert_key, Host *host, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name, Host *source, Host *target);

    char* simple_host_alert(const char *alert_key, Host *host, const AlertType type, const AlertLevel severity,
        const char *detail_name);

    char* complex_network_alert(const char *alert_key, const char *network, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name);

    char* simple_network_alert(const char *alert_key, const char *network, const AlertType type, const AlertLevel severity,
        const char *detail_name);

    char* complex_flow_alert(Flow *flow, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name);

    char* simple_flow_alert(Flow *flow, const AlertType type, const AlertLevel severity,
        const char *detail_name);

  public:
    AlertsBuilder(AlertsManager *am);
    static void setStartingAlertId(u_long alert_id);

    /* Flow Alerts */
    char* createFlowProbing(Flow *flow, AlertType probingType);

    char* createFlowBlacklistedHosts(Flow *flow);

    char* createFlowAlertedInterface(Flow *flow);

    char* createFlowTooManyAlerts(Flow *flow);

    /* Interface Alerts */
    char* createInterfaceThresholdCross(const char *alert_key,
        const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold);

    char* createInterfaceTooManyAlerts(const char *alert_key);

    char* createInterfaceTooManyFlows(const char *alert_key);

    char* createInterfaceTooManyHosts(const char *alert_key);

    char* createInterfaceTooManyOpenFiles(const char *alert_key);

    /* Network Alerts */
    char* createNetworkThresholdCross(const char *alert_key, const char *network,
        const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold);

    char* createNetworkTooManyAlerts(const char *alert_key, const char *network);

    /* Host Alerts */
    char* createHostThresholdCross(const char *alert_key, Host *host,
        const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold);

    char* createHostTooManyAlerts(const char *alert_key, Host *host);

    char* createHostAboveQuota(const char *alert_key, Host *host);

    char* createHostBlacklisted(const char *alert_key, Host *host);

    char* createHostSynFloodAttacker(const char *alert_key, Host *host,
        Host *victim, u_int32_t current_hits, u_int32_t duration);

    char* createHostSynFloodVictim(const char *alert_key, Host *host,
        Host *attacker, u_int32_t current_hits, u_int32_t duration);

    char* createHostFlowFloodAttacker(const char *alert_key, Host *host);

    char* createHostFlowFloodVictim(const char *alert_key, Host *host);
};

#endif

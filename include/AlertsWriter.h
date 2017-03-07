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

#ifndef _ALERTS_WRITER_H_
#define _ALERTS_WRITER_H_

#include "ntop_includes.h"

class AlertsManager;
class Flow;

class AlertsWriter {
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
    static json_object* json_alert_set_vlan(json_object *alert, u_int16_t vlan_id);
    static json_object* json_subject_add(json_object *alert, json_object *subject, const char *subject_value);
    static json_object* json_detail_add(json_object *subject, json_object *detail, const char *detail_value);
    static json_object* json_app_misconfiguration_setting_add(json_object* detail_json, const char* setting_value);

    static json_object* json_threshold_cross(const char *alarmable,
        const char *op, u_long value, u_long threshold);

    char* attack_host_alert(const char *alert_key, Host *host, Host *attacker, Host *victim,
        u_int32_t current_hits, u_int32_t duration);

    char* simple_host_alert(const char *alert_key, Host *host, const AlertType type, const AlertLevel severity,
        const char *detail_name);

  public:
    AlertsWriter(AlertsManager *am);
    static void setStartingAlertId(u_long alert_id);

    static json_object* json_alert_ends(json_object *alert, time_t end_time);

    /* Generic methods */

    /**
     * @brief Create an interface alert.
     * @details A generic function to engage/store an alert for an interface.
     *
     * @param alert_key if NULL, a stored alert will be generated. If not NULL, it will be used as a key to identify an engaged alert internally.
     * @param type internal type of the alert for categorization.
     * @param severity internal severity of the alert.
     * @param detail a JSON object with an alert specific structure.
     * @param detail_name a unique string to indentify the specific alert in JSON.
     *
     * @return a JSON string representing the alert. It is up to the caller to free the returned string.
     */
    char* createGenericInterfaceAlert(const char *alert_key, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name);

    /**
     * @brief Create an host alert.
     * @details A generic function to engage/store an alert for an host.
     *
     * @param alert_key if NULL, a stored alert will be generated. If not NULL, it will be used as a key to identify an engaged alert internally.
     * @param host pointer to an Host object, which is the subject of the alert.
     * @param type internal type of the alert for categorization.
     * @param severity internal severity of the alert.
     * @param detail a JSON object with an alert specific structure.
     * @param detail_name a unique string to indentify the specific alert in JSON.
     * @param source a pointer to the logical source of the alert, NULL if there is no associated alert source.
     * @param target a pointer to the logical target of the alert, NULL if there is no associated alert target.
     *
     * @return a JSON string representing the alert. It is up to the caller to free the returned string.
     */
    char* createGenericHostAlert(const char *alert_key, Host *host, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name, Host *source, Host *target);

    /**
     * @brief Create a network alert.
     * @details A generic function to engage/store an alert for a local network.
     *
     * @param alert_key if NULL, a stored alert will be generated. If not NULL, it will be used as a key to identify an engaged alert internally.
     * @param network a network in the CIDR notation, which is the subject of the alert.
     * @param type internal type of the alert for categorization.
     * @param severity internal severity of the alert.
     * @param detail a JSON object with an alert specific structure.
     * @param detail_name a unique string to indentify the specific alert in JSON.
     *
     * @return a JSON string representing the alert. It is up to the caller to free the returned string.
     */
    char* createGenericNetworkAlert(const char *alert_key, const char *network, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name);

    /**
     * @brief Create a flow alert.
     * @details A generic function to store an alert for a flow.
     *
     * @param flow a pointer to a Flow object, which is the subject of the alert.
     * @param type internal type of the alert for categorization.
     * @param severity internal severity of the alert.
     * @param detail a JSON object with an alert specific structure.
     * @param detail_name a unique string to indentify the specific alert in JSON.
     *
     * @return a JSON string representing the alert. It is up to the caller to free the returned string.
     */
    char* createGenericFlowAlert(Flow *flow, const AlertType type, const AlertLevel severity,
        json_object *detail, const char *detail_name);

    /* Flow Alerts */
    char* storeFlowProbing(Flow *flow, FlowStatus flow_status);

    char* storeFlowBlacklistedHosts(Flow *flow);

    char* storeFlowAlertedInterface(Flow *flow);

    /* Interface Alerts */
    char* engageInterfaceThresholdCross(const char *time_period,
        const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold);
    char* releaseInterfaceThresholdCross(const char *time_period, const char *alarmable);

    char* storeInterfaceTooManyAlerts();

    char* storeInterfaceTooManyFlowAlerts();

    char* storeInterfaceTooManyFlows();

    char* storeInterfaceTooManyHosts();

    char* engageInterfaceTooManyOpenFiles();
    char* releaseInterfaceTooManyOpenFiles();

    /* Network Alerts */
    char* engageNetworkThresholdCross(const char *time_period, const char *network,
        const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold);
    char* releaseNetworkThresholdCross(const char *time_period, const char *network, const char *alarmable);

    char* storeNetworkTooManyAlerts(const char *network);

    /* Host Alerts */
    char* engageHostThresholdCross(const char *time_period, Host *host,
        const char *alarmable, const char *op, u_int32_t value, u_int32_t threshold);
    char* releaseHostThresholdCross(const char *time_period, Host *host, const char *alarmable);

    char* storeHostTooManyAlerts(Host *host);

    char* storeHostAboveQuota(Host *host);

    char* storeHostBlacklisted(Host *host);

    char* storeHostSynFloodAttacker(Host *host,
        Host *victim, u_int32_t current_hits, u_int32_t duration);

    char* storeHostSynFloodVictim(Host *host,
        Host *attacker, u_int32_t current_hits, u_int32_t duration);

    char* engageHostFlowFloodAttacker(Host *host);
    char* releaseHostFlowFloodAttacker(Host *host);

    char* engageHostFlowFloodVictim(Host *host);
    char* releaseHostFlowFloodVictim(Host *host);
};

#endif

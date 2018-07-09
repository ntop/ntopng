--
-- (C) 2018 - ntop.org
--
-- This file contains the alert constats

local alert_consts = {}
local locales_utils = require "locales_utils"
local format_utils  = require "format_utils"

-- Alerts (see ntop_typedefs.h)
-- each table entry is an array as:
-- {"alert html string", "alert C enum value", "plain string"}
alert_consts.alert_severity_keys = {
   { "<span class='label label-info'>" .. i18n("alerts_dashboard.none") .. "</span>",      -1, "none"    },
   { "<span class='label label-info'>" .. i18n("alerts_dashboard.info") .. "</span>",       0, "info"    },
   { "<span class='label label-warning'>" .. i18n("alerts_dashboard.warning") .. "</span>", 1, "warning" },
   { "<span class='label label-danger'>" .. i18n("alerts_dashboard.error") .. "</span>",    2, "error"   }
}

alert_consts.alert_type_keys = {
   { "<i class='fa fa-ok'></i> " .. i18n("alerts_dashboard.no_alert"),                             -1, "alert_none"                 },
   { "<i class='fa fa-life-ring'></i> " .. i18n("alerts_dashboard.tcp_syn_flood"),                  0, "tcp_syn_flood"              },
   { "<i class='fa fa-life-ring'></i> " .. i18n("alerts_dashboard.flows_flood"),                    1, "flows_flood"                },
   { "<i class='fa fa-arrow-circle-up'></i> " .. i18n("alerts_dashboard.threashold_cross"),         2, "threshold_cross"            },
   { "<i class='fa fa-exclamation'></i> " .. i18n("alerts_dashboard.suspicious_activity"),          3, "suspicious_activity"        },
   { "<i class='fa fa-exclamation'></i> " .. i18n("alerts_dashboard.interface_alerted"),            4, "interface_alerted"          },
   { "<i class='fa fa-exclamation'></i> " .. i18n("alerts_dashboard.flow_misbehaviour"),            5, "flow_misbehaviour"          },
   { "<i class='fa fa-exclamation'></i> " .. i18n("alerts_dashboard.remote_to_remote_flow"),        6, "flow_remote_to_remote"      },
   { "<i class='fa fa-exclamation'></i> " .. i18n("alerts_dashboard.blacklisted_flow"),             7, "flow_blacklisted"           },
   { "<i class='fa fa-ban'></i> " .. i18n("alerts_dashboard.blocked_flow"),                         8, "flow_blocked"               },
   { "<i class='fa fa-asterisk'></i> " .. i18n("alerts_dashboard.new_device"),                      9, "new_device"                 },
   { "<i class='fa fa-sign-in'></i> " .. i18n("alerts_dashboard.device_connection"),               10, "device_connection"          },
   { "<i class='fa fa-sign-out'></i> " .. i18n("alerts_dashboard.device_disconnection"),           11, "device_disconnection"       },
   { "<i class='fa fa-sign-in'></i> " .. i18n("alerts_dashboard.host_pool_connection"),            12, "host_pool_connection"       },
   { "<i class='fa fa-sign-out'></i> " .. i18n("alerts_dashboard.host_pool_disconnection"),        13, "host_pool_disconnection"    },
   { "<i class='fa fa-thermometer-full'></i> " .. i18n("alerts_dashboard.quota_exceeded"),         14, "quota_exceeded"             },
   { "<i class='fa fa-cog'></i> " .. i18n("alerts_dashboard.misconfigured_app"),                   15, "misconfigured_app"          },
   { "<i class='fa fa-tint'></i> " .. i18n("alerts_dashboard.too_many_drops"),                     16, "too_many_drops"             },
   { "<i class='fa fa-exchange'></i> " .. i18n("alerts_dashboard.mac_ip_association_change"),      17, "mac_ip_association_change"  },
   { "<i class='fa fa-exclamation'></i> " .. i18n("alerts_dashboard.snmp_port_status_change"),     18, "port_status_change"         },
   { "<i class='fa fa-exclamation'></i> " .. i18n("alerts_dashboard.unresponsive_device"),         19, "unresponsive_device"        },
   { "<i class='fa fa-truck'></i> " .. i18n("alerts_dashboard.process"),                           20, "process_notification"       },
   { "<i class='fa fa-bitcoin'></i> " .. i18n("alerts_dashboard.web_mining"),                      21, "web_mining"                 },
   { "<i class='fa fa-angle-double-down'></i> " .. i18n("alerts_dashboard.nfq_flushed"),           22, "nfq_flushed"                },
}

-- Keep in sync with ntop_typedefs.h:AlertEntity
alert_consts.alert_entity_keys = {
   { "Interface",       0, "interface"     },
   { "Host",            1, "host"          },
   { "Network",         2, "network"       },
   { "SNMP device",     3, "snmp_device"   },
   { "Flow",            4, "flow"          },
   { "Device",          5, "mac"           },
   { "Host Pool",       6, "host_pool"     },
   { "Process",         7, "process"       },
}

alert_consts.alert_engine_keys = {
   {i18n("show_alerts.minute"),       0, "min"    },
   {i18n("show_alerts.five_minutes"), 1, "5mins"  },
   {i18n("show_alerts.hourly"),       2, "hour"   },
   {i18n("show_alerts.daily"),        3, "day"    },
}

-- Note: keep in sync with alarmable_metrics and alert_functions_infoes
alert_consts.alert_functions_description = {
   ["active"]  = i18n("alerts_thresholds_config.alert_active_description"),
   ["bytes"]   = i18n("alerts_thresholds_config.alert_bytes_description"),
   ["dns"]     = i18n("alerts_thresholds_config.alert_dns_description"),
   ["idle"]    = i18n("alerts_thresholds_config.alert_idle_description"),
   ["packets"] = i18n("alerts_thresholds_config.alert_packets_description"),
   ["p2p"]     = i18n("alerts_thresholds_config.alert_p2p_description"),
   ["throughput"]   = i18n("alerts_thresholds_config.alert_throughput_description"),
   ["flows"]   = i18n("alerts_thresholds_config.alert_flows_description"),
}

alert_consts.iface_alert_functions_description = {
   ["active_local_hosts"] = i18n("alerts_thresholds_config.active_local_hosts_threshold_descr"),
}

alert_consts.network_alert_functions_description = {
   ["ingress"] = i18n("alerts_thresholds_config.alert_network_ingress_description"),
   ["egress"]  = i18n("alerts_thresholds_config.alert_network_egress_description"),
   ["inner"]   = i18n("alerts_thresholds_config.alert_network_inner_description"),
}

-- ################################################################################

alert_consts.alerts_granularity = {
   { "min", i18n("alerts_thresholds_config.every_minute"), 60 },
   { "5mins", i18n("alerts_thresholds_config.every_5_minutes"), 300 },
   { "hour", i18n("alerts_thresholds_config.hourly"), 3600 },
   { "day", i18n("alerts_thresholds_config.daily"), 86400 }
}

alert_consts.alarmable_metrics = {'bytes', 'dns', 'active', 'idle', 'packets', 'p2p', 'throughput',
				  'ingress', 'egress', 'inner',
				  'flows'}

alert_consts.alert_functions_info = {
   ["active"] = {
      label = i18n("alerts_thresholds_config.activity_time"),
      fmt = format_utils.secondsToTime,
   }, ["bytes"] = {
      label = i18n("traffic"),
      fmt = format_utils.bytesToSize,
   }, ["dns"] = {
      label = i18n("alerts_thresholds_config.dns_traffic"),
      fmt = format_utils.bytesToSize,
   }, ["idle"] = {
      label = i18n("alerts_thresholds_config.idle_time"),
      fmt = format_utils.secondsToTime,
   }, ["packets"] = {
      label = i18n("packets"),
      fmt = format_utils.formatPackets,
   }, ["p2p"] = {
      label = i18n("alerts_thresholds_config.p2p_traffic"),
      fmt = format_utils.bytesToSize,
   }, ["throughput"] = {
      label = i18n("alerts_thresholds_config.throughput"),
      fmt = format_utils.bytesToSize,
   }, ["flows"] = {
      label = i18n("flows"),
      fmt = format_utils.formatFlows,
   }, ["inner"] = {
      label = i18n("alerts_thresholds_config.inner_traffic"),
      fmt = format_utils.bytesToSize
   }, ["ingress"] = {
      label = i18n("alerts_thresholds_config.ingress_traffic"),
      fmt = format_utils.bytesToSize
   }, ["egress"] = {
      label = i18n("alerts_thresholds_config.egress_traffic"),
      fmt = format_utils.bytesToSize
   }, ["active_local_hosts"] = {
      label = i18n("alerts_thresholds_config.active_local_hosts"),
      fmt = format_utils.formatValue
   }
}

return alert_consts

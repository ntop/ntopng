--
-- (C) 2018 - ntop.org
--
-- This file contains the alert constats

local alert_consts = {}
local locales_utils = require "locales_utils"
local format_utils  = require "format_utils"

-- Alerts (see ntop_typedefs.h)
-- each table entry is an array as:
-- {"alert html string", "alert C enum value", "plain string", "syslog severity"}
alert_consts.alert_severities = {
  info = {
    severity_id = 0,
    label = "label-info",
    i18n_title = "alerts_dashboard.info",
    syslog_severity = 6,
  }, warning = {
    severity_id = 1,
    label = "label-warning",
    i18n_title = "alerts_dashboard.warning",
    syslog_severity = 4,
  }, error = {
    severity_id = 2,
    label = "label-danger",
    i18n_title = "alerts_dashboard.error",
    syslog_severity = 3,
  }
}

-- ##############################################

local function formatSynFlood(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   if entity_info.anomalies ~= nil then
      if (alert_key == "syn_flood_attacker") and (entity_info.anomalies.syn_flood_attacker ~= nil) then
	 local anomaly_info = entity_info.anomalies.syn_flood_attacker

	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is a SYN Flooder ("..
	    (anomaly_info.last_trespassed_hits).." SYN sent in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      elseif (alert_key == "syn_flood_victim") and (entity_info.anomalies.syn_flood_victim ~= nil) then
	 local anomaly_info = entity_info.anomalies.syn_flood_victim

	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is under SYN flood attack ("..
	    (anomaly_info.last_trespassed_hits).." SYN received in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      end
   end

   return ""
end

-- ##############################################

local function formatFlowsFlood(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   if entity_info.anomalies ~= nil then
      if (alert_key == "flows_flood_attacker") and (entity_info.anomalies.flows_flood_attacker) then
	 local anomaly_info = entity_info.anomalies.flows_flood_attacker
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is a Flooder ("..
	    (anomaly_info.last_trespassed_hits).." flows sent in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      elseif (alert_key == "flows_flood_victim") and (entity_info.anomalies.flows_flood_victim) then
	 local anomaly_info = entity_info.anomalies.flows_flood_victim
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is under flood attack ("..
	    (anomaly_info.last_trespassed_hits).." flows received in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      end
   end

   return ""
end

-- ##############################################

local function formatAlertEntity(ifid, entity_type, entity_value)
   require "flow_utils"
   local value
   local epoch_begin, epoch_end = getAlertTimeBounds({alert_tstamp = os.time()})

   if entity_type == "host" then
      local host_info = hostkey2hostinfo(entity_value)
      value = resolveAddress(host_info)

      if host_info ~= nil then
	 value = "<a href='"..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifid..
	    "&host="..hostinfo2hostkey(host_info).."&page=historical&epoch_begin="..
	    epoch_begin .."&epoch_end=".. epoch_end .."'>"..value.."</a>"
      end
   elseif entity_type == "interface" then
      value = "<a href='"..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..ifid..
        "&page=historical&epoch_begin="..epoch_begin .."&epoch_end=".. epoch_end ..
        "'>"..getInterfaceName(ifid).."</a>"
   elseif entity_type == "network" then
      value = getLocalNetworkAlias(hostkey2hostinfo(entity_value)["host"])

      value = "<a href='"..ntop.getHttpPrefix().."/lua/network_details.lua?network_cidr="..
        entity_value.."&page=historical&epoch_begin=".. epoch_begin
         .."&epoch_end=".. epoch_end .."'>" ..value.."</a>"
   else
      -- fallback
      value = entity_value
   end

   -- try to get a localized message
   local localized = i18n("alert_messages."..entity_type.."_entity", {entity_value=value})

   if localized ~= nil then
      return localized
   else
      -- fallback
      return entity_type.." "..value
   end
end

-- ##############################################

local function formatThresholdCross(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local engine_label = alertEngineLabel(alertEngine(sec2granularity(alert["alert_periodicity"])))

  return engine_label.." <b>".. threshold_info.metric .."</b> crossed by ".. entity ..
    " ["..threshold_info.value.." &"..(threshold_info.operator).."; "..threshold_info.threshold.."]"
end

-- ##############################################

local function formatMisconfiguredApp(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   if entity_info.anomalies ~= nil then
      if alert_key == "too_many_flows" then
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info))..
	    " has too many flows. Please extend the --max-num-flows/-X command line option"
      elseif alert_key == "too_many_hosts" then
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info))..
	    " has too many hosts. Please extend the --max-num-hosts/-x command line option"
      end
   end

   return ""
end

-- ##############################################

function formatSlowStatsUpdate(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   return "Statistics update on ".. formatAlertEntity(ifid, entity_type, entity_value, entity_info) .. " is too slow."..
      " This could lead to data accuracy loss and missing alerts. Update frequency can be tuned by the "..
      "<a href=\"".. ntop.getHttpPrefix() .."/lua/admin/prefs.lua?tab=in_memory\">".. i18n("prefs.housekeeping_frequency_title") .."</a> preference."
end

-- ##############################################

local function formatTooManyPacketDrops(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   local max_drop_perc = ntop.getPref(getInterfacePacketDropPercAlertKey(getInterfaceName(ifid)))
   if isEmptyString(max_drop_perc) then
      max_drop_perc = CONST_DEFAULT_PACKETS_DROP_PERCENTAGE_ALERT
   end

   return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info))..
      " has too many dropped packets [&gt " .. max_drop_perc .. "%]"
end

-- ##############################################

local function formatActiveFlowsAnomaly(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   if entity_info.anomalies ~= nil then
      if(alert_key == "num_active_flows_as_client") and (entity_info.anomalies.num_active_flows_as_client) then
	 local anomaly_info = entity_info.anomalies.num_active_flows_as_client

	 return string.format("%s has an anomalous number of active client flows [current_flows=%u][anomaly_index=%u]",
	    firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)),
	    anomaly_info.value, anomaly_info.anomaly_index)
      elseif(alert_key == "num_active_flows_as_server") and (entity_info.anomalies.num_active_flows_as_server) then
	 local anomaly_info = entity_info.anomalies.num_active_flows_as_server

	 return string.format("%s has an anomalous number of active server flows [current_flows=%u][anomaly_index=%u]",
	    firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)),
	    anomaly_info.value, anomaly_info.anomaly_index)
      end
   end

   return ""
end

-- ##############################################

local function formatDNSAnomaly(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   -- tprint({ifid =ifid, engine = engine, entity_type = entity_type, entity_value = entity_value, entity_info = entity_info, alert_key = alert_key, alert_info = alert_info})

   if entity_info.anomalies ~= nil then
      for _, v in pairs({"dns.rcvd.num_replies_ok", "dns.rcvd.num_queries", "dns.rcvd.num_replies_error",
			 "dns.sent.num_replies_ok", "dns.sent.num_queries", "dns.sent.num_replies_error"}) do
	 if alert_key == v and entity_info.anomalies[v] then
	    local anomaly_info = entity_info.anomalies[v]

	    local res =  string.format("%s has a DNS anomaly [%s][current=%u][anomaly_index=%u]",
				       firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)),
				       v,
				       anomaly_info.value,
				       anomaly_info.anomaly_index)
	    return res
	 end
      end
   end

   return ""
end

-- ##############################################

local function formatICMPAnomaly(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   -- tprint({ifid =ifid, engine = engine, entity_type = entity_type, entity_value = entity_value, entity_info = entity_info, alert_key = alert_key, alert_info = alert_info})

   if entity_info.anomalies ~= nil then
      for _, v in pairs({"icmp.num_destination_unreachable"}) do
	 if alert_key == v and entity_info.anomalies[v] then
	    local anomaly_info = entity_info.anomalies[v]

	    local res =  string.format("%s has an ICMP anomaly [%s][current=%u][anomaly_index=%u]",
				       firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)),
				       v,
				       anomaly_info.value,
				       anomaly_info.anomaly_index)
	    return res
	 end
      end
   end

   return ""
end

-- ##############################################

-- Keep ID in sync with AlertType
alert_consts.alert_types = {
  tcp_syn_flood = {
    alert_id = 0,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.tcp_syn_flood",
    icon = "fa-life-ring",
    i18n_description = formatSynFlood,
  }, flows_flood = {
    alert_id = 1,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.flows_flood",
    icon = "fa-life-ring",
    i18n_description = formatFlowsFlood,
  }, threshold_cross = {
    alert_id = 2,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.threashold_cross",
    icon = "fa-arrow-circle-up",
    i18n_description = formatThresholdCross,
  }, suspicious_activity = {
    alert_id = 3,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.suspicious_activity",
    icon = "fa-exclamation",
  }, interface_alerted = {
    alert_id = 4,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.interface_alerted",
    icon = "fa-exclamation",
  }, flow_misbehaviour = {
    alert_id = 5,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.flow_misbehaviour",
    icon = "fa-exclamation",
  }, remote_to_remote = {
    alert_id = 6,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.remote_to_remote",
    icon = "fa-exclamation",
  }, flow_blacklisted = {
    alert_id = 7,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.blacklisted_flow",
    icon = "fa-exclamation",
  }, flow_blocked = {
    alert_id = 8,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.blocked_flow",
    icon = "fa-ban",
  }, new_device = {
    alert_id = 9,
    severity = alert_consts.alert_severities.info,
    i18n_title = "alerts_dashboard.new_device",
    icon = "fa-asterisk",
  }, device_connection = {
    alert_id = 10,
    severity = alert_consts.alert_severities.info,
    i18n_title = "alerts_dashboard.device_connection",
    icon = "fa-sign-in",
  }, device_disconnection = {
    alert_id = 11,
    severity = alert_consts.alert_severities.info,
    i18n_title = "alerts_dashboard.device_disconnection",
    icon = "fa-sign-out",
  }, host_pool_connection = {
    alert_id = 12,
    severity = alert_consts.alert_severities.info,
    i18n_title = "alerts_dashboard.host_pool_connection",
    icon = "fa-sign-in",
  }, host_pool_disconnection = {
    alert_id = 13,
    severity = alert_consts.alert_severities.info,
    i18n_title = "alerts_dashboard.host_pool_disconnection",
    icon = "fa-sign-out",
  }, quota_exceeded = {
    alert_id = 14,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.quota_exceeded",
    icon = "fa-thermometer-full",
  }, misconfigured_app = {
    alert_id = 15,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.misconfigured_app",
    icon = "fa-cog",
    i18n_description = formatMisconfiguredApp,
  }, too_many_drops = {
    alert_id = 16,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.too_many_drops",
    icon = "fa-tint",
    i18n_description = formatTooManyPacketDrops,
  }, mac_ip_association_change = {
    alert_id = 17,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.mac_ip_association_change",
    icon = "fa-exchange",
  }, port_status_change = {
    alert_id = 18,
    severity = alert_consts.alert_severities.info,
    i18n_title = "alerts_dashboard.snmp_port_status_change",
    icon = "fa-exclamation",
  }, unresponsive_device = {
    alert_id = 19,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.unresponsive_device",
    icon = "fa-exclamation",
  }, process_notification = {
    alert_id = 20,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.process",
    icon = "fa-truck",
  }, web_mining = {
    alert_id = 21,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.web_mining",
    icon = "fa-bitcoin",
  }, nfq_flushed = {
    alert_id = 22,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.nfq_flushed",
    icon = "fa-angle-double-down",
  }, slow_stats_update = {
    alert_id = 23,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.slow_stats_update",
    icon = "fa-exclamation",
    i18n_description = formatSlowStatsUpdate,
  }, alert_device_protocol_not_allowed = {
    alert_id = 24,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.suspicious_device_protocol",
    icon = "fa-exclamation",
  }, alert_user_activity = {
    alert_id = 25,
    severity = alert_consts.alert_severities.info,
    i18n_title = "alerts_dashboard.user_activity",
    icon = "fa-user",
  }, influxdb_export_failure = {
    alert_id = 26,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.influxdb_export_failure",
    icon = "fa-database",
  }, port_errors = {
    alert_id = 27,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.snmp_port_errors",
    icon = "fa-exclamation",
  }, test_failed = {
    alert_id = 28,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "Test failed",
    icon = "fa-exclamation",
  }, inactivity = {
    alert_id = 29,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.inactivity",
    icon = "fa-exclamation",
  }, active_flows_anomaly = {
    alert_id = 30,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.active_flows_anomaly",
    icon = "fa-life-ring",
    i18n_description = formatActiveFlowsAnomaly,
  }, list_download_failed = {
    alert_id = 31,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.list_download_failed",
    icon = "fa-sticky-note",
  }, dns_anomaly = {
    alert_id = 32,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.dns_anomaly",
    icon = "fa-life-ring",
    i18n_description = formatDNSAnomaly,
  }, icmp_anomaly = {
    alert_id = 33,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.icmp_anomaly",
    icon = "fa-life-ring",
    i18n_description = formatICMPAnomaly,
  }, broadcast_domain_too_large = {
    alert_id = 34,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.broadcast_domain_too_large",
    icon = "fa-sitemap",
  }, ids_alert = {
    alert_id = 35,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.ids_alert",
    icon = "fa-eye",
  }, ip_outsite_dhcp_range = {
    alert_id = 36,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.misconfigured_dhcp_range",
    icon = "fa-exclamation",
  }, port_duplexstatus_change = {
    alert_id = 37,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.snmp_port_duplexstatus_change",
    icon = "fa-exclamation",
  }, port_load_threshold_exceeded = {
    alert_id = 38,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.snmp_port_load_threshold_exceeded",
    icon = "fa-exclamation",
  }, ping_issues = {
    alert_id = 39,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.ping_issues",
    icon = "fa-exclamation",
  }, slow_periodic_activity = {
    alert_id = 40,
    severity = alert_consts.alert_severities.warning,
    i18n_title = "alerts_dashboard.slow_periodic_activity",
    icon = "fa-undo",
  }, influxdb_dropped_points = {
    alert_id = 41,
    severity = alert_consts.alert_severities.error,
    i18n_title = "alerts_dashboard.influxdb_dropped_points",
    icon = "fa-database",
  }
}

-- ##############################################

-- See getFlowStatusTypes() in lua_utils for flow alerts
-- See Utils::flowStatus2str to determine the alert_type for flow alerts

-- Keep in sync with ntop_typedefs.h:AlertEntity
alert_consts.alert_entities = {
   interface = {
    entity_id = 0,
    label = "Interface",
   }, host = {
    entity_id = 1,
    label = "Host",
   }, network = {
    entity_id = 2,
    label = "Network",
   }, snmp_device = {
    entity_id = 3,
    label = "SNMP device",
   }, flow = {
    entity_id = 4,
    label = "Flow",
   }, mac = {
    entity_id = 5,
    label = "Device",
   }, host_pool = {
    entity_id = 6,
    label = "Host Pool",
   }, process = {
    entity_id = 7,
    label = "Process",
   }, user = {
    entity_id = 8,
    label = "User",
   }, influx_db = {
    entity_id = 9,
    label = "Influx DB",
   }, test = {
    entity_id = 10,
    label = "Test",
   }, category_lists = {
    entity_id = 11,
    label = "Category Lists",
   }, pinged_host = {
    entity_id = 12,
    label = "PINGed host",
   }, periodic_activity = {
    entity_id = 13,
    label = "Periodic Activity",
  }
}

-- Keep in sync with C
alert_consts.alerts_granularities = {
  ["min"] = {
    granularity_id = 0,
    granularity_seconds = 60,
    i18n_title = "show_alerts.minute",
    i18n_description = "alerts_thresholds_config.every_minute",
  }, ["5mins"] = {
    granularity_id = 1,
    granularity_seconds = 300,
    i18n_title = "show_alerts.5_min",
    i18n_description = "alerts_thresholds_config.every_5_minutes",
  }, ["hour"] = {
    granularity_id = 2,
    granularity_seconds = 3600,
    i18n_title = "show_alerts.hourly",
    i18n_description = "alerts_thresholds_config.hourly",
  }, ["day"] = {
    granularity_id = 3,
    granularity_seconds = 86400,
    i18n_title = "show_alerts.daily",
    i18n_description = "alerts_thresholds_config.daily",
  }
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
      fmt = function(val) return format_utils.bitsToSize(1000000 * val) end,
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

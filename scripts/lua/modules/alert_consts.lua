--
-- (C) 2018 - ntop.org
--
-- This file contains the alert constats

local alert_consts = {}
local locales_utils = require "locales_utils"
local format_utils  = require "format_utils"

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  -- NOTE: import snmp_utils below to avoid import cycles
end

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

local function formatAlertEntity(ifid, entity_type, entity_value)
   require "flow_utils"
   local value
   local epoch_begin, epoch_end = getAlertTimeBounds({alert_tstamp = os.time()})
   local label = string.lower(alert_consts.alert_entities[entity_type].label)

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
   elseif entity_type == "host_pool" then
      host_pools_utils = require("host_pools_utils")
      value = host_pools_utils.getPoolName(ifid, entity_value)
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
      return label.." "..value
   end
end

-- TODO: should this be global?
alert_consts.formatAlertEntity = formatAlertEntity

-- ##############################################

local function formatThresholdCross(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local engine_label = alertEngineLabel(alertEngine(sec2granularity(alert["alert_granularity"])))

  return i18n("alert_messages.threshold_crossed", {
    granularity = engine_label,
    metric = threshold_info.metric,
    entity = entity,
    value = string.format("%u", math.ceil(threshold_info.value)),
    op = "&"..threshold_info.operator..";",
    threshold = threshold_info.threshold,
  })
end

-- ##############################################

local function formatSynFlood(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  if(alert.alert_subtype == "syn_flood_attacker") then
    return i18n("alert_messages.syn_flood_attacker", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  else
    return i18n("alert_messages.syn_flood_victim", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  end
end

-- ##############################################

local function formatFlowsFlood(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  if(alert.alert_subtype == "flow_flood_attacker") then
    return i18n("alert_messages.flow_flood_attacker", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  else
    return i18n("alert_messages.flow_flood_victim", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  end
end

-- ##############################################

local function formatMisconfiguredApp(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  if alert.alert_subtype == "too_many_flows" then
    return(i18n("alert_messages.too_many_flows", {iface=entity, option="--max-num-flows/-X"}))
  elseif alert.alert_subtype == "too_many_hosts" then
    return(i18n("alert_messages.too_many_hosts", {iface=entity, option="--max-num-hosts/-x"}))
  else
    return("Unknown app misconfiguration: " .. (alert.alert_subtype or ""))
  end
end

-- ##############################################

local function formatSlowStatsUpdate(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  return(i18n("alert_messages.slow_stats_update", {
    iface = entity,
    url = ntop.getHttpPrefix() .."/lua/admin/prefs.lua?tab=in_memory",
    pref_name = i18n("prefs.housekeeping_frequency_title"),
  }))
end

-- ##############################################

local function formatTooManyPacketDrops(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local max_drop_perc = threshold_info.edge or 0

  return(i18n("alert_messages.too_many_drops", {iface = entity, max_drops = max_drop_perc}))
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

local function getMacUrl(mac)
   return ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. mac
end

-- ##############################################

local function getHostUrl(host, vlan_id)
   return ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url({host = host, vlan = vlan_id})
end

-- ##############################################

local function getHostPoolUrl(pool_id)
   return ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?pool=" .. pool_id
end

-- ##############################################

local function snmpDeviceUrl(snmp_device)
  return ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_device)
end

-- ##############################################

local function snmpIfaceUrl(snmp_device, interface_idx)
  return ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d", snmp_device, interface_idx)
end

-- ##############################################

local function formatBroadcastDomainAlert(ifid, alert, info)
  return(i18n("alert_messages.broadcast_domain_too_large", {
    src_mac = info.src_mac,
    src_mac_url = getMacUrl(info.src_mac),
    dst_mac = info.dst_mac,
    dst_mac_url = getMacUrl(info.dst_mac),
    spa = info.spa,
    spa_url = getHostUrl(info.spa, info.vlan_id),
    tpa = info.tpa,
    tpa_url = getHostUrl(info.tpa, info.vlan_id),
  }))
end

-- ##############################################

local function nfwFlushedFormatter(ifid, alert, info)
  return(i18n("alert_messages.nfq_flushed", {
    name = info.ifname, pct = info.pct,
    tot = info.tot, dropped = info.dropped,
    url = ntop.getHttpPrefix().."/lua/if_stats.lua?ifid=" .. ifid,
  }))
end

-- ##############################################

local function remoteToRemoteFormatter(ifid, alert, info)
  return(i18n("alert_messages.host_remote_to_remote", {
    url = ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. hostinfo2hostkey(hostkey2hostinfo(alert.alert_entity_val)),
    flow_alerts_url = ntop.getHttpPrefix() .."/lua/show_alerts.lua?status=historical-flows&alert_type="..alertType("remote_to_remote"),
    mac_url = ntop.getHttpPrefix() .."/lua/mac_details.lua?host="..info.mac,
    ip = info.host,
    mac = get_symbolic_mac(info.mac, true),
  }))
end

-- ##############################################

local function outsideDhcpRangeFormatter(ifid, alert, info)
  local hostinfo = hostkey2hostinfo(alert.alert_entity_val)
  local hostkey = hostinfo2hostkey(hostinfo)
  local router_info = hostkey2hostinfo(info.router_info)

  return(i18n("alert_messages.ip_outsite_dhcp_range", {
    client_url = getMacUrl(info.client_mac),
    client_mac = get_symbolic_mac(info.client_mac, true),
    client_ip = hostkey,
    client_ip_url = getHostUrl(hostinfo["host"], hostinfo["vlan"]),
    dhcp_url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid="..ifid.."&page=dhcp",
    sender_url = getMacUrl(info.sender_mac),
    sender_mac = get_symbolic_mac(info.sender_mac, true),
  }) .. " " .. ternary(router_info["host"] == "0.0.0.0", "", i18n("alert_messages.ip_outside_dhcp_range_router_ip", {
    router_url = getHostUrl(router_info["host"], router_info["vlan"]),
    router_ip = info.router_host,
  })))
end

-- ##############################################

local function slowPeriodicActivityFormatter(ifid, alert, info)
  local duration
  local max_duration

  if(info.max_duration_ms > 3000) then
    duration = string.format("%u s", math.floor(info.duration_ms/1000))
    max_duration = string.format("%u s", math.floor(info.max_duration_ms/1000))
  else
    duration = string.format("%u ms", math.floor(info.duration_ms))
    max_duration = string.format("%u ms", math.floor(info.max_duration_ms))
  end

  return(i18n("alert_messages.slow_periodic_activity", {
    script = alert.alert_entity_val,
    duration = duration,
    max_duration = max_duration,
  }))
end

-- ##############################################

local function formatDeviceAlert(i18n_string, ifid, alert, info)
  return(i18n(i18n_string, {
    device = info.device,
    url = getMacUrl(alert.alert_entity_val),
  }))
end

local function formatNewDeviceConnectionAlert(ifid, alert, info)
  return(formatDeviceAlert("alert_messages.a_new_device_has_connected", ifid, alert, info))
end

local function formatDeviceConnectionAlert(ifid, alert, info)
  return(formatDeviceAlert("alert_messages.device_has_connected", ifid, alert, info))
end

local function formatDeviceDisconnectionAlert(ifid, alert, info)
  return(formatDeviceAlert("alert_messages.device_has_disconnected", ifid, alert, info))
end

-- ##############################################

local function quotaExceededFormatter(ifid, alert, info)
  local quota_str
  local value_str
  local subject_str

  if alert.alert_subtype == "traffic_quota" then
    quota_str = bytesToSize(info.quota)
    value_str = bytesToSize(info.value)
    subject_str = i18n("alert_messages.proto_bytes_quotas", {proto=info.proto})
  else
    quota_str = secondsToTime(info.quota)
    value_str = secondsToTime(info.value)
    subject_str = i18n("alert_messages.proto_time_quotas", {proto=info.proto})
  end

  return(i18n("alert_messages.subject_quota_exceeded", {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
    subject = subject_str,
    quota = quota_str,
    value = value_str
  }))
end

-- ##############################################

local function poolAlertFormat(i18n_string, ifid, alert, info)
  return(i18n(i18n_string, {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
  }))
end

local function poolConnectionFormat(ifid, alert, info)
  return(poolAlertFormat("alert_messages.host_pool_has_connected", ifid, alert, info))
end

local function poolDisconnectionFormat(ifid, alert, info)
  return(poolAlertFormat("alert_messages.host_pool_has_disconnected", ifid, alert, info))
end

-- ##############################################

local function macIpAssociationChangedFormatter(ifid, alert, info)
  return(i18n("alert_messages.mac_ip_association_change", {
    new_mac = info.new_mac, old_mac = info.old_mac,
    ip = info.ip, new_mac_url = getMacUrl(info.new_mac), old_mac_url = getMacUrl(info.old_mac)
  }))
end

-- ##############################################

local function userActivityFormatter(ifid, alert, info)
  local decoded = info
  local user = alert.alert_entity_val

  if decoded.scope ~= nil then

    if decoded.scope == 'login' and decoded.status ~= nil then

      if decoded.status == 'authorized' then
        return i18n('user_activity.login_successful', {user=user})
      else
        return i18n('user_activity.login_not_authorized', {user=user})
      end

    elseif decoded.scope == 'function' and decoded.name ~= nil then
      local ifname = getInterfaceName(decoded.ifid)

      -- User add/del/password

      if decoded.name == 'addUser' and decoded.params[1] ~= nil then
        local add_user = decoded.params[1]
        return i18n('user_activity.user_added', {user=user, add_user=add_user})

      elseif decoded.name == 'deleteUser' and decoded.params[1] ~= nil then
        local del_user = decoded.params[1]
        return i18n('user_activity.user_deleted', {user=user, del_user=del_user})

      elseif decoded.name == 'resetUserPassword' and decoded.params[2] ~= nil then
        local pwd_user = decoded.params[2]
        local user_ip = ternary(decoded.remote_addr, decoded.remote_addr, '')
        return  i18n('user_activity.password_changed', {user=user, pwd_user=pwd_user, ip=user_ip}) 

      -- SNMP device add/del

      elseif decoded.name == 'add_snmp_device' and decoded.params[1] ~= nil then
        local device_ip = decoded.params[1]
        return i18n('user_activity.snmp_device_added', {user=user, ip=device_ip})

      elseif decoded.name == 'del_snmp_device' and decoded.params[1] ~= nil then
        local device_ip = decoded.params[1]
        return i18n('user_activity.snmp_device_deleted', {user=user, ip=device_ip})

      -- Stored data

      elseif decoded.name == 'request_delete_active_interface_data' and decoded.params[1] ~= nil then
        return i18n('user_activity.deleted_interface_data', {user=user, ifname=ifname})

      elseif decoded.name == 'delete_all_interfaces_data' then
        return i18n('user_activity.deleted_all_interfaces_data', {user=user})

      elseif decoded.name == 'delete_host' and decoded.params[1] ~= nil then
        local host = decoded.params[1]
        local hostinfo = hostkey2hostinfo(host)
        local hostname = host2name(hostinfo.host, hostinfo.vlan)
        local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..decoded.ifid.."&host="..host.."\">"..hostname .."</a>" 
        return i18n('user_activity.deleted_host_data', {user=user, ifname=ifname, host=host_url})

      elseif decoded.name == 'delete_network' and decoded.params[1] ~= nil then
        local network = decoded.params[1]
        return i18n('user_activity.deleted_network_data', {user=user, ifname=ifname, network=network})

      elseif decoded.name == 'delete_inactive_interfaces' then
        return i18n('user_activity.deleted_inactive_interfaces_data', {user=user})

      -- Service enable/disable

      elseif decoded.name == 'disableService' and decoded.params[1] ~= nil then
        local service_name = decoded.params[1]
        if service_name == 'n2disk-ntopng' and decoded.params[2] ~= nil then
          local service_instance = decoded.params[2]
          return i18n('user_activity.recording_disabled', {user=user, ifname=service_instance})
        elseif service_name == 'n2n' then
          return i18n('user_activity.remote_assistance_disabled', {user=user})
        end

      elseif decoded.name == 'enableService' and decoded.params[1] ~= nil then
        local service_name = decoded.params[1]
        if service_name == 'n2disk-ntopng' and decoded.params[2] ~= nil then
          local service_instance = decoded.params[2]
          return i18n('user_activity.recording_enabled', {user=user, ifname=service_instance})
        elseif service_name == 'n2n' then
          return i18n('user_activity.remote_assistance_enabled', {user=user})
        end

      -- File download

      elseif decoded.name == 'dumpBinaryFile' and decoded.params[1] ~= nil then
        local file_name = decoded.params[1]
        return i18n('user_activity.file_downloaded', {user=user, file=file_name})

      elseif decoded.name ==  'export_data' and decoded.params[1] ~= nil then
        local mode = decoded.params[1]
        if decoded.params[2] ~= nil then
          local host = decoded.params[1]
          local hostinfo = hostkey2hostinfo(host)
          local hostname = host2name(hostinfo.host, hostinfo.vlan)
          local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..decoded.ifid.."&host="..host.."\">"..hostname .."</a>" 
          return i18n('user_activity.exported_data_host', {user=user, mode=mode, host=host_url})
        else
          return i18n('user_activity.exported_data', {user=user, mode=mode})
        end

      elseif decoded.name == 'host_get_json' and decoded.params[1] ~= nil then
        local host = decoded.params[1]
        local hostinfo = hostkey2hostinfo(host)
        local hostname = host2name(hostinfo.host, hostinfo.vlan)
        local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..(decoded.ifid or ifid).."&host="..host.."\">"..hostname .."</a>" 
        return i18n('user_activity.host_json_downloaded', {user=user, host=host_url})

      elseif decoded.name == 'live_flows_extraction' and decoded.params[1] ~= nil and decoded.params[2] ~= nil then
        local time_from = format_utils.formatEpoch(decoded.params[1])
        local time_to = format_utils.formatEpoch(decoded.params[2])
        return i18n('user_activity.flows_downloaded', {user=user, from=time_from, to=time_to })

      -- Live capture

      elseif decoded.name == 'liveCapture' then
        if not isEmptyString(decoded.params[1]) then
          local host = decoded.params[1]
          local hostinfo = hostkey2hostinfo(host)
          local hostname = host2name(hostinfo.host, hostinfo.vlan)
          local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..decoded.ifid.."&host="..host.."\">"..hostname .."</a>" 
          if not isEmptyString(decoded.params[3]) then
            local filter = decoded.params[3]
            return i18n('user_activity.live_capture_host_with_filter', {user=user, host=host_url, filter=filter, ifname=ifname})
          else
            return i18n('user_activity.live_capture_host', {user=user, host=host_url, ifname=ifname})
          end
        else
          if not isEmptyString(decoded.params[3]) then
            local filter = decoded.params[3]
            return i18n('user_activity.live_capture_with_filter', {user=user,filter=filter, ifname=ifname})
          else
            return i18n('user_activity.live_capture', {user=user, ifname=ifname})
          end
        end

      -- Live extraction

      elseif decoded.name == 'runLiveExtraction' and decoded.params[1] ~= nil then
        local time_from = format_utils.formatEpoch(decoded.params[2])
        local time_to = format_utils.formatEpoch(decoded.params[3])
        local filter = decoded.params[4]
        return i18n('user_activity.live_extraction', {user=user, ifname=ifname, 
                    from=time_from, to=time_to, filter=filter})

      -- Alerts

      elseif decoded.name == 'checkDeleteStoredAlerts' and decoded.params[1] ~= nil then
        local status = decoded.params[1]
        return i18n('user_activity.alerts_deleted', {user=user, status=status})

      elseif decoded.name == 'setPref' and decoded.params[1] ~= nil and decoded.params[2] ~= nil then
        local key = decoded.params[1]
        local value = decoded.params[2]
        local k = key:gsub("^ntopng%.prefs%.", "")
        local pref_desc

        if k == "disable_alerts_generation" then pref_desc = i18n("prefs.disable_alerts_generation_title")
        elseif k == "mining_alerts" then pref_desc = i18n("prefs.toggle_mining_alerts_title")
        elseif k == "probing_alerts" then pref_desc = i18n("prefs.toggle_alert_probing_title")
        elseif k == "ssl_alerts" then pref_desc = i18n("prefs.toggle_ssl_alerts_title")
        elseif k == "dns_alerts" then pref_desc = i18n("prefs.toggle_dns_alerts_title")
        elseif k == "ip_reassignment_alerts" then pref_desc = i18n("prefs.toggle_ip_reassignment_title")
        elseif k == "remote_to_remote_alerts" then pref_desc = i18n("prefs.toggle_remote_to_remote_alerts_title")
        elseif k == "mining_alerts" then pref_desc = i18n("prefs.toggle_mining_alerts_title")
        elseif k == "host_blacklist" then pref_desc = i18n("prefs.toggle_malware_probing_title")
        elseif k == "ids_alerts" then pref_desc = i18n("prefs.toggle_ids_alert_title")
        elseif k == "device_protocols_alerts" then pref_desc = i18n("prefs.toggle_device_protocols_title")
        elseif k == "alerts.device_first_seen_alert" then pref_desc = i18n("prefs.toggle_device_first_seen_alert_title")
        elseif k == "alerts.device_connection_alert" then pref_desc = i18n("prefs.toggle_device_activation_alert_title")
        elseif k == "alerts.pool_connection_alert" then pref_desc = i18n("prefs.toggle_pool_activation_alert_title")
        elseif k == "alerts.external_notifications_enabled" then pref_desc = i18n("prefs.toggle_alerts_notifications_title")
        elseif k == "alerts.email_notifications_enabled" then pref_desc = i18n("prefs.toggle_email_notification_title")
        elseif k == "alerts.slack_notifications_enabled" then pref_desc = i18n("prefs.toggle_slack_notification_title", {url="http://www.slack.com"})
        elseif k == "alerts.syslog_notifications_enabled" then pref_desc = i18n("prefs.toggle_alert_syslog_title")
        elseif k == "alerts.nagios_notifications_enabled" then pref_desc = i18n("prefs.toggle_alert_nagios_title")
        elseif k == "alerts.webhook_notifications_enabled" then pref_desc = i18n("prefs.toggle_webhook_notification_title")
        elseif starts(k, "alerts.email_") then pref_desc = i18n("prefs.email_notification")
        elseif starts(k, "alerts.smtp_") then pref_desc = i18n("prefs.email_notification")
        elseif starts(k, "alerts.slack_") then pref_desc = i18n("prefs.slack_integration")
        elseif starts(k, "alerts.nagios_") then pref_desc = i18n("prefs.nagios_integration")
        elseif starts(k, "nagios_") then pref_desc = i18n("prefs.nagios_integration")
        elseif starts(k, "alerts.webhook_") then pref_desc = i18n("prefs.webhook_notification")
        else pref_desc = k -- last resort if not handled
        end

        if k == "disable_alerts_generation" then
          if value == "1" then value = "0" else value = "1" end
        end 

        if value == "1" then 
          return i18n('user_activity.enabled_preference', {user=user, pref=pref_desc})
        elseif value == "0" then 
          return i18n('user_activity.disabled_preference', {user=user, pref=pref_desc})
        else
          return i18n('user_activity.changed_preference', {user=user, pref=pref_desc})
        end

      else
        return i18n('user_activity.unknown_activity_function', {user=user, name=decoded.name})

      end
    end
  end

  return i18n('user_activity.unknown_activity', {user=user, scope=decoded.scope})
end

-- ##############################################

function loginFailedFormatter(ifid, alert, info)
  return(i18n("user_activity.login_not_authorized", {
    user = alert.alert_entity_val,
  }))
end

-- ##############################################

function requestReplyRatioFormatter(ifid, alert, info)
  local entity = firstToUpper(formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"]))
  local engine_label = alertEngineLabel(alertEngine(sec2granularity(alert["alert_granularity"])))
  local ratio = round(math.min((info.replies * 100) / (info.requests + 1), 100), 1)

  -- {i18_string, what}
  local subtype_to_info = {
    dns_sent = {"alerts_dashboard.too_low_replies_received", "DNS"},
    dns_rcvd = {"alerts_dashboard.too_low_replies_sent", "DNS"},
    http_sent = {"alerts_dashboard.too_low_replies_received", "HTTP"},
    http_rcvd = {"alerts_dashboard.too_low_replies_sent", "HTTP"},
    icmp_echo_sent = {"alerts_dashboard.too_low_replies_received", "ICMP ECHO"},
    icmp_echo_rcvd = {"alerts_dashboard.too_low_replies_received", "ICMP ECHO"},
  }

  local subtype_info = subtype_to_info[alert.alert_subtype]

  return(i18n(subtype_info[1], {
    entity = entity,
    granularity = engine_label,
    ratio = ratio,
    requests = i18n(
      ternary(info.requests == 1, "alerts_dashboard.one_request", "alerts_dashboard.many_requests"),
      {count = formatValue(info.requests), what = subtype_info[2]}),
    replies =  i18n(
      ternary(info.replies == 1, "alerts_dashboard.one_reply", "alerts_dashboard.many_replies"),
      {count = formatValue(info.replies), what = subtype_info[2]}),
  }))
end

-- ##############################################

local function processNotificationFormatter(ifid, alert, info)
  if info.event_type == "start" then
    return string.format("%s %s", i18n("alert_messages.ntopng_start"), info.msg_details)
  elseif info.event_type == "stop" then
    return string.format("%s %s", i18n("alert_messages.ntopng_stop"), info.msg_details)
  elseif info.event_type == "anomalous_termination" then
    return string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {url="https://www.ntop.org/support/need-help-2/need-help/"}), info.msg_details)
  end

  return "Unknown Process Event: " .. (info.event_type or "")
end

-- ##############################################

local function portStatusChangeFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.snmp_port_changed_operational_status",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     new_op = snmp_ifstatus(info.status)}))
end

-- ##############################################

local function snmpPortDuplexChangeFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.snmp_port_changed_duplex_status",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     new_op = snmp_duplexstatus(info.status)}))
end

-- ##############################################

local function snmpInterfaceErrorsFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.snmp_port_errors_increased",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface)}))
end

-- ##############################################

local function snmpPortLoadThresholdFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.snmp_port_load_threshold_exceeded_message",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     port_load = info.interface_load,
     direction = ternary(info.interface_load, "RX", "TX")}))
end

-- ##############################################

local function pingIssuesFormatter(ifid, alert, info)
   local msg
   -- example of an ip label:
   -- google-public-dns-b.google.com@ipv4@icmp/216.239.38.120
   local ip_label = (alert.alert_entity_val:split("@") or {alert.alert_entity_val})[1]
   local numeric_ip = alert.ip

   if numeric_ip and numeric_ip ~= ip_label then
      numeric_ip = string.format("[%s]", numeric_ip)
   else
      numeric_ip = ""
   end

   if(info.value == 0) then -- host unreachable
      msg = i18n("alert_messages.ping_host_unreachable",
		 {ip_label = ip_label,
		  numeric_ip = numeric_ip})
   else -- host too slow
      msg = i18n("alert_messages.ping_rtt_too_slow",
		 {ip_label = ip_label,
		  numeric_ip = numeric_ip,
		  rtt_value = format_utils.round(info.value, 2),
		  maximum_rtt = info.threshold})
   end

   return msg
end

-- ##############################################

local function anomalousTCPFlagsFormatter(ifid, alert, info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  return(i18n("alert_messages.anomalous_tcp_flags", {
    entity = firstToUpper(entity),
    ratio = round(info.ratio, 1),
    sent_or_rcvd = ternary(info.is_sent, i18n("graphs.metrics_suffixes.sent"), string.lower(i18n("received"))),
  }))
end

-- ##############################################

local function misbehavingFlowsRatioFormatter(ifid, alert, info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  return(i18n("alert_messages.misbehaving_flows_ratio", {
    entity = firstToUpper(entity),
    ratio = round(info.ratio, 1),
    sent_or_rcvd = ternary(info.is_sent, i18n("graphs.metrics_suffixes.sent"), string.lower(i18n("received"))),
  }))
end

-- ##############################################

local function ghostNetworkFormatter(ifid, alert, info)
  return(i18n("alerts_dashboard.ghost_network_detected_description", {
    network = alert.alert_subtype,
    entity = getInterfaceName(ifid),
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=".. ifid .."&page=networks",
  }))
end

-- ##############################################

-- Keep ID in sync with AlertType
-- NOTE: flow alerts are formatted based on their status. See flow_consts.flow_status_types.
alert_consts.alert_types = {
  tcp_syn_flood = {
    alert_id = 0,
    i18n_title = "alerts_dashboard.tcp_syn_flood",
    i18n_description = formatSynFlood,
    icon = "fa-life-ring",
  }, flows_flood = {
    alert_id = 1,
    i18n_title = "alerts_dashboard.flows_flood",
    i18n_description = formatFlowsFlood,
    icon = "fa-life-ring",
  }, threshold_cross = {
    alert_id = 2,
    i18n_title = "alerts_dashboard.threashold_cross",
    i18n_description = formatThresholdCross,
    icon = "fa-arrow-circle-up",
  }, suspicious_activity = {
    alert_id = 3,
    i18n_title = "alerts_dashboard.suspicious_activity",
    icon = "fa-exclamation",
  }, alert_connection_issues = {
    alert_id = 4,
    i18n_title = "alerts_dashboard.connection_issues",
    icon = "fa-exclamation",
  }, flow_misbehaviour = {
    alert_id = 5,
    i18n_title = "alerts_dashboard.flow_misbehaviour",
    icon = "fa-exclamation",
  }, remote_to_remote = {
    alert_id = 6,
    i18n_title = "alerts_dashboard.remote_to_remote",
    i18n_description = remoteToRemoteFormatter,
    icon = "fa-exclamation",
  }, flow_blacklisted = {
    alert_id = 7,
    i18n_title = "alerts_dashboard.blacklisted_flow",
    icon = "fa-exclamation",
  }, flow_blocked = {
    alert_id = 8,
    i18n_title = "alerts_dashboard.blocked_flow",
    icon = "fa-ban",
  }, new_device = {
    alert_id = 9,
    i18n_title = "alerts_dashboard.new_device",
    i18n_description = formatNewDeviceConnectionAlert,
    icon = "fa-asterisk",
  }, device_connection = {
    alert_id = 10,
    i18n_title = "alerts_dashboard.device_connection",
    i18n_description = formatDeviceConnectionAlert,
    icon = "fa-sign-in",
  }, device_disconnection = {
    alert_id = 11,
    i18n_title = "alerts_dashboard.device_disconnection",
    i18n_description = formatDeviceDisconnectionAlert,
    icon = "fa-sign-out",
  }, host_pool_connection = {
    alert_id = 12,
    i18n_title = "alerts_dashboard.host_pool_connection",
    i18n_description = poolConnectionFormat,
    icon = "fa-sign-in",
  }, host_pool_disconnection = {
    alert_id = 13,
    i18n_title = "alerts_dashboard.host_pool_disconnection",
    i18n_description = poolDisconnectionFormat,
    icon = "fa-sign-out",
  }, quota_exceeded = {
    alert_id = 14,
    i18n_title = "alerts_dashboard.quota_exceeded",
    i18n_description = quotaExceededFormatter,
    icon = "fa-thermometer-full",
  }, misconfigured_app = {
    alert_id = 15,
    i18n_title = "alerts_dashboard.misconfigured_app",
    icon = "fa-cog",
    i18n_description = formatMisconfiguredApp,
  }, too_many_drops = {
    alert_id = 16,
    i18n_title = "alerts_dashboard.too_many_drops",
    icon = "fa-tint",
    i18n_description = formatTooManyPacketDrops,
  }, mac_ip_association_change = {
    alert_id = 17,
    i18n_title = "alerts_dashboard.mac_ip_association_change",
    icon = "fa-exchange",
    i18n_description = macIpAssociationChangedFormatter,
  }, port_status_change = {
    alert_id = 18,
    i18n_title = "alerts_dashboard.snmp_port_status_change",
    i18n_description = portStatusChangeFormatter,
    icon = "fa-exclamation",
  }, unresponsive_device = {
    alert_id = 19,
    i18n_title = "alerts_dashboard.unresponsive_device",
    icon = "fa-exclamation",
  }, process_notification = {
    alert_id = 20,
    i18n_title = "alerts_dashboard.process",
    i18n_description = processNotificationFormatter,
    icon = "fa-truck",
  }, web_mining = {
    alert_id = 21,
    i18n_title = "alerts_dashboard.web_mining",
    icon = "fa-bitcoin",
  }, nfq_flushed = {
    alert_id = 22,
    i18n_title = "alerts_dashboard.nfq_flushed",
    i18n_description = nfwFlushedFormatter,
    icon = "fa-angle-double-down",
  }, slow_stats_update = {
    alert_id = 23,
    i18n_title = "alerts_dashboard.slow_stats_update",
    icon = "fa-exclamation",
    i18n_description = formatSlowStatsUpdate,
  }, alert_device_protocol_not_allowed = {
    alert_id = 24,
    i18n_title = "alerts_dashboard.suspicious_device_protocol",
    icon = "fa-exclamation",
  }, alert_user_activity = {
    alert_id = 25,
    i18n_title = "alerts_dashboard.user_activity",
    i18n_description = userActivityFormatter,
    icon = "fa-user",
  }, influxdb_export_failure = {
    alert_id = 26,
    i18n_title = "alerts_dashboard.influxdb_export_failure",
    i18n_description = "alert_messages.influxdb_dropped_points",
    icon = "fa-database",
  }, port_errors = {
    alert_id = 27,
    i18n_title = "alerts_dashboard.snmp_port_errors",
    i18n_description = snmpInterfaceErrorsFormatter,
    icon = "fa-exclamation",
  }, test_failed = {
    alert_id = 28,
    i18n_title = "alert_messages.test_failed",
    icon = "fa-exclamation",
  }, inactivity = {
    alert_id = 29,
    i18n_title = "alerts_dashboard.inactivity",
    icon = "fa-exclamation",
  }, active_flows_anomaly = {
    alert_id = 30,
    i18n_title = "alerts_dashboard.active_flows_anomaly",
    icon = "fa-life-ring",
    i18n_description = formatActiveFlowsAnomaly,
  }, list_download_failed = {
    alert_id = 31,
    i18n_title = "alerts_dashboard.list_download_failed",
    i18n_description = "category_lists.error_occurred",
    icon = "fa-sticky-note",
  }, dns_anomaly = {
    alert_id = 32,
    i18n_title = "alerts_dashboard.dns_anomaly",
    icon = "fa-life-ring",
    i18n_description = formatDNSAnomaly,
  }, icmp_anomaly = {
    alert_id = 33,
    i18n_title = "alerts_dashboard.icmp_anomaly",
    icon = "fa-life-ring",
    i18n_description = formatICMPAnomaly,
  }, broadcast_domain_too_large = {
    alert_id = 34,
    i18n_title = "alerts_dashboard.broadcast_domain_too_large",
    i18n_description = formatBroadcastDomainAlert,
    icon = "fa-sitemap",
  }, ids_alert = {
    alert_id = 35,
    i18n_title = "alerts_dashboard.ids_alert",
    icon = "fa-eye",
  }, ip_outsite_dhcp_range = {
    alert_id = 36,
    i18n_title = "alerts_dashboard.misconfigured_dhcp_range",
    i18n_description = outsideDhcpRangeFormatter,
    icon = "fa-exclamation",
  }, port_duplexstatus_change = {
    alert_id = 37,
    i18n_title = "alerts_dashboard.snmp_port_duplexstatus_change",
    i18n_description = snmpPortDuplexChangeFormatter,
    icon = "fa-exclamation",
  }, port_load_threshold_exceeded = {
    alert_id = 38,
    i18n_title = "alerts_dashboard.snmp_port_load_threshold_exceeded",
    i18n_description = snmpPortLoadThresholdFormatter,
    icon = "fa-exclamation",
  }, ping_issues = {
    alert_id = 39,
    i18n_title = "alerts_dashboard.ping_issues",
    i18n_description = pingIssuesFormatter,
    icon = "fa-exclamation",
  }, slow_periodic_activity = {
    alert_id = 40,
    i18n_title = "alerts_dashboard.slow_periodic_activity",
    i18n_description = slowPeriodicActivityFormatter,
    icon = "fa-undo",
  }, influxdb_dropped_points = {
    alert_id = 41,
    i18n_title = "alerts_dashboard.influxdb_dropped_points",
    icon = "fa-database",
  }, login_failed = {
    alert_id = 42,
    i18n_title = "alerts_dashboard.login_failed",
    i18n_description = loginFailedFormatter,
    icon = "fa-sign-in",
  }, potentially_dangerous_protocol = {
    alert_id = 43,
    i18n_title = "alerts_dashboard.potentially_dangerous_protocol",
    i18n_description = "alert_messages.potentially_dangerous_protocol_description",
    icon = "fa-exclamation",
  }, request_reply_ratio = {
    alert_id = 44,
    i18n_title = "entity_thresholds.request_reply_ratio_title",
    i18n_description = requestReplyRatioFormatter,
    icon = "fa-exclamation",
  }, anomalous_tcp_flags = {
    alert_id = 45,
    i18n_title = "alerts_dashboard.anomalous_tcp_flags",
    i18n_description = anomalousTCPFlagsFormatter,
    icon = "fa-exclamation",
  }, misbehaving_flows_ratio = {
    alert_id = 46,
    i18n_title = "alerts_dashboard.misbehaving_flows_ratio",
    i18n_description = misbehavingFlowsRatioFormatter,
    icon = "fa-exclamation",
  }, ghost_network = {
    alert_id = 47,
    i18n_title = "alerts_dashboard.ghost_network_detected",
    i18n_description = ghostNetworkFormatter,
    icon = "fa-snapchat-ghost",
  }, malicious_signature = {
    alert_id = 48,
    i18n_title = "alerts_dashboard.malicious_signature_detected",
    icon = "fa-ban",
  },
}

-- ##############################################

-- See flow_consts.flow_status_types in flow_consts for flow alerts
-- See Utils::flowStatus2AlertType to determine the alert_type for flow alerts

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
      granularity_id = 1,
      granularity_seconds = 60,
      i18n_title = "show_alerts.minute",
      i18n_description = "alerts_thresholds_config.every_minute",
   },
   ["5mins"] = {
      granularity_id = 2,
      granularity_seconds = 300,
      i18n_title = "show_alerts.5_min",
      i18n_description = "alerts_thresholds_config.every_5_minutes",
   },
   ["hour"] = {
      granularity_id = 3,
      granularity_seconds = 3600,
      i18n_title = "show_alerts.hourly",
      i18n_description = "alerts_thresholds_config.hourly",
   },
   ["day"] = {
      granularity_id = 4,
      granularity_seconds = 86400,
      i18n_title = "show_alerts.daily",
      i18n_description = "alerts_thresholds_config.daily",
   }
}

-- ################################################################################

alert_consts.field_units = {
  seconds = "field_units.seconds",
  bytes = "field_units.bytes",
  flows = "field_units.flows",
  packets = "field_units.packets",
  mbits = "field_units.mbits",
  hosts = "field_units.hosts",
  syn_sec = "field_units.syn_sec",
  flow_sec = "field_units.flow_sec",
  percentage = "field_units.percentage",
}

-- ################################################################################

alert_consts.ids_rule_maker = {
  GPL = "GPL",
  SURICATA = "Suricata",
  ET = "Emerging Threats",
}

-- ################################################################################

return alert_consts

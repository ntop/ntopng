--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")
local alert_endpoints = require("alert_endpoints_utils")
local alert_consts = require("alert_consts")
local os_utils = require("os_utils")
local do_trace = false

local alerts_api = {}

-- Just helpers
local str_2_periodicity = {
  ["min"]     = 60,
  ["5mins"]   = 300,
  ["hour"]    = 3600,
  ["day"]     = 86400,
}

local known_alerts = {}
local current_script = nil
local current_configset_id = nil

-- ##############################################

-- Returns a string which identifies an alert
function alerts_api.getAlertId(alert)
  return(string.format("%s_%s_%s_%s_%s", alert.alert_type,
    alert.alert_subtype or "", alert.alert_granularity or "",
    alert.alert_entity, alert.alert_entity_val))
end

-- ##############################################

local function alertErrorTraceback(msg)
  traceError(TRACE_ERROR, TRACE_CONSOLE, msg)
  traceError(TRACE_ERROR, TRACE_CONSOLE, debug.traceback())
end

-- ##############################################

local function get_alert_triggered_key(type_info)
  if((type_info == nil) or (type_info.alert_type == nil)) then
    tprint(debug.traceback())
  end

  return(string.format("%d@%s", type_info.alert_type.alert_id, type_info.alert_subtype or ""))
end

-- ##############################################

-- Performs the alert store asynchronously.
-- This is necessary both to avoid paying the database io cost inside
-- the other scripts and as a necessity to avoid a deadlock on the
-- host hash in the host.lua script
function alerts_api.checkPendingStoreAlerts()
  if(not areAlertsEnabled()) then
    return(false)
  end

  -- SQLite Alerts
  while(true) do
    local alert_json = ntop.popSqliteAlert()

    if(not alert_json) then
      break
    end

    local alert = json.decode(alert_json)

    if(alert) then
      interface.select(string.format("%d", alert.ifid))

      if(alert.is_flow_alert) then
        interface.storeFlowAlert(alert)
      else
        interface.storeAlert(
          alert.alert_tstamp, alert.alert_tstamp_end, alert.alert_granularity,
          alert.alert_type, alert.alert_subtype, alert.alert_severity,
          alert.alert_entity, alert.alert_entity_val,
          alert.alert_json)
      end
    end

    if ntop.isDeadlineApproaching() then
      return(false)
    end
  end

  return(true)
end

-- ##############################################

function alerts_api.addAlertGenerationInfo(alert_json, current_script, current_configset_id)
  if alert_json and current_script and current_configset_id then
    -- Add information about the script who generated this alert
    alert_json.alert_generation = {
      script_key = current_script.key,
      subdir = current_script.subdir,
      confset_id = current_configset_id,
    }
  else
    -- NOTE: there are currently some internally generated alerts which
    -- do not use the user_scripts api (e.g. the ntopng startup)
    --tprint(debug.traceback())
  end
end

local function addAlertGenerationInfo(alert_json)
  alerts_api.addAlertGenerationInfo(alert_json, current_script, current_configset_id)
end

-- ##############################################

--! @brief Stores a single alert (or event) into the alerts database
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @return true if the alert was successfully stored, false otherwise
function alerts_api.store(entity_info, type_info, when)
  local force = false
  local ifid = interface.getId()
  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or -1

  type_info.alert_type_params = type_info.alert_type_params or {}
  addAlertGenerationInfo(type_info.alert_type_params)

  local alert_json = json.encode(type_info.alert_type_params)
  local subtype = type_info.alert_subtype or ""
  when = when or os.time()

  if(not areAlertsEnabled()) then
    return(false)
  end

  if alerts_api.isEntityAlertDisabled(ifid, entity_info.alert_entity.entity_id, entity_info.alert_entity_val, type_info.alert_type.alert_id) then
    return(false)
  end

  -- Here the alert is considered stored. The actual store will be performed
  -- asynchronously

  -- NOTE: keep in sync with SQLite alert format in AlertsManager.cpp
  local alert_to_store = {
    ifid = ifid,
    action = "store",
    alert_type = type_info.alert_type.alert_id,
    alert_subtype = subtype,
    alert_granularity = granularity_sec,
    alert_entity = entity_info.alert_entity.entity_id,
    alert_entity_val = entity_info.alert_entity_val,
    alert_severity = type_info.alert_severity.severity_id,
    alert_tstamp = when,
    alert_tstamp_end = when,
    alert_json = alert_json,
  }

  if(entity_info.alert_entity.entity_id == alert_consts.alertEntity("host")) then
    -- NOTE: for engaged alerts this operation is performed during trigger in C
    interface.incTotalHostAlerts(entity_info.alert_entity_val, type_info.alert_type.alert_id)
  end

  local alert_json = json.encode(alert_to_store)
  ntop.pushSqliteAlert(alert_json)
  ntop.pushAlertNotification(alert_json)

  return(true)
end

-- ##############################################

--! @brief Determine whether the alert has already been triggered
--! @param candidate_severity the candidate alert severity
--! @param candidate_type the candidate alert type
--! @param candidate_granularity the candidate alert granularity
--! @param candidate_alert_subtype the candidate alert subtype
--! @param cur_alerts a table of currently triggered alerts
--! @return true on if the alert has already been triggered, false otherwise
--!
--! @note Example of cur_alerts
--! cur_alerts table
--! cur_alerts.1 table
--! cur_alerts.1.alert_type number 2
--! cur_alerts.1.alert_subtype string min_bytes
--! cur_alerts.1.alert_entity_val string 192.168.2.222@0
--! cur_alerts.1.alert_granularity number 60
--! cur_alerts.1.alert_severity number 2
--! cur_alerts.1.alert_json string {"metric":"bytes","threshold":1,"value":13727070,"operator":"gt"}
--! cur_alerts.1.alert_tstamp_end number 1571328097
--! cur_alerts.1.alert_tstamp number 1571327460
--! cur_alerts.1.alert_entity number 1
local function already_triggered(cur_alerts, candidate_severity, candidate_type,
	candidate_granularity, candidate_alert_subtype)
   for i = #cur_alerts, 1, -1 do
      local cur_alert = cur_alerts[i]

      if candidate_severity == cur_alert.alert_severity
	 and candidate_type == cur_alert.alert_type
	 and candidate_granularity == cur_alert.alert_granularity
         and candidate_alert_subtype == cur_alert.alert_subtype then
	    -- Remove from cur_alerts, this will save cycles for
	    -- subsequent calls of this method.
	    -- Using .remove is OK here as there won't unnecessarily move memory multiple times:
	    -- we return immeediately
	    -- NOTE: see un-removed alerts will be released by releaseEntityAlerts in interface.lua
	    table.remove(cur_alerts, i)
	    return true
      end
   end

   return false
end

-- ##############################################

--! @brief Trigger an alert of given type on the entity
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @param cur_alerts (optional) a table containing triggered alerts for the current entity
--! @return true on if the alert was triggered, false otherwise
--! @note The actual trigger is performed asynchronously
--! @note false is also returned if an existing alert is found and refreshed
function alerts_api.trigger(entity_info, type_info, when, cur_alerts)
  local ifid = interface.getId()
  local is_disabled = alerts_api.isEntityAlertDisabled(ifid, entity_info.alert_entity.entity_id, entity_info.alert_entity_val, type_info.alert_type.alert_id)

  -- Check if the alerts has been disabled and, in case return, before checking already_triggered,
  -- so that the alert will be automatically released during the next check.
  if is_disabled then
     return(true)
  end

  if(not areAlertsEnabled()) then
    return(false)
  end

  if(type_info.alert_granularity == nil) then
    alertErrorTraceback("Missing mandatory 'alert_granularity'")
    return(false)
  end

  -- Apply defaults
  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or 0 --[[ 0 is aperiodic ]]
  local subtype = type_info.alert_subtype or ""

  if(cur_alerts and already_triggered(cur_alerts, type_info.alert_severity.severity_id,
	  type_info.alert_type.alert_id, granularity_sec, subtype) == true) then
     return(true)
  end

  when = when or os.time()

  type_info.alert_type_params = type_info.alert_type_params or {}
  addAlertGenerationInfo(type_info.alert_type_params)

  local alert_json = json.encode(type_info.alert_type_params)
  local triggered
  local alert_key_name = get_alert_triggered_key(type_info)

  local params = {
    alert_key_name, granularity_id,
    type_info.alert_severity.severity_id, type_info.alert_type.alert_id,
    subtype, alert_json,
  }

  if(entity_info.alert_entity.entity_id == alert_consts.alertEntity("host")) then
    host.checkContext(entity_info.alert_entity_val)
    triggered = host.storeTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alert_consts.alertEntity("interface")) then
    interface.checkContext(entity_info.alert_entity_val)
    triggered = interface.storeTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alert_consts.alertEntity("network")) then
    network.checkContext(entity_info.alert_entity_val)
    triggered = network.storeTriggeredAlert(table.unpack(params))
  else
    triggered = interface.triggerExternalAlert(entity_info.alert_entity.entity_id, entity_info.alert_entity_val, table.unpack(params))
  end

  if(triggered == nil) then
    if(do_trace) then print("[Don't Trigger alert (already triggered?) @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title..":".. subtype .. "\n") end
    return(false)
  else
    if(do_trace) then print("[TRIGGER alert @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title..":".. subtype .. "\n") end
  end

  triggered.ifid = ifid
  triggered.action = "engage"

  local alert_json = json.encode(triggered)
  ntop.pushAlertNotification(alert_json)

  return(true)
end

-- ##############################################

--! @brief Release an alert of given type on the entity
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @param cur_alerts (optional) a table containing triggered alerts for the current entity
--! @note The actual release is performed asynchronously
--! @return true on success, false otherwise
function alerts_api.release(entity_info, type_info, when, cur_alerts)
  -- Apply defaults
  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or 0 --[[ 0 is aperiodic ]]
  local subtype = type_info.alert_subtype or ""

  if(cur_alerts and (not already_triggered(cur_alerts, type_info.alert_severity.severity_id,
	  type_info.alert_type.alert_id, granularity_sec, subtype))) then
     return(true)
  end

  when = when or os.time()
  local alert_key_name = get_alert_triggered_key(type_info)
  local ifid = interface.getId()
  local params = {alert_key_name, granularity_id, when}
  local released = nil

  if(not areAlertsEnabled()) then
    return(false)
  end

  if(type_info.alert_severity == nil) then
    alertErrorTraceback(string.format("Missing alert_severity [type=%s]", type_info.alert_type and type_info.alert_type.alert_id or ""))
    return(false)
  end

  if(entity_info.alert_entity.entity_id == alert_consts.alertEntity("host")) then
    host.checkContext(entity_info.alert_entity_val)
    released = host.releaseTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alert_consts.alertEntity("interface")) then
    interface.checkContext(entity_info.alert_entity_val)
    released = interface.releaseTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alert_consts.alertEntity("network")) then
    network.checkContext(entity_info.alert_entity_val)
    released = network.releaseTriggeredAlert(table.unpack(params))
  else
    released = interface.releaseExternalAlert(entity_info.alert_entity.entity_id, entity_info.alert_entity_val, table.unpack(params))
  end

  if(released == nil) then
    if(do_trace) then print("[Dont't Release alert (not triggered?) @ "..granularity_sec.."] "..
      entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title..":".. subtype .. "\n") end
    return(false)
  else
    if(do_trace) then print("[RELEASE alert @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title..":".. subtype .. "\n") end
  end

  released.ifid = ifid
  released.action = "release"

  local alert_json = json.encode(released)
  ntop.pushSqliteAlert(alert_json)
  ntop.pushAlertNotification(alert_json)

  return(true)
end

-- ##############################################

-- Convenient method to release multiple alerts on an entity
function alerts_api.releaseEntityAlerts(entity_info, alerts)
  if(alerts == nil) then
    alerts = interface.getEngagedAlerts(entity_info.alert_entity.entity_id, entity_info.alert_entity_val)
  end

  for _, alert in pairs(alerts) do
    -- NOTE: do not pass alerts here as a parameters as deleting items while
    -- does not work in lua
    alerts_api.release(entity_info, {
      alert_type = alert_consts.alert_types[alertTypeRaw(alert.alert_type)],
      alert_severity = alert_consts.alert_severities[alertSeverityRaw(alert.alert_severity)],
      alert_subtype = alert.alert_subtype,
      alert_granularity = alert_consts.alerts_granularities[sec2granularity(alert.alert_granularity)],
    })
  end
end

-- ##############################################
-- entity_info building functions
-- ##############################################

function alerts_api.hostAlertEntity(hostip, hostvlan)
  return {
    alert_entity = alert_consts.alert_entities.host,
    -- NOTE: keep in sync with C (Alertable::setEntityValue)
    alert_entity_val = hostinfo2hostkey({ip = hostip, vlan = hostvlan}, nil, true)
  }
end

-- ##############################################

function alerts_api.interfaceAlertEntity(ifid)
  return {
    alert_entity = alert_consts.alert_entities.interface,
    -- NOTE: keep in sync with C (Alertable::setEntityValue)
    alert_entity_val = string.format("iface_%d", ifid)
  }
end

-- ##############################################

function alerts_api.networkAlertEntity(network_cidr)
  return {
    alert_entity = alert_consts.alert_entities.network,
    -- NOTE: keep in sync with C (Alertable::setEntityValue)
    alert_entity_val = network_cidr
  }
end

-- ##############################################

function alerts_api.snmpInterfaceEntity(snmp_device, snmp_interface)
  return {
    alert_entity = alert_consts.alert_entities.snmp_device,
    alert_entity_val = string.format("%s_ifidx%d", snmp_device, snmp_interface)
  }
end

-- ##############################################

function alerts_api.snmpDeviceEntity(snmp_device)
  return {
    alert_entity = alert_consts.alert_entities.snmp_device,
    alert_entity_val = snmp_device
  }
end

-- ##############################################

function alerts_api.macEntity(mac)
  return {
    alert_entity = alert_consts.alert_entities.mac,
    alert_entity_val = mac
  }
end

-- ##############################################

function alerts_api.userEntity(user)
  return {
    alert_entity = alert_consts.alert_entities.user,
    alert_entity_val = user
  }
end

-- ##############################################

function alerts_api.processEntity(process)
  return {
    alert_entity = alert_consts.alert_entities.process,
    alert_entity_val = process
  }
end

-- ##############################################

function alerts_api.hostPoolEntity(pool_id)
  return {
    alert_entity = alert_consts.alert_entities.host_pool,
    alert_entity_val = tostring(pool_id)
  }
end

-- ##############################################

function alerts_api.periodicActivityEntity(activity_path)
  return {
    alert_entity = alert_consts.alert_entities.periodic_activity,
    alert_entity_val = activity_path
  }
end

-- ##############################################

function alerts_api.pingedHostEntity(host)
  return {
    alert_entity = alert_consts.alert_entities.pinged_host,
    alert_entity_val = host
  }
end

-- ##############################################

function alerts_api.categoryListsEntity(list_name)
  return {
    alert_entity = alert_consts.alert_entities.category_lists,
    alert_entity_val = list_name
  }
end

-- ##############################################

function alerts_api.influxdbEntity(dburl)
  return {
    alert_entity = alert_consts.alert_entities.influx_db,
    alert_entity_val = dburl
  }
end

-- ##############################################
-- type_info building functions
-- ##############################################

function alerts_api.userActivityType(scope, name, params, remote_addr, status)
  return({
    alert_type = alert_consts.alert_types.alert_user_activity,
    alert_severity = alert_consts.alert_severities.info,
    alert_type_params = {
      scope = scope, name = name, params = params,
      remote_addr = remote_addr, status = status,
    }
  })
end

-- ##############################################

function alerts_api.loginFailedType()
  return({
    alert_type = alert_consts.alert_types.alert_login_failed,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {},
  })
end

-- ##############################################

function alerts_api.processNotificationType(event_type, severity, msg_details)
  return({
    alert_type = alert_consts.alert_types.alert_process_notification,
    alert_severity = alert_consts.alert_severities[alertSeverityRaw(severity)],
    alert_type_params = {
      msg_details = msg_details,
      event_type = event_type,
    },
  })
end

-- ##############################################

function alerts_api.listDownloadFailedType(list_name, last_error)
  return({
    alert_type = alert_consts.alert_types.alert_list_download_failed,
    alert_severity = alert_consts.alert_severities.error,
    alert_type_params = {
      name=list_name, err=last_error
    }
  })
end

-- ##############################################

function alerts_api.influxdbDroppedPointsType(influxdb_url)
  return({
    alert_type = alert_consts.alert_types.alert_influxdb_export_failure,
    alert_severity = alert_consts.alert_severities.error,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {
      influxdb = influxdb_url,
    },
  })
end

-- ##############################################

function alerts_api.newDeviceType(device_name)
  return({
    alert_type = alert_consts.alert_types.alert_new_device,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      device = device_name,
    },
  })
end

-- ##############################################

function alerts_api.deviceHasConnectedType(device_name)
  return({
    alert_type = alert_consts.alert_types.alert_device_connection,
    alert_severity = alert_consts.alert_severities.info,
    alert_type_params = {
      device = device_name,
    },
  })
end

-- ##############################################

function alerts_api.deviceHasDisconnectedType(device_name)
  return({
    alert_type = alert_consts.alert_types.alert_device_disconnection,
    alert_severity = alert_consts.alert_severities.info,
    alert_type_params = {
      device = device_name,
    },
  })
end

-- ##############################################

function alerts_api.poolQuotaExceededType(pool, proto, subtype, value, quota)
  local host_pools_utils = require("host_pools_utils")

  return({
    alert_type = alert_consts.alert_types.alert_quota_exceeded,
    alert_subtype = subtype,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      pool = host_pools_utils.getPoolName(interface.getId(), pool),
      proto = proto, value = value, quota = quota,
    },
  })
end

-- ##############################################

function alerts_api.poolConnectionType(pool)
  local host_pools_utils = require("host_pools_utils")

  return({
    alert_type = alert_consts.alert_types.alert_host_pool_connection,
    alert_severity = alert_consts.alert_severities.info,
    alert_type_params = {
      pool = host_pools_utils.getPoolName(interface.getId(), pool),
    },
  })
end

-- ##############################################

function alerts_api.poolDisconnectionType(pool)
  local host_pools_utils = require("host_pools_utils")

  return({
    alert_type = alert_consts.alert_types.alert_host_pool_disconnection,
    alert_severity = alert_consts.alert_severities.info,
    alert_type_params = {
      pool = host_pools_utils.getPoolName(interface.getId(), pool),
    },
  })
end

-- ##############################################

function alerts_api.macIpAssociationChangeType(device, ip, old_mac, new_mac)
  return({
    alert_type = alert_consts.alert_types.alert_mac_ip_association_change,
    alert_subtype = string.format("%s_%s_%s", ip, old_mac, new_mac),
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      device = device, ip = ip,
      old_mac = old_mac, new_mac = new_mac,
    },
  })
end

-- ##############################################

function alerts_api.broadcastDomainTooLargeType(src_mac, dst_mac, vlan, spa, tpa)
  return({
    alert_type = alert_consts.alert_types.alert_broadcast_domain_too_large,
    -- Subtype is the concatenation of src and dst macs and ips and the VLAN. This
    -- allows the elerts engine to properly aggregate alerts when they have the same type and subtype
    alert_subtype = string.format("%u_%s_%s_%s_%s", vlan, src_mac, spa, dst_mac, tpa),
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      src_mac = src_mac, dst_mac = dst_mac,
      spa = spa, tpa = tpa, vlan_id = vlan,
    },
  })
end

-- ##############################################

function alerts_api.nfqFlushedType(ifname, pct, tot, dropped)
  return({
    alert_type = alert_consts.alert_types.alert_nfq_flushed,
    alert_severity = alert_consts.alert_severities.error,
    alert_type_params = {
      ifname = ifname, pct = pct, tot = tot, dropped = dropped,
    },
  })
end

-- ##############################################

function alerts_api.remoteToRemoteType(host_info, mac)
  return({
    alert_type = alert_consts.alert_types.alert_remote_to_remote,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      host = getResolvedAddress(host_info),
      mac = mac,
    },
  })
end

-- ##############################################

function alerts_api.ipOutsideDHCPRangeType(router_info, mac, client_mac, sender_mac)
  return({
    alert_type = alert_consts.alert_types.alert_ip_outsite_dhcp_range,
    alert_subtype = string.format("%s_%s_%s", hostinfo2hostkey(router_info), client_mac, sender_mac),
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      router_info = hostinfo2hostkey(router_info),
      mac = mac, client_mac = client_mac, sender_mac = sender_mac,
      router_host = getResolvedAddress(router_info),
    },
  })
end

-- ##############################################

function alerts_api.misconfiguredAppType(subtype)
  return({
    alert_type = alert_consts.alert_types.alert_misconfigured_app,
    alert_subtype = subtype,
    alert_severity = alert_consts.alert_severities.error,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {},
  })
end

-- ##############################################

function alerts_api.tooManyDropsType(drops, drop_perc, threshold)
  return({
    alert_type = alert_consts.alert_types.alert_too_many_drops,
    alert_severity = alert_consts.alert_severities.error,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {
      drops = drops, drop_perc = drop_perc, edge = threshold,
    },
  })
end

-- ##############################################

function alerts_api.userScriptCallsDrops(subdir, drops)
  return({
    alert_type = alert_consts.alert_types.alert_user_script_calls_drops,
    alert_severity = alert_consts.alert_severities.error,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_subtype = subdir,
    alert_type_params = {
      drops = drops,
    },
  })
end

-- ##############################################

function alerts_api.slowPurgeType(idle, idle_perc, threshold)
  return({
    alert_type = alert_consts.alert_types.alert_slow_purge,
    alert_severity = alert_consts.alert_severities.warning,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {
      idle = idle, idle_perc = idle_perc, edge = threshold,
    },
  })
end

-- ##############################################

function alerts_api.requestReplyRatioType(key, requests, replies, granularity)
  return({
    alert_type = alert_consts.alert_types.alert_request_reply_ratio,
    alert_subtype = key,
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      requests = requests, replies = replies,
    }
  })
end

-- ##############################################

function alerts_api.anomalousTCPFlagsType(num_syn, num_rst, ratio, is_sent, granularity)
  return({
    alert_type = alert_consts.alert_types.alert_anomalous_tcp_flags,
    alert_subtype = ternary(is_sent, "sent", "rcvd"),
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      num_syn = num_syn,
      num_rst = num_rst,
      is_sent = is_sent,
      ratio = ratio,
    }
  })
end

-- ##############################################

function alerts_api.misbehavingFlowsRatioType(misbehaving_flows, total_flows, ratio, is_sent, granularity)
  return({
    alert_type = alert_consts.alert_types.alert_misbehaving_flows_ratio,
    alert_subtype = ternary(is_sent, "sent", "rcvd"),
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      misbehaving_flows = misbehaving_flows,
      total_flows = total_flows,
      is_sent = is_sent,
      ratio = ratio,
    }
  })
end

-- ##############################################

function alerts_api.ghostNetworkType(network, granularity)
  return({
    alert_type = alert_consts.alert_types.alert_ghost_network,
    alert_subtype = network,
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {},
  })
end

-- ##############################################

-- TODO document
function alerts_api.checkThresholdAlert(params, alert_type, value)
  local script = params.user_script
  local threshold_config = params.alert_config
  local alarmed = false

  local threshold_type = {
    alert_type = alert_type,
    alert_subtype = script.key,
    alert_granularity = alert_consts.alerts_granularities[params.granularity],
    alert_severity = alert_consts.alert_severities.error,
    alert_type_params = {
      metric = params.user_script.key,
      value = value,
      operator = threshold_config.operator,
      threshold = threshold_config.threshold,
    }
  }

  if(threshold_config.operator == "lt") then
    if(value < threshold_config.threshold) then alarmed = true end
  else
    if(value > threshold_config.threshold) then alarmed = true end
  end

  if(alarmed) then
    return(alerts_api.trigger(params.alert_entity, threshold_type, nil, params.cur_alerts))
  else
    return(alerts_api.release(params.alert_entity, threshold_type, nil, params.cur_alerts))
  end
end

-- ##############################################

-- An alert check function which checks for anomalies.
-- The user_script key is the type of the anomaly to check.
-- The user_script must implement a anomaly_type_builder(anomaly_key) function
-- which returns a type_info for the given anomaly.
function alerts_api.anomaly_check_function(params)
  local anomal_key = params.user_script.key
  local type_info = params.user_script.anomaly_type_builder(anomal_key)

  if params.entity_info.anomalies[anomal_key] then
    return alerts_api.trigger(params.alert_entity, type_info, nil, params.cur_alerts)
  else
    return alerts_api.release(params.alert_entity, type_info, nil, params.cur_alerts)
  end
end

-- ##############################################

-- @brief Performs a difference between the current metric value and
-- the previous saved value and saves the current value for next call.
-- @param reg lua C context pointer to the alertable entity storage
-- @param metric_name name of the metric to retrieve
-- @param granularity the granularity string
-- @param curr_val the current metric value
-- @param skip_first if true, 0 will be returned when no cached value is present
-- @return the difference between current and previous value
local function delta_val(reg, metric_name, granularity, curr_val, skip_first)
   local granularity_num = granularity2id(granularity)
   local key = string.format("%s:%s", metric_name, granularity_num)

   -- Read cached value and purify it
   local prev_val = tonumber(reg.getCachedAlertValue(key, granularity_num))

   -- Save the value for the next round
   reg.setCachedAlertValue(key, tostring(curr_val), granularity_num)

   if((skip_first == true) and (prev_val == nil)) then
      return(0)
   else
      return(curr_val - (prev_val or 0))
   end
end

-- ##############################################

function alerts_api.host_delta_val(metric_name, granularity, curr_val, skip_first)
  return(delta_val(host --[[ the host Lua reg ]], metric_name, granularity, curr_val, skip_first))
end

function alerts_api.interface_delta_val(metric_name, granularity, curr_val, skip_first)
  return(delta_val(interface --[[ the interface Lua reg ]], metric_name, granularity, curr_val, skip_first))
end

function alerts_api.network_delta_val(metric_name, granularity, curr_val, skip_first)
  return(delta_val(network --[[ the network Lua reg ]], metric_name, granularity, curr_val, skip_first))
end

-- ##############################################

function alerts_api.application_bytes(info, application_name)
   local curr_val = 0

   if info["ndpi"] and info["ndpi"][application_name] then
      curr_val = info["ndpi"][application_name]["bytes.sent"] + info["ndpi"][application_name]["bytes.rcvd"]
   end

   return curr_val
end

-- ##############################################

function alerts_api.category_bytes(info, category_name)
   local curr_val = 0

   if info["ndpi_categories"] and info["ndpi_categories"][category_name] then
      curr_val = info["ndpi_categories"][category_name]["bytes.sent"] + info["ndpi_categories"][category_name]["bytes.rcvd"]
   end

   return curr_val
end

-- ##############################################
-- ENTITY DISABLED ALERTS API
-- ##############################################

local function getEntityDisabledAlertsBitmapHash(ifid, entity_type)
  -- NOTE: should be able to accept strings for alerts_api.purgeAlertsPrefs
  if(type(ifid) == "number") then ifid = string.format("%d", ifid) end
  if(type(entity_type) == "number") then entity_type = string.format("%u", entity_type) end

  return string.format("ntopng.prefs.alerts.ifid_%s.disabled_alerts.entity_%s", ifid, entity_type)
end

-- ##############################################

-- @brief Get a table containing the disabled alert bitmaps of the alertable entities
-- for the given entity_type
-- @return {entity_key -> disabled_alerts_bitmap}
function alerts_api.getEntityTypeDisabledAlertsBitmap(ifid, entity_type)
  local hash = getEntityDisabledAlertsBitmapHash(ifid, entity_type)
  local rv = ntop.getHashAllCache(hash) or {}

  for k, v in pairs(rv) do
    rv[k] = tonumber(v)
  end

  return(rv)
end

-- ##############################################

-- A cache variable to know if there are configured disabled alerts
local function getInterfaceHasDisabledAlertsKey(ifid)
  -- NOTE: should be able to accept strings for alerts_api.purgeAlertsPrefs
  if(type(ifid) == "number") then ifid = string.format("%d", ifid) end

  return(string.format("ntopng.cache.alerts.ifid_%s.has_disabled_alerts", ifid))
end

-- ##############################################

-- @brief Set the disabled alerts bitmap for the given alertable entity
function alerts_api.setEntityAlertsDisabledBitmap(ifid, entity_type, entity_val, bitmap)
  local hash = getEntityDisabledAlertsBitmapHash(ifid, entity_type)

  if(bitmap == 0) then
    -- No status disabled
    ntop.delHashCache(hash, entity_val)
  else
    ntop.setHashCache(hash, entity_val, string.format("%u", bitmap))
  end

  -- Invalidate the disabled alerts cache
  ntop.delCache(getInterfaceHasDisabledAlertsKey(ifid))

  -- Reload the periodic scripts as the configuration has changed
  ntop.reloadPeriodicScripts()
end

-- ##############################################

-- @brief Get the disabled alert bitmap for the given entity
function alerts_api.getEntityAlertsDisabledBitmap(ifid, entity_type, entity_val)
  local hash = getEntityDisabledAlertsBitmapHash(ifid, entity_type)

  return(tonumber(ntop.getHashCache(hash, entity_val)) or 0)
end

-- ##############################################

-- A cache is used to reduce Redis accesses
local cache_disabled_by_entity_type = {}

-- @brief Check if the alert_type is disabled for the given entity
function alerts_api.isEntityAlertDisabled(ifid, entity_type, entity_val, alert_id)
  local entities_disabled = cache_disabled_by_entity_type[entity_type]

  if(entities_disabled == nil) then
    -- Local from redis
    entities_disabled = alerts_api.getEntityTypeDisabledAlertsBitmap(ifid, entity_type)
    cache_disabled_by_entity_type[entity_type] = entities_disabled
  end

  local bitmap = entities_disabled[entity_val]

  if((bitmap ~= nil) and ntop.bitmapIsSet(bitmap, alert_id)) then
    return(true)
  end

  return(false)
end

-- ##############################################

-- @brief Check if there are any entities with disabled alerts configured
function alerts_api.hasEntitiesWithAlertsDisabled(ifid)
  local has_disabled_cache_key = getInterfaceHasDisabledAlertsKey(ifid)
  local cached_val = ntop.getCache(has_disabled_cache_key) or ""

  if(cached_val ~= "") then
    return(cached_val == "1")
  end

  -- Slow search
  local available_entities = alert_consts.alert_entities
  local found = false

  for _, entity in pairs(available_entities) do
    local keys = ntop.getKeysCache(getEntityDisabledAlertsBitmapHash(ifid, entity.entity_id))

    if(not table.empty(keys)) then
      found = true
      break
    end
  end

  ntop.setCache(has_disabled_cache_key, ternary(found, "1", "0"), 3600 --[[ 1h ]])
  return(found)
end

-- ##############################################

-- @brief Get all the disabled alerts by entity
-- @return {entity_type -> {entity_val1 -> bitmap, entity_val2 -> bitmap, ...}, ...}
function alerts_api.getAllEntitiesDisabledAlerts(ifid)
  local available_entities = alert_consts.alert_entities
  local res = {}

  for entity_key, entity in pairs(available_entities) do
    local hash = getEntityDisabledAlertsBitmapHash(ifid, entity.entity_id)
    local entities_bitmaps = ntop.getHashAllCache(hash) or {}
    local is_empty = true

    for k, v in pairs(entities_bitmaps) do
      entities_bitmaps[k] = tonumber(v)
      is_empty = false
    end

    if(not is_empty) then
      res[entity_key] = entities_bitmaps
    end
  end

  return(res)
end

-- ##############################################
-- HOST DISABLED FLOW STATUS API
-- ##############################################

local function getHostDisabledStatusBitmapHash(ifid)
  -- NOTE: should be able to accept strings for alerts_api.purgeAlertsPrefs
  if(type(ifid) == "number") then ifid = string.format("%d", ifid) end

  return(string.format("ntopng.prefs.alerts.ifid_%s.disabled_status", ifid))
end

-- ##############################################

-- @brief Get the bitmap of disabled flow status for an host
function alerts_api.getHostDisabledStatusBitmap(ifid, hostkey)
  local hash = getHostDisabledStatusBitmapHash(ifid)

  return(tonumber(ntop.getHashCache(hash, hostkey)) or 0)
end

-- ##############################################

-- @brief Set the bitmap of disabled flow status for an host
function alerts_api.setHostDisabledStatusBitmap(ifid, hostkey, bitmap)
  local hash = getHostDisabledStatusBitmapHash(ifid)

  if(bitmap == 0) then
    -- No status disabled
    ntop.delHashCache(hash, hostkey)
  else
    ntop.setHashCache(hash, hostkey, string.format("%u", bitmap))
  end

  -- Reload the periodic scripts as the configuration has changed
  ntop.reloadPeriodicScripts()
end

-- ##############################################

-- @brief Get all the hosts disabled flow status bitmaps
function alerts_api.getAllHostsDisabledStatusBitmaps(ifid)
  local hash = getHostDisabledStatusBitmapHash(ifid)
  local rv = ntop.getHashAllCache(hash) or {}

  for k, v in pairs(rv) do
    rv[k] = tonumber(v)
  end

  return(rv)
end

-- ##############################################
-- SUPPRESSED ALERTS API
-- ##############################################

local function getSuppressedSetKey(ifid, entity_type)
  -- NOTE: should be able to accept strings for alerts_api.purgeAlertsPrefs
  if(type(ifid) == "number") then ifid = string.format("%d", ifid) end
  if(type(entity_type) == "number") then entity_type = string.format("%u", entity_type) end

  return(string.format("ntopng.prefs.alerts.ifid_%s.suppressed_alerts.entity_%s", ifid, entity_type))
end

-- @brief Get the suppressed alertable entities given the entity_type
function alerts_api.getSuppressedEntityAlerts(ifid, entity_type)
  local setk = getSuppressedSetKey(ifid, entity_type)
  local suppressed_entities = ntop.getMembersCache(setk) or {}
  local ret = {}

  for _, v in pairs(suppressed_entities) do
    ret[v] = true
  end

  return(ret)
end

-- ##############################################

-- @brief Enable/disable suppressed alerts on the given alertable entity
function alerts_api.setSuppressedAlerts(ifid, entity_type, entity_value, suppressed)
  local setk = getSuppressedSetKey(ifid, entity_type)

  if(suppressed) then
    ntop.setMembersCache(setk, entity_value)
  else
    ntop.delMembersCache(setk, entity_value)
  end
end

-- ##############################################

-- A cache is used to reduce Redis accesses
local cache_suppressed_by_entity_type = {}

-- @brief Check if the given entity has suppressed alerts
function alerts_api.hasSuppressedAlerts(ifid, entity_type, entity_value)
  local entities_suppressed = cache_suppressed_by_entity_type[entity_type]

  if(entities_suppressed == nil) then
    -- Local from redis
    entities_suppressed = alerts_api.getSuppressedEntityAlerts(ifid, entity_type)
    cache_suppressed_by_entity_type[entity_type] = entities_suppressed
  end

  return(entities_suppressed[entity_value] ~= nil)
end

-- ##############################################

-- @brief Purge all the alerts prefs set by this module
function alerts_api.purgeAlertsPrefs()
  -- Purge all the alerts prefs on all the interfaces
  deleteCachePattern(getEntityDisabledAlertsBitmapHash("*", "*"))
  deleteCachePattern(getSuppressedSetKey("*", "*"))
  deleteCachePattern(getInterfaceHasDisabledAlertsKey("*"))
  deleteCachePattern(getHostDisabledStatusBitmapHash("*"))
end

-- ##############################################

function alerts_api.invokeScriptHook(user_script, configset_id, hook_fn, p1, p2, p3)
  current_script = user_script
  current_configset_id = configset_id

  return(hook_fn(p1, p2, p3))
end

-- ##############################################

return(alerts_api)

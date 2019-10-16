--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")
local alert_endpoints = require("alert_endpoints_utils")
local alert_consts = require("alert_consts")
local os_utils = require("os_utils")
local do_trace = false

local alerts_api = {}

-- NOTE: sqlite can handle about 10-50 alerts/sec
local MAX_NUM_ENQUEUED_ALERT_PER_INTERFACE = 256

-- Just helpers
local str_2_periodicity = {
  ["min"]     = 60,
  ["5mins"]   = 300,
  ["hour"]    = 3600,
  ["day"]     = 86400,
}

local known_alerts = {}

-- ##############################################

local function getAlertEventQueue(ifid)
  return string.format("ntopng.cache.ifid_%d.alerts_events_queue", ifid)
end

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

local function getEntityDisabledAlertsCountersKey(ifid, entity, entity_val)
  return(string.format("ntopng.cache.alerts.ifid_%d.%d_%s", ifid, entity, entity_val))
end

local function incDisabledAlertsCount(ifid, granularity_id, entity, entity_val, alert_type)
  local key = getEntityDisabledAlertsCountersKey(ifid, entity, entity_val)

  -- NOTE: using separate keys based on granularity to avoid concurrency issues
  counter_key = string.format("%d_%d", granularity_id, alert_type)

  local val = tonumber(ntop.getHashCache(key, counter_key)) or 0
  val = val + 1
  ntop.setHashCache(key, counter_key, string.format("%d", val))
  return(val)
end

-- ##############################################

local function deleteEntityDisabledAlertsCountersKey(ifid, entity, entity_val, target_type)
  local key = getEntityDisabledAlertsCountersKey(ifid, entity, entity_val)
  local entity_counters = ntop.getHashAllCache(key) or {}

  for what, counter in pairs(entity_counters) do
    local parts = string.split(what, "_")

    if((parts) and (#parts == 2)) then
      local alert_type = tonumber(parts[2])

      if(alert_type == target_type) then
        ntop.delHashCache(key, what)
      end
    end
  end
end

-- ##############################################

function alerts_api.getEntityDisabledAlertsCounters(ifid, entity, entity_val)
  local key = getEntityDisabledAlertsCountersKey(ifid, entity, entity_val)
  local entity_counters = ntop.getHashAllCache(key) or {}
  local by_alert_type = {}

  for what, counter in pairs(entity_counters) do
    local parts = string.split(what, "_")

    if((parts) and (#parts == 2)) then
      local granularity_id = tonumber(parts[1])
      local alert_type = tonumber(parts[2])

      by_alert_type[alert_type] = by_alert_type[alert_type] or 0
      by_alert_type[alert_type] = by_alert_type[alert_type] + counter
    end
  end

  return(by_alert_type)
end

-- ##############################################

local function get_alert_triggered_key(type_info)
  return(string.format("%d@%s", type_info.alert_type.alert_id, type_info.alert_subtype or ""))
end

-- ##############################################

-- Enqueue a store alert action on the DB to be performed asynchronously
local function enqueueStoreAlert(ifid, alert)
  local trim = nil

  local alert_json = json.encode(alert)
  local queue = getAlertEventQueue(ifid)

  if(ntop.llenCache(queue) > MAX_NUM_ENQUEUED_ALERT_PER_INTERFACE) then
    trim = math.ceil(MAX_NUM_ENQUEUED_ALERT_PER_INTERFACE/2)
    traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Alerts event queue too long: dropping %u alerts", trim))

    interface.incNumDroppedAlerts(trim)
  end

  ntop.rpushCache(queue, alert_json, trim)
  return(true)
end

-- ##############################################

-- Performs the alert store asynchronously.
-- This is necessary both to avoid paying the database io cost inside
-- the other scripts and as a necessity to avoid a deadlock on the
-- host hash in the host.lua script
function alerts_api.checkPendingStoreAlerts(deadline)
  if(not areAlertsEnabled()) then
    return(false)
  end

  local ifnames = interface.getIfNames()
  ifnames[getSystemInterfaceId()] = getSystemInterfaceName()

  for ifid, _ in pairs(ifnames) do
    interface.select(ifid)
    local queue = getAlertEventQueue(ifid)

    while(true) do
      local alert_json = ntop.lpopCache(queue)

      if(not alert_json) then
        break
      end

      local alert = json.decode(alert_json)

      if(alert) then
        interface.storeAlert(
          alert.alert_tstamp, alert.alert_tstamp_end, alert.alert_granularity,
          alert.alert_type, alert.alert_subtype, alert.alert_severity,
          alert.alert_entity, alert.alert_entity_val,
          alert.alert_json)
      end

      if(os.time() > deadline) then
        return(false)
      end
    end
  end

  return(true)
end

-- ##############################################

local function pushAlertNotification(ifid, action, alert)
  alert.ifid = ifid
  alert.action = action
  ntop.rpushCache("ntopng.alerts.notifications_queue", json.encode(alert))
end

-- ##############################################

--! @brief Stores a single alert (or event) into the alerts database
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @return true if the alert was successfully stored, false otherwise
function alerts_api.store(entity_info, type_info, when)
  local force = false
  local alert_json = json.encode(type_info.alert_type_params)
  local ifid = interface.getId()
  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or -1
  local alert_json = plain_message or json.encode(type_info.alert_type_params)
  local subtype = type_info.alert_subtype or ""
  when = when or os.time()

  if(not areAlertsEnabled()) then
    return(false)
  end

  if alerts_api.isEntityAlertDisabled(ifid, entity_info.alert_entity.entity_id, entity_info.alert_entity_val, type_info.alert_type.alert_id) then
    incDisabledAlertsCount(ifid, granularity_id, entity_info.alert_entity.entity_id, entity_info.alert_entity_val, type_info.alert_type.alert_id)
    return(false)
  end

  -- Here the alert is considered stored. The actual store will be performed
  -- asynchronously

  -- NOTE: keep in sync with SQLite alert format in AlertsManager.cpp
  local alert_to_store = {
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

  if(entity_info.alert_entity.entity_id == alertEntity("host")) then
    -- NOTE: for engaged alerts this operation is performed during trigger in C
    interface.incTotalHostAlerts(entity_info.alert_entity_val, type_info.alert_type.alert_id)
  end

  enqueueStoreAlert(ifid, alert_to_store)
  pushAlertNotification(ifid, "store", alert_to_store)
  return(true)
end

-- ##############################################

function alerts_api.storeFlowAlert(alert_type, alert_severity, flow_info)
   if flow then
      -- flow.storeAlert(alert_type.alert_id, alert_severity.severity_id, json.encode(flow_info))
   end
end

-- ##############################################

--! @brief Trigger an alert of given type on the entity
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @return true on if the alert was triggered, false otherwise
--! @note The actual trigger is performed asynchronously
--! @note false is also returned if an existing alert is found and refreshed
function alerts_api.trigger(entity_info, type_info, when)
  when = when or os.time()
  local ifid = interface.getId()

  if(not areAlertsEnabled()) then
    return(false)
  end

  if(type_info.alert_granularity == nil) then
    alertErrorTraceback("Missing mandatory granularity")
    return(false)
  end

  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or 0 --[[ 0 is aperiodic ]]
  local subtype = type_info.alert_subtype or ""
  local alert_json = json.encode(type_info.alert_type_params)
  local is_disabled = alerts_api.isEntityAlertDisabled(ifid, entity_info.alert_entity.entity_id, entity_info.alert_entity_val, type_info.alert_type.alert_id)
  local triggered
  local alert_key_name = get_alert_triggered_key(type_info)

  local params = {
    alert_key_name, granularity_id,
    type_info.alert_severity.severity_id, type_info.alert_type.alert_id,
    subtype, alert_json, is_disabled
  }

  if(entity_info.alert_entity.entity_id == alertEntity("host")) then
    host.checkContext(entity_info.alert_entity_val)
    triggered = host.storeTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alertEntity("interface")) then
    interface.checkContext(entity_info.alert_entity_val)
    triggered = interface.storeTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alertEntity("network")) then
    network.checkContext(entity_info.alert_entity_val)
    triggered = network.storeTriggeredAlert(table.unpack(params))
  else
    triggered = interface.triggerExternalAlert(entity_info.alert_entity.entity_id, entity_info.alert_entity_val, table.unpack(params))
  end

  if(triggered == nil) then
    if(do_trace) then print("[Don't Trigger alert (already triggered?) @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title..":".. subtype .. "\n") end
    return(false)
  elseif(is_disabled) then
    if(do_trace) then print("[COUNT Disabled alert @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title..":".. subtype .. "\n") end

    incDisabledAlertsCount(ifid, granularity_id, entity_info.alert_entity.entity_id, entity_info.alert_entity_val, type_info.alert_type.alert_id)
    return(false)
  else
    if(do_trace) then print("[TRIGGER alert @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title..":".. subtype .. "\n") end
  end

  pushAlertNotification(ifid, "engage", triggered)
  return(true)
end

-- ##############################################

--! @brief Release an alert of given type on the entity
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @note The actual release is performed asynchronously
--! @return true on success, false otherwise
function alerts_api.release(entity_info, type_info, when)
  local when = when or os.time()
  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or 0 --[[ 0 is aperiodic ]]
  local subtype = type_info.alert_subtype or ""
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

  if(entity_info.alert_entity.entity_id == alertEntity("host")) then
    host.checkContext(entity_info.alert_entity_val)
    released = host.releaseTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alertEntity("interface")) then
    interface.checkContext(entity_info.alert_entity_val)
    released = interface.releaseTriggeredAlert(table.unpack(params))
  elseif(entity_info.alert_entity.entity_id == alertEntity("network")) then
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

  enqueueStoreAlert(ifid, released)
  pushAlertNotification(ifid, "release", released)
  return(true)
end

-- ##############################################

-- Convenient method to release multiple alerts on an entity
function alerts_api.releaseEntityAlerts(entity_info, alerts)
  if(alerts == nil) then
    alerts = interface.getEngagedAlerts(entity_info.alert_entity.entity_id, entity_info.alert_entity_val)
  end

  for _, alert in pairs(alerts) do
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

function alerts_api.thresholdCrossType(granularity, metric, value, operator, threshold)
  return({
    alert_type = alert_consts.alert_types.alert_threshold_cross,
    alert_subtype = string.format("%s_%s", granularity, metric),
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_severity = alert_consts.alert_severities.error,
    alert_type_params = {
      metric = metric, value = value,
      operator = operator, threshold = threshold,
    }
  })
end

-- ##############################################

function alerts_api.synFloodType(granularity, metric, value, operator, threshold)
  return({
    alert_type = alert_consts.alert_types.alert_tcp_syn_flood,
    alert_subtype = metric,
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_severity = alert_consts.alert_severities.error,
    alert_type_params = {
      value = value,
      threshold = threshold,
    }
  })
end

-- ##############################################

function alerts_api.flowFloodType(granularity, metric, value, operator, threshold)
  return({
    alert_type = alert_consts.alert_types.alert_flows_flood,
    alert_subtype = metric,
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_severity = alert_consts.alert_severities.error,
    alert_type_params = {
      value = value,
      threshold = threshold,
    }
  })
end

-- ##############################################

function alerts_api.pingIssuesType(value, threshold, ip)
  return({
    alert_type = alert_consts.alert_types.alert_ping_issues,
    alert_severity = alert_consts.alert_severities.warning,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {
      value = value, threshold = threshold, ip = ip,
    }
  })
end

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

function alerts_api.slowPeriodicActivityType(duration_ms, max_duration_ms)
  return({
    alert_type = alert_consts.alert_types.alert_slow_periodic_activity,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      duration_ms = duration_ms,
      max_duration_ms = max_duration_ms
    },
  })
end

-- ##############################################

function alerts_api.ipOutsideDHCPRangeType(router_info, mac, client_mac, sender_mac)
  return({
    alert_type = alert_consts.alert_types.alert_ip_outsite_dhcp_range,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      router_info = hostinfo2hostkey(router_info),
      mac = mac, client_mac = client_mac, sender_mac = sender_mac,
      router_host = getResolvedAddress(router_info),
    },
  })
end

-- ##############################################

function alerts_api.snmpInterfaceStatusChangeType(device, interface, interface_name, status)
  return({
    alert_type = alert_consts.alert_types.alert_port_status_change,
    alert_severity = alert_consts.alert_severities.info,
    alert_type_params = {
      device = device, interface = interface,
      interface_name = interface_name, status = status,
    },
  })
end

-- ##############################################

function alerts_api.snmpInterfaceDuplexStatusChangeType(device, interface, interface_name, status)
  return({
    alert_type = alert_consts.alert_types.alert_port_duplexstatus_change,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      device = device, interface = interface,
      interface_name = interface_name, status = status,
    },
  })
end

-- ##############################################

function alerts_api.snmpInterfaceErrorsType(device, interface, interface_name)
  return({
    alert_type = alert_consts.alert_types.alert_port_errors,
    alert_severity = alert_consts.alert_severities.info,
    alert_type_params = {
      device = device, interface = interface,
      interface_name = interface_name,
    },
  })
end

-- ##############################################

function alerts_api.snmpPortLoadThresholdExceededType(device, interface, interface_name, interface_load, in_direction)
  return({
    alert_type = alert_consts.alert_types.alert_port_load_threshold_exceeded,
    alert_severity = alert_consts.alert_severities.warning,
    alert_type_params = {
      device = device, interface = interface,
      interface_name = interface_name,
      interface_load = interface_load, in_direction = in_direction,
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

function alerts_api.slowStatsUpdateType()
  return({
    alert_type = alert_consts.alert_types.alert_slow_stats_update,
    alert_severity = alert_consts.alert_severities.warning,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {},
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

-- An alert check function which performs threshold checks of a value
-- against a configured threshold and generates a threshold_cross alert
-- if the value is above the threshold.
-- A user script (see user_scripts.lua) must implement:
--   get_threshold_value(granularity, entity_info)
--   A function, which returns the current value to be compared agains the threshold
-- The user_script may implement an additional threshold_type_builder function which
-- which returns a type_info. Check alerts_api.thresholdCrossType for the threshold_type_builder signature.
function alerts_api.threshold_check_function(params)
  local alarmed = false
  local value = params.user_script.get_threshold_value(params.granularity, params.entity_info)
  local threshold_config = params.alert_config

  local threshold_edge = tonumber(threshold_config.edge)
  local threshold_builder = ternary(params.user_script.threshold_type_builder, params.user_script.threshold_type_builder, alerts_api.thresholdCrossType)
  local threshold_type = threshold_builder(params.granularity, params.user_script.key, value, threshold_config.operator, threshold_edge)

  if(threshold_config.operator == "lt") then
    if(value < threshold_edge) then alarmed = true end
  else
    if(value > threshold_edge) then alarmed = true end
  end

  if(alarmed) then
    return(alerts_api.trigger(params.alert_entity, threshold_type))
  else
    return(alerts_api.release(params.alert_entity, threshold_type))
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
    return alerts_api.trigger(params.alert_entity, type_info)
  else
    return alerts_api.release(params.alert_entity, type_info)
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

local function getEntityDisabledAlertsBitmapKey(ifid, entity, entity_val)
  return string.format("ntopng.prefs.alerts.ifid_%d.disabled_alerts.__%s__%s", ifid, entity, entity_val)
end

-- ##############################################

function alerts_api.getEntityAlertsDisabled(ifid, entity, entity_val)
  local bitmap = tonumber(ntop.getPref(getEntityDisabledAlertsBitmapKey(ifid, entity, entity_val))) or 0
  -- traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("ifid: %d, entity: %s, val: %s -> bitmap=%x", ifid, alertEntityRaw(entity), entity_val, bitmap))
  return(bitmap)
end

-- ##############################################

function alerts_api.setEntityAlertsDisabled(ifid, entity, entity_val, bitmap)
  local key = getEntityDisabledAlertsBitmapKey(ifid, entity, entity_val)

  if(bitmap == 0) then
    ntop.delCache(key)
  else
    ntop.setPref(key, string.format("%u", bitmap))
  end
end

-- ##############################################

local function toggleEntityAlert(ifid, entity, entity_val, alert_type, disable)
  alert_type = tonumber(alert_type)
  bitmap = alerts_api.getEntityAlertsDisabled(ifid, entity, entity_val)

  if(disable) then
    bitmap = ntop.bitmapSet(bitmap, alert_type)
  else
    bitmap = ntop.bitmapClear(bitmap, alert_type)
    deleteEntityDisabledAlertsCountersKey(ifid, entity, entity_val, alert_type)
  end

  alerts_api.setEntityAlertsDisabled(ifid, entity, entity_val, bitmap)
  return(bitmap)
end

-- ##############################################

function alerts_api.disableEntityAlert(ifid, entity, entity_val, alert_type)
  return(toggleEntityAlert(ifid, entity, entity_val, alert_type, true))
end

-- ##############################################

function alerts_api.enableEntityAlert(ifid, entity, entity_val, alert_type)
  return(toggleEntityAlert(ifid, entity, entity_val, alert_type, false))
end

-- ##############################################

function alerts_api.isEntityAlertDisabled(ifid, entity, entity_val, alert_type)
  local bitmap = alerts_api.getEntityAlertsDisabled(ifid, entity, entity_val)
  return(ntop.bitmapIsSet(bitmap, tonumber(alert_type)))
end

-- ##############################################

function alerts_api.hasEntitiesWithAlertsDisabled(ifid)
  return(table.len(ntop.getKeysCache(getEntityDisabledAlertsBitmapKey(ifid, "*", "*"))) > 0)
end

-- ##############################################

function alerts_api.listEntitiesWithAlertsDisabled(ifid)
  local keys = ntop.getKeysCache(getEntityDisabledAlertsBitmapKey(ifid, "*", "*")) or {}
  local res = {}

  for key in pairs(keys) do
    local parts = string.split(key, "__")

    if((parts) and (#parts == 3)) then
      local entity = tonumber(parts[2])
      local entity_val = parts[3]

      res[entity] = res[entity] or {}
      res[entity][entity_val] = true
    end
  end

  return(res)
end

-- ##############################################

return(alerts_api)

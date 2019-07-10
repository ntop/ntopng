--
-- (C) 2013-19 - ntop.org
--

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local dirs = ntop.getDirs()
local json = require("dkjson")
local alert_endpoints = require("alert_endpoints_utils")
local alert_consts = require("alert_consts")
local os_utils = require("os_utils")
local do_trace = false

local alerts = {}

local MAX_NUM_ENQUEUED_ALERTS_EVENTS = 100
local ALERTS_EVENTS_QUEUE = "ntopng.cache.alerts_events_queue"
local ALERT_CHECKS_MODULES_BASEDIR = dirs.installdir .. "/scripts/callbacks/interface/alerts"

-- Just helpers
local str_2_periodicity = {
  ["min"]     = 60,
  ["5mins"]   = 300,
  ["hour"]    = 3600,
  ["day"]     = 86400,
}

local known_alerts = {}

-- ##############################################

local function makeAlertId(alert_type, subtype, periodicity, alert_entity)
  return(string.format("%s_%s_%s_%s", alert_type, subtype or "", periodicity or "", alert_entity))
end

function alerts:getId()
  return(makeAlertId(self.type_id, self.subtype, self.periodicity, self.entity_type_id))
end

-- ##############################################

local function alertErrorTraceback(msg)
  traceError(TRACE_ERROR, TRACE_CONSOLE, msg)
  traceError(TRACE_ERROR, TRACE_CONSOLE, debug.traceback())
end

-- ##############################################

--! @brief Creates an alert object
--! @param metadata the information about the alert type and severity
--! @return an alert object on success, nil on error
function alerts:newAlert(metadata)
  if(metadata == nil) then
    alertErrorTraceback("alerts:newAlert() missing argument")
    return(nil)
  end

  local obj = table.clone(metadata)

  if type(obj.periodicity) == "string" then
    if(str_2_periodicity[obj.periodicity]) then
      obj.periodicity = str_2_periodicity[obj.periodicity]
    else
      alertErrorTraceback("unknown periodicity '".. obj.periodicity .."'")
      return(nil)
    end
  end

  if(type(obj.entity) ~= "string") then alertErrorTraceback("'entity' string required") end
  if(type(obj.type) ~= "string") then alertErrorTraceback("'type' string required") end
  if(type(obj.severity) ~= "string") then alertErrorTraceback("'severity' string required") end

  obj.entity_type_id = alertEntity(obj.entity)
  obj.type_id = alertType(obj.type)
  obj.severity_id = alertSeverity(obj.severity)
  obj.periodicity = obj.periodicity or 0

  if(type(obj.entity_type_id) ~= "number") then alertErrorTraceback("unknown entity_type '".. obj.entity .."'") end
  if(type(obj.type_id) ~= "number") then alertErrorTraceback("unknown alert_type '".. obj.type .."'") end
  if(type(obj.severity_id) ~= "number") then alertErrorTraceback("unknown severity '".. obj.severity .."'") end

  local alert_id = makeAlertId(obj.type_id, obj.subtype, obj.periodicity, obj.entity_type_id)
  known_alerts[alert_id] = obj

  setmetatable(obj, self)
  self.__index = self

  return(obj)
end

-- ##############################################

--! @brief Triggers a new alert or refreshes an existing one (if already engaged)
--! @param entity_value the string representing the entity of the alert (e.g. "192.168.1.1")
--! @param alert_message the message (string) or json (table) to store
--! @param when (optional) the time when the trigger event occurs
--! @return true on success, false otherwise
function alerts:trigger(entity_value, alert_message, when)
  local force = false
  local msg = alert_message
  when = when or os.time()

  if(type(alert_message) == "table") then
    msg = json.encode(alert_message)
  end

  local rv = interface.triggerAlert(when, self.periodicity,
    self.type_id, self.severity_id,
    self.entity_type_id, entity_value, msg, self.subtype)

  if(rv ~= nil) then
    if(rv.success and rv.new_alert) then
      local action = ternary(self.periodicity, "engage", "store")
      local message = {
        ifid = interface.getId(),
        entity_type = self.entity_type_id,
        entity_value = entity_value,
        type = self.entity_type_id,
        severity = self.severity_id,
        message = msg,
        tstamp = when,
        action = action,
     }

     alert_endpoints.dispatchNotification(message, json.encode(message))
    end
  end

  return(rv.success)
end

-- ##############################################

--! @brief Manually releases an engaged alert
--! @param entity_value the string representing the entity of the alert (e.g. "192.168.1.1")
--! @param when (optional) the time when the release event occurs
--! @note Alerts are also automatically released based on their periodicity,
--! @return true on success, false otherwise
function alerts:release(entity_value, when)
  when = when or os.time()

  local rv = interface.releaseAlert(when, self.periodicity,
    self.type_id, self.severity_id, self.entity_type_id, entity_value)

  if(rv ~= nil) then
    if(rv.success and rv.rowid) then
      local res = interface.queryAlertsRaw("SELECT alert_json", string.format("WHERE rowid=%u", rv.rowid))

      if((res ~= nil) and (#res == 1)) then
        local msg = res[1].alert_json

        local message = {
          ifid = interface.getId(),
          entity_type = self.entity_type_id,
          entity_value = entity_value,
          type = self.entity_type_id,
          severity = self.severity_id,
          message = msg,
          tstamp = when,
          action = "release",
         }

         alert_endpoints.dispatchNotification(message, json.encode(message))
      end
    end
  end

  return(rv.success)
end

-- ##############################################

function alerts.parseAlert(metadata)
  local alert_id = makeAlertId(metadata.alert_type, metadata.alert_subtype, metadata.alert_periodicity, metadata.alert_entity)

  if known_alerts[alert_id] then
    return(known_alerts[alert_id])
  end

  -- new alert
  return(alerts:newAlert({
    entity = alertEntityRaw(metadata.alert_entity),
    type = alertTypeRaw(metadata.alert_type),
    severity = alertSeverityRaw(metadata.alert_severity),
    periodicity = tonumber(metadata.alert_periodicity),
    subtype = metadata.alert_subtype,
  }))
end

-- ##############################################

-- TODO unify alerts and metadataications format
function alerts.parseNotification(metadata)
  local alert_id = makeAlertId(alertType(metadata.type), metadata.alert_subtype, metadata.alert_periodicity, alertEntity(metadata.entity_type))

  if known_alerts[alert_id] then
    return(known_alerts[alert_id])
  end

  -- new alert
  return(alerts:newAlert({
    entity = metadata.entity_type,
    type = metadata.type,
    severity = metadata.severity,
    periodicity = metadata.periodicity,
    subtype = metadata.subtype,
  }))
end

-- ##############################################

function get_alert_triggered_key(type_info)
  return(string.format("%d_%s", type_info.alert_type.alert_id, type_info.alert_subtype or ""))
end

-- ##############################################

local function enqueueAlertEvent(alert_event)
  local event_json = json.encode(alert_event)

  ntop.rpushCache(ALERTS_EVENTS_QUEUE, event_json, MAX_NUM_ENQUEUED_ALERTS_EVENTS)

  return(true)
end

-- ##############################################

-- Performs the trigger/release asynchronously.
-- This is necessary both to avoid paying the database io cost inside
-- the other scripts and as a necessity to avoid a deadlock on the
-- host hash in the host.lua script
function alerts.processPendingAlertEvents(deadline)
  while(true) do
    local event_json = ntop.lpopCache(ALERTS_EVENTS_QUEUE)

    if(not event_json) then
      break
    end

    local event = json.decode(event_json)
    local to_call

    interface.select(tostring(event.ifid))

    if(event.action == "release") then
      to_call = interface.releaseAlert
    else
      to_call = interface.triggerAlert
    end

    rv = to_call(
      event.tstamp, event.granularity,
      event.type, event.severity,
      event.entity_type, event.entity_value,
      event.message, event.subtype)

    if(rv.success) then
      alert_endpoints.dispatchNotification(event, event_json)
    end

    if(os.time() > deadline) then
      break
    end
  end
end

-- ##############################################

-- TODO: remove the "new_" prefix and unify with other alerts

--! @brief Trigger an alert of given type on the entity
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @note The actual trigger is performed asynchronously
--! @return true on success, false otherwise
function alerts.new_trigger(entity_info, type_info, when)
  when = when or os.time()
  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or nil

  if(granularity_id ~= nil) then
    local triggered = true
    local alert_key_name = get_alert_triggered_key(type_info)

    if((host.storeTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("host"))) then
      triggered = host.storeTriggeredAlert(alert_key_name, granularity_id)
    elseif((interface.storeTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("interface"))) then
      triggered = interface.storeTriggeredAlert(alert_key_name, granularity_id)
    elseif((network.storeTriggerAlert) and (entity_info.alert_entity.entity_id == alertEntity("network"))) then
      triggered = network.storeTriggerAlert(alert_key_name, granularity_id)
    end

    if(not triggered) then
      return(false)
    end
  end

  local alert_json = json.encode(type_info.alert_type_params)
  local action = ternary((granularity_id ~= nil), "engaged", "stored")

  local alert_event = {
    ifid = interface.getId(),
    granularity = granularity_sec,
    entity_type = entity_info.alert_entity.entity_id,
    entity_value = entity_info.alert_entity_val,
    type = type_info.alert_type.alert_id,
    severity = type_info.alert_type.severity.severity_id,
    message = alert_json,
    subtype = type_info.alert_subtype or "",
    tstamp = when,
    action = action,
  }

  return(enqueueAlertEvent(alert_event))
end

-- ##############################################

--! @brief Release an alert of given type on the entity
--! @param entity_info data returned by one of the entity_info building functions
--! @param type_info data returned by one of the type_info building functions
--! @param when (optional) the time when the release event occurs
--! @note The actual release is performed asynchronously
--! @return true on success, false otherwise
function alerts.new_release(entity_info, type_info)
  when = when or os.time()
  local granularity_sec = type_info.alert_granularity and type_info.alert_granularity.granularity_seconds or 0
  local granularity_id = type_info.alert_granularity and type_info.alert_granularity.granularity_id or nil

  if(granularity_id ~= nil) then
    local released = true
    local alert_key_name = get_alert_triggered_key(type_info)

    if((host.releaseTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("host"))) then
      triggered = host.releaseTriggeredAlert(alert_key_name, granularity_id)
    elseif((interface.releaseTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("interface"))) then
      triggered = interface.releaseTriggeredAlert(alert_key_name, granularity_id)
    elseif((network.releaseTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("network"))) then
      triggered = network.releaseTriggeredAlert(alert_key_name, granularity_id)
    end

    if(not released) then
      return(false)
    end
  end

  local alert_event = {
    ifid = interface.getId(),
    granularity = granularity_sec,
    entity_type = entity_info.alert_entity.entity_id,
    entity_value = entity_info.alert_entity_val,
    type = type_info.alert_type.alert_id,
    severity = type_info.alert_type.severity.severity_id,
    message = alert_json,
    subtype = type_info.alert_subtype or "",
    tstamp = when,
    action = "release",
  }

  return(enqueueAlertEvent(alert_event))
end

-- ##############################################
-- entity_info building functions
-- ##############################################

function alerts.hostAlertEntity(hostip, hostvlan)
  return {
    alert_entity = alert_consts.alert_entities.host,
    alert_entity_val = hostinfo2hostkey({ip = hostip, vlan = hostvlan}, nil, true)
  }
end

-- ##############################################

function alerts.interfaceAlertEntity(ifid)
  return {
    alert_entity = alert_consts.alert_entities.interface,
    alert_entity_val = string.format("iface_%d", ifid)
  }
end

-- ##############################################

function alerts.networkAlertEntity(network_cidr)
  return {
    alert_entity = alert_consts.alert_entities.network,
    alert_entity_val = network_cidr
  }
end

-- ##############################################
-- type_info building functions
-- ##############################################

function alerts.thresholdCrossType(granularity, metric, value, operator, threshold)
  local res = {
    alert_type = alert_consts.alert_types.threshold_cross,
    alert_subtype = string.format("%s_%s", granularity, metric),
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {
      metric = metric, value = value,
      operator = operator, threshold = threshold,
    }
  }
  return(res)
end

-- ##############################################

function alerts.load_check_modules(subdir)
  local checks_dir = os_utils.fixPath(ALERT_CHECKS_MODULES_BASEDIR .. "/" .. subdir)
  local available_modules = {}

  package.path = checks_dir .. "/?.lua;" .. package.path

  for fname in pairs(ntop.readdir(checks_dir)) do
    if(ends(fname, ".lua")) then
      local modname = string.sub(fname, 1, string.len(fname) - 4)
      local check_module = require(modname)

      if(check_module.check_function ~= nil) then
        available_modules[fname] = check_module
      end
    end
  end

  return(available_modules)
end

-- ##############################################

function alerts.check_threshold_cross(granularity, function_name, alert_entity, value, threshold_config)
  local alarmed = false

  local threshold_edge = tonumber(threshold_config.edge)

  if(do_trace) then print("[Alert @ "..granularity.."] ".. alert_entity.alert_entity_val .." ["..function_name.."]\n") end

  if(threshold_config.operator == "lt") then
    if(value < threshold_edge) then alarmed = true end
  else
    if(value > threshold_edge) then alarmed = true end
  end

  if(alarmed) then
    if(do_trace) then print("Trigger alert [value: "..tostring(value).."]\n") end

    return(alerts.new_trigger(
      alert_entity,
      alerts.thresholdCrossType(granularity, function_name, value, threshold_config.operator, threshold_edge)
    ))
  else
    if(do_trace) then print("DON'T trigger alert [value: "..tostring(value).."]\n") end

    return(alerts.new_release(
      alert_entity,
      alerts.thresholdCrossType(granularity, function_name, value, threshold_config.operator, threshold_edge)
    ))
  end
end

-- ##############################################

local function delta_val(reg, metric_name, granularity, curr_val)
   local granularity_num = granularity2id(granularity)
   local key = string.format("%s:%s", metric_name, granularity_num)

   -- Read cached value and purify it
   local prev_val = reg.getCachedAlertValue(key, granularity_num)
   prev_val = tonumber(prev_val) or 0
   -- Save the value for the next round
   reg.setCachedAlertValue(key, tostring(curr_val), granularity_num)

   -- Compute the delta
   return curr_val - prev_val
end

-- ##############################################

function alerts.host_delta_val(metric_name, granularity, curr_val)
  return(delta_val(host --[[ the host Lua reg ]], metric_name, granularity, curr_val))
end

function alerts.interface_delta_val(metric_name, granularity, curr_val)
  return(delta_val(interface --[[ the interface Lua reg ]], metric_name, granularity, curr_val))
end

function alerts.network_delta_val(metric_name, granularity, curr_val)
  return(delta_val(network --[[ the network Lua reg ]], metric_name, granularity, curr_val))
end

-- ##############################################

function alerts.application_bytes(info, application_name)
   local curr_val = 0

   if info["ndpi"] and info["ndpi"][application_name] then
      curr_val = info["ndpi"][application_name]["bytes.sent"] + info["ndpi"][application_name]["bytes.rcvd"]
   end

   return curr_val
end

-- ##############################################

return(alerts)

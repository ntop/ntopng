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

local MAX_NUM_ENQUEUED_ALERTS_EVENTS = 1024
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
    self.type_id, self.subtype or "", self.severity_id,
    self.entity_type_id, entity_value, msg)

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
    self.type_id, self.subtype or "", self.severity_id, self.entity_type_id, entity_value)

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

local function get_alert_triggered_key(type_info)
  return(string.format("%d@%s", type_info.alert_type.alert_id, type_info.alert_subtype or ""))
end

-- ##############################################

function alerts.triggerIdToAlertType(trigger_id)
  local parts = string.split(trigger_id, "@")

  if((parts ~= nil) and (#parts == 2)) then
    -- alert_type, alert_subtype
    return tonumber(parts[1]), parts[2]
  end
end

-- ##############################################

local function enqueueAlertEvent(alert_event)
  local event_json = json.encode(alert_event)
  local trim = nil

  if(ntop.llenCache(ALERTS_EVENTS_QUEUE) > MAX_NUM_ENQUEUED_ALERTS_EVENTS) then
    trim = math.ceil(MAX_NUM_ENQUEUED_ALERTS_EVENTS/2)
    traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Alerts event queue too long: dropping %u alerts", trim))
  end

  ntop.rpushCache(ALERTS_EVENTS_QUEUE, event_json, trim)
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
      event.type, event.subtype or "", event.severity,
      event.entity_type, event.entity_value,
      event.message) -- event.message: nil for "release"

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
  local subtype = type_info.alert_subtype or ""
  local alert_json = json.encode(type_info.alert_type_params)

  if(granularity_id ~= nil) then
    local triggered = true
    local alert_key_name = get_alert_triggered_key(type_info)
    local params = {alert_key_name, granularity_id,
      type_info.alert_type.severity.severity_id, type_info.alert_type.alert_id,
      subtype, alert_json
    }

    if((host.storeTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("host"))) then
      triggered = host.storeTriggeredAlert(table.unpack(params))
    elseif((interface.storeTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("interface"))) then
      triggered = interface.storeTriggeredAlert(table.unpack(params))
    elseif((network.storeTriggeredAlert) and (entity_info.alert_entity.entity_id == alertEntity("network"))) then
      triggered = network.storeTriggeredAlert(table.unpack(params))
    end

    if(not triggered) then
      if(do_trace) then print("[DON'T Trigger alert (already triggered?) @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title.."\n") end
      return(false)
    end
  end

  local action = ternary((granularity_id ~= nil), "engaged", "stored")

  local alert_event = {
    ifid = interface.getId(),
    granularity = granularity_sec,
    entity_type = entity_info.alert_entity.entity_id,
    entity_value = entity_info.alert_entity_val,
    type = type_info.alert_type.alert_id,
    severity = type_info.alert_type.severity.severity_id,
    message = alert_json,
    subtype = subtype,
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
      if(do_trace) then print("[DON'T Release alert (already not triggered?) @ "..granularity_sec.."] "..
        entity_info.alert_entity_val .."@"..type_info.alert_type.i18n_title.."\n") end
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
    alert_granularity = alert_consts.alerts_granularities[granularity],
    alert_type_params = {
      metric = metric, value = value,
      operator = operator, threshold = threshold,
    }
  }
  return(res)
end

-- ##############################################

function alerts.anomalyType(anomal_name, alert_type, value, threshold)
  local res = {
    alert_type = alert_type,
    alert_subtype = anomal_name,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {
      value = value,
      threshold = threshold,
    }
  }

  return(res)
end

-- ##############################################

function alerts.load_check_modules(subdir, str_granularity)
  local checks_dir = os_utils.fixPath(ALERT_CHECKS_MODULES_BASEDIR .. "/" .. subdir)
  local available_modules = {}

  package.path = checks_dir .. "/?.lua;" .. package.path

  for fname in pairs(ntop.readdir(checks_dir)) do
    if ends(fname, ".lua") then
      local modname = string.sub(fname, 1, string.len(fname) - 4)
      local check_module = require(modname)

      if check_module.check_function then
	 if check_module.granularity and str_granularity then
	    -- When the module specify one or more granularities
	    -- at which checks have to be run, the module is only
	    -- loaded after checking the granularity
	    for _, gran in pairs(check_module.granularity) do
	       if gran == str_granularity then
		  available_modules[modname] = check_module
		  break
	       end
	    end
	 else
	    -- When no granularity is explicitly specified
	    -- in the module, then the check it is assumed to
	    -- be run for every granularity and the module is
	    -- always loaded
	    available_modules[modname] = check_module
	 end
      end
    end
  end

  return available_modules
end

-- ##############################################

function alerts.threshold_check_function(params)
  local alarmed = false
  local value = params.check_module.get_threshold_value(params.granularity, params.entity_info)
  local threshold_config = params.alert_config

  local threshold_edge = tonumber(threshold_config.edge)
  local threshold_type = alerts.thresholdCrossType(params.granularity, params.check_module.key, value, threshold_config.operator, threshold_edge)

  if(do_trace) then print("[Alert @ "..params.granularity.."] ".. params.alert_entity.alert_entity_val .." ["..params.check_module.key.."]\n") end

  if(threshold_config.operator == "lt") then
    if(value < threshold_edge) then alarmed = true end
  else
    if(value > threshold_edge) then alarmed = true end
  end

  if(alarmed) then
    if(do_trace) then print("Trigger alert [value: "..tostring(value).."]\n") end

    return(alerts.new_trigger(params.alert_entity, threshold_type))
  else
    if(do_trace) then print("Release alert [value: "..tostring(value).."]\n") end

    return(alerts.new_release(params.alert_entity, threshold_type))
  end
end

-- ##############################################

function alerts.check_anomaly(anomal_name, alert_type, alert_entity, entity_anomalies, anomal_config)
  local anomaly = entity_anomalies[anomal_name] or {value = 0}
  local value = anomaly.value
  local anomaly_type = alerts.anomalyType(anomal_name, alert_type, value, anomal_config.threshold)

  if(do_trace) then print("[Anomaly check] ".. alert_entity.alert_entity_val .." ["..anomal_name.."]\n") end

  if(anomaly ~= nil) then
    if(do_trace) then print("Trigger alert anomaly [value: "..tostring(value).."]\n") end

    return(alerts.new_trigger(alert_entity, anomaly_type))
  else
    if(do_trace) then print("Release alert anomaly [value: "..tostring(value).."]\n") end

    return(alerts.new_release(alert_entity, threshold_type))
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

function alerts.category_bytes(info, category_name)
   local curr_val = 0

   if info["ndpi_categories"] and info["ndpi_categories"][category_name] then
      curr_val = info["ndpi_categories"][category_name]["bytes.sent"] + info["ndpi_categories"][category_name]["bytes.rcvd"]
   end

   return curr_val
end

-- ##############################################

function alerts.threshold_cross_input_builder(gui_conf, input_id, value)
  value = value or {}
  local gt_selected = ternary(value[1] == "gt", ' selected="selected"', '')
  local lt_selected = ternary(value[1] == "lt", ' selected="selected"', '')
  local input_op = "op_" .. input_id
  local input_val = "value_" .. input_id

  return(string.format([[<select name="%s">
  <option value="gt"%s>&gt;</option>
  <option value="lt"%s>&lt;</option>
</select> <input type="number" class="text-right form-control" min="%s" max="%s" step="%s" style="display:inline; width:12em;" name="%s" value="%s"/> <span>%s</span>]],
    input_op, gt_selected, lt_selected,
    gui_conf.field_min or "0", gui_conf.field_max or "", gui_conf.field_step or "1",
    input_val, value[2], i18n(gui_conf.i18n_field_unit))
  )
end

-- ##############################################

return(alerts)

--
-- (C) 2013-19 - ntop.org
--

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")
local alert_endpoints = require("alert_endpoints_utils")

local alerts = {}

-- Just helpers
local str_2_periodicity = {
  ["min"]     = 60,
  ["5mins"]   = 300,
  ["hour"]    = 3600,
  ["day"]     = 86400,
}

local MAX_NUM_PER_MODULE_QUEUED_ALERTS = 1024 -- should match ALERTS_MANAGER_MAX_ENTITY_ALERTS on the AlertsManager

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

--
-- Creates a alert object
--
-- Metadata is a table which contains the following mandatory parameters:
--    - entity: the entity type
--    - type: the type of the alert
--    - severity the alert severity
-- See https://github.com/ntop/ntopng/blob/dev/doc/README.alerts for more details
--
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

function alerts:emit(entity_value, alert_message, when)
  local force = false
  local msg = alert_message
  when = when or os.time()

  if(type(alert_message) == "table") then
    msg = json.encode(alert_message)
  end

  local rv = interface.emitAlert(when, self.periodicity,
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

  return(rv)
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

return(alerts)

--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
local alert_severities = require "alert_severities"

-- ##############################################

local Alert = classes.class()

-- ##############################################

function Alert:init()
end

-- ##############################################

function Alert:format()
   --tprint("base format")
end

-- ##############################################

function Alert:_build_type_info()
   local type_info =  {
      -- Keys necessary for the engine
      alert_type = self.meta,
      subtype = self.subtype,
      granularity = self.granularity,
      score = self.score,
      device_type = self.device_type,
      device_name = self.device_name,
      -- Stuff added in subclasses :init
      alert_type_params = self.alert_type_params or {}
   }

   -- Add the attacker to the alert params (if present)
   if self.attacker then
      type_info.alert_type_params.attacker = self.attacker
   end

   -- Add the victim to the alert params (if present)
   if self.victim then
      type_info.alert_type_params.victim = self.victim
   end

   return type_info
end

-- ##############################################

function Alert:_check_alert_data()
   if self == nil then
      return true
   end

   if self.meta.has_victim and not self.victim then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "alert.alert_error.configuration.no_victim")
      return false
   end

   if self.meta.has_attacker and not self.attacker then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "alert.alert_error.configuration.no_attacker")
      return false
   end

   return true
end

-- ##############################################

function Alert:trigger(entity_info, when, cur_alerts)
   local alerts_api = require "alerts_api"

   if not self._check_alert_data() then
      return
   end

   return alerts_api.trigger(entity_info, self:_build_type_info(), nil, cur_alerts)
end

-- ##############################################

function Alert:release(entity_info, when, cur_alerts)
   local alerts_api = require "alerts_api"

   if not self._check_alert_data() then
      return
   end

   return alerts_api.release(entity_info, self:_build_type_info(), nil, cur_alerts)
end

-- ##############################################

function Alert:store(entity_info)
   local alerts_api = require "alerts_api"

   if not self._check_alert_data() then
      return
   end

   return alerts_api.store(entity_info, self:_build_type_info())
end

-- ##############################################

function Alert:set_score(score)
   self.score = tonumber(score)
end

--@brief Methods to set score defaults, keep them in sync with
-- ntop_defines.h
function Alert:set_score_notice()  self.score = ntop.mapSeverityToScore(alert_severities.notice.severity_id) end
function Alert:set_score_warning() self.score = ntop.mapSeverityToScore(alert_severities.warning.severity_id) end
function Alert:set_score_error()   self.score = ntop.mapSeverityToScore(alert_severities.error.severity_id) end

-- ##############################################

function Alert:set_subtype(subtype)
   self.subtype = subtype
end

-- ##############################################

function Alert:set_granularity(granularity)
   local alert_consts = require "alert_consts"
   self.granularity = alert_consts.alerts_granularities[granularity]
end

-- ##############################################

--@brief Functions to set L2-related data, e.g., device type and name
function Alert:set_device_type(devtype) self.device_type = tonumber(devtype) end
function Alert:set_device_name(devname) self.device_name = tostring(devname) end

-- ##############################################

function Alert:set_attacker(attacker) self.attacker = attacker end
function Alert:set_victim(victim) self.victim = victim end
function Alert:set_origin(origin) self.origin = origin end
function Alert:set_target(target) self.target = target end

-- ##############################################

return Alert

-- ##############################################

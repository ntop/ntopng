--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

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
      severity = self.severity,
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

function Alert:set_severity(severity)
   self.severity = severity
end

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

function Alert:set_attacker(attacker) self.attacker = attacker end
function Alert:set_victim(victim) self.victim = victim end
function Alert:set_origin(origin) self.origin = origin end
function Alert:set_target(target) self.target = target end

-- ##############################################

return Alert

-- ##############################################

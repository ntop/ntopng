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
      alert_subtype = self.alert_subtype,
      alert_granularity = self.alert_granularity,
      alert_severity = self.alert_severity,
      -- Stuff added in subclasses :init
      alert_type_params = self.alert_type_params or {}
   }

   -- Add the attacker to the alert params (if present)
   if self.alert_attacker then
      type_info.alert_type_params.alert_attacker = self.alert_attacker
   end

   -- Add the victim to the alert params (if present)
   if self.alert_victim then
      type_info.alert_type_params.alert_victim = self.alert_victim
   end

   return type_info
end

-- ##############################################

function Alert:_build_flow_status_info()
   local flow_status_info = {
      status_type = {
	 status_key = self.meta.status_key,
	 alert_type = self.meta,
      },
      alert_severity = self.alert_severity,
      -- Stuff added in subclasses :init
      alert_type_params = self.alert_type_params or {}
   }

   if self.alert_attacker ~= nil then
      flow_status_info.alert_type_params.alert_attacker = self.alert_attacker
   end

   if self.alert_victim ~= nil then
      flow_status_info.alert_type_params.alert_victim = self.alert_victim
   end

   return flow_status_info
end

-- ##############################################

function Alert:check_attacker_victim()
   if self == nil then
      return true
   end

   if self.meta ~= nil then
      if self.meta.has_victim ~= nil and self.alert_victim == nil then
         traceError(TRACE_ERROR, TRACE_CONSOLE, "alert.alert_error.configuration.no_victim")
         return false
      end

      if self.meta.has_attacker ~= nil and self.alert_attacker == nil then
         traceError(TRACE_ERROR, TRACE_CONSOLE, "alert.alert_error.configuration.no_attacker")
         return false
      end
   end

   return true
end

-- ##############################################

function Alert:trigger_status(cli_score, srv_score, flow_score)
   local alerts_api = require "alerts_api"
   if self.meta.status_key == nil then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "alert.alert_error.configuration.no_status_key")
   end

   if self.check_attacker_victim() == false then
      return
   end
   
   alerts_api.trigger_status(self:_build_flow_status_info(), self.alert_severity, cli_score, srv_score, flow_score)
end

-- ##############################################

function Alert:trigger(entity_info, when, cur_alerts)
   local alerts_api = require "alerts_api"
   if self.check_attacker_victim() == false then
      return
   end
   
   return alerts_api.trigger(entity_info, self:_build_type_info(), nil, cur_alerts)
end

-- ##############################################

function Alert:release(entity_info, when, cur_alerts)
   local alerts_api = require "alerts_api"
   if self.check_attacker_victim() == false then
      return
   end
   
   return alerts_api.release(entity_info, self:_build_type_info(), nil, cur_alerts)
end

-- ##############################################

function Alert:store(entity_info)
   local alerts_api = require "alerts_api"
   if self.check_attacker_victim() == false then
      return
   end
   
   return alerts_api.store(entity_info, self:_build_type_info())
end

-- ##############################################

function Alert:set_severity(severity)
   self.alert_severity = severity
end

-- ##############################################

function Alert:set_subtype(subtype)
   self.alert_subtype = subtype
end

-- ##############################################

function Alert:set_granularity(granularity)
   local alert_consts = require "alert_consts"
   self.alert_granularity = alert_consts.alerts_granularities[granularity]
end

-- ##############################################

function Alert:set_attacker(attacker) self.alert_attacker = attacker end
function Alert:set_victim(victim) self.alert_victim = victim end
function Alert:set_origin(origin) self.origin = origin end
function Alert:set_target(target) self.target = target end

-- ##############################################

return Alert

-- ##############################################

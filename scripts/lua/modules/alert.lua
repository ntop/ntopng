--
-- (C) 2013-20 - ntop.org
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
   tprint("base format")
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

   return type_info
end

-- ##############################################

function Alert:trigger(entity_info, when, cur_alerts)
   local alerts_api = require "alerts_api"
   return alerts_api.trigger(entity_info, self:_build_type_info(), nil, cur_alerts)
end

-- ##############################################

function Alert:release(entity_info, when, cur_alerts)
   local alerts_api = require "alerts_api"
   return alerts_api.release(entity_info, self:_build_type_info(), nil, cur_alerts)
end

-- ##############################################

function Alert:set_severity(severity)
   self.alert_severity = severity
end

-- ##############################################

function Alert:set_granularity(granularity)
   local alert_consts = require "alert_consts"
   self.alert_granularity = alert_consts.alerts_granularities[granularity]
end

-- ##############################################

function Alert:set_attacker(attacker) self.attacker = attacker end
function Alert:set_victim(victim) self.victim = victim end
function Alert:set_origin(origin) self.origin = origin end
function Alert:set_target(target) self.target = target end

-- ##############################################

return Alert

-- ##############################################

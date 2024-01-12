--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require "dkjson"
local checks = require("checks")
local syslog_utils = require "syslog_utils"

local syslog_module = {
  -- Script category
  category = checks.check_categories.security,

  key = "nbox",

  -- See below
  hooks = {},

  gui = {
    i18n_title = "nbox_collector.title",
    i18n_description = "nbox_collector.description",
    input_builder = "threshold_cross",
    field_max = 7,
    field_min = 0,
    field_operator = "lt"
  },

  default_value = {
    operator = "lt",
    threshold = 5,
  },
}

-- #################################################################

-- The function below is called once (#pragma once)
function syslog_module.setup()
   return true
end

-- #################################################################

-- The function below is called for each received alert
function syslog_module.hooks.handleEvent(syslog_conf, message, host, priority)
   local num_unhandled = 0
   local num_alerts = 0

   local event = json.decode(message)

   if event then

      local event_type = event.event
      local reason = ''

      if event_type == 'stop' and not isEmptyString(event.exit_status) and event.exit_status ~= '0' then 
         event_type = 'failure'
         reason = '[' .. event.exit_status .. ']'
      end

      local message = i18n("alert_messages.nbox_service", {service=event.service_name, host=event.hostname, ip=host, reason=reason})
      if not isEmptyString(event.instance_name) then
         message = i18n("alert_messages.nbox_service_instance", {service=event.service_name, instance=event.instance_name, host=event.hostname, ip=host, reason=reason})
      end

      local is_alert = syslog_utils.handle_system_event(host, event.service_name, event_type, message, priority,
         syslog_conf.nbox.all.script_conf.threshold)

      if is_alert then
         num_alerts = num_alerts + 1
      end
   else
      num_unhandled = num_unhandled + 1
   end

   interface.incSyslogStats(1, 0, num_unhandled, num_alerts, 0, 0)
end 

-- #################################################################

-- The function below is called once (#pragma once)
function syslog_module.teardown()
   return true
end

-- #################################################################

return syslog_module

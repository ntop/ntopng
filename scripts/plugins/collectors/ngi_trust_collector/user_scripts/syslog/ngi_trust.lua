--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "flow_utils"
local json = require ("dkjson")
local alert_severities = require "alert_severities"
local user_scripts = require("user_scripts")

local syslog_module = {
  -- Script category
  category = user_scripts.script_categories.security,

  nedge_exclude = true,

  key = "ngi_trust",

  -- See below
  hooks = {},

  gui = {
    i18n_title = "ngi_trust_collector.title",
    i18n_description = "ngi_trust_collector.description",
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
   local handled = false
   local num_unhandled = 0
   local num_alerts = 0

   -- Examples:
   -- Source      time_now                      last_measurement_timestamp   mac_address    last_state state_unchanged_since        abnormality_grade in_alarm alarm_notifications_sent
   -- "NGI_TRUST","2021-03-05T14: 00:06.759950","2021-03-05T10:55:17.505034","50C7BF010196","1",       "2021-03-05T10:55:17.505034","25.5",           "1",     "0"
   -- "NGI_TRUST","2021-03-05T14: 59:03.960753","2021-03-05T14:40:18.094783","50C7BF010196","0",       "2021-03-05T14:40:18.094783","24.6",           "0",     "0"

   -- Parsing log
   local json_array = "["..message.."]"
   local event = json.decode(json_array)
   if event == nil or type(event) ~= "table" or #event < 9 then
      num_unhandled = num_unhandled + 1
      interface.incSyslogStats(1, 0, num_unhandled, num_alerts, 0, 0)
      return
   end

   local source = event[1]
   local time_now = event[2]
   local last_measurement_timestamp = event[3]
   local mac_address = event[4]
   local last_state = event[5]
   local state_unchanged_since = event[6]
   local abnormality_grade = event[7]
   local in_alarm = event[8]
   local alarm_notifications_sent = event[9]
   local severity = alert_severities.warning

   traceError(TRACE_NORMAL, TRACE_CONSOLE, "NGI Trust Event Time = "..time_now.." "..(ternary(in_alarm == "1", "ENGAGED", "RELEASED")))

   -- TODO build and process alert

   -- local external_host_alert = {}
   -- local alert_json = json.encode(external_host_alert)
   --interface.processHostAlert(alert_json)

   num_alerts = num_alerts + 1
   interface.incSyslogStats(1, 0, num_unhandled, num_alerts, 0, 0)
end 

-- #################################################################

-- The function below is called once (#pragma once)
function syslog_module.teardown()
   return true
end

-- #################################################################

return syslog_module

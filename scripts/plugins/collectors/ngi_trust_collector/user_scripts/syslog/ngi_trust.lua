--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "flow_utils"
local json = require ("dkjson")
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")
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

   local m = split(mac_address)
   if #m < 12 then
      num_unhandled = num_unhandled + 1
      interface.incSyslogStats(1, 0, num_unhandled, num_alerts, 0, 0)
      return
   end
   local mac = m[ 1]..m[ 2]..":"..m[ 3]..m[ 4]..":"..m[ 5]..m[ 6]..":"..
               m[ 7]..m[ 8]..":"..m[ 9]..m[10]..":"..m[11]..m[12]

   alerts_api.store(alerts_api.macEntity(mac), {
      alert_type = alert_consts.alert_types.alert_ngi_trust_event.meta,
      alert_severity = severity,
      alert_type_params = {
         mac = mac,
         time_now = time_now,
         last_measurement_timestamp = last_measurement_timestamp,
	 last_state = last_state,
         state_unchanged_since = state_unchanged_since,
         abnormality_grade = abnormality_grade,
         in_alarm = in_alarm,
         alarm_notifications_sent = alarm_notifications_sent,
      },
   })

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

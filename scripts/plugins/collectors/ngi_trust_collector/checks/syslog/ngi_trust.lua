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
local checks = require("checks")

local syslog_module = {
  -- Script category
  category = checks.check_categories.security,

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
   -- {"identifier": "NGI_TRUST", "time_epoch": 1617790158.720995, "last_measurement_timestamp": 1617790151.016749, "mac_address": "ECB5FA13B46F", "last_state": 1, "state_unchanged_since": 1617790151.016749, "abnormality_grade": 0.5, "in_alarm": 1, "alarm_notifications_sent": 0}
   -- {"identifier": "NGI_TRUST", "time_epoch": 1617790158.720995, "last_measurement_timestamp": 1617790154.016749, "mac_address": "ECB5FA13B46F", "last_state": 1, "state_unchanged_since": 1617790154.016749, "abnormality_grade": 0.1, "in_alarm": 0, "alarm_notifications_sent": 0}

   -- Parsing log
   local event = json.decode(message)
   if event == nil or type(event) ~= "table" or isEmptyString(event["mac_address"]) then
      num_unhandled = num_unhandled + 1
      interface.incSyslogStats(1, 0, num_unhandled, num_alerts, 0, 0)
      return
   end

   local m = split(event.mac_address)
   if #m == 12 then
      local mac = m[ 1]..m[ 2]..":"..m[ 3]..m[ 4]..":"..m[ 5]..m[ 6]..":"..
                  m[ 7]..m[ 8]..":"..m[ 9]..m[10]..":"..m[11]..m[12]
      event.mac_address = mac
   end

   --traceError(TRACE_NORMAL, TRACE_CONSOLE, "NGI Trust Event")
   --tprint(event)

   local severity = alert_severities.notice
   if event.in_alarm == 1 then
      severity = alert_severities.warning
   end

   alerts_api.store(alerts_api.macEntity(event.mac_address), {
      alert_type = alert_consts.alert_types.alert_ngi_trust_event.meta,
      alert_subtype = event.mac_address.."-"..event.in_alarm.."-"..event.time_epoch, -- TODO add real subtype
      alert_severity = severity,
      alert_type_params = event,
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

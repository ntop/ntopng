--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alerts_api = require "alerts_api"
local user_scripts = require("user_scripts")
local companion_interface_utils = require "companion_interface_utils"

local syslog_module = {
  -- Script category
  category = user_scripts.script_categories.security,

  key = "host_log",

  -- See below
  hooks = {},

  gui = {
    i18n_title = "host_log_collector.title",
    i18n_description = "host_log_collector.description",
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
  
local syslog_facility = {
   [0] = "kernel messages",
   [1] = "user-level messages",
   [2] = "mail system",
   [3] = "system daemons",
   [4] = "**security/authorization messages",
   [5] = "messages generated internally by syslog",
   [6] = "line printer subsystem",
   [7] = "network news subsystem",
   [8] = "UUCP subsystem",
   [9] = "clock daemon",
   [10] = "security/authorization messages",
   [11] = "FTP daemon",
   [12] = "NTP subsystem",
   [13] = "log audit",
   [14] = "log alert",
   [15] = "clock daemon",
}

local syslog_level = {
   [0] = "EMERGENCY",
   [1] = "ALERT",
   [2] = "CRITICAL",
   [3] = "ERROR",
   [4] = "WARNING",
   [5] = "NOTICE",
   [6] = "INFORMATIONAL",
   [7] = "DEBUG",
}

-- #################################################################

-- The function below is called once (#pragma once)
function syslog_module.setup()
   return true
end

-- #################################################################

-- The function below returns a subtype for the log based on a simple hash
local function getLogSubtype(line)
   local hash = 0
   for i = 1, #line do
    hash = hash + line:byte(i)
   end
   return tostring(hash)
end

-- #################################################################

-- The function below is called for each received alert
function syslog_module.hooks.handleEvent(syslog_conf, message, host, priority)
   -- Priority = Facility * 8 + Level
   local facility = math.floor(priority / 8)
   local level = priority - (facility * 8)

   local facility_name = syslog_facility[facility] or ""
   local level_name = syslog_level[level] or ""

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "[host="..host.."][facility="..facility_name.."][level="..level_name.."][message="..message.."]")

   if isEmptyString(host) then
      return
   end

   -- Discard info messages
   if level > syslog_conf.host_log.all.script_conf.threshold then
      return
   end

   local entity = alerts_api.hostAlertEntity(host, 0)

   local severity = alert_severities.notice
   if level <= 3 then
      severity = alert_severities.error
   elseif level <= 4 then
      severity = alert_severities.warning
   end

   local type_info = alert_consts.alert_types.alert_host_log.create(
      getLogSubtype(message),
      severity,
      host,
      level_name,
      facility_name,
      message)

   -- Deliver alert
   alerts_api.store(entity, type_info)

   -- Deliver to companion if any
   local companion_of = companion_interface_utils.getCurrentCompanionOf(interface.getId())
   local curr_iface = tostring(interface.getId())
   for _, m in pairs(companion_of) do
      interface.select(m)
      alerts_api.store(entity, type_info)
   end
   interface.select(curr_iface)

end 

-- #################################################################

-- The function below is called once (#pragma once)
function syslog_module.teardown()
   return true
end

-- #################################################################

return syslog_module

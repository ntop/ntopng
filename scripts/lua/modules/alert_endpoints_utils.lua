--
-- (C) 2013-20 - ntop.org
--

local alert_endpoints = {}

package.path = dirs.installdir .. "/scripts/lua/modules/alert_endpoints/?.lua;" .. package.path

local alert_consts = require("alert_consts")
local plugins_utils = require("plugins_utils")

--
-- Generic alerts external report
--

-- ##############################################

local function getAlertNotificationModules()
   local has_alerts_disabled = (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1")

   if has_alerts_disabled then
      return {}
   end

   local loaded_modules = plugins_utils.getLoadedAlertEndpoints()
   local available_modules = {}

   for _, _module in ipairs(loaded_modules) do
      local modname = _module.key
      local req_name = modname

      available_modules[#available_modules + 1] = {
         name = modname,
         export_frequency = tonumber(_module.EXPORT_FREQUENCY) or 60,
         export_queue = "ntopng.alerts.modules_notifications_queue." .. modname,
         ["module"] = _module,
      }
   end

   return available_modules
end

-- ##############################################

local modules = nil

local function loadModules()
   if not modules then
      modules = getAlertNotificationModules()
   end

   return(modules)
end

-- ##############################################

function alert_endpoints.getModules()
   loadModules()
  
   local modules_by_name = {}

   for _, m in ipairs(modules) do
      modules_by_name[m.name] = m
   end

   return modules_by_name
end

-- ##############################################

function alert_endpoints.getSeverityLabels()
   return({i18n("prefs.errors"), i18n("prefs.errors_and_warnings"), i18n("prefs.all")})
end

-- ##############################################

function alert_endpoints.getSeverityValues()
   return({"error", "warning", "info"})
end

-- ##############################################

return(alert_endpoints)

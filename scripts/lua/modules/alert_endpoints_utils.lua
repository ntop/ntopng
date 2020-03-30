--
-- (C) 2013-20 - ntop.org
--

local alert_endpoints = {}

package.path = dirs.installdir .. "/scripts/lua/modules/alert_endpoints/?.lua;" .. package.path

local alert_consts = require("alert_consts")
local plugins_utils = require("plugins_utils")

--
-- Generic alerts extenral report
--
-- Guidelines:
--
--  - modules are enabled with the getAlertNotificationModuleEnableKey key
--  - module severity is defined with the getAlertNotificationModuleSeverityKey key
--

-- ##############################################

function alert_endpoints.getAlertNotificationModuleEnableKey(module_name, short)
   if module_name == "syslog" and ntop.getPref("ntopng.prefs.alerts_syslog") ~= "" then
      -- For backward compatibility
      if short then
	 return "alerts_syslog"
      else
	 return "ntopng.prefs.alerts_syslog"
      end
   end

   local short_k = "alerts." .. module_name .. "_notifications_enabled"

   if short then
      return short_k
   else
      return "ntopng.prefs." .. short_k
   end
end

-- ##############################################

function alert_endpoints.getAlertNotificationModuleSeverityKey(module_name, short)
   local short_k = "alerts." .. module_name .. "_severity"

   if short then
      return short_k
   else
      return "ntopng.prefs." .. short_k
   end
end

-- ##############################################

local function getEnabledAlertNotificationModules()
   local has_alerts_disabled = (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1")

   if has_alerts_disabled then
      return {}
   end

   local available_modules = plugins_utils.getLoadedAlertEndpoints()
   local enabled_modules = {}

   for _, _module in ipairs(available_modules) do
      local modname = _module.key
      local module_enabled = ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey(modname))
      local min_severity = ntop.getPref(alert_endpoints.getAlertNotificationModuleSeverityKey(modname))
      local req_name = modname

      if module_enabled == "1" then
         if isEmptyString(min_severity) then
            min_severity = _module.DEFAULT_SEVERITY or "warning"
         end

         enabled_modules[#enabled_modules + 1] = {
            name = modname,
            severity = min_severity,
            export_frequency = tonumber(_module.EXPORT_FREQUENCY) or 60,
            export_queue = "ntopng.alerts.modules_notifications_queue." .. modname,
            ["module"] = _module,
         }
      end
   end

   return enabled_modules
end

-- ##############################################

local modules = nil

local function loadModules()
  if modules == nil then
    modules = getEnabledAlertNotificationModules()
  end

  return(modules)
end

-- ##############################################

function alert_endpoints.dispatchNotification(message, json_message)
   loadModules()

   for _, m in ipairs(modules) do
      if tonumber(message.alert_severity) >= alertSeverity(m.severity) then
         ntop.rpushCache(m.export_queue, json_message, alert_consts.MAX_NUM_QUEUED_ALERTS_PER_MODULE)
      end
   end
end

-- ##############################################

function alert_endpoints.processNotifications(now, periodic_frequency)
  loadModules()

  -- Process the alerts export. NOTE: endpoints are sorted by priority (higher priority first)
  for _, m in ipairs(modules) do
    if force_export or ((now % m.export_frequency) < periodic_frequency) then

       local rv = m.module.dequeueAlerts(m.export_queue)

       if not rv.success then
          local msg = rv.error_message or "Unknown Error"

          -- TODO: generate alert
          traceError(TRACE_ERROR, TRACE_CONSOLE, "Error while sending notifications via " .. m.name .. " module: " .. msg)
       end
    end
  end
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

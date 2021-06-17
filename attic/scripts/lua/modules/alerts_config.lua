--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_consts     = require "alert_consts"
local alert_severities = require "alert_severities"
local json             = require "dkjson"

-- ##############################################

local alerts_config = {}

-- ##############################################

local CONFIGSET_KEY = "ntopng.prefs.alerts_config.configset_v1" -- Keep in sync with ntop_defines.h FLOW_CALLBACKS_CONFIG

-- ##############################################

local function saveConfigset(configset)
   local v = json.encode(configset)
   ntop.setCache(CONFIGSET_KEY, v)

   -- Reload the periodic scripts as the configuration has changed
   ntop.reloadPeriodicScripts()

   -- TODO: Reload flow alerts in C++
   -- ntop.reloadFlowAlerts()

   return true
end

-- ##############################################

local cached_config_set = nil

-- Return the default config set
-- Note: Other config sets are deprecated
function alerts_config.getConfigset()
   if not cached_config_set then
      cached_config_set = json.decode(ntop.getCache(CONFIGSET_KEY))
   end

   return cached_config_set
end

-- ##############################################

-- @brief Initializes a default configuration for checks
-- @param overwrite If true, a possibly existing configuration is overwritten with default values
function alerts_config.initDefaultConfig()
   -- Current (possibly not-existing, not yet created configset)
   local configset = alerts_config.getConfigset() or {}

   for alert_type, alert in pairs(alert_consts.alert_types) do
      -- Alert metadata, including the alert key
      local meta = alert.meta

      if not configset[alert_type] then
	 -- This is a new alert, prepare to fill it with defaults
	 configset[alert_type] = {}
      end

      -- Populate config severity
      if not configset[alert_type]["severity"] then
	 -- No severity found in the configuration, let's add a default
	 local alert_severity = meta.default and meta.default.severity

	 if not alert_severity then
	    traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("Alert %s has no default severity, assuming 'notice'", alert_type))
	    alert_severity = alert_severities.notice
	 end

	 configset[alert_type]["severity"] = alert_severity.severity_id
      end

      -- Populate config filters
      if not configset[alert_type]["filters"] then
	 -- No filters found in the configuration, let's see if there are default filters and add them
	 local alert_filters = meta.default and meta.default.filters

	 configset[alert_type]["filters"] = alert_filters or {}
      end

      saveConfigset(configset)
   end
end

-- ##############################################

function alerts_config.resetConfigset()
   cached_config_set = nil
   ntop.delCache(CONFIGSET_KEY)
   alerts_config.initDefaultConfig()

   return(true)
end

-- ##############################################

return(alerts_config)

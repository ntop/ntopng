--
-- (C) 2019-20 - ntop.org
--

local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")
local cpu_utils = require("cpu_utils")

local script = {
  -- Script category
  category = user_scripts.script_categories.system,

  -- This module is enabled by default
  default_enabled = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_dashboard.alerts_ts",
    i18n_description = "alerts_dashboard.alerts_ts_description",
  },
}

-- ##############################################

function script.hooks.min(params)
   if params.ts_enabled then
      local system_host_stats = cpu_utils.systemHostStats()

      ts_utils.append("process:num_alerts",
		      {
			 ifid = getSystemInterfaceId(),
			 dropped_alerts = system_host_stats.dropped_alerts or 0,
			 written_alerts = system_host_stats.written_alerts or 0,
			 alerts_queries = system_host_stats.alerts_queries or 0
		      }, when, verbose)
   end
end

-- ##############################################

return script

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
    i18n_title = "alerts_dashboard.memory_ts",
    i18n_description = "alerts_dashboard.memory_ts_description",
  },
}

-- ##############################################

function script.hooks.min(params)
   if params.ts_enabled then
      local system_host_stats = cpu_utils.systemHostStats()

      if((system_host_stats.mem_ntopng_resident ~= nil) and
	 (system_host_stats.mem_ntopng_virtual ~= nil)) then
	 ts_utils.append("process:resident_memory",
			 {
			    ifid = getSystemInterfaceId(),
			    resident_bytes = system_host_stats.mem_ntopng_resident * 1024,
			 }, when, verbose)
      end
   end
end

-- ##############################################

return script

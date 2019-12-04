--
-- (C) 2019 - ntop.org
--

local ts_utils = require("ts_utils_core")

local script = {
  -- This module is enabled by default
  default_enabled = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},
}

-- ##############################################

function script.hooks.min(params)
   if params.ts_enabled then
      local system_host_stats = ntop.systemHostStat()

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

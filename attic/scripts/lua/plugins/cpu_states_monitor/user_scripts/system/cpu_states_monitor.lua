--
-- (C) 2019-21 - ntop.org
--

local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")
local ts_utils = require("ts_utils_core")
local alerts_api = require("alerts_api")
local json = require "dkjson"

local STATES_KEY = "ntopng.cache.cpu_states_monitor.last"

local script = {
  -- Script category
  category = user_scripts.script_categories.system,

  -- This module is enabled by default
  default_enabled = not ntop.isWindows(),

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},

  gui = {
    i18n_title = "system_stats.cpu_states_monitor",
    i18n_description = "system_stats.cpu_states_monitor_description",
  },
}

-- ##############################################

-- Computes the CPU states in percentage
function script.hooks.min(params)
   if not ntop.isWindows() then
      local f = io.open("/proc/stat", "r")
      local res

      if f then
         -- The first line of the file contains cpu jiffies
         -- See http://man7.org/linux/man-pages/man5/proc.5.html for the meaning of each column
         local cpu = f:read("*line")

         if not isEmptyString(cpu) then
            -- Parse the cpu string using an sscanf-like pattern
            local user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice = cpu:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
            local states = {user = user, nice = nice, system = system, idle = idle, iowait = iowait, softirq = softirq, steal = steal, guest = guest, guest_nice = guest_nice}

            -- Compute the deltas with reference to the previous values
            local delta_total = 0
            local delta_states = {}
            for state, state_total in pairs(states) do
               local delta = alerts_api.interface_delta_val(script.key..state, params.granularity, state_total or 0)
               delta_states[state] = delta
               delta_total = delta_total + delta
            end

            -- Compute the deltas in percent
	    if delta_total > 0 then
	       local delta_total_pct = 0
	       local delta_states_pct = {}
	       for state, state_delta in pairs(delta_states) do
		  local delta_pct = state_delta / delta_total * 100
		  delta_states_pct[state] = delta_pct
		  delta_total_pct = delta_total_pct + delta_pct
	       end

	       local res = {delta_states_pct = delta_states_pct}
	       ntop.setCache(STATES_KEY, json.encode(res), 120 --[[ keep it for at most 2 minutes --]])

	       -- tprint(cpu)
	       -- tprint(states)
	       -- tprint(delta_states)
	       -- tprint(delta_states_pct)
	       -- tprint(delta_total_pct)
	    end
            -- Cache the cpu value so it can be re-read during next call
         end

         f:close()
      end
   end
end

-- ##############################################

return(script)

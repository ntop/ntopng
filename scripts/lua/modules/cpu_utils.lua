--
-- (C) 2014-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local cpu_utils = {}
local alert_utils = require "alert_utils"

-- #################################

local CPU_STATES_PREV_KEY = "ntopng.cache.system_utils.cpu_states.prev"
local CPU_STATES_DELTA    = "ntopng.cache.system_utils.cpu_states.delta"

-- #################################

-- Save cpu_states (either a delta or an absolute value) in a redis key.
-- The format used is the same as the one used by /proc/stat
local function save_cpu_states(cpu_states, key)
   -- To serialize CPU states use the same format as the one used in /proc/stat
   -- This allows us to re-use the parse function both to read serialized values as well as to read the line directly from /proc/stat

   local cpu_line = string.format("cpu %u %u %u %u %u %u %u %u %u %u",
				  cpu_states["user"] or 0, cpu_states["nice"] or 0, cpu_states["system"] or 0,
				  cpu_states["idle"] or 0, cpu_states["iowait"] or 0, cpu_states["irq"] or 0,
				  cpu_states["softirq"] or 0, cpu_states["steal"] or 0, cpu_states["guest"] or 0,
				  cpu_states["guest_nice"] or 0)

   ntop.setCache(key, cpu_line, 120 --[[ 2 minutes --]])
end

-- #################################

-- Reads a line with the format of /proc/stat and parses the various state values into a table
local function parse_proc_stat_cpu_line(cpu_line)
   -- Parse the cpu string using an sscanf-like pattern
   local user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice = cpu_line:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")

   local states = {
      user = user or 0, nice = nice or 0, system = system or 0,
      idle = idle or 0, iowait = iowait or 0, irq = irq or 0,
      softirq = softirq or 0, steal = steal or 0, guest = guest or 0,
      guest_nice = guest_nice or 0
   }

   return states
end

-- #################################

-- Computes the delta of the current cpu states submitted in cur_states
-- with their previous values
local function compute_cpu_states_delta(cur_states)
   -- Read the previously saved line so it can be compared with the cur_states
   -- to compute the variation
   local prev_cpu_line = ntop.getCache(CPU_STATES_PREV_KEY)
   local states_delta = {}

   -- It there was a previous line...
   if prev_cpu_line and prev_cpu_line ~= "" then
      -- Parse the previous line in its corresponding previous states
      local prev_states = parse_proc_stat_cpu_line(prev_cpu_line)

      -- Now iterate the current states and compute their deltas with reference
      -- to their previous value
      for cur_state, cur_val in pairs(cur_states) do
	 local cur_delta = 0

	 if prev_states[cur_state] then
	    cur_delta = cur_val - prev_states[cur_state]

	    -- Safety check
	    if cur_delta < 0 then
	       cur_delta = 0
	    end
	 end

	 states_delta[cur_state] = math.floor(cur_delta) -- make sure it's an integer
      end

      -- Save the deltas
      save_cpu_states(states_delta, CPU_STATES_DELTA)
   end

   -- Save the current cpu states in the prev key so they will automatically
   -- become previous during the next call
   save_cpu_states(cur_states, CPU_STATES_PREV_KEY)

   return states_delta
end

-- #################################

function cpu_utils.compute_cpu_states()
   if not ntop.isWindows() then
      local f = io.open("/proc/stat", "r")

      if f then
	 -- The first line of the file contains cpu time_spent
	 -- See http://man7.org/linux/man-pages/man5/proc.5.html for the meaning of each column
	 local cpu_line = f:read("*line")

	 if cpu_line and cpu_line ~= "" then
	    local cur_states = parse_proc_stat_cpu_line(cpu_line)
	    local states_delta = compute_cpu_states_delta(cur_states)
	 end

	 f:close()
      end
   end
end

-- #################################

-- Returns all the available cpu states in %
function cpu_utils.get_cpu_states()
   local states_delta_line = ntop.getCache(CPU_STATES_DELTA)

   if states_delta_line and states_delta_line ~= "" then
      -- Parse the delta in its corresponding states
      local delta_states = parse_proc_stat_cpu_line(states_delta_line)

      local total = 0
      for _, delta_val in pairs(delta_states) do
	 total = total + delta_val
      end

      -- Express in percentage
      for state in pairs(delta_states) do
	 if total > 0 then
	    delta_states[state] = delta_states[state] / total * 100
	 else
	    delta_states[state] = 0
	 end
      end

      return delta_states
   end
end

-- #################################

function cpu_utils.systemHostStats()
   local cur_id = interface.getId()
   interface.select(getSystemInterfaceId())

   local system_host_stats =  ntop.systemHostStat()
   system_host_stats["cpu_states"] = cpu_utils.get_cpu_states()
   system_host_stats["engaged_alerts"] = alert_utils.getNumAlerts("engaged", {})

   interface.select(tostring(cur_id))

   return system_host_stats
end

-- #################################

return cpu_utils


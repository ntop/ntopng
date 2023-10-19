--
-- (C) 2019-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

-- ########################################################

local ts_utils = require "ts_utils_core"
local cpu_utils = require "cpu_utils"
local ts_dump = require "ts_5sec_dump_utils"

-- ########################################################

require "ts_5sec"

-- ########################################################

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 12

for i=1,num_runs do
   if(ntop.isShutdown()) then break end

   local when = os.time()
   
   cpu_utils.compute_cpu_states()

   -- Update CPU load timeseries
   if(ntop.getPref("ntopng.prefs.system_probes_timeseries") ~= "0") then
      local cpu_load = ntop.refreshCPULoad()

      if(cpu_load ~= nil) then
	 ts_utils.append("system:cpu_load", {ifid = interface.getId(), load_percentage = cpu_load}, when)
      end
      
      ts_dump.dump_cpu_states(interface.getId(), when, cpu_utils.get_cpu_states())
   end
   
   -- ########################################################
   
   if ntop.getPref("ntopng.prefs.internals_rrd_creation") == "1" then
      ts_dump.update_rrd_queue_length(interface.getId(), when)
   end
   
   -- ########################################################
   
   ntop.msleep(5000) -- 5 seconds frequency
end

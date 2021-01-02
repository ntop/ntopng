--
-- (C) 2019-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
local ts_utils = require "ts_utils_core"
require "ts_5sec"
local cpu_utils = require "cpu_utils"
local ts_dump = require "ts_5sec_dump_utils"
local when = os.time()

-- ########################################################

cpu_utils.compute_cpu_states()

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


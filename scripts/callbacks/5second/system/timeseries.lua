--
-- (C) 2019-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path

-- ########################################################

local ts_utils = require "ts_utils_core"
local ts_dump = require "ts_5sec_dump_utils"
local cpu_utils = require "cpu_utils"

-- ########################################################

require "ts_5sec"

-- ########################################################

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 3

for i = 1, num_runs do
    if (ntop.isShuttingDown()) then
        break
    end

    local when = os.time()
    cpu_utils.compute_cpu_states()

    -- Update CPU load timeseries
    if (ntop.getPref("ntopng.prefs.system_probes_timeseries") ~= "0") then
        ts_dump.dump_cpu_stats(interface.getId(), when)
    end

    -- ########################################################

    if ntop.getPref("ntopng.prefs.internals_rrd_creation") == "1" then
        ts_dump.update_rrd_queue_length(interface.getId(), when)
    end

    -- ########################################################

    ntop.msleep(5000) -- 5 seconds frequency
end
--
-- (C) 2019-24 - ntop.org
--
-- ########################################################
local ts_utils = require("ts_utils_core")
local ts_dump = {}

-- ########################################################

function ts_dump.update_rrd_queue_length(ifid, when)
    if ts_utils.getDriverName() == "rrd" then
        ts_utils.append("iface:ts_queue_length", {
            ifid = ifid,
            num_ts = interface.rrd_queue_length(ifid) or 0
        }, when)
    end
end

-- ########################################################

function ts_dump.dump_cpu_stats(ifid, when)
    local cpu_utils = require "cpu_utils"
    local cpu_states = cpu_utils.get_cpu_states()
		local cpu_load = ntop.refreshCPULoad()
    
		if cpu_states then
        ts_utils.append("system:cpu_states", {
            ifid = ifid,
            iowait_pct = cpu_states["iowait"],
            active_pct = cpu_states["user"] + cpu_states["system"] + cpu_states["nice"] + cpu_states["irq"] +
                cpu_states["softirq"] + cpu_states["guest"] + cpu_states["guest_nice"],
            idle_pct = cpu_states["idle"] + cpu_states["steal"]
        }, when)
    end

		if cpu_load then
			ts_utils.append("system:cpu_load", {
					ifid = ifid,
					load_percentage = cpu_load
			}, when)			
		end
end

-- ########################################################

return ts_dump

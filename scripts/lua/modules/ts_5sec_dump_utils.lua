--
-- (C) 2019-26 - ntop.org
--
-- ########################################################
local ts_utils = require("ts_utils_core")
local ts_dump = {}

-- ########################################################

function ts_dump.update_ts_queue_stats(ifid, when)
   local qlen, qdrops
   
   if ts_utils.getDriverName() == "rrd" then
      qlen   = interface.rrd_queue_length() or 0
      qdrops = interface.ts_queue_drops()
   else
      if ts_utils.getDriverName() == "clickhousets" then
	 qlen   = interface.chTsQueueLen() or 0
	 qdrops = interface.ts_queue_drops()
      else
	 return -- any other timeseries driver
      end      
   end

   ts_utils.append("iface:ts_queue_length", { ifid = ifid, num_ts = qlen },   when)
   ts_utils.append("iface:ts_queue_drops",  { ifid = ifid, num_ts = qdrops }, when)   
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

function ts_dump.dump_thread_cpu_stats(ifid, when)
    local threads_info = ntop.threadsInfo()
    if not threads_info then return end

    for thread_name, stats in pairs(threads_info) do
        local cpu_pct = stats["cpu_utilization_pct"]
        if cpu_pct ~= nil then
            ts_utils.append("system:thread_cpu_load", {
                ifid       = ifid,
                thread_name = thread_name,
                cpu_utilization_pct = cpu_pct
            }, when)
        end
    end
end

-- ########################################################

return ts_dump

--
-- (C) 2019-22 - ntop.org
--

-- ########################################################

local ts_utils = require("ts_utils_core")
local ts_dump = {}

-- ########################################################

function ts_dump.update_rrd_queue_length(ifid, when)
   if ts_utils.getDriverName() == "rrd" then
      ts_utils.append("iface:ts_queue_length",
		      {
			 ifid = ifid,
			 num_ts = interface.rrd_queue_length(ifid) or 0
		      },
		      when)
   end
end

-- ########################################################

function ts_dump.dump_cpu_states(ifid, when, cpu_states)
   if cpu_states then
      ts_utils.append("system:cpu_states",
		      {
			 ifid = ifid,
			 iowait_pct = cpu_states["iowait"],
			 active_pct = cpu_states["user"] + cpu_states["system"] + cpu_states["nice"] + cpu_states["irq"] + cpu_states["softirq"] + cpu_states["guest"] + cpu_states["guest_nice"],
			 idle_pct = cpu_states["idle"] + cpu_states["steal"],
		      },
		      when)
   end
end

-- ########################################################

return ts_dump

--
-- (C) 2019-21 - ntop.org
--

-- ########################################################

local ts_utils = require("ts_utils_core")
local checks = require("checks")
local ts_dump = {}

-- ########################################################

local function iface_update_periodic_ht_state_update_stats(when, ifid, periodic_ht_state_update_stats)
   local ht_name = "FlowHash"
   local ht_stats = periodic_ht_state_update_stats[ht_name]

   if(ht_stats and ht_stats["stats"]) then
      local num_calls = 0
      local num_ms = 0
      local stats = ht_stats["stats"]

      ts_utils.append("flow_script:skipped_calls", {ifid = ifid,
	 idle = stats.num_skipped_idle,
	 proto_detected = stats.num_skipped_proto_detected,
	 periodic_update = stats.num_skipped_periodic_update
      }, when)

      ts_utils.append("flow_script:pending_calls", {ifid = ifid,
	 proto_detected = stats.num_pending_proto_detected,
	 periodic_update = stats.num_pending_periodic_update
      }, when)

     ts_utils.append("flow_script:lua_duration", {ifid = ifid, num_ms = stats["tot_duration_ms"]}, when)
     ts_utils.append("flow_script:successful_calls", {ifid = ifid, num_calls = stats["num_successful"]}, when)
   end
end

-- ########################################################

local function update_checks_stats(when, ifid, verbose)
  -- NOTE: interface/host/network scripts are monitored in minute.lua
  local all_scripts = {
    flow = checks.script_types.flow,
  }

  checks.ts_dump(when, ifid, verbose, "flow_check", all_scripts)
end

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

function ts_dump.run_5sec_dump(ifid, when, periodic_ht_state_update_stats)
   local iface_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0")
   local internals_rrd_creation_enabled = ntop.getPref("ntopng.prefs.internals_rrd_creation") == "1"

   if not iface_rrd_creation_enabled or not internals_rrd_creation_enabled then
      return
   end

   iface_update_periodic_ht_state_update_stats(when, ifid, periodic_ht_state_update_stats)
   update_checks_stats(when, ifid, verbose)
   ts_dump.update_rrd_queue_length(ifid, when)
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

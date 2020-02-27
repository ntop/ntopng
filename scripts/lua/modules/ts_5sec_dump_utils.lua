--
-- (C) 2019-20 - ntop.org
--

-- ########################################################

local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")
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

local function update_user_scripts_stats(when, ifid, verbose)
  -- NOTE: interface/host/network scripts are monitored in minute.lua
  local all_scripts = {
    flow = user_scripts.script_types.flow,
  }

  user_scripts.ts_dump(when, ifid, verbose, "flow_user_script", all_scripts)
end

-- ########################################################

function ts_dump.run_5sec_dump(ifid, when, periodic_ht_state_update_stats)
   local iface_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.ifid_"..ifid..".interface_rrd_creation") ~= "false")
      and (ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0")
   local user_scripts_rrd_creation_enabled = ntop.getPref("ntopng.prefs.user_scripts_rrd_creation") == "1"

   if not iface_rrd_creation_enabled or not user_scripts_rrd_creation_enabled then
      return
   end

   iface_update_periodic_ht_state_update_stats(when, ifid, periodic_ht_state_update_stats)
   update_user_scripts_stats(when, ifid, verbose)
end

-- ########################################################

return ts_dump

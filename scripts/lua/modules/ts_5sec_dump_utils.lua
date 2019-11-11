-- ########################################################

local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")
local ts_dump = {}

-- ########################################################

function ts_dump.iface_update_periodic_ht_state_update_stats(when, ifid, periodic_ht_state_update_stats)
   for ht_name, ht_stats in pairs(periodic_ht_state_update_stats) do
      local num_calls = 0
      local num_ms = 0
      local stats = ht_stats["stats"]

      if stats then
	 if stats["num_calls"] then
	    num_calls = stats["num_calls"]
	 end
	 if stats["tot_duration_ms"] then
	    num_ms = stats["tot_duration_ms"]
	 end

	 if stats.num_skipped_idle ~= nil then
	    ts_utils.append("ht:num_skipped_calls", {ifid = ifid, hash_table = ht_name,
						     idle = stats.num_skipped_idle,
						     proto_detected = stats.num_skipped_proto_detected,
						     periodic_update = stats.num_skipped_periodic_update,
						    }, when, verbose)
	 end
      end

     ts_utils.append("ht:duration", {ifid = ifid, hash_table = ht_name, num_ms = num_ms}, when, verbose)
     ts_utils.append("ht:num_calls", {ifid = ifid, hash_table = ht_name, num_calls = num_calls}, when, verbose)
   end
end

-- ########################################################

function ts_dump.update_user_scripts_stats(when, ifid, verbose)
  -- NOTE: interface/host/network scripts are monitored in minute.lua
  local all_scripts = {
    flow = user_scripts.script_types.flow,
  }

  user_scripts.ts_dump(when, ifid, verbose, "flow_user_script", all_scripts)
end

-- ########################################################

function ts_dump.run_5sec_dump(ifid, periodic_ht_state_update_stats)
   local iface_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.ifid_"..ifid..".interface_rrd_creation") ~= "false")
      and (ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0")
   local when = os.time()

   if not iface_rrd_creation_enabled then
      return
   end

   ts_dump.iface_update_periodic_ht_state_update_stats(when, ifid, periodic_ht_state_update_stats)
   ts_dump.update_user_scripts_stats(when, ifid, verbose)
end

-- ########################################################

return ts_dump
